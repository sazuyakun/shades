import CoreText
import Foundation
import Observation
import ShadesCore

/// The plugins loaded from the plugin folders, kept up to date as their files change. Their fonts
/// are available to text while they're loaded.
@MainActor
@Observable
public final class PluginLibrary {

  // MARK: Lifecycle

  public init(folders: PluginFolders) {
    self.folders = folders
  }

  // MARK: Public

  public private(set) var plugins = [Plugin]()

  /// Loads the plugins now, and again whenever the folders or their files change.
  public func start() async {
    await reload()
    observeFolders()
  }

  /// Reads every plugin again.
  public func reload() async {
    let loaded = await PluginLoader.plugins(in: folders.urls)
    useFonts(loaded.flatMap(\.fonts))
    plugins = loaded
  }

  /// A text style by name, `plugin/name` or just `name` (the first plugin that has it).
  public func style(named name: String) -> TextStyle? {
    find(name) { $0.styles }
  }

  /// A look by name, `plugin/name` or just `name`, with its LUT (if any) resolved to a file.
  public func look(named name: String) -> Look? {
    for plugin in matching(name) {
      if var look = plugin.looks[localName(name)] {
        let lut = look.grade?.lut
          .map { name in plugin.luts[name]?.path ?? lutPath(named: name) ?? name }
        look.grade?.lut = lut
        let shader = look.effects?.shader.map { name in
          plugin.shaders[name]?.path ?? shaderPath(named: name) ?? name
        }
        look.effects?.shader = shader
        return look
      }
    }
    return nil
  }

  /// A shader effect's file path by name, `plugin/name` or just `name`.
  public func shaderPath(named name: String) -> String? {
    find(name) { $0.shaders }?.path
  }

  /// A LUT's file path by name, `plugin/name` or just `name`.
  public func lutPath(named name: String) -> String? {
    find(name) { $0.luts }?.path
  }

  /// A sound effect's file by name, `plugin/name` or just `name`.
  public func sound(named name: String) -> URL? {
    find(name) { $0.sounds }
  }

  /// A template by name, `plugin/name` or just `name`, with the plugin it comes from.
  public func template(named name: String) -> (template: Template, plugin: Plugin)? {
    for plugin in matching(name) {
      if let template = plugin.templates[localName(name)] {
        return (template, plugin)
      }
    }
    return nil
  }

  // MARK: Private

  @ObservationIgnored private let folders: PluginFolders
  @ObservationIgnored private var watcher: FolderWatcher?
  @ObservationIgnored private var registeredFonts = [URL]()

  /// Watches the current folders, and starts over when the list of folders changes.
  private func observeFolders() {
    watcher = FolderWatcher(folders.urls) { [weak self] in
      Task { await self?.reload() }
    }
    withObservationTracking {
      _ = folders.urls
    } onChange: { [weak self] in
      Task { @MainActor in
        await self?.reload()
        self?.observeFolders()
      }
    }
  }

  /// Makes exactly `fonts` available to text, dropping fonts of plugins that went away.
  private func useFonts(_ fonts: [URL]) {
    let gone = registeredFonts.filter { !fonts.contains($0) }
    let new = fonts.filter { !registeredFonts.contains($0) }
    if !gone.isEmpty {
      CTFontManagerUnregisterFontURLs(gone as CFArray, .process, nil)
    }
    if !new.isEmpty {
      CTFontManagerRegisterFontURLs(new as CFArray, .process, true, nil)
    }
    registeredFonts = fonts
  }

  private func find<Value>(_ name: String, in pick: (Plugin) -> [String: Value]) -> Value? {
    matching(name).compactMap { pick($0)[localName(name)] }.first
  }

  /// The plugins a name can come from: the named one for `plugin/name`, otherwise all in order.
  private func matching(_ name: String) -> [Plugin] {
    guard let slash = name.firstIndex(of: "/") else {
      return plugins
    }
    let pluginName = String(name[..<slash])
    return plugins.filter { $0.name == pluginName || $0.folder.lastPathComponent == pluginName }
  }

  private func localName(_ name: String) -> String {
    name.firstIndex(of: "/").map { String(name[name.index(after: $0)...]) } ?? name
  }

}
