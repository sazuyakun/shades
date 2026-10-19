import Foundation
import ShadesCore
import UniformTypeIdentifiers

/// Reads plugins from disk. A plugin is a folder with a `plugin.json` manifest (its name,
/// description, text styles and templates) and any of `stickers/`, `sounds/` and `fonts/`.
public enum PluginLoader {

  // MARK: Public

  /// The plugins in `folders`, in order: each folder is a plugin itself, or holds plugins one
  /// level down.
  @concurrent
  public static func plugins(in folders: [URL]) async -> [Plugin] {
    folders.flatMap { folder -> [Plugin] in
      if isPlugin(folder) {
        return [plugin(at: folder)]
      }
      // why: a missing or unreadable folder simply holds no plugins (Settings shows it).
      let children = (try? FileManager.default.contentsOfDirectory(
        at: folder,
        includingPropertiesForKeys: nil,
        options: .skipsHiddenFiles,
      )) ?? []
      return children.filter(isPlugin).sorted { $0.lastPathComponent < $1.lastPathComponent }
        .map(plugin)
    }
  }

  // MARK: Private

  /// What a manifest holds; everything is optional.
  private struct Manifest: Decodable {
    let name: String?
    let description: String?
    let styles: [String: TextStyle]?
    let templates: [String: Template]?
  }

  private static func isPlugin(_ folder: URL) -> Bool {
    ["plugin.json", "stickers", "sounds", "fonts"].contains { item in
      FileManager.default.fileExists(atPath: folder.appending(path: item).path)
    }
  }

  private static func plugin(at folder: URL) -> Plugin {
    var manifest: Manifest?
    var problem: String?
    let manifestURL = folder.appending(path: "plugin.json")
    if FileManager.default.fileExists(atPath: manifestURL.path) {
      do {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        manifest = try decoder.decode(Manifest.self, from: Data(contentsOf: manifestURL))
      } catch {
        logger.error("plugin.unreadable path=\(manifestURL.path, privacy: .private)")
        problem = "plugin.json couldn't be read: \(describe(error))"
      }
    }
    return Plugin(
      name: manifest?.name ?? folder.lastPathComponent,
      folder: folder,
      summary: manifest?.description ?? "",
      styles: manifest?.styles ?? [:],
      templates: manifest?.templates ?? [:],
      stickers: files(in: folder.appending(path: "stickers"), conformingTo: .image),
      sounds: files(in: folder.appending(path: "sounds"), conformingTo: .audio),
      fonts: Array(files(in: folder.appending(path: "fonts"), conformingTo: .font).values)
        .sorted { $0.path < $1.path },
      problem: problem,
    )
  }

  /// The files of a type anywhere under `folder`, by name without extension.
  private static func files(in folder: URL, conformingTo type: UTType) -> [String: URL] {
    guard let walker = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil)
    else {
      return [:]
    }
    var found = [String: URL]()
    for case let url as URL in walker {
      if UTType(filenameExtension: url.pathExtension)?.conforms(to: type) == true {
        found[url.deletingPathExtension().lastPathComponent] = url
      }
    }
    return found
  }

  /// A decoding failure in words a plugin author can act on: where, and what.
  private static func describe(_ error: any Error) -> String {
    guard let error = error as? DecodingError else {
      return error.localizedDescription
    }
    switch error {
    case .dataCorrupted(let context),
         .keyNotFound(_, let context),
         .typeMismatch(_, let context),
         .valueNotFound(_, let context):
      let path = context.codingPath.lazy.map { $0.intValue.map(String.init) ?? $0.stringValue }
        .joined(separator: ".")
      return (path.isEmpty ? "" : "at \(path): ") + context.debugDescription

    @unknown default:
      return error.localizedDescription
    }
  }

}
