import Observation
import ShadesCore

/// Owns the open project. The only way to change it is `perform(_:)`, so every change is a
/// command no matter who asks for it (the UI or Claude).
@MainActor
@Observable
public final class Editor {

  // MARK: Lifecycle

  public init(project: Project = Project()) {
    self.project = project
  }

  // MARK: Public

  public private(set) var project: Project

  /// Applies a command. If it throws, the project is left exactly as it was.
  public func perform(_ command: some Command) throws(CommandError) {
    var edited = project
    try command.apply(to: &edited)
    project = edited
  }

}
