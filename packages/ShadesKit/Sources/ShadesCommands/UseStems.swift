import ShadesCore

/// Swaps a clip's sound for its separated voice and music: two clips on free audio tracks, lined
/// up with it and keeping its volume, volume keyframes and fades. A video clip stops playing its
/// own sound; a sound clip is replaced. The stems' media come already loaded.
public struct UseStems: Command {

  // MARK: Lifecycle

  public init(clipID: Clip.ID, stems: [Media]) {
    self.clipID = clipID
    self.stems = stems
  }

  // MARK: Public

  public static let title = "Separate Voice and Music"

  public let clipID: Clip.ID
  /// The separated sounds, in the order their clips are placed (voice first).
  public let stems: [Media]

  public func apply(to project: inout Project) throws(CommandError) {
    let location = try project.requireClip(clipID)
    let clip = project.timeline.tracks[location.track].clips[location.clip]
    let isVideoTrack = project.timeline.tracks[location.track].kind == .video
    guard !isVideoTrack || clip.isAudioEnabled else {
      throw rejected(.noAudio(clipID))
    }
    for stem in stems where project.media(withID: stem.id) == nil {
      project.media.append(stem)
    }
    if isVideoTrack {
      project.timeline.tracks[location.track].clips[location.clip].isAudioEnabled = false
    } else {
      project.timeline.tracks[location.track].clips.remove(at: location.clip)
    }
    for stem in stems {
      let audioTracks = project.timeline.tracks.indices.filter {
        project.timeline.tracks[$0].kind == .audio
      }
      let index = audioTracks.first {
        project.timeline.tracks[$0].isClear(from: clip.timelineStart, to: clip.timelineEnd)
      } ?? project.addTrack(.audio)
      project.timeline.tracks[index].add(Clip(
        mediaID: stem.id,
        sourceStart: clip.sourceStart,
        duration: clip.duration,
        timelineStart: clip.timelineStart,
        volume: clip.volume,
        keyframes: clip.keyframes.filter { $0.property == .volume },
        fadeIn: clip.fadeIn,
        fadeOut: clip.fadeOut,
      ))
    }
  }

}
