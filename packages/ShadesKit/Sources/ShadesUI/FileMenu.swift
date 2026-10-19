import SwiftUI

/// The File and Edit menu items for projects: new, open, checkpoints, revert, export, undo and
/// redo.
public struct FileMenu: Commands {

  // MARK: Lifecycle

  public init(workspace: Workspace) {
    self.workspace = workspace
  }

  // MARK: Public

  public var body: some Commands {
    CommandGroup(replacing: .newItem) {
      Button("New or Open Project…") { openWindow(id: WindowID.welcome) }
        .keyboardShortcut("n")
    }
    CommandGroup(replacing: .saveItem) {
      Button("Save Checkpoint…") { workspace.sheet = .checkpoint }
        .keyboardShortcut("s")
        .disabled(workspace.documentURL == nil)
      Button("Revert To…") { workspace.sheet = .revert }
        .disabled(workspace.documentURL == nil)
    }
    CommandGroup(replacing: .importExport) {
      Button("Export…") { workspace.sheet = .export }
        .keyboardShortcut("e")
        .disabled(workspace.documentURL == nil)
    }
    CommandGroup(replacing: .undoRedo) {
      Button(workspace.editor.undoTitle.map { "Undo \($0)" } ?? "Undo") {
        // why: the item is disabled when there's nothing to undo, the only way this throws.
        try? workspace.editor.undo()
      }
      .keyboardShortcut("z")
      .disabled(workspace.editor.undoTitle == nil)
      Button(workspace.editor.redoTitle.map { "Redo \($0)" } ?? "Redo") {
        // why: the item is disabled when there's nothing to redo, the only way this throws.
        try? workspace.editor.redo()
      }
      .keyboardShortcut("z", modifiers: [.command, .shift])
      .disabled(workspace.editor.redoTitle == nil)
    }
  }

  // MARK: Private

  @Environment(\.openWindow) private var openWindow

  private let workspace: Workspace

}
