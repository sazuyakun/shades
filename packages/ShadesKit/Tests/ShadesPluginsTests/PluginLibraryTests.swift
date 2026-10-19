import Foundation
import ShadesCore
import ShadesPlugins
import ShadesTestSupport
import Testing

@MainActor
struct PluginLibraryTests {

  // MARK: Internal

  @Test
  func `a plugin folder's styles, templates and stickers load, in snake or camel case`(
  ) async throws {
    let root = try makeRoot()
    try write(manifest, to: root.appending(path: "taste/plugin.json"))
    try FileManager.default.createDirectory(
      at: root.appending(path: "taste/stickers"),
      withIntermediateDirectories: true,
    )
    try FileManager.default.copyItem(
      at: try ImageFixture.makeDisc(),
      to: root.appending(path: "taste/stickers/disc.png"),
    )
    let plugins = await PluginLoader.plugins(in: [root])
    let plugin = try #require(plugins.first)
    #expect(plugin.name == "Taste")
    #expect(plugin.problem == nil)
    #expect(plugin.styles["chul"]?.outlineColor == HexColor("#FF0000"))
    #expect(plugin.templates["lower-third"]?.fields == ["name"])
    #expect(plugin.stickers["disc"] != nil)
  }

  @Test
  func `a broken manifest is reported in words, with where it broke`() async throws {
    let root = try makeRoot()
    try write(
      #"{"styles": {"chul": {"size": "big"}}}"#,
      to: root.appending(path: "bad/plugin.json"),
    )
    let plugin = try #require(await PluginLoader.plugins(in: [root]).first)
    #expect(plugin.problem?.contains("styles.chul.size") == true)
  }

  @Test
  func `names resolve with or without the plugin's name, and edits reload by themselves`(
  ) async throws {
    let root = try makeRoot()
    try write(manifest, to: root.appending(path: "taste/plugin.json"))
    let defaults = try #require(UserDefaults(suiteName: UUID().uuidString))
    let folders = PluginFolders(defaults: defaults)
    folders.remove(atOffsets: IndexSet(folders.urls.indices))
    folders.add(root)
    let library = PluginLibrary(folders: folders)
    await library.start()
    #expect(library.style(named: "chul") != nil)
    #expect(library.style(named: "Taste/chul") != nil)
    #expect(library.style(named: "Other/chul") == nil)
    #expect(library.template(named: "lower-third")?.plugin.name == "Taste")
    try write(
      manifest.replacing("\"chul\"", with: "\"keeda\""),
      to: root.appending(path: "taste/plugin.json"),
    )
    for _ in 0 ..< 50 where library.style(named: "keeda") == nil {
      try await Task.sleep(for: .milliseconds(100))
    }
    #expect(library.style(named: "keeda") != nil)
  }

  // MARK: Private

  private let manifest = """
    {
      "name": "Taste",
      "description": "Soham's looks",
      "styles": {"chul": {"size": 0.12, "outline_color": "#FF0000", "anchor": "center"}},
      "templates": {
        "lower-third": {"layers": [{"text": "{name}", "style": "chul", "reveal": "pop"}]}
      }
    }
    """

  private func makeRoot() throws -> URL {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
  }

  private func write(_ text: String, to url: URL) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true,
    )
    try Data(text.utf8).write(to: url)
  }

}
