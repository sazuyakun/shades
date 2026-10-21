import ShadesCore

/// Lays an overlay movie (a light leak, dust, a film burn) over the footage: on a free track
/// above, filling the frame, silent, and blended (screen by default, so its black drops away).
public struct AddOverlay: Command {

  // MARK: Lifecycle

  public init(
    mediaID: Media.ID,
    at time: MediaTime,
    duration: MediaTime? = nil,
    blend: BlendMode = .screen,
    opacity: Double = 1,
  ) {
    self.mediaID = mediaID
    at = time
    self.duration = duration
    self.blend = blend
    self.opacity = opacity
  }

  // MARK: Public

  public static let title = "Add Overlay"

  public let mediaID: Media.ID
  public let at: MediaTime
  /// How long it stays; by default the whole overlay, cut off where the timeline ends.
  public let duration: MediaTime?
  public let blend: BlendMode
  public let opacity: Double

  public func apply(to project: inout Project) throws(CommandError) {
    let media = try project.requireMedia(mediaID)
    guard media.hasVideo else {
      throw rejected(.invalidValue("an overlay needs a movie or picture, not a sound"))
    }
    guard (0 ... 1).contains(opacity) else {
      throw rejected(.invalidValue("opacity goes from 0 to 1"))
    }
    let start = project.onFrame(at)
    let left = project.timeline.duration - start
    let length = duration ?? (left > .zero ? min(media.duration, left) : media.duration)
    let range = try project.sourceRange(of: media, from: .zero, to: length)
    let clipID = project.placeOnTop(media, range: range, at: start)
    try ReframeClip(clipID: clipID).apply(to: &project)
    let location = try project.requireClip(clipID)
    project.timeline.tracks[location.track].clips[location.clip].blend = blend
    project.timeline.tracks[location.track].clips[location.clip].opacity = opacity
    project.timeline.tracks[location.track].clips[location.clip].isAudioEnabled = false
  }

}
