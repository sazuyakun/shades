import ShadesCore

/// How edits carry linked clips (a video and its detached sound) along with each other.
extension Project {

  /// `indices` and every track holding a clip linked to a clip on them, so a ripple on those
  /// tracks keeps linked clips in step.
  func linkedTracks(_ indices: [Int]) -> [Int] {
    var tracks = indices
    for index in indices {
      for clip in timeline.tracks[index].clips {
        for partner in timeline.partners(of: clip.id) {
          if
            let location = timeline.location(ofClip: partner.id),
            !tracks.contains(location.track)
          {
            tracks.append(location.track)
          }
        }
      }
    }
    return tracks
  }

  /// Slides the clip `id` by `offset` along its own track, replacing whatever is in the way.
  mutating func slide(_ id: Clip.ID, by offset: MediaTime) throws(CommandError) {
    let location = try requireClip(id)
    var clip = timeline.tracks[location.track].clips.remove(at: location.clip)
    clip.timelineStart = clip.timelineStart + offset
    guard clip.timelineStart >= .zero else {
      throw rejected(.invalidRange(
        "a linked clip would start before the timeline does; unlink them first"
      ))
    }
    timeline.tracks[location.track].clear(from: clip.timelineStart, to: clip.timelineEnd)
    timeline.tracks[location.track].add(clip)
  }

}
