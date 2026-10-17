import Foundation

/// Writes small test sounds, so tests never depend on real recordings.
public enum AudioFixture {

  // MARK: Public

  /// Writes a mono 16-bit 44.1 kHz WAV of a sine tone and returns its URL.
  public static func makeTone(
    seconds: Double = 1,
    frequency: Double = 440,
    amplitude: Double = 0.5,
  ) throws(FixtureError) -> URL {
    try write(seconds: seconds) { time in sin(2 * .pi * frequency * time) * amplitude }
  }

  /// Writes a WAV that's silent except for a tone during each of `bursts` (start, end seconds),
  /// like speech with pauses.
  public static func makeBursts(
    seconds: Double,
    bursts: [(Double, Double)],
  ) throws(FixtureError) -> URL {
    try write(seconds: seconds) { time in
      bursts.contains { $0.0 <= time && time < $0.1 } ? sin(2 * .pi * 220 * time) * 0.5 : 0
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

  // MARK: Private

  /// Writes `seconds` of mono 16-bit 44.1 kHz WAV, each sample from `signal(time)`.
  private static func write(
    seconds: Double,
    signal: (Double) -> Double,
  ) throws(FixtureError) -> URL {
    let sampleRate = 44_100
    let count = Int(seconds * Double(sampleRate))
    var samples = Data(capacity: count * 2)
    for index in 0 ..< count {
      let value = signal(Double(index) / Double(sampleRate))
      withUnsafeBytes(of: Int16(value * Double(Int16.max)).littleEndian) {
        samples.append(contentsOf: $0)
      }
    }
    var file = Data("RIFF".utf8)
    append(UInt32(36 + samples.count), to: &file)
    file.append(contentsOf: Data("WAVEfmt ".utf8))
    append(UInt32(16), to: &file)
    append(UInt16(1), to: &file)
    append(UInt16(1), to: &file)
    append(UInt32(sampleRate), to: &file)
    append(UInt32(sampleRate * 2), to: &file)
    append(UInt16(2), to: &file)
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
