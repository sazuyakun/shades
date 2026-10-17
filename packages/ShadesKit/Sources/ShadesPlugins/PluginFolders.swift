import Foundation
import Observation

/// The folders Shades loads plugins from, in priority order. Saved between launches.
@MainActor
@Observable
public final class PluginFolders {

  // MARK: Lifecycle

  /// Loads the saved folders, or starts with `~/Shades/Plugins` the first time.
  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    let paths = defaults.stringArray(forKey: Self.key)
    urls = paths?.map { URL(filePath: $0, directoryHint: .isDirectory) } ?? [Self.defaultFolder]
  }

  // MARK: Public

  /// Where plugins live until the user picks other folders.
  public static let defaultFolder = URL.homeDirectory.appending(
    path: "Shades/Plugins",
    directoryHint: .isDirectory,
  )

  public private(set) var urls: [URL]

  /// Adds a folder at the end, unless it's already in the list.
  public func add(_ url: URL) {
    guard !urls.contains(url) else {
      return
    }
    urls.append(url)
    save()
  }

  /// Removes the folders at the given positions.
  public func remove(atOffsets offsets: IndexSet) {
    for index in offsets.reversed() {
      urls.remove(at: index)
    }
    save()
  }

  /// Reorders folders, as a drag in a list does.
  public func move(fromOffsets source: IndexSet, toOffset destination: Int) {
    let moving = source.map { urls[$0] }
    for index in source.reversed() {
      urls.remove(at: index)
    }
    urls.insert(contentsOf: moving, at: destination - source.count(in: 0..<destination))
    save()
  }

  // MARK: Private

  private static let key = "pluginFolders"

  @ObservationIgnored private let defaults: UserDefaults

  private func save() {
    defaults.set(urls.map(\.path), forKey: Self.key)
  }

}
