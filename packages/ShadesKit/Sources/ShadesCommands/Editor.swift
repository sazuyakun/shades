import Foundation
import Observation
import ShadesCore

// MARK: - Editor

/// Owns the open project. The only way to change it is `perform`, so every change is a command
/// no matter who asks (the UI or Claude), and every change can be undone.
@MainActor
@Observable
public final class Editor {

  // MARK: Lifecycle

  public init(project: Project = Project()) {
    self.project = project
  }

  // MARK: Public

  /// Most undo steps kept; older ones are dropped.
  public static let undoLimit = 200

  public private(set) var project: Project
  /// The clips the user has selected on the timeline.
  public var selection = Set<Clip.ID>()

  /// What Undo would undo, e.g. "Split Clip".
  public var undoTitle: String? {
    undoStack.last?.title
  }

  /// What Redo would redo.
  public var redoTitle: String? {
    redoStack.last?.title
  }

  /// Applies a command as one undo step. If it throws, the project is left exactly as it was.
  public func perform<C: Command>(_ command: C) throws(CommandError) {
    try perform([command], title: C.title)
  }

  /// Applies several commands as one undo step, all or nothing.
  public func perform(_ commands: [any Command], title: String) throws(CommandError) {
    var edited = project
    for command in commands {
      try command.apply(to: &edited)
    }
    guard edited != project else {
      return
    }
    undoStack.append(UndoStep(title: title, project: project))
    if undoStack.count > Self.undoLimit {
      undoStack.removeFirst()
    }
    redoStack.removeAll()
    project = edited
    pruneSelection()
  }

  /// Steps back one edit.
  public func undo() throws(CommandError) {
    guard let step = undoStack.popLast() else {
      throw rejected(.nothingToUndo)
    }
    redoStack.append(UndoStep(title: step.title, project: project))
    project = step.project
    pruneSelection()
  }

  /// Steps forward again after an undo.
  public func redo() throws(CommandError) {
    guard let step = redoStack.popLast() else {
      throw rejected(.nothingToRedo)
    }
    undoStack.append(UndoStep(title: step.title, project: project))
    project = step.project
    pruneSelection()
  }

  /// Swaps in another project (one just opened), with a fresh undo history.
  public func load(_ project: Project) {
    self.project = project
    undoStack.removeAll()
    redoStack.removeAll()
    selection.removeAll()
  }

  // MARK: Private

  private var undoStack = [UndoStep]()
  private var redoStack = [UndoStep]()

  /// Drops selected clips that no longer exist.
  private func pruneSelection() {
    let existing = Set(project.timeline.allClips.map(\.id))
    selection.formIntersection(existing)
  }

}

// MARK: - UndoStep

/// The project as it was before an edit, and the edit's name.
private struct UndoStep {
  let title: String
  let project: Project
}
