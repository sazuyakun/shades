import Foundation
import ShadesCore
import ShadesMedia

// MARK: - SpeechActivity

/// Finds when someone is talking, from loudness alone. Ported from Nebula.
///
/// Each 20 ms frame's level is compared with an adaptive noise floor: the minimum of the lightly
/// smoothed level over a sliding ~6 s window, ignoring digital silence, and never more than 12 dB
/// above the recording's quiet level (its 10th percentile), so long speech can't become its own
/// floor. Speech starts 10 dB above the floor (and above -50 dBFS) and continues while 6 dB above
/// it, bridging dips under 0.25 s. Segments get 0.05 s padding, gaps under 0.35 s merge and
/// segments under 0.2 s drop.
public enum SpeechActivity {

  // MARK: Public

  /// When someone talks in the file at `url` (in its own time), and how loud its background is.
  @concurrent
  public static func detect(in url: URL) async throws(AudioError) -> Speech {
    let samples: [Float]
    do {
      samples = try await AudioDecoder.mono(from: url, sampleRate: sampleRate)
    } catch {
      throw .unreadable(error)
    }
    let perFrame = Int(sampleRate * frameDuration)
    let levels = stride(from: 0, to: samples.count, by: perFrame).map { start in
      let frame = samples[start ..< min(start + perFrame, samples.count)]
      let squares = frame.reduce(Float(0)) { $0 + $1 * $1 }
      return (squares / Float(max(frame.count, 1))).squareRoot()
    }
    let ranges = detect(levels: levels, frameDuration: frameDuration).map { range in
      TimeRange(
        start: MediaTime(seconds: range.start, timescale: 1000),
        end: MediaTime(seconds: range.end, timescale: 1000),
      )
    }
    return Speech(ranges: ranges, noiseFloor: noiseFloor(levels: levels))
  }

  // MARK: Internal

  /// Speech in a series of linear RMS levels, one per `frameDuration` seconds. Pure: ranges are
  /// sorted, non-overlapping and in seconds.
  static func detect(levels: [Float], frameDuration: Double) -> [(start: Double, end: Double)] {
    guard !levels.isEmpty, frameDuration > 0 else {
      return []
    }
    let decibels = levels.map { 20 * log10(max($0.isFinite ? $0 : 0, 1e-6)) }
    let floor = noiseFloor(decibels: decibels, frameDuration: frameDuration)
    let total = Double(levels.count) * frameDuration
    let hangoverFrames = max(1, Int((hangover / frameDuration).rounded()))
    var raw = [(start: Double, end: Double)]()
    var segmentStart: Int?
    var lastActive = 0
    for index in decibels.indices {
      let level = decibels[index]
      if let start = segmentStart {
        if level >= max(floor[index] + offsetMargin, absoluteOffset) {
          lastActive = index
        } else if index - lastActive > hangoverFrames {
          raw.append(padded(start, lastActive, frameDuration, total))
          segmentStart = nil
        }
      } else if level >= max(floor[index] + onsetMargin, absoluteOnset) {
        segmentStart = index
        lastActive = index
      }
    }
    if let start = segmentStart {
      raw.append(padded(start, lastActive, frameDuration, total))
    }
    return cleaned(raw)
  }

  /// The background's level in dBFS: the quietest tenth of the frames' levels (digital silence
  /// counts, as the cleanest background there is), never below -100.
  static func noiseFloor(levels: [Float]) -> Double {
    let decibels = levels.map { 20 * log10(max($0.isFinite ? Double($0) : 0, 1e-5)) }.sorted()
    guard !decibels.isEmpty else {
      return Double(minimumFloor)
    }
    return decibels[Int(Double(decibels.count - 1) * quietPercentile)]
  }

  // MARK: Private

  private static let sampleRate = 16_000.0
  private static let frameDuration = 0.02
  private static let onsetMargin: Float = 10
  private static let offsetMargin: Float = 6
  private static let absoluteOnset: Float = -50
  private static let absoluteOffset: Float = -56
  /// Frames quieter than this are digital silence and ignored by the noise floor.
  private static let digitalSilence: Float = -90
  private static let minimumFloor: Float = -100
  private static let floorWindow = 3.0
  private static let floorCeilingMargin: Float = 12
  private static let quietPercentile = 0.1
  private static let smoothingWindow = 0.05
  private static let hangover = 0.25
  private static let edgePadding = 0.05
  private static let mergeGap = 0.35
  private static let minimumSegment = 0.2

  private static func padded(
    _ start: Int,
    _ end: Int,
    _ frame: Double,
    _ total: Double,
  ) -> (start: Double, end: Double) {
    (max(0, Double(start) * frame - edgePadding), min(total, Double(end + 1) * frame + edgePadding))
  }

  /// Merges segments closer than `mergeGap` and drops ones shorter than `minimumSegment`.
  private static func cleaned(_ ranges: [(start: Double, end: Double)]) -> [(
    start: Double,
    end: Double,
  )] {
    var merged = [(start: Double, end: Double)]()
    for range in ranges.sorted(by: { $0.start < $1.start }) {
      if let last = merged.last, range.start - last.end < mergeGap {
        merged[merged.count - 1].end = max(last.end, range.end)
      } else {
        merged.append(range)
      }
    }
    return merged.filter { $0.end - $0.start >= minimumSegment }
  }

  /// The adaptive noise floor in dB per frame: a sliding-window minimum of the smoothed level.
  private static func noiseFloor(decibels: [Float], frameDuration: Double) -> [Float] {
    let count = decibels.count
    let smoothHalf = max(1, Int((smoothingWindow / frameDuration).rounded()))
    var prefix = [Double](repeating: 0, count: count + 1)
    var validPrefix = [Int](repeating: 0, count: count + 1)
    for index in 0 ..< count {
      let isValid = decibels[index] > digitalSilence
      prefix[index + 1] = prefix[index] + (isValid ? Double(decibels[index]) : 0)
      validPrefix[index + 1] = validPrefix[index] + (isValid ? 1 : 0)
    }
    var smoothed = [Float](repeating: .infinity, count: count)
    for index in 0 ..< count {
      let low = max(0, index - smoothHalf)
      let high = min(count, index + smoothHalf + 1)
      let valid = validPrefix[high] - validPrefix[low]
      if valid > 0 {
        smoothed[index] = Float((prefix[high] - prefix[low]) / Double(valid))
      }
    }
    let usable = smoothed.filter(\.isFinite).sorted()
    let ceiling = usable.isEmpty
      ? minimumFloor
      : usable[min(usable.count - 1, Int(Double(usable.count) * quietPercentile))] +
      floorCeilingMargin
    let half = max(1, Int((floorWindow / frameDuration).rounded()))
    var floor = [Float](repeating: minimumFloor, count: count)
    var window = [Int]()
    var head = 0
    var pushed = 0
    for index in 0 ..< count {
      let windowEnd = min(count - 1, index + half)
      while pushed <= windowEnd {
        while window.count > head, let back = window.last, smoothed[back] >= smoothed[pushed] {
          window.removeLast()
        }
        window.append(pushed)
        pushed += 1
      }
      while head < window.count, window[head] < index - half {
        head += 1
      }
      if head < window.count {
        let minimum = smoothed[window[head]]
        floor[index] = minimum.isFinite ? max(min(minimum, ceiling), minimumFloor) : minimumFloor
      }
    }
    return floor
  }

}

// MARK: - Speech

/// What sound analysis heard in a recording.
public struct Speech: Sendable {
  /// When someone talks, in the recording's own time.
  public let ranges: [TimeRange]
  /// How loud the background is, in dBFS.
  public let noiseFloor: Double
}
