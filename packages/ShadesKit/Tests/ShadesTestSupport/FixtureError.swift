/// Why a test fixture couldn't be created or read.
public enum FixtureError: Error {
  case writerFailed
  case imageUnreadable
  /// An HTTP request to the test server failed or its reply wasn't the JSON expected.
  case requestFailed
}
