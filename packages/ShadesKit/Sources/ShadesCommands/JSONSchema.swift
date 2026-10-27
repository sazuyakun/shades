/// Builders for the JSON Schemas that tell Claude what each tool takes. Ported from Nebula.
public enum JSONSchema {

  // MARK: Public

  /// An object with the given properties; `required` names the ones that must be sent.
  public static func object(_ properties: [String: JSONValue], required: [String] = [])
    -> JSONValue
  {
    var schema: [String: JSONValue] = ["type": "object", "properties": .object(properties)]
    if !required.isEmpty {
      schema["required"] = .array(required.map { .string($0) })
    }
    return .object(schema)
  }

  /// A string, optionally limited to `values`.
  public static func string(_ description: String, values: [String]? = nil) -> JSONValue {
    var schema = base("string", description)
    if let values {
      schema["enum"] = .array(values.map { .string($0) })
    }
    return .object(schema)
  }

  /// A number, optionally bounded (inclusive).
  public static func number(_ description: String, minimum: Double? = nil, maximum: Double? = nil)
    -> JSONValue
  {
    var schema = base("number", description)
    if let minimum {
      schema["minimum"] = .number(minimum)
    }
    if let maximum {
      schema["maximum"] = .number(maximum)
    }
    return .object(schema)
  }

  /// A true/false switch.
  public static func boolean(_ description: String) -> JSONValue {
    .object(base("boolean", description))
  }

  /// Throws when `arguments` has top-level fields `schema` doesn't list, so a misspelt field
  /// fails instead of being skipped while the tool reports success.
  public static func check(
    _ arguments: JSONValue,
    against schema: JSONValue,
    tool: String,
  ) throws(CommandError) {
    guard case .object(let fields) = arguments, case .object(let known) = schema["properties"]
    else {
      return
    }
    let unknown = fields.keys.filter { known[$0] == nil }.sorted()
    guard !unknown.isEmpty else {
      return
    }
    let takes = known.isEmpty ? "nothing" : known.keys.sorted().joined(separator: ", ")
    throw .invalidArguments(
      "\(tool) doesn't take \(unknown.joined(separator: ", ")) (it takes \(takes))"
    )
  }

  /// A list of items matching `items`.
  public static func array(_ description: String, items: JSONValue) -> JSONValue {
    var schema = base("array", description)
    schema["items"] = items
    return .object(schema)
  }

  // MARK: Private

  private static func base(_ type: String, _ description: String) -> [String: JSONValue] {
    ["type": .string(type), "description": .string(description)]
  }

}
