import Foundation
import ShadesCore

/// Splits a video clip's own sound onto an audio track as a clip linked to the video, so it can
/// be shaped on its own (volume, noise, stems) while edits keep the two together.
public struct DetachAudio: ToolCommand {

  // MARK: Lifecycle

  public init(clipID: Clip.ID) {
    self.clipID = clipID
  }

  // MARK: Public

  public static let title = "Detach Audio"
  public static let name = "detach_audio"
  public static let summary = "Move a video clip's own sound onto a free audio track as its own "
    + "clip, linked to the video so they still move, trim and split together. Unlink them "
    + "(unlink_clips) to slip the sound on its own."
  public static let parameters = JSONSchema.object(
    ["clip_id": Fields.clipID],
    required: ["clip_id"],
  )

  public let clipID: Clip.ID

  public func apply(to project: inout Project) throws(CommandError) {
    let location = try project.requireClip(clipID)
    let clip = project.timeline.tracks[location.track].clips[location.clip]
    guard let mediaID = clip.mediaID else {
      throw rejected(.noAudio(clipID))
    }
    let media = try project.requireMedia(mediaID)
    guard
      project.timeline.tracks[location.track].kind == .video, media.hasAudio,
      clip.isAudioEnabled
    else {
      throw rejected(.noAudio(clipID))
    }
    let link = clip.link ?? UUID()
    project.timeline.tracks[location.track].clips[location.clip].isAudioEnabled = false
    project.timeline.tracks[location.track].clips[location.clip].link = link
    let audioTracks = project.timeline.tracks.indices.filter {
      project.timeline.tracks[$0].kind == .audio
    }
    let index = audioTracks.first {
      project.timeline.tracks[$0].isClear(from: clip.timelineStart, to: clip.timelineEnd)
    } ?? project.addTrack(.audio)
    project.timeline.tracks[index].add(Clip(
      mediaID: mediaID,
      sourceStart: clip.sourceStart,
      duration: clip.duration,
      timelineStart: clip.timelineStart,
      volume: clip.volume,
      keyframes: clip.keyframes.filter { $0.property == .speed },
      speed: clip.speed,
      link: link,
    ))
  }

}
