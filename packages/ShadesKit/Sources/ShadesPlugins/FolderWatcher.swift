import CoreServices
import Foundation

// MARK: - FolderWatcher

/// Calls back when anything changes inside some folders, using the system's file events (no
/// polling, so nothing runs while nothing changes). When the system can't take another file
/// events client, it checks the folders' files once a second instead.
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
    let stream = FSEventStreamCreate(
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
      if FSEventStreamStart(stream) {
        self.stream = stream
        return
      }
      FSEventStreamInvalidate(stream)
      FSEventStreamRelease(stream)
    }
    // why: fseventsd serves at most 1024 streams across the whole Mac; with many file-watching
    // tools running it refuses new ones, and plugin edits would never reload.
    logger.error("folders.watchFailed reason=fileEventsUnavailable count=\(folders.count)")
    checking = Task { [weak self] in
      // why: files can change before the first look; starting from nothing reloads once then.
      var last = [FileStamp]()
      while true {
        do {
          try await Task.sleep(for: .seconds(1))
        } catch {
          return
        }
        let now = await Self.fingerprint(of: folders)
        if now != last {
          last = now
          self?.onChange()
        }
      }
    }
  }

  isolated deinit {
    checking?.cancel()
    if let stream {
      FSEventStreamStop(stream)
      FSEventStreamInvalidate(stream)
      FSEventStreamRelease(stream)
    }
  }

  // MARK: Private

  private let onChange: @MainActor () -> Void
  private var stream: FSEventStreamRef?
  /// Checks the folders for changes when file events aren't available.
  private var checking: Task<Void, Never>?

  /// Every file and folder under `folders`, with when it last changed and its size.
  @concurrent
  private static func fingerprint(of folders: [URL]) async -> [FileStamp] {
    let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey]
    return folders.flatMap { folder in
      let items = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: keys)?
        .compactMap { $0 as? URL } ?? []
      return items.map { url in
        // why: a file deleted while it's read has no values; it's then stamped as empty.
        let values = try? url.resourceValues(forKeys: Set(keys))
        return FileStamp(
          path: url.path,
          modified: values?.contentModificationDate,
          size: values?.fileSize,
        )
      }
    }
  }

}

// MARK: - FileStamp

/// One file as last seen: where it is, when it last changed and how big it is.
private struct FileStamp: Equatable, Sendable {
  let path: String
  let modified: Date?
  let size: Int?
}
