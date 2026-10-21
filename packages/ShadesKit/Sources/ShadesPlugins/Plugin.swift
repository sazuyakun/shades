import Foundation
import ShadesCore

/// A plugin folder's contents: styles, templates, looks, stickers, overlays, sounds, LUTs,
/// shaders, fonts.
/// Plugins are data only (no code), so they're safe to load from anywhere.
public struct Plugin: Hashable, Sendable, Identifiable {
  /// The plugin's name, from its manifest or its folder.
  public let name: String
  public let folder: URL
  public let summary: String
  public let styles: [String: TextStyle]
  public let templates: [String: Template]
  /// Grade recipes: a grade, effects and blend under a name.
  public let looks: [String: Look]
  /// Pictures in `stickers/`, by file name without its extension.
  public let stickers: [String: URL]
  /// Movies in `overlays/` (light leaks, dust, film burns), by file name without its extension.
  public let overlays: [String: URL]
  /// Sounds in `sounds/`, by file name without its extension.
  public let sounds: [String: URL]
  /// `.cube` LUTs in `luts/`, by file name without its extension.
  public let luts: [String: URL]
  /// Metal shader effects in `shaders/`, by file name without its extension.
  public let shaders: [String: URL]
  /// Font files in `fonts/`, available to text while the plugin is loaded.
  public let fonts: [URL]
  /// What's wrong with its manifest, in plain words, when it couldn't be read.
  public let problem: String?

  public var id: URL {
    folder
  }
}
