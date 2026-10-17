import Foundation

/// Writes spoken test sentences with the Mac's own voice, so transcription tests know exactly
/// what was said without real recordings.
public enum SpeechFixture {
  /// Speaks `text` into an audio file and returns its URL.
  public static func make(saying text: String) throws(FixtureError) -> URL {
    let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).aiff")
    let say = Process()
    say.executableURL = URL(filePath: "/usr/bin/say")
    say.arguments = ["-o", url.path, text]
    do {
      try say.run()
    } catch {
      throw .writerFailed
    }
    say.waitUntilExit()
    guard say.terminationStatus == 0 else {
      throw .writerFailed
    }
    return url
  }
}
