import Foundation

/// Writes small `.cube` LUTs, so colour tests never depend on real grading files.
public enum LUTFixture {

  /// Writes a 17-point `.cube` file mapping each colour (red, green, blue, 0 to 1) through `map`
  /// to `url` (a new temporary file by default) and returns its URL.
  public static func make(
    at url: URL = FileManager.default.temporaryDirectory
      .appending(path: "\(UUID().uuidString).cube"),
    _ map: (Double, Double, Double) -> (Double, Double, Double),
  ) throws(FixtureError) -> URL {
    var lines = ["LUT_3D_SIZE 17"]
    for blue in 0 ..< 17 {
      for green in 0 ..< 17 {
        for red in 0 ..< 17 {
          let out = map(Double(red) / 16, Double(green) / 16, Double(blue) / 16)
          lines.append("\(out.0) \(out.1) \(out.2)")
        }
      }
    }
    do {
      try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    } catch {
      throw .writerFailed
    }
    return url
  }

}
