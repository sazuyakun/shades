import Foundation

// MARK: - JSONValue

/// Any JSON value: tool arguments from Claude, results sent back, and JSON Schemas. Ported from
/// Nebula.
public enum JSONValue: Hashable, Sendable {
  case null
  case bool(Bool)
  case number(Double)
  case string(String)
  case array([JSONValue])
  case object([String: JSONValue])

  // MARK: Lifecycle

  /// Parses JSON data.
  public init(data: Data) throws(CommandError) {
    do {
      self = try JSONDecoder().decode(JSONValue.self, from: data)
    } catch {
      throw .invalidJSON
    }
  }

  /// Converts any `Encodable` value, e.g. a project summary, into JSON.
  public init(encoding value: some Encodable) throws(CommandError) {
    do {
      let data = try JSONEncoder().encode(value)
      self = try JSONDecoder().decode(JSONValue.self, from: data)
    } catch {
      throw .invalidJSON
    }
  }

  // MARK: Public

  /// The text, when this is a string.
  public var stringValue: String? {
    if case .string(let value) = self {
      return value
    }
    return nil
  }

  /// The number, when this is a number.
  public var doubleValue: Double? {
    if case .number(let value) = self {
      return value
    }
    return nil
  }

  /// The member named `key` when this is an object.
  public subscript(key: String) -> JSONValue? {
    if case .object(let object) = self {
      return object[key]
    }
    return nil
  }

  /// Compact JSON with sorted keys (pretty-printed when asked).
  public func jsonData(pretty: Bool = false) throws(CommandError) -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = pretty
      ? [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
      : [.sortedKeys, .withoutEscapingSlashes]
    do {
      return try encoder.encode(self)
    } catch {
      throw .invalidJSON
    }
  }

  /// Decodes the value into a type, reading Claude's `snake_case` keys as Swift's `camelCase`.
  public func decode<T: Decodable>(_: T.Type) throws(CommandError) -> T {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .custom { path in
      SwiftKey(snakeCase: path.last?.stringValue ?? "")
    }
    do {
      return try decoder.decode(T.self, from: jsonData())
    } catch let error as DecodingError {
      throw .invalidArguments(Self.explain(error))
    } catch {
      throw .invalidJSON
    }
  }

  // MARK: Private

  /// A decoding error in plain words naming the bad field.
  private static func explain(_ error: DecodingError) -> String {
    switch error {
    case .keyNotFound(let key, _):
      "missing \(snakeCase(key.stringValue))"
    case .typeMismatch(_, let context),
         .valueNotFound(_, let context):
      "\(field(context)) has the wrong type"
    case .dataCorrupted(let context):
      "\(field(context)) is invalid: \(context.debugDescription)"
    @unknown default:
      "the arguments are invalid"
    }
  }

  private static func field(_ context: DecodingError.Context) -> String {
    context.codingPath.last.map { snakeCase($0.stringValue) } ?? "a field"
  }

  /// `clipIDs` → `clip_ids`, the spelling Claude sees.
  private static func snakeCase(_ camelCase: String) -> String {
    camelCase.replacing("IDs", with: "Ids").replacing("ID", with: "Id")
      .reduce(into: "") { result, character in
        if character.isUppercase {
          result += "_" + character.lowercased()
        } else {
          result.append(character)
        }
      }
  }
}

// MARK: Codable

extension JSONValue: Codable {

  // MARK: Lifecycle

  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .null
    } else if let value = try? container.decode(Bool.self) {
      self = .bool(value)
    } else if let value = try? container.decode(Double.self) {
      self = .number(value)
    } else if let value = try? container.decode(String.self) {
      self = .string(value)
    } else if let value = try? container.decode([JSONValue].self) {
      self = .array(value)
    } else {
      self = try .object(container.decode([String: JSONValue].self))
    }
  }

  // MARK: Public

  /// Whole numbers are written without a fraction (`1`, not `1.0`).
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .null: try container.encodeNil()

    case .bool(let value): try container.encode(value)

    case .number(let value):
      if value.rounded() == value, abs(value) < 9e15 {
        try container.encode(Int64(value))
      } else {
        try container.encode(value)
      }

    case .string(let value): try container.encode(value)

    case .array(let value): try container.encode(value)

    case .object(let value): try container.encode(value)
    }
  }

}

// MARK: ExpressibleByStringLiteral

extension JSONValue: ExpressibleByStringLiteral {
  public init(stringLiteral value: String) {
    self = .string(value)
  }
}

// MARK: ExpressibleByIntegerLiteral

extension JSONValue: ExpressibleByIntegerLiteral {
  public init(integerLiteral value: Int) {
    self = .number(Double(value))
  }
}

// MARK: ExpressibleByBooleanLiteral

extension JSONValue: ExpressibleByBooleanLiteral {
  public init(booleanLiteral value: Bool) {
    self = .bool(value)
  }
}

// MARK: ExpressibleByArrayLiteral

extension JSONValue: ExpressibleByArrayLiteral {
  public init(arrayLiteral elements: JSONValue...) {
    self = .array(elements)
  }
}

// MARK: ExpressibleByDictionaryLiteral

extension JSONValue: ExpressibleByDictionaryLiteral {
  public init(dictionaryLiteral elements: (String, JSONValue)...) {
    self = .object(Dictionary(elements) { _, last in last })
  }
}

// MARK: - SwiftKey

/// A coding key converted from `snake_case` to Swift's spelling: `clip_ids` → `clipIDs`.
private struct SwiftKey: CodingKey {

  // MARK: Lifecycle

  init(snakeCase: String) {
    let parts = snakeCase.split(separator: "_").map(String.init)
    stringValue = parts.enumerated().map { index, part in
      switch part {
      case "id": index == 0 ? part : "ID"
      case "ids": index == 0 ? part : "IDs"
      default: index == 0 ? part : part.prefix(1).uppercased() + part.dropFirst()
      }
    }
    .joined()
  }

  init?(stringValue: String) {
    self.stringValue = stringValue
  }

  init?(intValue: Int) {
    stringValue = "\(intValue)"
    self.intValue = intValue
  }

  // MARK: Internal

  var stringValue: String
  var intValue: Int?

}

// MARK: - JSONValue + ExpressibleByFloatLiteral

extension JSONValue: ExpressibleByFloatLiteral {
  public init(floatLiteral value: Double) {
    self = .number(value)
  }
}
