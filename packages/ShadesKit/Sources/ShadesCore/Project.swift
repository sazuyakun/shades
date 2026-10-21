import Foundation

/// Everything the user is editing: imported media and the timeline built from it.
public struct Project: Codable, Hashable, Sendable {
  public init(media: [Media] = [], timeline: Timeline = Timeline()) {
    self.media = media
    self.timeline = timeline
  }

  public var media: [Media]
  public var timeline: Timeline

  /// Whether `track` makes sound: an audio track, or a video track whose clips play their own.
  public func hasSound(_ track: Track) -> Bool {
    track.kind == .audio || track.kind == .video && track.clips.contains { clip in
      clip.isAudioEnabled && clip.mediaID.flatMap(media(withID:))?.hasAudio == true
    }
  }

  /// Looks up imported media by its ID.
  public func media(withID id: Media.ID) -> Media? {
    media.first { $0.id == id }
  }
}
