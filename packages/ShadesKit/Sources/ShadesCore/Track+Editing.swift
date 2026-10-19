import Foundation

/// The building blocks every timeline edit is made of. Each keeps clips sorted and
/// non-overlapping.
extension Track {

  /// Cuts the clip spanning `time` in two. Returns the new right-hand clip's ID, or `nil` if no
  /// clip spans `time` (a cut on a clip's edge changes nothing).
  @discardableResult
  public mutating func split(at time: MediaTime) -> Clip.ID? {
    guard
      let index = clips.firstIndex(where: { $0.timelineStart < time && time < $0.timelineEnd })
    else {
      return nil
    }
    let left = clips[index].trimmingEnd(to: time)
    var right = clips[index].trimmingStart(to: time)
    right = right.withNewID()
    clips[index] = left
    clips.insert(right, at: index + 1)
    return right.id
  }

  /// Empties `start..<end`: clips inside it are removed and clips crossing its edges are trimmed.
  public mutating func clear(from start: MediaTime, to end: MediaTime) {
    split(at: start)
    split(at: end)
    clips.removeAll { $0.timelineStart >= start && $0.timelineEnd <= end }
  }

  /// Moves every clip that starts at or after `time` by `offset` (negative moves left). A clip
  /// spanning `time` is split first, so only its right part moves.
  public mutating func shift(from time: MediaTime, by offset: MediaTime) {
    split(at: time)
    for index in clips.indices where clips[index].timelineStart >= time {
      clips[index].timelineStart = clips[index].timelineStart + offset
    }
  }

  /// Puts a clip into empty space, in time order. The space must already be clear.
  public mutating func add(_ clip: Clip) {
    let index = clips.firstIndex { $0.timelineStart > clip.timelineStart } ?? clips.endIndex
    clips.insert(clip, at: index)
  }

  /// Slides every clip left so they play back to back from the start, with no gaps.
  public mutating func closeGaps() {
    var time = MediaTime.zero
    for index in clips.indices {
      clips[index].timelineStart = time
      time = clips[index].timelineEnd
    }
  }

  /// Whether `start..<end` holds no clips.
  public func isClear(from start: MediaTime, to end: MediaTime) -> Bool {
    !clips.contains { $0.timelineStart < end && start < $0.timelineEnd }
  }

}

extension Clip {

  /// The clip with its start moved to `time` on the timeline; its end stays put.
  public func trimmingStart(to time: MediaTime) -> Clip {
    var clip = self
    let delta = time - timelineStart
    clip.sourceStart = sourceStart + delta
    clip.duration = duration - delta
    clip.timelineStart = time
    return clip
  }

  /// The clip with its end moved to `time` on the timeline; its start stays put.
  public func trimmingEnd(to time: MediaTime) -> Clip {
    var clip = self
    clip.duration = time - timelineStart
    return clip
  }

  /// The same clip under a fresh ID, for the second half of a split or a copy.
  public func withNewID() -> Clip {
    Clip(
      source: source,
      sourceStart: sourceStart,
      duration: duration,
      timelineStart: timelineStart,
      transform: transform,
      opacity: opacity,
      depth: depth,
      volume: volume,
      isAudioEnabled: isAudioEnabled,
      keyframes: keyframes,
      sticker: sticker,
      grade: grade,
      effects: effects,
      blend: blend,
    )
  }

}
