import ShadesCore

/// A single edit to the project. Buttons, shortcuts and Claude all change the project only
/// through commands.
public protocol Command: Sendable {
  /// Applies the edit, or throws and leaves the project unchanged.
  func apply(to project: inout Project) throws(CommandError)
}
