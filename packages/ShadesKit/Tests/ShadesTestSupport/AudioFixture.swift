import Foundation

/// Writes small test sounds, so tests never depend on real recordings.
public enum AudioFixture {

  // MARK: Public

  /// Writes a 16-bit 44.1 kHz WAV of a sine tone (the same in every one of its `channels`) and
  /// returns its URL.
  public static func makeTone(
    seconds: Double = 1,
    frequency: Double = 440,
    amplitude: Double = 0.5,
    channels: Int = 1,
  ) throws(FixtureError) -> URL {
    try write(seconds: seconds, channels: channels) { time in
      sin(2 * .pi * frequency * time) * amplitude
    }
  }

  /// Writes a WAV that's silent except for a tone during each of `bursts` (start, end seconds),
  /// like speech with pauses, over steady hiss of `noise` amplitude (none by default).
  public static func makeBursts(
    seconds: Double,
    bursts: [(Double, Double)],
    noise: Double = 0,
  ) throws(FixtureError) -> URL {
    var state: UInt64 = 1
    return try write(seconds: seconds) { time in
      // why: a fixed pseudo-random sequence keeps the hiss the same on every run.
      state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
      let hiss = (Double(state >> 11) / Double(1 << 53) * 2 - 1) * noise
      let tone = bursts.contains { $0.0 <= time && time < $0.1 }
        ? sin(2 * .pi * 220 * time) * 0.5
        : 0
      return tone + hiss
    }
  }

  /// Writes a click track: a short sharp click on every beat at `beatsPerMinute`, from 0.
  public static func makeClicks(
    beatsPerMinute: Double,
    seconds: Double,
  ) throws(FixtureError) -> URL {
    let beat = 60 / beatsPerMinute
    return try write(seconds: seconds) { time in
      let sinceBeat = time.truncatingRemainder(dividingBy: beat)
      return sinceBeat < 0.01 ? sin(2 * .pi * 2000 * time) * (1 - sinceBeat / 0.01) * 0.8 : 0
    }
  }

  /// Writes a WAV of a tone sounding for the first `on` seconds of every `period`, like speech
  /// with pauses, for `periods` periods. Quick at any length: one period is made and repeated.
  public static func makePulses(
    periods: Int,
    period: Double = 4,
    on: Double = 2.5,
  ) throws(FixtureError) -> URL {
    let one = samples(seconds: period, channels: 1) { time in
      time < on ? sin(2 * .pi * 220 * time) * 0.5 : 0
    }
    var all = Data(capacity: one.count * periods)
    for _ in 0 ..< periods {
      all.append(one)
    }
    return try write(all, channels: 1)
  }

  // MARK: Private

  private static let sampleRate = 44_100

  /// Writes `seconds` of 16-bit 44.1 kHz WAV, each sample from `signal(time)` in every one of
  /// its `channels` (mono by default).
  private static func write(
    seconds: Double,
    channels: Int = 1,
    signal: (Double) -> Double,
  ) throws(FixtureError) -> URL {
    try write(samples(seconds: seconds, channels: channels, signal: signal), channels: channels)
  }

  /// `seconds` of 16-bit samples, each from `signal(time)` in every one of its `channels`.
  private static func samples(
    seconds: Double,
    channels: Int,
    signal: (Double) -> Double,
  ) -> Data {
    let count = Int(seconds * Double(sampleRate))
    var samples = Data(capacity: count * 2 * channels)
    for index in 0 ..< count {
      let value = signal(Double(index) / Double(sampleRate))
      for _ in 0 ..< channels {
        withUnsafeBytes(of: Int16(value * Double(Int16.max)).littleEndian) {
          samples.append(contentsOf: $0)
        }
      }
    }
    return samples
  }

  /// Writes 16-bit 44.1 kHz `samples` (interleaved `channels`) as a WAV file.
  private static func write(_ samples: Data, channels: Int) throws(FixtureError) -> URL {
    var file = Data("RIFF".utf8)
    append(UInt32(36 + samples.count), to: &file)
    file.append(contentsOf: Data("WAVEfmt ".utf8))
    append(UInt32(16), to: &file)
    append(UInt16(1), to: &file)
    append(UInt16(channels), to: &file)
    append(UInt32(sampleRate), to: &file)
    append(UInt32(sampleRate * 2 * channels), to: &file)
    append(UInt16(2 * channels), to: &file)
    append(UInt16(16), to: &file)
    file.append(contentsOf: Data("data".utf8))
    append(UInt32(samples.count), to: &file)
    file.append(samples)
    let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).wav")
    do {
      try file.write(to: url)
    } catch {
      throw .writerFailed
    }
    return url
  }

  private static func append(_ value: some FixedWidthInteger, to data: inout Data) {
    withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
  }

}
