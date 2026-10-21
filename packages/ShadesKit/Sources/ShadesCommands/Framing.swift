import ShadesCore

/// How far a video clip must zoom to fill the frame, and how far it can then shift each way.
struct Framing {

  // MARK: Lifecycle

  init(of clipID: Clip.ID, in project: Project) throws(CommandError) {
    location = try project.requireClip(clipID)
    clip = project.timeline.tracks[location.track].clips[location.clip]
    guard let mediaID = clip.mediaID else {
      throw rejected(.invalidValue("only video clips can be reframed"))
    }
    let media = try project.requireMedia(mediaID)
    guard media.hasVideo, media.width > 0, media.height > 0 else {
      throw rejected(.invalidValue("only video clips can be reframed"))
    }
    let pictureAspect = Double(media.width) / Double(media.height)
    let format = project.timeline.format
    let frameAspect = Double(format.width) / Double(format.height)
    scale = max(pictureAspect / frameAspect, frameAspect / pictureAspect)
    let reach = (scale - 1) / 2
    reachX = pictureAspect > frameAspect ? reach : 0
    reachY = pictureAspect > frameAspect ? 0 : reach
  }

  // MARK: Internal

  let location: (track: Int, clip: Int)
  let clip: Clip
  /// The zoom that fills the frame.
  let scale: Double
  /// How far the picture can move sideways (a fraction of the frame) before an edge shows.
  let reachX: Double
  /// How far it can move up or down.
  let reachY: Double

  /// The offset along `axis` that puts a subject at `position` (0–1 across the picture) in the
  /// middle of the frame, as near as the edges allow.
  func offset(forSubjectAt position: Double, axis: AnimatedProperty) -> Double {
    let reach = axis == .x ? reachX : reachY
    return min(max(-(position - 0.5) * scale, -reach), reach)
  }

}
