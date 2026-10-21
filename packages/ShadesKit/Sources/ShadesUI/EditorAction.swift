import ShadesCommands
import ShadesCore
import ShadesMatting
import ShadesMCP
import ShadesPolish
import SwiftUI

/// Every action a person can take in the editor. The key handler and the ⌘K palette both come
/// from this one list, so a shortcut and its name never drift apart.
enum EditorAction: CaseIterable, Identifiable {
  case playPause
  case playReverse
  case stop
  case playForward
  case previousFrame
  case nextFrame
  case previousEdit
  case nextEdit
  case previewQuality
  case selectTool
  case bladeTool
  case trimTool
  case drawTool
  case trackTool
  case toggleSnapping
  case split
  case rippleTrimStart
  case rippleTrimEnd
  case trimStart
  case trimEnd
  case append
  case insert
  case overwrite
  case placeOnTop
  case delete
  case rippleDelete
  case closeGaps
  case join
  case detachAudio
  case splitWords
  case freezeFrame
  case normalSpeed
  case nudgeLeft
  case nudgeRight
  case nudgeLeftFive
  case nudgeRightFive
  case moveUp
  case moveDown
  case selectAtPlayhead
  case selectForward
  case deselect
  case matchFrame
  case addMarker
  case markShort
  case renameShort
  case shortStartToPlayhead
  case shortEndToPlayhead
  case removeShort
  case removeMarker
  case markIn
  case markOut
  case clearMarks
  case undo
  case redo
  case zoomIn
  case zoomOut
  case zoomToFit
  case importMedia
  case commandPalette
  case toggleHistory
  case toggleScopes
  case toggleTranscript
  case toggleMixer
  case polishSelection
  case cutOutSubject
  case cutOutObject
  case reframe
  case reframeLocked
  case addText
  case addSticker
  case addAdjustment
  case addTransition
  case analyzeAudio
  case duckMusic
  case normalizeLoudness

  // MARK: Internal

  var id: Self {
    self
  }

  var title: String {
    switch self {
    case .playPause: "Play / Pause"
    case .playReverse: "Play Backwards"
    case .stop: "Stop"
    case .playForward: "Play Forward (press again to speed up)"
    case .previousFrame: "Previous Frame"
    case .nextFrame: "Next Frame"
    case .previousEdit: "Previous Edit"
    case .nextEdit: "Next Edit"
    case .previewQuality: "Preview Quality: Auto, Full or Half"
    case .selectTool: "Select Tool"
    case .bladeTool: "Blade Tool"
    case .trimTool: "Trim Tool"
    case .drawTool: "Draw Tool"
    case .trackTool: "Track Tool (drag a box in the viewer to follow it)"
    case .toggleSnapping: "Snapping On / Off"
    case .split: "Split at Playhead"
    case .rippleTrimStart: "Ripple Trim Start to Playhead"
    case .rippleTrimEnd: "Ripple Trim End to Playhead"
    case .trimStart: "Trim Start to Playhead"
    case .trimEnd: "Trim End to Playhead"
    case .append: "Append to End"
    case .insert: "Insert at Playhead"
    case .overwrite: "Overwrite at Playhead"
    case .placeOnTop: "Place on Top"
    case .delete: "Delete (Leave Gap)"
    case .rippleDelete: "Ripple Delete"
    case .closeGaps: "Close All Gaps"
    case .join: "Join Clips"
    case .detachAudio: "Detach Audio"
    case .splitWords: "Split Text into Words"
    case .freezeFrame: "Freeze Frame at Playhead"
    case .normalSpeed: "Normal Speed"
    case .nudgeLeft: "Nudge Left 1 Frame"
    case .nudgeRight: "Nudge Right 1 Frame"
    case .nudgeLeftFive: "Nudge Left 5 Frames"
    case .nudgeRightFive: "Nudge Right 5 Frames"
    case .moveUp: "Move Clip Up a Track"
    case .moveDown: "Move Clip Down a Track"
    case .selectAtPlayhead: "Select Clip at Playhead"
    case .selectForward: "Select Forward"
    case .deselect: "Deselect All"
    case .matchFrame: "Match Frame"
    case .addMarker: "Add Marker"
    case .markShort: "Mark Short from Selection"
    case .renameShort: "Rename Short…"
    case .shortStartToPlayhead: "Move Short Start to Playhead"
    case .shortEndToPlayhead: "Move Short End to Playhead"
    case .removeShort: "Remove Short"
    case .removeMarker: "Remove Marker at Playhead"
    case .markIn: "Mark In (hovering a media clip)"
    case .markOut: "Mark Out (hovering a media clip)"
    case .clearMarks: "Clear Marks"
    case .undo: "Undo"
    case .redo: "Redo"
    case .zoomIn: "Zoom In"
    case .zoomOut: "Zoom Out"
    case .zoomToFit: "Zoom to Fit"
    case .importMedia: "Import Media…"
    case .commandPalette: "Command Palette"
    case .toggleHistory: "Show / Hide History"
    case .toggleScopes: "Show / Hide Scopes"
    case .toggleTranscript: "Show / Hide Transcript"
    case .toggleMixer: "Show / Hide Mixer"
    case .polishSelection: "Polish Selection"
    case .cutOutSubject: "Cut Out Person in Selected Clips"
    case .cutOutObject: "Cut Out Any Object in Selected Clips"
    case .reframe: "Reframe Selected Clips (Pan with Subject)"
    case .reframeLocked: "Reframe Selected Clips (Locked)"
    case .addText: "Add Text at Playhead"
    case .addSticker: "Add Chosen Picture as a Sticker"
    case .addAdjustment: "Add Adjustment Clip"
    case .addTransition: "Add Dissolve into Selected Clips"
    case .analyzeAudio: "Find Speech and Beats"
    case .duckMusic: "Duck Music Under Speech"
    case .normalizeLoudness: "Normalize Loudness to -14 LUFS"
    }
  }

  var shortcut: Shortcut {
    switch self {
    case .playPause: Shortcut(.space)
    case .playReverse: Shortcut("j")
    case .stop: Shortcut("k")
    case .playForward: Shortcut("l")
    case .previousFrame: Shortcut(.leftArrow)
    case .nextFrame: Shortcut(.rightArrow)
    case .previousEdit: Shortcut(.upArrow)
    case .nextEdit: Shortcut(.downArrow)
    case .previewQuality: Shortcut("h", .option)
    case .selectTool: Shortcut("a")
    case .bladeTool: Shortcut("b")
    case .trimTool: Shortcut("t")
    case .drawTool: Shortcut("p")
    case .trackTool: Shortcut("t", .option)
    case .toggleSnapping: Shortcut("n")
    case .split: Shortcut("s")
    case .rippleTrimStart: Shortcut("q")
    case .rippleTrimEnd: Shortcut("w")
    case .trimStart: Shortcut("q", .shift)
    case .trimEnd: Shortcut("w", .shift)
    case .append: Shortcut("r")
    case .insert: Shortcut("z")
    case .overwrite: Shortcut("z", .option)
    case .placeOnTop: Shortcut("c")
    case .delete: Shortcut(.delete)
    case .rippleDelete: Shortcut(.delete, .shift)
    case .closeGaps: Shortcut("d")
    case .join: Shortcut("j", [.option, .command])
    case .detachAudio: Shortcut("l", [.shift, .command])
    case .splitWords: Shortcut("w", [.option, .command])
    case .freezeFrame: Shortcut("f", .option)
    case .normalSpeed: Shortcut("n", .shift)
    case .nudgeLeft: Shortcut(",")
    case .nudgeRight: Shortcut(".")
    case .nudgeLeftFive: Shortcut(",", .shift)
    case .nudgeRightFive: Shortcut(".", .shift)
    case .moveUp: Shortcut(.upArrow, .option)
    case .moveDown: Shortcut(.downArrow, .option)
    case .selectAtPlayhead: Shortcut("v", .shift)
    case .selectForward: Shortcut("y")
    case .deselect: Shortcut(.escape)
    case .matchFrame: Shortcut("f")
    case .addMarker: Shortcut("m")
    case .markShort: Shortcut("m", .option)
    case .renameShort: Shortcut("n", .option)
    case .shortStartToPlayhead: Shortcut("i", .option)
    case .shortEndToPlayhead: Shortcut("o", .option)
    case .removeShort: Shortcut("m", [.option, .shift])
    case .removeMarker: Shortcut("m", .control)
    case .markIn: Shortcut("i")
    case .markOut: Shortcut("o")
    case .clearMarks: Shortcut("x", .option)
    case .undo: Shortcut("e")
    case .redo: Shortcut("r", .control)
    case .zoomIn: Shortcut("=", .command)
    case .zoomOut: Shortcut("-", .command)
    case .zoomToFit: Shortcut("z", .shift)
    case .importMedia: Shortcut("i", .command)
    case .commandPalette: Shortcut("k", .command)
    case .toggleHistory: Shortcut("l", .command)
    case .toggleScopes: Shortcut("s", [.option, .command])
    case .toggleTranscript: Shortcut("t", [.command, .option])
    case .toggleMixer: Shortcut("a", [.option, .command])
    case .polishSelection: Shortcut("p", .option)
    case .cutOutSubject: Shortcut("u", .option)
    case .cutOutObject: Shortcut("u", [.option, .shift])
    case .reframe: Shortcut("r", .option)
    case .reframeLocked: Shortcut("r", [.option, .shift])
    case .addText: Shortcut("t", .control)
    case .addSticker: Shortcut("c", .shift)
    case .addAdjustment: Shortcut("a", .option)
    case .addTransition: Shortcut("t", .command)
    case .analyzeAudio: Shortcut("b", .option)
    case .duckMusic: Shortcut("d", .option)
    case .normalizeLoudness: Shortcut("l", .option)
    }
  }

  /// Does the action. Edits go through commands, so they can be undone.
  func perform(in context: ActionContext) throws(CommandError) {
    switch self {
    case .playPause,
         .playReverse,
         .stop,
         .playForward,
         .previousFrame,
         .nextFrame,
         .previousEdit,
         .nextEdit,
         .previewQuality:
      transport(in: context)

    case .selectTool,
         .bladeTool,
         .trimTool,
         .drawTool,
         .trackTool,
         .toggleSnapping,
         .zoomIn,
         .zoomOut,
         .zoomToFit,
         .importMedia,
         .commandPalette,
         .toggleHistory,
         .toggleScopes,
         .toggleTranscript,
         .toggleMixer:
      view(in: context)

    case .selectAtPlayhead,
         .selectForward,
         .deselect,
         .matchFrame:
      select(in: context)

    case .markIn,
         .markOut,
         .clearMarks:
      mark(in: context)

    case .polishSelection:
      try polish(in: context)

    case .markShort,
         .renameShort,
         .shortStartToPlayhead,
         .shortEndToPlayhead,
         .removeShort:
      try short(in: context)

    case .cutOutSubject,
         .cutOutObject:
      let media = Array(Set(context.selectedClips.compactMap(\.mediaID)))
      guard !media.isEmpty else {
        throw .invalidArguments("select the clips to cut out first")
      }
      _ = context.workspace.makeCutouts(
        media,
        engine: self == .cutOutObject ? .visionForeground : .visionPerson,
      )

    case .analyzeAudio,
         .duckMusic,
         .normalizeLoudness:
      try sound(in: context)

    case .reframe,
         .reframeLocked:
      _ = try context.workspace.autoReframe(nil, locked: self == .reframeLocked)

    case .undo:
      try context.editor.undo()

    case .redo:
      try context.editor.redo()

    default:
      try edit(in: context)
    }
  }

  // MARK: Private

  /// Points per second to zoom from when the timeline is fitted.
  private static let defaultZoom = 40.0

  /// How long ⌥F holds a frame.
  private static let freezeLength = MediaTime(seconds: 2)

  private func transport(in context: ActionContext) {
    let player = context.player
    switch self {
    case .playPause: player.togglePlayback()

    case .playReverse: player.play(atRate: -1)

    case .stop: player.pause()

    case .playForward: player.play(atRate: player.isPlaying && player.rate > 0
        ? min(player.rate * 2, 8)
        : 1)

    case .previousFrame: context.seek(to: context.playhead - context.frame)

    case .nextFrame: context.seek(to: context.playhead + context.frame)

    case .previousEdit,
         .nextEdit:
      let edges = Set(context.timeline.allClips.flatMap { [$0.timelineStart, $0.timelineEnd] })
        .sorted()
      let time = context.playhead
      let target = self == .nextEdit ? edges.first { $0 > time } : edges.last { $0 < time }
      if let target {
        context.seek(to: target)
      }

    case .previewQuality: player.previewQuality = player.previewQuality.next

    default: break
    }
  }

  private func view(in context: ActionContext) {
    let settings = context.settings
    switch self {
    case .selectTool:
      settings.wrappedValue.tool = .select
      settings.wrappedValue.isDrawing = false
      settings.wrappedValue.isTracking = false

    case .bladeTool:
      settings.wrappedValue.tool = .blade
      settings.wrappedValue.isDrawing = false
      settings.wrappedValue.isTracking = false

    case .trimTool:
      settings.wrappedValue.tool = .trim
      settings.wrappedValue.isDrawing = false
      settings.wrappedValue.isTracking = false

    case .drawTool:
      settings.wrappedValue.isDrawing.toggle()
      settings.wrappedValue.isTracking = false

    case .trackTool:
      settings.wrappedValue.isTracking.toggle()
      settings.wrappedValue.isDrawing = false

    case .toggleScopes: settings.wrappedValue.showsScopes.toggle()

    case .toggleSnapping: settings.wrappedValue.isSnapping.toggle()

    case .zoomIn: settings.wrappedValue.pointsPerSecond = min(
        (settings.wrappedValue.pointsPerSecond ?? Self.defaultZoom) * 1.5,
        2000,
      )

    case .zoomOut: settings.wrappedValue.pointsPerSecond = max(
        (settings.wrappedValue.pointsPerSecond ?? Self.defaultZoom) / 1.5,
        2,
      )

    case .zoomToFit: settings.wrappedValue.pointsPerSecond = nil

    case .importMedia: context.isImporting.wrappedValue = true

    case .commandPalette: context.isShowingPalette.wrappedValue = true

    case .toggleHistory:
      context.sidePane.wrappedValue = context.sidePane.wrappedValue == .history
        ? .inspector
        : .history

    case .toggleTranscript:
      context.sidePane.wrappedValue = context.sidePane.wrappedValue == .transcript
        ? .inspector
        : .transcript

    case .toggleMixer:
      context.sidePane.wrappedValue = context.sidePane.wrappedValue == .mixer ? .inspector : .mixer

    default: break
    }
  }

  private func select(in context: ActionContext) {
    let time = context.playhead
    switch self {
    case .selectAtPlayhead:
      let topmost = context.timeline.tracks.reversed().lazy.compactMap { $0.clip(at: time) }.first
      context.editor.selection = Set([topmost?.id].compactMap(\.self))

    case .selectForward:
      context.editor
        .selection = Set(context.timeline.allClips.filter { $0.timelineStart >= time }.map(\.id))

    case .deselect:
      context.editor.selection = []

    case .matchFrame:
      let clip = context.selectedClips.first
        ?? context.timeline.tracks.reversed().lazy.compactMap { $0.clip(at: time) }.first
      context.mediaSelection.wrappedValue = clip?.mediaID ?? context.mediaSelection.wrappedValue

    default: break
    }
  }

  /// Proposes Polish over the selected clips' span, on the first selected clip's track.
  private func polish(in context: ActionContext) throws(CommandError) {
    let selected = context.selectedClips
    guard
      let first = selected.min(by: { $0.timelineStart < $1.timelineStart }),
      let last = selected.max(by: { $0.timelineEnd < $1.timelineEnd }),
      let location = context.timeline.location(ofClip: first.id)
    else {
      throw .invalidArguments("select the clips to polish first")
    }
    context.workspace.proposePolish(
      in: TimeRange(start: first.timelineStart, end: last.timelineEnd),
      track: context.timeline.label(of: context.timeline.tracks[location.track]),
      options: PolishOptions(),
    )
  }

  /// ⌥M marks the selected clips' span as a new short; the others change the current short.
  private func short(in context: ActionContext) throws(CommandError) {
    if self == .markShort {
      let selected = context.selectedClips
      guard
        let start = selected.map(\.timelineStart).min(),
        let end = selected.map(\.timelineEnd).max()
      else {
        throw .invalidArguments("select the clips the short covers first")
      }
      let name = "Short \(context.timeline.shorts.count + 1)"
      try context.editor.perform(AddShort(name: name, start: start, end: end))
      context.settings.wrappedValue.selectedShort = context.timeline.shorts.last?.id
      return
    }
    let short = try context.requireShort()
    switch self {
    case .renameShort:
      context.renamingShort.wrappedValue = short.id

    case .shortStartToPlayhead:
      try context.editor.perform(SetShort(shortID: short.id, start: context.playhead))

    case .shortEndToPlayhead:
      try context.editor.perform(SetShort(shortID: short.id, end: context.playhead))

    default:
      try context.editor.perform(RemoveShort(shortID: short.id))
    }
  }

  /// Works on the timeline's sound: finds speech and beats (in the selected clips, or whatever
  /// isn't analysed yet), ducks the music (the selected audio track's, or the one that sounds
  /// like music) or sets the master level for -14 LUFS.
  private func sound(in context: ActionContext) throws(CommandError) {
    let workspace = context.workspace
    switch self {
    case .analyzeAudio:
      let media = context.selectedClips.compactMap(\.mediaID)
      if workspace.analyzeAudio(media.isEmpty ? nil : media).isEmpty {
        throw .invalidArguments("there's no sound left to analyse; select clips to analyse again")
      }

    case .duckMusic:
      let timeline = context.timeline
      let music = context.selectedClips.lazy.compactMap { timeline.location(ofClip: $0.id) }
        .map { timeline.tracks[$0.track] }.first { $0.kind == .audio }
      _ = try workspace.duckMusic(track: music.map(timeline.label(of:)), level: 0.25)

    default:
      Task {
        do throws(ToolError) {
          _ = try await workspace.normalizeLoudness(target: -14)
        } catch {
          workspace.errorMessage = error.errorDescription
        }
      }
    }
  }

  /// R, Z, ⌥Z and C: places the chosen media, just its I / O part when marked.
  private func place(in context: ActionContext, at time: MediaTime) throws(CommandError) {
    let media = try context.requireMedia()
    let marks = context.marks(of: media)
    switch self {
    case .append:
      try context.editor.perform(AppendClip(
        mediaID: media,
        sourceStart: marks.start,
        sourceEnd: marks.end,
      ))

    case .insert:
      try context.editor.perform(InsertClip(
        mediaID: media,
        at: time,
        sourceStart: marks.start,
        sourceEnd: marks.end,
      ))

    case .overwrite:
      try context.editor.perform(OverwriteClip(
        mediaID: media,
        at: time,
        sourceStart: marks.start,
        sourceEnd: marks.end,
      ))

    default:
      try context.editor.perform(PlaceOnTop(
        mediaID: media,
        at: time,
        sourceStart: marks.start,
        sourceEnd: marks.end,
      ))
    }
  }

  /// I and O mark the hovered media (and choose it); ⌥X clears the chosen media's marks.
  private func mark(in context: ActionContext) {
    if self == .clearMarks {
      if let media = context.mediaSelection.wrappedValue {
        context.marks.wrappedValue[media] = nil
      }
      return
    }
    guard let hover = context.hover.wrappedValue else {
      return
    }
    context.mediaSelection.wrappedValue = hover.mediaID
    var marks = context.marks(of: hover.mediaID)
    if self == .markIn {
      marks.start = hover.time
      if let end = marks.end, end <= hover.time {
        marks.end = nil
      }
    } else {
      marks.end = hover.time
      if let start = marks.start, start >= hover.time {
        marks.start = nil
      }
    }
    context.marks.wrappedValue[hover.mediaID] = marks
  }

  private func edit(in context: ActionContext) throws(CommandError) {
    let time = context.playhead
    let selected = context.selectedClips
    switch self {
    case .split:
      try context.perform(
        context.clipsAtPlayhead.map { SplitClip(clipID: $0.id, at: time) },
        title: "Split",
      )

    case .rippleTrimStart,
         .trimStart:
      let ripple = self == .rippleTrimStart
      try context.perform(
        context.clipsAtPlayhead.map { TrimClip(clipID: $0.id, start: time, ripple: ripple) },
        title: "Trim Start",
      )

    case .rippleTrimEnd,
         .trimEnd:
      let ripple = self == .rippleTrimEnd
      try context.perform(
        context.clipsAtPlayhead.map { TrimClip(clipID: $0.id, end: time, ripple: ripple) },
        title: "Trim End",
      )

    case .append,
         .insert,
         .overwrite,
         .placeOnTop:
      try place(in: context, at: time)

    case .delete,
         .rippleDelete:
      try context.perform(
        selected.isEmpty
          ? []
          : [DeleteClips(clipIDs: selected.map(\.id), ripple: self == .rippleDelete)],
        title: DeleteClips.title,
      )

    case .closeGaps:
      try context.editor.perform(CloseGaps())

    case .join:
      try context.editor.perform(JoinClips(clipIDs: selected.map(\.id)))

    case .detachAudio:
      try context.perform(selected.map { DetachAudio(clipID: $0.id) }, title: DetachAudio.title)

    case .splitWords:
      let texts = selected.filter { $0.text != nil && $0.text?.word == nil }
      guard !texts.isEmpty else {
        throw .invalidArguments("select the text clips to split into words first")
      }
      try context.perform(texts.map { SplitWords(clipID: $0.id) }, title: SplitWords.title)

    case .freezeFrame:
      let timeline = context.timeline
      let video = context.clipsAtPlayhead.last { clip in
        let track = timeline.location(ofClip: clip.id).map { timeline.tracks[$0.track] }
        return track?.kind == .video && clip.mediaID != nil && !clip.isFrozen
      }
      guard let video else {
        throw .invalidArguments("put the playhead over a video clip to freeze its frame")
      }
      try context.editor.perform(FreezeFrame(
        clipID: video.id,
        at: time,
        duration: Self.freezeLength,
      ))

    case .normalSpeed:
      let retimed = (selected.isEmpty ? context.clipsAtPlayhead : selected)
        .filter { $0.isRetimed && !$0.isFrozen }
      try context.perform(
        retimed.flatMap { clip -> [any Command] in
          let steady = SetClip(clipID: clip.id, speed: 1)
          return clip.hasSpeedRamp
            ? [RemoveKeyframes(clipID: clip.id, property: .speed), steady]
            : [steady]
        },
        title: "Normal Speed",
      )

    case .nudgeLeft,
         .nudgeRight,
         .nudgeLeftFive,
         .nudgeRightFive:
      let frames: Int64 = [.nudgeLeftFive, .nudgeRightFive].contains(self) ? 5 : 1
      let isRight = [.nudgeRight, .nudgeRightFive].contains(self)
      let step = MediaTime(value: context.frame.value * frames, timescale: context.frame.timescale)
      // why: moving in the nudge direction's far end first stops selected clips overwriting
      // each other on the way.
      let ordered = selected.sorted { isRight
        ? $0.timelineStart > $1.timelineStart
        : $0.timelineStart < $1.timelineStart
      }
      try context.perform(
        ordered.map { clip in
          let start = isRight ? clip.timelineStart + step : clip.timelineStart - step
          return MoveClip(clipID: clip.id, to: max(start, .zero))
        },
        title: "Nudge",
      )

    case .moveUp,
         .moveDown:
      let offset = self == .moveUp ? 1 : -1
      try context.perform(
        selected.compactMap { clip in
          context.neighbourTrack(of: clip, offset: offset)
            .map { MoveClip(clipID: clip.id, track: $0) }
        },
        title: MoveClip.title,
      )

    case .addMarker:
      try context.editor.perform(AddMarker(at: time))

    case .removeMarker:
      guard let marker = context.timeline.markers.first(where: { $0.time == time }) else {
        throw .invalidArguments(
          "move the playhead onto a marker first, or right-click the marker on the ruler"
        )
      }
      try context.editor.perform(RemoveMarker(markerID: marker.id))

    case .addText:
      try context.add(AddText(
        text: "Title",
        at: time,
        duration: MediaTime(seconds: 3),
        style: TextStyle(anchor: .center),
      ))

    case .addSticker:
      try context.add(AddSticker(mediaID: context.requireMedia(), at: time))

    case .addAdjustment:
      let start = selected.map(\.timelineStart).min() ?? time
      let end = selected.map(\.timelineEnd).max() ?? time + MediaTime(seconds: 5)
      try context.add(AddAdjustment(at: start, duration: end - start))

    case .addTransition:
      let cuts = selected.filter { context.timeline.clip(cuttingInto: $0) != nil }
      guard !cuts.isEmpty else {
        throw .invalidArguments("select a clip that starts right where another ends")
      }
      try context.perform(
        cuts.map { SetTransition(clipID: $0.id, kind: .dissolve) },
        title: SetTransition.title,
      )

    default:
      break
    }
  }
}
