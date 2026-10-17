import ShadesCore

/// Replaces the whole project with an earlier version (File › Revert To), as one undoable edit.
public struct RestoreProject: Command {
  public init(project: Project) {
    self.project = project
  }

  public static let title = "Revert"

  public let project: Project

  public func apply(to project: inout Project) throws(CommandError) {
    project = self.project
  }
}
