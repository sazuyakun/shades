import CoreVideo

/// One layer's footage motion blur this frame: its media's optical flow, how much of the source
/// passes while the shutter is open, and the most taps a pixel is smeared over.
struct FootageBlur {
  /// The flow frame for this moment (see `FlowVideo`).
  let flow: CVPixelBuffer
  /// Seconds of the source the shutter spans: shorter for slow motion, none for a freeze frame.
  let length: Double
  let taps: Int
}
