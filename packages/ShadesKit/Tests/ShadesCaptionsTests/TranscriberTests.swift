import Foundation
import ShadesCaptions
import ShadesTestSupport
import Testing

struct TranscriberTests {
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
