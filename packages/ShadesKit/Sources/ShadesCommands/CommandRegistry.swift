/// Every command Claude can call by name. Adding a `ToolCommand` here exposes it over MCP and in
/// the batch tool.
public enum CommandRegistry {

  /// All tool commands, in the order Claude sees them.
  public static let tools: [any ToolCommand.Type] = [
    AppendClip.self,
    InsertClip.self,
    OverwriteClip.self,
    PlaceOnTop.self,
    MoveClip.self,
    TrimClip.self,
    SplitClip.self,
    DeleteClips.self,
    RemoveRanges.self,
    CloseGaps.self,
    JoinClips.self,
    SetClip.self,
    ReframeClip.self,
    SetKeyframes.self,
    RemoveKeyframes.self,
    AddText.self,
    SetText.self,
    DetachAudio.self,
    AddTrack.self,
    RemoveTrack.self,
    SetTrack.self,
    AddMarker.self,
    RemoveMarker.self,
    RemoveMedia.self,
  ]

  /// Builds the command `name` from Claude's arguments.
  public static func command(named name: String, arguments: JSONValue) throws(CommandError)
    -> any ToolCommand
  {
    guard let type = tools.first(where: { $0.name == name }) else {
      throw rejected(.unknownTool(name))
    }
    do {
      return try arguments.decode(type)
    } catch {
      throw rejected(error)
    }
  }

}
