import ShadesCore

extension TextStyle {
  /// Refuses sizes and outlines that can't be drawn sensibly.
  func validate() throws(CommandError) {
    guard (0.01 ... 0.5).contains(size) else {
      throw rejected(.invalidValue("text size goes from 0.01 to 0.5 of the frame height"))
    }
    guard (-360 ... 360).contains(arc) else {
      throw rejected(.invalidValue("arc goes from -360 to 360 degrees"))
    }
    guard (0 ... 0.3).contains(outline) else {
      throw rejected(.invalidValue("outline goes from 0 to 0.3 of the size"))
    }
    guard (-0.3 ... 2).contains(spacing) else {
      throw rejected(.invalidValue("spacing goes from -0.3 to 2 of the size"))
    }
    if let extrusion {
      guard (0.02 ... 3).contains(extrusion.depth) else {
        throw rejected(.invalidValue("extrusion depth goes from 0.02 to 3 of the size"))
      }
      guard (0 ... 0.2).contains(extrusion.bevel) else {
        throw rejected(.invalidValue("extrusion bevel goes from 0 to 0.2 of the size"))
      }
    }
  }
}
