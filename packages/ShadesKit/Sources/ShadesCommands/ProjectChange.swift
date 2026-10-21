import Foundation
import ShadesCore

// MARK: - ProjectChange

/// What one edit changed in the project, as the saved JSON it replaced and wrote. It's enough to
/// take that edit back later, even after other edits, by putting back only the parts it touched.
public indirect enum ProjectChange: Codable, Hashable, Sendable {
  /// A value written, added (no `before`) or removed (no `after`).
  case value(before: JSONValue?, after: JSONValue?)
  /// Some fields of an object changed.
  case fields([String: ProjectChange])
  /// Some items of a list of things with IDs (tracks, clips, media, markers…) changed. `order`
  /// holds the IDs as they were, to put removed items back in place.
  case items([String: ProjectChange], order: [String])

  // MARK: Lifecycle

  /// What changed from `before` to `after`, or `nil` when nothing did.
  public init?(from before: Project, to after: Project) {
    guard let change = Self.between(before.savedJSON, after.savedJSON) else {
      return nil
    }
    self = change
  }

  // MARK: Internal

  /// `current` with this change taken back. Parts already back as they were stay as they are;
  /// parts changed again since throw `editedSince`.
  func reverted(_ current: JSONValue?) throws(CommandError) -> JSONValue? {
    switch self {
    case .value(let before, let after):
      guard current == after || current == before else {
        throw rejected(.editedSince)
      }
      return before

    case .fields(let changes):
      guard case .object(var object) = current else {
        throw rejected(.editedSince)
      }
      for (key, change) in changes {
        object[key] = try change.reverted(object[key])
      }
      return .object(object)

    case .items(let changes, let order):
      guard case .array(let array) = current, let current = Self.identified(array) else {
        throw rejected(.editedSince)
      }
      var items = [(id: String, item: JSONValue)]()
      for (id, item) in current {
        if let change = changes[id] {
          if let kept = try change.reverted(item) {
            items.append((id, kept))
          }
        } else {
          items.append((id, item))
        }
      }

      for (index, id) in order.enumerated() where !items.contains(where: { $0.id == id }) {
        guard let restored = try changes[id]?.reverted(nil) else {
          continue
        }
        let previous = Set(order[..<index])
        let place = items.lastIndex { previous.contains($0.id) }.map { $0 + 1 } ?? 0
        items.insert((id, restored), at: place)
      }
      return .array(items.map(\.item))
    }
  }

  // MARK: Private

  /// The change from `before` to `after` (either may be missing), or `nil` when they match.
  /// Lists of things with IDs change item by item; their order isn't kept, since clips are
  /// put back in time order.
  private static func between(_ before: JSONValue?, _ after: JSONValue?) -> ProjectChange? {
    guard before != after else {
      return nil
    }
    switch (before, after) {
    case (.object(let old), .object(let new)):
      return .fields(Dictionary(uniqueKeysWithValues: Set(old.keys).union(new.keys)
          .compactMap { key in between(old[key], new[key]).map { (key, $0) } }))

    case (.array(let old), .array(let new)):
      guard let oldItems = identified(old), let newItems = identified(new) else {
        return .value(before: before, after: after)
      }
      let oldByID = Dictionary(uniqueKeysWithValues: oldItems)
      let newByID = Dictionary(uniqueKeysWithValues: newItems)
      return .items(
        Dictionary(uniqueKeysWithValues: Set(oldByID.keys).union(newByID.keys)
          .compactMap { id in between(oldByID[id], newByID[id]).map { (id, $0) } }),
        order: oldItems.map(\.id),
      )

    default:
      return .value(before: before, after: after)
    }
  }

  /// The items of a list where every item is an object with its own `id`, or `nil`.
  private static func identified(_ array: [JSONValue]) -> [(id: String, item: JSONValue)]? {
    let items = array.compactMap { item in item["id"]?.stringValue.map { (id: $0, item: item) } }
    guard items.count == array.count, Set(items.map(\.id)).count == items.count else {
      return nil
    }
    return items
  }
}

// MARK: - Project + JSON

extension Project {

  // MARK: Lifecycle

  /// Reads a project back from its saved JSON.
  init(savedJSON json: JSONValue) throws(CommandError) {
    do {
      self = try JSONDecoder().decode(Project.self, from: json.jsonData())
    } catch {
      throw rejected(.editedSince)
    }
  }

  // MARK: Internal

  /// The project as it's saved, as JSON.
  var savedJSON: JSONValue {
    do {
      return try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(self))
    } catch {
      logger.fault("project.encodeFailed")
      assertionFailure("A project failed to encode")
      return .null
    }
  }

}
