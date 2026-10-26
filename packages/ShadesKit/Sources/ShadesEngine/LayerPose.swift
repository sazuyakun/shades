import ShadesCore

/// Where a layer sits at one moment: its own placement and the camera it's seen through, and
/// what moves inside its picture then.
struct LayerPose {
  let transform: ClipTransform
  /// The timeline camera's move, or identity for layers that don't follow it.
  let camera: ClipTransform
  /// How far, in pixels, the layer's content has moved inside its own picture by this moment
  /// (text travelling its path, an endless zoom flying in), so the shutter counts it as motion.
  var drift = 0.0
  /// Its picture at this moment, when that changes inside the shutter (text travelling its
  /// path); `nil` keeps the layer's.
  var picture: LayerPicture?
  /// How far its endless zoom has travelled at this moment, when that's animated.
  var portalTravel: Double?
}
