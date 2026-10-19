import Foundation
import ShadesCore

/// A plugin folder's contents: type styles, templates, stickers, sounds and fonts. Plugins are
/// data only (no code), so they're safe to load from anywhere.
public struct Plugin: Hashable, Sendable, Identifiable {
  /// The plugin's name, from its manifest or its folder.
  public let name: String
  public let folder: URL
  public let summary: String
  public let styles: [String: TextStyle]
  public let templates: [String: Template]
  /// Pictures in `stickers/`, by file name without its extension.
  public let stickers: [String: URL]
  /// Sounds in `sounds/`, by file name without its extension.
  public let sounds: [String: URL]
  /// Font files in `fonts/`, available to text while the plugin is loaded.
  public let fonts: [URL]
  /// What's wrong with its manifest, in plain words, when it couldn't be read.
  public let problem: String?

  public var id: URL {
    folder
  }
}
