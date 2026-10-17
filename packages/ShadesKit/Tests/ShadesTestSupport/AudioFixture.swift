import Foundation

/// Writes small test sounds, so tests never depend on real recordings.
public enum AudioFixture {

  // MARK: Public

  /// Writes a mono 16-bit 44.1 kHz WAV of a sine tone (silence when `frequency` is 0) and
  /// returns its URL.
  public static func makeTone(
    seconds: Double = 1,
    frequency: Double = 440,
    amplitude: Double = 0.5,
  ) throws(FixtureError) -> URL {
    let sampleRate = 44_100
    let count = Int(seconds * Double(sampleRate))
    var samples = Data(capacity: count * 2)
    for index in 0 ..< count {
      let value = sin(2 * .pi * frequency * Double(index) / Double(sampleRate)) * amplitude
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

  // MARK: Private

  private static func append(_ value: some FixedWidthInteger, to data: inout Data) {
    withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
  }

}
