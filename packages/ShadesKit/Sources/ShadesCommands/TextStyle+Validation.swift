import ShadesCore

extension TextStyle {
  /// Refuses sizes and outlines that can't be drawn sensibly.
  func validate() throws(CommandError) {
    guard (0.01 ... 0.5).contains(size) else {
      throw rejected(.invalidValue("text size goes from 0.01 to 0.5 of the frame height"))
    }
    guard (0 ... 0.3).contains(outline) else {
      throw rejected(.invalidValue("outline goes from 0 to 0.3 of the size"))
    }
  }
}
