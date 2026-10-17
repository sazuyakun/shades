/// Sheets the menus can open over the editor.
public enum EditorSheet: String, Identifiable {
  case checkpoint
  case revert

  public var id: String {
    rawValue
  }
}
