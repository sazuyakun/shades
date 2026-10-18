import ShadesCommands
import ShadesCore
import ShadesMatting
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
  case selectTool
  case bladeTool
  case trimTool
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
  case toggleTranscript
  case polishSelection
  case cutOutSubject
  case reframe

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
    case .selectTool: "Select Tool"
    case .bladeTool: "Blade Tool"
    case .trimTool: "Trim Tool"
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
    case .toggleTranscript: "Show / Hide Transcript"
    case .polishSelection: "Polish Selection"
    case .cutOutSubject: "Cut Out Subject of Selected Clips"
    case .reframe: "Reframe Selected Clips"
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
    case .selectTool: Shortcut("a")
    case .bladeTool: Shortcut("b")
    case .trimTool: Shortcut("t")
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
    case .toggleTranscript: Shortcut("t", [.command, .option])
    case .polishSelection: Shortcut("p", .option)
    case .cutOutSubject: Shortcut("u", .option)
    case .reframe: Shortcut("r", .option)
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
         .nextEdit:
      transport(in: context)

    case .selectTool,
         .bladeTool,
         .trimTool,
         .toggleSnapping,
         .zoomIn,
         .zoomOut,
         .zoomToFit,
         .importMedia,
         .commandPalette,
         .toggleHistory,
         .toggleTranscript:
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

    case .cutOutSubject:
      let media = Array(Set(context.selectedClips.compactMap(\.mediaID)))
      guard !media.isEmpty else {
        throw .invalidArguments("select the clips to cut out first")
      }
      _ = context.workspace.makeCutouts(media, engine: .visionPerson)

    case .reframe:
      _ = try context.workspace.autoReframe(nil)

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

    default: break
    }
  }

  private func view(in context: ActionContext) {
    let settings = context.settings
    switch self {
    case .selectTool: settings.wrappedValue.tool = .select

    case .bladeTool: settings.wrappedValue.tool = .blade

    case .trimTool: settings.wrappedValue.tool = .trim

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

    default:
      break
    }
  }
}
