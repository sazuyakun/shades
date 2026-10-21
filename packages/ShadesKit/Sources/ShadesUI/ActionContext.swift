import ShadesCommands
import ShadesCore
import ShadesEngine
import SwiftUI

/// Everything an `EditorAction` works on: the project, playback, and the editor window's state.
struct ActionContext {

  let editor: Editor
  let player: Player
  let workspace: Workspace
  let settings: Binding<TimelineSettings>
  let mediaSelection: Binding<Media.ID?>
  let sidePane: Binding<SidePane>
  let isShowingPalette: Binding<Bool>
  let isImporting: Binding<Bool>
  let marks: Binding<[Media.ID: SourceMarks]>
  let hover: Binding<MediaHover?>
  /// The short whose name is being edited, if any.
  let renamingShort: Binding<Short.ID?>

  var timeline: Timeline {
    editor.project.timeline
  }

  /// The playhead on the nearest frame.
  var playhead: MediaTime {
    MediaTime(seconds: player.currentTime).roundedToFrame(at: timeline.format.framesPerSecond)
  }

  var frame: MediaTime {
    timeline.format.frameDuration
  }

  /// The clips an edit at the playhead applies to: the selected ones, or else every clip under
  /// the playhead.
  var clipsAtPlayhead: [Clip] {
    let time = playhead
    let selected = timeline.allClips.filter { editor.selection.contains($0.id) }
    let candidates = selected.isEmpty ? timeline.allClips : selected
    return candidates.filter { $0.timelineStart < time && time < $0.timelineEnd }
  }

  /// The short the short actions change: the one clicked above the timeline, or else the one
  /// under the playhead.
  var currentShort: Short? {
    let shorts = timeline.shorts
    return shorts.first { $0.id == settings.wrappedValue.selectedShort }
      ?? shorts.first { $0.range.start <= playhead && playhead < $0.range.end }
  }

  var selectedClips: [Clip] {
    timeline.allClips.filter { editor.selection.contains($0.id) }
  }

  /// Applies `commands` as one undo step named `title`; does nothing when there are none.
  func perform(_ commands: [any Command], title: String) throws(CommandError) {
    guard !commands.isEmpty else {
      return
    }
    try editor.perform(commands, title: title)
  }

  /// Moves the playhead, keeping it on the timeline.
  func seek(to time: MediaTime) {
    Task { await player.seek(toSeconds: time.seconds) }
  }

  /// The short the short actions change, or an error saying how to pick one.
  func requireShort() throws(CommandError) -> Short {
    guard let short = currentShort else {
      throw .invalidArguments("click a short above the timeline, or move the playhead into one")
    }
    return short
  }

  /// The media chosen in the browser, to place with R, Z, ⌥Z or C.

  func requireMedia() throws(CommandError) -> Media.ID {
    guard let id = mediaSelection.wrappedValue else {
      throw .invalidArguments("pick a clip in the media browser first")
    }
    return id
  }

  /// The I / O marks on `media`, if any.
  func marks(of media: Media.ID) -> SourceMarks {
    marks.wrappedValue[media] ?? SourceMarks()
  }

  /// The label of the track `offset` places above (+) or below (−) `clip`'s track, among tracks
  /// of the same kind.
  func neighbourTrack(of clip: Clip, offset: Int) -> String? {
    guard let location = timeline.location(ofClip: clip.id) else {
      return nil
    }
    let track = timeline.tracks[location.track]
    let sameKind = timeline.tracks.filter { $0.kind == track.kind }
    guard
      let index = sameKind.firstIndex(where: { $0.id == track.id }),
      sameKind.indices.contains(index + offset)
    else {
      return nil
    }
    return timeline.label(of: sameKind[index + offset])
  }

}
