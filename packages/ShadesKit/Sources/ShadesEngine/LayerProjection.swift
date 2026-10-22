import CoreGraphics
import ShadesCore
import simd

/// Where a layer's upright picture lands in the frame, worked out with the same matrix the layer
/// shader draws it with: fitted (or at its own size, for text), moved, scaled, turned and tilted
/// in 3D, and seen through the camera with perspective. A bend is left out: it's drawn flat.
/// Points are fractions from the top left, of the picture or of the frame.
public struct LayerProjection: Sendable {

  // MARK: Lifecycle

  init(
    picture: CGSize,
    isNaturalSize: Bool,
    frame: CGSize,
    transform: ClipTransform,
    camera: ClipTransform,
  ) {
    let uniforms = FrameUniforms(
      stored: picture,
      rotation: .identity,
      output: frame,
      transform: transform,
      camera: camera,
      isNaturalSize: isNaturalSize,
    )
    matrix = uniforms.transform
    half = uniforms.fit * uniforms.frameSize * 0.5
  }

  // MARK: Public

  /// The frame point showing `point` of the picture, or `nil` when it's behind the viewer.
  public func framePoint(of point: CGPoint) -> CGPoint? {
    let pixel = SIMD4(Float(point.x * 2 - 1) * half.x, Float(1 - point.y * 2) * half.y, 0, 1)
    let onScreen = matrix * pixel
    guard onScreen.w > 0 else {
      return nil
    }
    return CGPoint(
      x: Double(onScreen.x / onScreen.w) * 0.5 + 0.5,
      y: 0.5 - Double(onScreen.y / onScreen.w) * 0.5,
    )
  }

  /// The point of the picture showing at `point` of the frame, or `nil` when the picture is seen
  /// edge-on there.
  public func picturePoint(at point: CGPoint) -> CGPoint? {
    // why: the picture is flat (z 0), so its projection is a 3×3 map of x, y and 1, which can be
    // turned round exactly.
    let flat = simd_float3x3(columns: (
      SIMD3(matrix.columns.0.x, matrix.columns.0.y, matrix.columns.0.w),
      SIMD3(matrix.columns.1.x, matrix.columns.1.y, matrix.columns.1.w),
      SIMD3(matrix.columns.3.x, matrix.columns.3.y, matrix.columns.3.w),
    ))
    let pixel = flat.inverse * SIMD3(Float(point.x * 2 - 1), Float(1 - point.y * 2), 1)
    guard pixel.z > 0, pixel.x.isFinite, pixel.y.isFinite else {
      return nil
    }
    return CGPoint(
      x: (Double(pixel.x / pixel.z / half.x) + 1) / 2,
      y: (1 - Double(pixel.y / pixel.z / half.y)) / 2,
    )
  }

  /// The part of the picture under `box` of the frame (the box round its corners there), cut to
  /// the picture; empty when none of it is.
  public func pictureBox(under box: CGRect) -> CGRect {
    let corners = [
      CGPoint(x: box.minX, y: box.minY),
      CGPoint(x: box.maxX, y: box.minY),
      CGPoint(x: box.minX, y: box.maxY),
      CGPoint(x: box.maxX, y: box.maxY),
    ].compactMap(picturePoint)
    guard corners.count == 4 else {
      return .zero
    }
    let around = corners.dropFirst().reduce(CGRect(origin: corners[0], size: .zero)) { box, point in
      box.union(CGRect(origin: point, size: .zero))
    }
    let inside = around.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
    return inside.isNull ? .zero : inside
  }

  // MARK: Private

  /// Takes a point of the layer (pixels from its centre, y up) to the screen.
  private let matrix: simd_float4x4
  /// Half the layer's size in pixels.
  private let half: SIMD2<Float>

}
