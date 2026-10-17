import Foundation
import ShadesCore

/// Made-up media for command tests; nothing is read from disk.
func makeMedia(seconds: Double, hasVideo: Bool = true, hasAudio: Bool = true) -> Media {
  Media(
    url: URL(filePath: "/tmp/clip.mov"),
    duration: MediaTime(seconds: seconds),
    width: hasVideo ? 1920 : 0,
    height: hasVideo ? 1080 : 0,
    hasVideo: hasVideo,
    hasAudio: hasAudio,
  )
}

/// Shorthand for a timeline time.
func seconds(_ value: Double) -> MediaTime {
  MediaTime(seconds: value)
}
