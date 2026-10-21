/// How optical flow is stored as video, shared by the job that writes it and the renderer that
/// reads it: red holds how fast each pixel moves across, green how fast down, in pictures a
/// second, with 0.5 for still.
public enum FlowVideo {

  /// The fastest motion stored, in pictures a second; faster motion is clamped to it.
  public static let range = 4.0

  /// A speed (pictures a second) as a stored channel value, 0 to 1.
  public static func value(of speed: Double) -> Double {
    min(max(0.5 + speed / (2 * range), 0), 1)
  }

  /// The speed (pictures a second) a stored channel value stands for.
  public static func speed(of value: Double) -> Double {
    (value - 0.5) * 2 * range
  }

}
