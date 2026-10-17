import Foundation
@testable import ShadesCaptions
import ShadesTestSupport
import Testing

struct TranscriberTests {
  @Test
  func `sound decodes to 16 kHz mono samples`() async throws {
    let url = try AudioFixture.makeTone(seconds: 2)
    let samples = try await AudioSamples.mono(from: url)
    #expect(abs(Double(samples.count) - 2 * AudioSamples.sampleRate) < AudioSamples
      .sampleRate * 0.05)
    #expect(samples.contains { abs($0) > 0.3 })
  }

  @Test
  func `a file without sound is reported`() async throws {
    let url = try await VideoFixture.make(red: 0, green: 0, blue: 0)
    await #expect(throws: CaptionsError.noAudio(url)) {
      try await AudioSamples.mono(from: url)
    }
  }

  /// Needs the Small model (485 MB, downloaded once), so it only runs with SHADES_WHISPER=1.
  @Test(.enabled(if: ProcessInfo.processInfo.environment["SHADES_WHISPER"] == "1"))
  func `spoken words come back with timings`() async throws {
    let url = try SpeechFixture.make(saying: "Hello world, this is a test of the speech model.")
    let transcript = try await Transcriber.transcribe(url, model: .small, language: "en") { _ in }
    let text = transcript.segments.map(\.text).joined(separator: " ").lowercased()
    #expect(text.contains("hello world"))
    #expect(text.contains("test"))
    let words = transcript.words
    #expect(zip(words, words.dropFirst()).allSatisfy { $0.start <= $1.start })
  }
}
