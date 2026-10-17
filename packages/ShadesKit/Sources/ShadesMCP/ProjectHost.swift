import Foundation
import ShadesCore
import ShadesDocument

/// Whoever holds the open project (the app's workspace), so Claude can list, create and open
/// projects.
@MainActor
public protocol ProjectHost: AnyObject {
  /// The open project's package, if one is open.
  var documentURL: URL? { get }

  /// Saves the open project and opens another.
  func openProject(at url: URL) async throws(DocumentError)
  /// Creates a project in the library and opens it.
  func createProject(named name: String, format: VideoFormat) async throws(DocumentError)
}
