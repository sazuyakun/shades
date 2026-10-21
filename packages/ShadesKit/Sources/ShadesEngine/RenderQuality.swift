/// How finely motion blur is drawn: lighter while playing, so playback keeps up, and full for
/// exports and frames.
enum RenderQuality {
  case preview
  case full

  /// The most moments a moving layer is drawn at inside the shutter.
  var layerSamples: Int {
    switch self {
    case .preview: 8
    case .full: 32
    }
  }

  /// The most taps a pixel of moving footage is smeared over.
  var footageTaps: Int {
    switch self {
    case .preview: 8
    case .full: 24
    }
  }
}
