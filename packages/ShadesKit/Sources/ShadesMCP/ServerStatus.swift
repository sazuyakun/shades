/// Whether Claude can connect to Shades right now.
public enum ServerStatus: Equatable, Sendable {
  case starting
  case ready
  case failed(ToolError)
}
