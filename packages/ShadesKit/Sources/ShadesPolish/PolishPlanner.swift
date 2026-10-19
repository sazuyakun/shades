import Foundation
import ShadesCore

/// Proposes Polish for talking-head footage on a stretch of one track, from its words (or speech
/// activity when there's no transcript) and any music beats. Pure: nothing changes until the
/// plan is applied.
public enum PolishPlanner {

  // MARK: Public

  /// The plan for `range` on `track` ("V1" by default).
  public static func plan(
    _ timeline: Timeline,
    analyses: [Media.ID: MediaAnalysis],
    range: TimeRange,
    track label: String? = nil,
    options: PolishOptions = PolishOptions(),
  ) -> PolishPlan {
    let track = timeline.tracks.first { label == nil
      ? $0.kind == .video
      : timeline.label(of: $0) == label?.uppercased()
    }
    let trackLabel = track.map(timeline.label(of:)) ?? "V1"
    guard let track else {
      return PolishPlan(id: UUID(), range: range, track: trackLabel, items: [])
    }
    let words = timeline.spokenWords(transcripts: analyses.compactMapValues(\.transcript))
      .filter { word in
        track.clips.contains { $0.id == word.clipID } && range.start <= word.start && word
          .start < range.end
      }
    var cuts = [PolishItem]()
    if options.retakes {
      cuts += retakes(in: words)
    }
    if options.fillers {
      cuts += fillers(in: words)
    }
    if options.silences {
      cuts += words.isEmpty
        ? silences(
          fromSpeech: speechOnTimeline(track, analyses: analyses),
          in: range,
          options: options,
        )
        : silences(between: words, in: range, options: options)
    }
    cuts = withoutOverlaps(cuts)
    var items = cuts
    if options.beatSnap {
      items += beatSnaps(
        for: cuts,
        beats: beatsOnTimeline(timeline, analyses: analyses),
        words: words,
      )
    }
    if options.punchIn {
      items += punchIns(after: cuts, in: range)
    }
    return PolishPlan(id: UUID(), range: range, track: trackLabel, items: items)
  }

  // MARK: Internal

  /// How much a punch-in zooms.
  static let punchInScale = 1.15

  /// Lowercased with punctuation stripped, for comparing words.
  static func normalized(_ word: String) -> String {
    word.lowercased().filter { $0.isLetter || $0.isNumber }
  }

  /// Speech stretches of the track's clips, moved to timeline time.
  static func speechOnTimeline(
    _ track: Track,
    analyses: [Media.ID: MediaAnalysis],
  ) -> [TimeRange] {
    track.clips.flatMap { clip -> [TimeRange] in
      guard let mediaID = clip.mediaID, let speech = analyses[mediaID]?.speech else {
        return []
      }
      let offset = clip.timelineStart - clip.sourceStart
      let sourceEnd = clip.sourceStart + clip.duration
      return speech.filter { $0.end > clip.sourceStart && $0.start < sourceEnd }.map { stretch in
        TimeRange(
          start: max(stretch.start, clip.sourceStart) + offset,
          end: min(stretch.end, sourceEnd) + offset,
        )
      }
    }
  }

  // MARK: Private

  /// How far a cut may move to land on a beat, in seconds.
  private static let beatReach = 0.25

  private static func seconds(_ value: Double) -> MediaTime {
    MediaTime(seconds: value, timescale: 1000)
  }

  /// Pauses between words longer than the minimum, keeping padding around the words, plus the
  /// pause before the first word and after the last.
  private static func silences(
    between words: [SpokenWord],
    in range: TimeRange,
    options: PolishOptions,
  ) -> [PolishItem] {
    guard let first = words.first, let last = words.last else {
      return []
    }
    let pad = seconds(options.padding)
    var gaps = [(start: range.start, end: first.start - pad)]
    gaps += zip(words, words.dropFirst()).map { ($0.end + pad, $1.start - pad) }
    gaps.append((last.end + pad, range.end))
    return gaps.compactMap { gap in
      let length = (gap.end - gap.start).seconds
      guard length + 2 * options.padding >= options.minimumSilence, length > 0.04 else {
        return nil
      }
      return PolishItem(
        id: UUID(),
        kind: .silence,
        range: TimeRange(start: gap.start, end: gap.end),
        detail: String(format: "%.1f s pause", length),
      )
    }
  }

  /// Pauses between stretches of speech, when there's no transcript.
  private static func silences(
    fromSpeech speech: [TimeRange],
    in range: TimeRange,
    options: PolishOptions,
  ) -> [PolishItem] {
    let pad = seconds(options.padding)
    var edges = [range.start]
    for stretch in speech where stretch.overlaps(range) {
      edges += [stretch.start - pad, stretch.end + pad]
    }
    edges.append(range.end)
    return stride(from: 0, to: edges.count - 1, by: 2).compactMap { index in
      let start = max(edges[index], range.start)
      let end = min(edges[index + 1], range.end)
      let length = (end - start).seconds
      guard length + 2 * options.padding >= options.minimumSilence, length > 0.04 else {
        return nil
      }
      return PolishItem(
        id: UUID(),
        kind: .silence,
        range: TimeRange(start: start, end: end),
        detail: String(format: "%.1f s pause", length),
      )
    }
  }

  private static func fillers(in words: [SpokenWord]) -> [PolishItem] {
    words.filter { PolishOptions.fillerWords.contains(normalized($0.text)) }.map { word in
      PolishItem(
        id: UUID(),
        kind: .filler,
        range: TimeRange(start: word.start, end: word.end),
        detail: "“\(word.text)”",
      )
    }
  }

  /// A phrase the speaker restarts: when the next phrase opens with the same first three words,
  /// or shares most of its words, the earlier attempt goes.
  private static func retakes(in words: [SpokenWord]) -> [PolishItem] {
    let phrases = phrases(of: words)
    return zip(phrases, phrases.dropFirst()).compactMap { attempt, redo in
      let first = attempt.map { normalized($0.text) }.filter { !$0.isEmpty }
      let second = redo.map { normalized($0.text) }.filter { !$0.isEmpty }
      let opening = min(3, first.count)
      let sameOpening = opening >= 2 && Array(first.prefix(opening)) ==
        Array(second.prefix(opening))
      let shared = Double(Set(first).intersection(second).count) / Double(max(Set(first).count, 1))
      guard
        sameOpening || (first.count >= 3 && shared >= 0.7), let start = attempt.first,
        let next = redo.first
      else {
        return nil
      }
      let text = attempt.map(\.text).joined(separator: " ")
      return PolishItem(
        id: UUID(),
        kind: .retake,
        range: TimeRange(start: start.start, end: next.start),
        detail: "“\(text)”",
      )
    }
  }

  /// Words split into phrases at sentence ends and pauses of half a second or more.
  private static func phrases(of words: [SpokenWord]) -> [[SpokenWord]] {
    var phrases = [[SpokenWord]]()
    var current = [SpokenWord]()
    for (index, word) in words.enumerated() {
      current.append(word)
      let isLast = index + 1 == words.count
      let endsSentence = word.text.last.map { ".?!।".contains($0) } ?? false
      if isLast || endsSentence || (words[index + 1].start - word.end).seconds >= 0.5 {
        phrases.append(current)
        current = []
      }
    }
    return phrases
  }

  /// Cuts sorted, with ones overlapping an earlier (stronger) cut merged into it.
  private static func withoutOverlaps(_ cuts: [PolishItem]) -> [PolishItem] {
    var kept = [PolishItem]()
    for cut in cuts.sorted(by: { $0.range.start < $1.range.start }) {
      if let last = kept.last, cut.range.start < last.range.end {
        if cut.range.end > last.range.end {
          kept[kept.count - 1] = PolishItem(
            id: last.id,
            kind: last.kind,
            range: TimeRange(start: last.range.start, end: cut.range.end),
            detail: last.detail,
          )
        }
      } else {
        kept.append(cut)
      }
    }
    return kept
  }

  /// For each cut, a nudge of its start (within reach, never into a word) so that after the
  /// track closes up, the cut lands on a music beat.
  private static func beatSnaps(
    for cuts: [PolishItem],
    beats: [MediaTime],
    words: [SpokenWord],
  ) -> [PolishItem] {
    guard !beats.isEmpty else {
      return []
    }
    var removed = MediaTime.zero
    var snaps = [PolishItem]()
    for cut in cuts {
      let landing = cut.range.start - removed
      let previousWordEnd = words.last { $0.end <= cut.range.start }?.end ?? .zero
      if
        let beat = beats.min(by: { abs(($0 - landing).seconds) < abs(($1 - landing).seconds) }),
        abs((beat - landing).seconds) <= beatReach
      {
        let start = cut.range.start + (beat - landing)
        if start > previousWordEnd, start < cut.range.end, start != cut.range.start {
          snaps.append(PolishItem(
            id: UUID(),
            kind: .beatSnap,
            range: TimeRange(start: start, end: cut.range.end),
            detail: String(format: "cut moves %+.2f s onto a beat", (beat - landing).seconds),
          ))
          removed = removed + (cut.range.end - start)
          continue
        }
      }
      removed = removed + cut.range.duration
    }
    return snaps
  }

  /// Every second stretch between cuts gets a slight zoom, so jump cuts read as intentional.
  private static func punchIns(after cuts: [PolishItem], in range: TimeRange) -> [PolishItem] {
    var edges = [range.start] + cuts.flatMap { [$0.range.start, $0.range.end] } + [range.end]
    edges = edges.sorted()
    let stretches = stride(from: 0, to: edges.count - 1, by: 2).map { TimeRange(
      start: edges[$0],
      end: edges[$0 + 1],
    ) }
    .filter { $0.duration > .zero }
    return stretches.enumerated().filter { $0.offset % 2 == 1 }.map { _, stretch in
      PolishItem(
        id: UUID(),
        kind: .punchIn,
        range: stretch,
        detail: "zoom to \(Int((punchInScale * 100).rounded()))%",
      )
    }
  }

  /// Beats of music on audio tracks, moved to timeline time (audio tracks don't move when the
  /// speech track closes up).
  private static func beatsOnTimeline(
    _ timeline: Timeline,
    analyses: [Media.ID: MediaAnalysis],
  ) -> [MediaTime] {
    timeline.tracks.filter { $0.kind == .audio }.flatMap(\.clips).flatMap { clip -> [MediaTime] in
      guard let mediaID = clip.mediaID, let beats = analyses[mediaID]?.beats?.beats else {
        return []
      }
      let sourceEnd = clip.sourceStart + clip.duration
      return beats.filter { clip.sourceStart <= $0 && $0 < sourceEnd }
        .map { $0 - clip.sourceStart + clip.timelineStart }
    }
    .sorted()
  }

}
