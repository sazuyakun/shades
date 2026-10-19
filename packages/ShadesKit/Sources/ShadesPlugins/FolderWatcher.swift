import CoreServices
import Foundation

/// Calls back when anything changes inside some folders, using the system's file events (no
/// polling, so nothing runs while nothing changes).
@MainActor
final class FolderWatcher {

  // MARK: Lifecycle

  /// Starts watching `folders` (and everything under them).
  init(_ folders: [URL], onChange: @escaping @MainActor () -> Void) {
    self.onChange = onChange
    var context = FSEventStreamContext(
      version: 0,
      info: nil,
      retain: nil,
      release: nil,
      copyDescription: nil,
    )
    context.info = Unmanaged.passUnretained(self).toOpaque()
    stream = FSEventStreamCreate(
      nil,
      { _, info, _, _, _, _ in
        guard let info else {
          return
        }
        MainActor.assumeIsolated {
          Unmanaged<FolderWatcher>.fromOpaque(info).takeUnretainedValue().onChange()
        }
      },
      &context,
      folders.map(\.path) as CFArray,
      FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
      0.3,
      FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents |
        kFSEventStreamCreateFlagNoDefer),
    )
    if let stream {
      FSEventStreamSetDispatchQueue(stream, .main)
      FSEventStreamStart(stream)
    }
  }

  isolated deinit {
    if let stream {
      FSEventStreamStop(stream)
      FSEventStreamInvalidate(stream)
      FSEventStreamRelease(stream)
    }
  }

  // MARK: Private

  private let onChange: @MainActor () -> Void
  private var stream: FSEventStreamRef?

}
