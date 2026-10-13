import CoreMedia
import ShadesCore

extension MediaTime {
  /// The same time as AVFoundation's `CMTime`.
  var cmTime: CMTime {
    CMTime(value: value, timescale: timescale)
  }
}
