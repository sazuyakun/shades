import Foundation

// MARK: - SpokenWord

/// A word heard on the timeline: its text, when it plays, and the clip it comes from.
public struct SpokenWord: Hashable, Sendable {
  public init(text: String, start: MediaTime, end: MediaTime, clipID: Clip.ID) {
    self.text = text
    self.start = start
    self.end = end
    self.clipID = clipID
  }

  public let text: String
  public let start: MediaTime
  public let end: MediaTime
  public let clipID: Clip.ID
}

extension Timeline {
  /// Every word heard on the timeline, in time order: each clip that plays sound contributes the
  /// words of its media's transcript that fall inside the clip, moved to timeline time (and
  /// stretched with its speed).
  public func spokenWords(transcripts: [Media.ID: Transcript]) -> [SpokenWord] {
    var words = [SpokenWord]()
    for track in tracks where !track.isMuted {
      for clip in track.clips where track.kind == .audio || clip.isAudioEnabled {
        guard let mediaID = clip.mediaID, let transcript = transcripts[mediaID] else {
          continue
        }
        let sourceEnd = clip.sourceEnd
        for word in transcript.words
          where clip.sourceStart <= word.start && word.start < sourceEnd
        {
          let start = clip.timelineTime(atSource: word.start)
          guard clip.playsSound(at: start) else {
            continue
          }
          words.append(SpokenWord(
            text: word.text,
            start: start,
            end: clip.timelineTime(atSource: min(word.end, sourceEnd)),
            clipID: clip.id,
          ))
        }
      }
    }
    return words.sorted { $0.start < $1.start }
  }
}
