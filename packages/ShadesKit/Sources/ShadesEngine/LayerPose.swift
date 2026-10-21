import ShadesCore

/// Where a layer sits at one moment: its own placement and the camera it's seen through.
struct LayerPose: Equatable {
  let transform: ClipTransform
  /// The timeline camera's move, or identity for layers that don't follow it.
  let camera: ClipTransform
}
