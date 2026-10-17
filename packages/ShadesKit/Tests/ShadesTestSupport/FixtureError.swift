/// Why a test fixture couldn't be created or read.
public enum FixtureError: Error {
  case writerFailed
  case imageUnreadable
}
