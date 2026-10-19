import ShadesCore

/// Sets the whole mix's level, on top of every track and clip.
public struct SetMasterGain: ToolCommand {

  // MARK: Lifecycle

  public init(gain: Double) {
    self.gain = gain
  }

  // MARK: Public

  public static let title = "Set Master Level"
  public static let name = "set_master_gain"
  public static let summary = "Set the whole mix's level as a gain (1 unchanged, 0.5 about 6 dB "
    + "quieter). normalize_loudness sets it for a loudness target."
  public static let parameters = JSONSchema.object(
    ["gain": JSONSchema.number("The level, 0 to 8", minimum: 0, maximum: 8)],
    required: ["gain"],
  )

  public let gain: Double

  public func apply(to project: inout Project) throws(CommandError) {
    guard (0 ... 8).contains(gain) else {
      throw rejected(.invalidValue("the master level goes from 0 to 8"))
    }
    project.timeline.gain = gain
  }

}
