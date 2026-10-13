import ShadesCore

/// Places a whole media file at the end of a track.
public struct AppendClip: Command {

  // MARK: Lifecycle

  public init(mediaID: Media.ID, trackIndex: Int = 0) {
    self.mediaID = mediaID
    self.trackIndex = trackIndex
  }

  // MARK: Public

  public let mediaID: Media.ID
  public let trackIndex: Int

  public func apply(to project: inout Project) throws(CommandError) {
    guard let media = project.media(withID: mediaID) else {
      logger.error("clip.appendFailed reason=mediaNotFound id=\(mediaID, privacy: .public)")
      throw .mediaNotFound(mediaID)
    }
    guard project.timeline.tracks.indices.contains(trackIndex) else {
      logger.error("clip.appendFailed reason=trackNotFound index=\(trackIndex, privacy: .public)")
      throw .trackNotFound(index: trackIndex)
    }
    let clip = Clip(
      mediaID: media.id,
      sourceStart: .zero,
      duration: media.duration,
      timelineStart: project.timeline.tracks[trackIndex].end,
    )
    project.timeline.tracks[trackIndex].clips.append(clip)
  }

}
