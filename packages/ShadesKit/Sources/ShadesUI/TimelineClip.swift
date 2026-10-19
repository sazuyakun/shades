import AppKit
import ShadesAudio
import ShadesCommands
import ShadesCore
import ShadesEngine
import ShadesMCP
import SwiftUI

/// A clip on the timeline and what you can do to it: click to select (⌘ adds or removes), drag
/// to move (up or down to another track), drag an edge to trim, or click with the blade to cut.
/// Moves and trims preview live and snap; the edit happens when you let go.
struct TimelineClip: View {

  // MARK: Internal

  let clip: Clip
  let track: Track
  let rows: [Track]
  let scale: TimelineScale
  let settings: TimelineSettings
  let onError: (String) -> Void

  var body: some View {
    let width = scale.x(at: clip.duration) + endDelta - startDelta
    TimelineClipView(
      media: clip.mediaID.flatMap(editor.project.media(withID:)),
      text: clip.text?.text ?? clip.label,
      kind: track.kind,
      isSelected: editor.selection.contains(clip.id),
      isRecentlyChanged: server.activity.recentlyChangedClipIDs.contains(clip.id),
      keyframeSpots: Set(clip.keyframes.map {
        (clip.timelineTime(atSource: $0.time) - clip.timelineStart).seconds / clip.duration.seconds
      }).sorted(),
      peaks: peaks,
    )
    .opacity(track.isHidden || track.isMuted ? 0.45 : 1)
    .frame(width: max(width, 2), height: rowHeight(track) - 8)
    .overlay(alignment: .leading) { edgeHandle(isStart: true) }
    .overlay(alignment: .trailing) { edgeHandle(isStart: false) }
    .contentShape(.rect)
    .onTapGesture { location in tap(atX: location.x) }
    .gesture(moveGesture)
    .offset(
      x: scale.x(at: clip.timelineStart) + startDelta + moveOffset.width,
      y: 4 + moveOffset.height,
    )
    .zIndex(moveOffset == .zero ? 0 : 1)
  }

  // MARK: Private

  /// How wide the grab zone at each edge is, in points.
  private static let edgeWidth = 6.0

  @Environment(Editor.self) private var editor
  @Environment(Player.self) private var player
  @Environment(MCPServer.self) private var server
  @Environment(Workspace.self) private var workspace
  @State private var moveOffset = CGSize.zero
  @State private var startDelta = 0.0
  @State private var endDelta = 0.0

  /// The peaks of the stretch of the media the clip plays, shaped by its volume and fades.
  private var peaks: [Float]? {
    guard
      let mediaID = clip.mediaID,
      let all = workspace.analysis.analyses[mediaID]?.waveform
    else {
      return nil
    }
    let start = Int(clip.sourceStart.seconds * Waveform.peaksPerSecond)
    let end = Int((clip.sourceStart + clip.duration).seconds * Waveform.peaksPerSecond)
    return all[min(start, all.count) ..< min(max(end, start), all.count)].enumerated()
      .map { index, peak in
        let time = clip.timelineStart + MediaTime(seconds: Double(index) / Waveform.peaksPerSecond)
        let gain = clip.gain(at: time)
        return gain > 0 ? max(peak + Float(20 * log10(gain) / Waveform.decibelRange), 0) : 0
      }
  }

  private var fps: Int {
    editor.project.timeline.format.framesPerSecond
  }

  private var moveGesture: some Gesture {
    DragGesture(minimumDistance: 3)
      .onChanged { drag in
        guard settings.tool != .blade else {
          return
        }
        if !editor.selection.contains(clip.id) {
          editor.selection = [clip.id]
        }
        let start = proposedStart(dragX: drag.translation.width)
        moveOffset = CGSize(
          width: scale.x(at: start) - scale.x(at: clip.timelineStart),
          height: drag.translation.height,
        )
      }
      .onEnded { drag in
        guard settings.tool != .blade else {
          return
        }
        let start = proposedStart(dragX: drag.translation.width)
        let target = targetTrack(dragY: drag.translation.height)
        moveOffset = .zero
        move(to: start, track: target)
      }
  }

  private func edgeHandle(isStart: Bool) -> some View {
    Color.clear
      .frame(width: Self.edgeWidth)
      .contentShape(.rect)
      .pointerStyle(settings.tool == .blade
        ? nil
        : .frameResize(position: isStart ? .leading : .trailing))
        .highPriorityGesture(
          DragGesture(minimumDistance: 1)
            .onChanged { drag in
              guard settings.tool != .blade else {
                return
              }
              let time = trimmedEdge(isStart: isStart, dragX: drag.translation.width)
              if isStart {
                startDelta = scale.x(at: time) - scale.x(at: clip.timelineStart)
              } else {
                endDelta = scale.x(at: time) - scale.x(at: clip.timelineEnd)
              }
            }
            .onEnded { drag in
              guard settings.tool != .blade else {
                return
              }
              let time = trimmedEdge(isStart: isStart, dragX: drag.translation.width)
              startDelta = 0
              endDelta = 0
              let ripple = settings.tool == .trim
              perform(isStart
                ? TrimClip(clipID: clip.id, start: time, ripple: ripple)
                : TrimClip(clipID: clip.id, end: time, ripple: ripple))
            }
        )
  }

  private func tap(atX x: Double) {
    if settings.tool == .blade {
      let time = (clip.timelineStart + MediaTime(seconds: scale.seconds(atX: x)))
        .roundedToFrame(at: fps)
      perform(SplitClip(clipID: clip.id, at: time))
      return
    }
    if NSEvent.modifierFlags.contains(.command) {
      editor.selection.formSymmetricDifference([clip.id])
    } else if NSEvent.modifierFlags.contains(.shift) {
      editor.selection.insert(clip.id)
    } else {
      editor.selection = [clip.id]
    }
  }

  /// Where the clip would start after dragging `dragX` points, snapped by its start or end.
  private func proposedStart(dragX: Double) -> MediaTime {
    let raw = (clip.timelineStart + MediaTime(seconds: scale.seconds(atX: dragX)))
      .roundedToFrame(at: fps)
    let start = max(raw, .zero)
    guard settings.isSnapping else {
      return start
    }
    let points = snapPoints()
    let snappedStart = points.snapped(start, scale: scale)
    if snappedStart != start {
      return snappedStart
    }
    let end = start + clip.duration
    return max(points.snapped(end, scale: scale) - clip.duration, .zero)
  }

  /// Where an edge would be after dragging `dragX` points: snapped, and never past the media's
  /// ends or the other edge.
  private func trimmedEdge(isStart: Bool, dragX: Double) -> MediaTime {
    let edge = isStart ? clip.timelineStart : clip.timelineEnd
    var time = (edge + MediaTime(seconds: scale.seconds(atX: dragX))).roundedToFrame(at: fps)
    if settings.isSnapping {
      time = snapPoints().snapped(time, scale: scale)
    }
    let frame = editor.project.timeline.format.frameDuration
    if isStart {
      let earliest = max(clip.timelineStart - clip.sourceStart, .zero)
      return min(max(time, earliest), clip.timelineEnd - frame)
    }
    guard let mediaID = clip.mediaID else {
      return max(time, clip.timelineStart + frame)
    }
    let mediaDuration = editor.project.media(withID: mediaID)?.duration
      .flooredToFrame(at: fps) ?? clip.duration
    let latest = clip.timelineStart + (mediaDuration - clip.sourceStart)
    return max(min(time, latest), clip.timelineStart + frame)
  }

  private func snapPoints() -> SnapPoints {
    SnapPoints(
      timeline: editor.project.timeline,
      playhead: MediaTime(seconds: player.currentTime).roundedToFrame(at: fps),
      excluding: editor.selection.union([clip.id]),
    )
  }

  /// The track a vertical drag lands on, if it's another track of the same kind.
  private func targetTrack(dragY: Double) -> Track? {
    guard let index = rows.firstIndex(where: { $0.id == track.id }) else {
      return nil
    }
    let top = rows[..<index].reduce(0) { $0 + rowHeight($1) }
    let landing = top + rowHeight(track) / 2 + dragY
    var edge = 0.0
    for row in rows {
      edge += rowHeight(row)
      if landing < edge {
        return row.kind == track.kind && row.id != track.id ? row : nil
      }
    }
    return nil
  }

  /// Moves this clip (and any other selected clips by the same amount) to `start`.
  private func move(to start: MediaTime, track target: Track?) {
    let delta = start - clip.timelineStart
    guard delta != .zero || target != nil else {
      return
    }
    let timeline = editor.project.timeline
    let moving = timeline.allClips.filter { editor.selection.contains($0.id) || $0.id == clip.id }
    // why: moving the clips furthest along first stops them overwriting each other.
    let ordered = moving.sorted { delta > .zero
      ? $0.timelineStart > $1.timelineStart
      : $0.timelineStart < $1.timelineStart
    }
    let commands: [any Command] = ordered.map { other in
      MoveClip(
        clipID: other.id,
        to: max(other.timelineStart + delta, .zero),
        track: other.id == clip.id ? target.map(timeline.label(of:)) : nil,
      )
    }
    do {
      try editor.perform(commands, title: MoveClip.title)
    } catch {
      onError(error.errorDescription ?? "The clip couldn't be moved.")
    }
  }

  private func perform(_ command: some Command) {
    do {
      try editor.perform(command)
    } catch {
      onError(error.errorDescription ?? "That edit couldn't be made.")
    }
  }

  private func rowHeight(_ track: Track) -> Double {
    TrackRow.height(of: track)
  }

}
