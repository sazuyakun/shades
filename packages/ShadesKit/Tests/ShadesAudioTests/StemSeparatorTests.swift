import Foundation
import ShadesAudio
import ShadesMedia
import ShadesTestSupport
import Testing

struct StemSeparatorTests {

  // MARK: Internal

  /// Needs the HTDemucs model in Shades' models folder, so it only runs with SHADES_STEMS=1.
  @Test(.enabled(if: ProcessInfo.processInfo.environment["SHADES_STEMS"] == "1"))
  func `speech over a chord comes apart into voice and music`() async throws {
    let speech = try await AudioDecoder.mono(
      from: SpeechFixture.make(saying: "Shades separates the voice from the music behind it."),
      sampleRate: StemSeparator.sampleRate,
    )
    let chord = (0 ..< speech.count).map { index in
      let time = Double(index) / StemSeparator.sampleRate
      return Float([220.0, 277.2, 329.6].lazy.map { sin(2 * .pi * $0 * time) * 0.08 }.reduce(0, +))
    }
    let mix = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).m4a")
    let mixed = zip(speech, chord).map(+)
    try await AudioWriter.writeM4A([mixed, mixed], sampleRate: StemSeparator.sampleRate, to: mix)
    let stems = try await StemSeparator.separate(
      mix,
      modelURL: modelURL,
      progress: { _ in },
    )
    let voice = try #require(stems[.voice]?.first)
    let music = try #require(stems[.music]?.first)
    #expect(correlation(voice, speech) > 0.8)
    #expect(correlation(music, chord) > 0.8)
    #expect(correlation(voice, chord) < 0.3)
  }

  // MARK: Private

  private let modelURL = URL.applicationSupportDirectory
    .appending(path: "Shades/Models/HTDemucs.mlmodelc")

  private func correlation(_ first: [Float], _ second: [Float]) -> Double {
    let count = min(first.count, second.count)
    var product = 0.0
    var firstPower = 0.0
    var secondPower = 0.0
    for index in 0 ..< count {
      product += Double(first[index]) * Double(second[index])
      firstPower += Double(first[index] * first[index])
      secondPower += Double(second[index] * second[index])
    }
    return product / max((firstPower * secondPower).squareRoot(), 1e-12)
  }

}
