import Foundation
import ShadesPlugins
import Testing

@MainActor
struct PluginFoldersTests {

  // MARK: Internal

  @Test
  func `the first launch starts with the default folder`() {
    #expect(PluginFolders(defaults: defaults).urls == [PluginFolders.defaultFolder])
  }

  @Test
  func `folders are saved between launches`() {
    let folders = PluginFolders(defaults: defaults)
    folders.add(playbook)
    #expect(PluginFolders(defaults: defaults).urls == [PluginFolders.defaultFolder, playbook])
  }

  @Test
  func `adding a folder twice keeps one copy`() {
    let folders = PluginFolders(defaults: defaults)
    folders.add(playbook)
    folders.add(playbook)
    #expect(folders.urls.count == 2)
  }

  @Test
  func `folders can be reordered and removed`() {
    let folders = PluginFolders(defaults: defaults)
    folders.add(playbook)
    folders.move(fromOffsets: [1], toOffset: 0)
    #expect(folders.urls == [playbook, PluginFolders.defaultFolder])
    folders.remove(atOffsets: [1])
    #expect(PluginFolders(defaults: defaults).urls == [playbook])
  }

  @Test
  func `removing every folder is remembered`() {
    let folders = PluginFolders(defaults: defaults)
    folders.remove(atOffsets: [0])
    #expect(PluginFolders(defaults: defaults).urls.isEmpty)
  }

  @Test
  func `moving a folder down lands it where it was dropped`() {
    let folders = PluginFolders(defaults: defaults)
    folders.add(playbook)
    folders.add(other)
    folders.move(fromOffsets: [0], toOffset: 3)
    #expect(folders.urls == [playbook, other, PluginFolders.defaultFolder])
  }

  // MARK: Private

  private let defaults = UserDefaults(suiteName: UUID().uuidString) ?? .standard
  private let playbook = URL(filePath: "/tmp/playbook/plugins", directoryHint: .isDirectory)
  private let other = URL(filePath: "/tmp/other/plugins", directoryHint: .isDirectory)

}
