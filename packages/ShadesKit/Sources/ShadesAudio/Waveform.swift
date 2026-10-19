import Foundation
import ShadesMedia

/// A file's sound drawn as a waveform: how loud it peaks in each short stretch.
public enum Waveform {

  // MARK: Public

  /// Peaks a second: enough for a clip zoomed in to a few seconds.
  public static let peaksPerSecond = 25.0
  /// Decibels between silent (0) and full scale (1) on the peaks' scale.
  public static let decibelRange = 40.0

  /// The file's loudest moment in each stretch, on a decibel scale from 0 (−40 dB or quieter)
  /// to 1 (full scale), rounded to keep the saved analysis small.
  @concurrent
  public static func peaks(in url: URL) async throws(AudioError) -> [Float] {
    let samples: [Float]
    do {
      samples = try await AudioDecoder.mono(from: url, sampleRate: sampleRate)
    } catch {
      throw .unreadable(error)
    }
    return peaks(of: samples)
  }

  // MARK: Internal

  /// Peaks of mono samples at `sampleRate`.
  static func peaks(of samples: [Float]) -> [Float] {
    let perPeak = Int(sampleRate / peaksPerSecond)
    return stride(from: 0, to: samples.count, by: perPeak).map { start in
      let peak = samples[start ..< min(start + perPeak, samples.count)]
        .reduce(Float(0)) { max($0, abs($1)) }
      let level = 1 + 20 * log10(max(peak, 1e-6)) / Float(decibelRange)
      return (max(level, 0) * 100).rounded() / 100
    }
  }

  // MARK: Private

  private static let sampleRate = 8000.0

}
