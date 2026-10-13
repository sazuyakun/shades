/// An 8-bit RGB color for test videos.
public struct FixtureColor: Sendable {
  public init(red: UInt8, green: UInt8, blue: UInt8) {
    self.red = red
    self.green = green
    self.blue = blue
  }

  public static let red = FixtureColor(red: 255, green: 0, blue: 0)
  public static let green = FixtureColor(red: 0, green: 255, blue: 0)
  public static let blue = FixtureColor(red: 0, green: 0, blue: 255)

  public let red: UInt8
  public let green: UInt8
  public let blue: UInt8
}
