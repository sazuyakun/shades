import ShadesCore

/// Splits a video clip's own sound onto an audio track, so it can be edited separately.
public struct DetachAudio: ToolCommand {

  // MARK: Lifecycle

  public init(clipID: Clip.ID) {
    self.clipID = clipID
  }

  // MARK: Public

  public static let title = "Detach Audio"
  public static let name = "detach_audio"
  public static let summary = "Move a video clip's own sound onto a free audio track as its own "
    + "clip, so it can be trimmed or moved separately."
  public static let parameters = JSONSchema.object(
    ["clip_id": Fields.clipID],
    required: ["clip_id"],
  )

  public let clipID: Clip.ID

  public func apply(to project: inout Project) throws(CommandError) {
    let location = try project.requireClip(clipID)
    let clip = project.timeline.tracks[location.track].clips[location.clip]
    let media = try project.requireMedia(clip.mediaID)
    guard
      project.timeline.tracks[location.track].kind == .video, media.hasAudio,
      clip.isAudioEnabled
    else {
      throw rejected(.noAudio(clipID))
    }
    project.timeline.tracks[location.track].clips[location.clip].isAudioEnabled = false
    let audioTracks = project.timeline.tracks.indices.filter {
      project.timeline.tracks[$0].kind == .audio
    }
    let index = audioTracks.first {
      project.timeline.tracks[$0].isClear(from: clip.timelineStart, to: clip.timelineEnd)
    } ?? project.addTrack(.audio)
    project.timeline.tracks[index].add(Clip(
      mediaID: clip.mediaID,
      sourceStart: clip.sourceStart,
      duration: clip.duration,
      timelineStart: clip.timelineStart,
      volume: clip.volume,
    ))
  }

}
