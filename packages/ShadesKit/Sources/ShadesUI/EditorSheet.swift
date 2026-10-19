/// Sheets the menus can open over the editor.
public enum EditorSheet: String, Identifiable {
  case checkpoint
  case revert
  case export

  public var id: String {
    rawValue
  }
}
