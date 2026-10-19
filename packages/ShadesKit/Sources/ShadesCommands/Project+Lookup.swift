import ShadesCore

/// Lookups every command shares. Each throws (and logs) a plain-words error when the thing
/// asked for isn't there.
extension Project {

  /// The media with `id`.
  func requireMedia(_ id: Media.ID) throws(CommandError) -> Media {
    guard let media = media(withID: id) else {
      throw rejected(.mediaNotFound(id))
    }
    return media
  }

  /// Where the clip with `id` is.
  func requireClip(_ id: Clip.ID) throws(CommandError) -> (track: Int, clip: Int) {
    guard let location = timeline.location(ofClip: id) else {
      throw rejected(.clipNotFound(id))
    }
    return location
  }

  /// The index of the track labeled `label` ("V1", "A2"…).
  func requireTrack(_ label: String) throws(CommandError) -> Int {
    let normalized = label.uppercased()
    guard let index = timeline.tracks.firstIndex(where: { timeline.label(of: $0) == normalized })
    else {
      throw rejected(.trackNotFound(label))
    }
    return index
  }

  /// The track a clip of `media` goes on: the one labeled `label`, or the first track of the
  /// right kind (created if the timeline has none).
  mutating func track(for media: Media, labeled label: String?) throws(CommandError) -> Int {
    let kind: TrackKind = media.hasVideo ? .video : .audio
    if let label {
      let index = try requireTrack(label)
      guard timeline.tracks[index].kind == kind else {
        throw rejected(.wrongTrackKind(track: label.uppercased(), needs: kind))
      }
      return index
    }
    if let index = timeline.tracks.firstIndex(where: { $0.kind == kind }) {
      return index
    }
    return addTrack(kind)
  }

  /// Places part of `media` at `start` on the lowest upper track of its kind that's free then
  /// (above V1 or A1, added if none is), and returns the new clip's ID.
  @discardableResult
  mutating func placeOnTop(
    _ media: Media,
    range: (start: MediaTime, duration: MediaTime),
    at start: MediaTime,
  ) -> Clip.ID {
    let kind: TrackKind = media.hasVideo ? .video : .audio
    let end = start + range.duration
    let upper = timeline.tracks.indices.filter { timeline.tracks[$0].kind == kind }.dropFirst()
    let index = upper.first { timeline.tracks[$0].isClear(from: start, to: end) }
      ?? addTrack(kind)
    let clip = Clip(
      mediaID: media.id,
      sourceStart: range.start,
      duration: range.duration,
      timelineStart: start,
      isAudioEnabled: media.hasAudio,
    )
    timeline.tracks[index].add(clip)
    return clip.id
  }

  /// The text track labeled `label`, or the first text track (added if there is none).
  mutating func textTrack(labeled label: String?) throws(CommandError) -> Int {
    if let label {
      let index = try requireTrack(label)
      guard timeline.tracks[index].kind == .text else {
        throw rejected(.wrongTrackKind(track: label.uppercased(), needs: .text))
      }
      return index
    }
    return timeline.tracks.firstIndex { $0.kind == .text } ?? addTrack(.text)
  }

  /// Adds an empty track above the others of its kind and returns its index.
  @discardableResult
  mutating func addTrack(_ kind: TrackKind) -> Int {
    let index = (timeline.tracks.lastIndex { $0.kind == kind } ?? timeline.tracks.count - 1) + 1
    timeline.tracks.insert(Track(kind: kind), at: index)
    return index
  }

  /// `time` moved to the nearest frame of the timeline.
  func onFrame(_ time: MediaTime) -> MediaTime {
    time.roundedToFrame(at: timeline.format.framesPerSecond)
  }

  /// The part of `media` from `start` to `end` (the whole file by default; a still can run any
  /// length), on frame boundaries.
  func sourceRange(
    of media: Media,
    from start: MediaTime?,
    to end: MediaTime?,
  ) throws(CommandError) -> (start: MediaTime, duration: MediaTime) {
    let fps = timeline.format.framesPerSecond
    let whole = media.duration.flooredToFrame(at: fps)
    let first = start.map(onFrame) ?? .zero
    let last = end.map(onFrame) ?? whole
    guard first >= .zero, media.isStill || last <= whole else {
      throw rejected(.invalidRange("the media is only \(whole.seconds) seconds long"))
    }
    guard first < last else {
      throw rejected(.invalidRange("source_end must come after source_start"))
    }
    return (first, last - first)
  }

}
