import CoreImage
import CoreVideo
import Foundation
import ImageIO
import ShadesCore

/// Draws a still picture (a PNG sticker, a photo) onto a surface the GPU can read, decoded no
/// bigger than the frame needs, with the die-cut sticker look when asked.
enum StillRenderer {

  // MARK: Internal

  /// The picture at `url`, at most `maxSide` pixels on its longer side, upright, with `look`
  /// drawn around its outline; `nil` if it can't be read.
  static func render(_ url: URL, maxSide: Int, look: StickerLook?) -> CVPixelBuffer? {
    guard
      let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      let decoded = CGImageSourceCreateThumbnailAtIndex(source, 0, [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: maxSide,
      ] as CFDictionary)
    else {
      return nil
    }
    let picture = CIImage(cgImage: decoded)
    let image = look.map { stickered(picture, look: $0) } ?? picture
    let extent = image.extent.integral
    var made: CVPixelBuffer?
    let attributes: [String: Any] = [
      kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any],
      kCVPixelBufferMetalCompatibilityKey as String: true,
    ]
    CVPixelBufferCreate(
      nil,
      Int(extent.width),
      Int(extent.height),
      kCVPixelFormatType_32BGRA,
      attributes as CFDictionary,
      &made,
    )
    guard let buffer = made else {
      return nil
    }
    context.render(
      image.transformed(by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY)),
      to: buffer,
      bounds: CGRect(origin: .zero, size: extent.size),
      colorSpace: CGColorSpace(name: CGColorSpace.sRGB),
    )
    return buffer
  }

  // MARK: Private

  /// Shared across pictures: making a CoreImage context is slow, and one is safe to share.
  private static let context = CIContext()

  /// The picture on a white silhouette grown out from its outline, with a paper grain if asked,
  /// over a soft shadow, with room around it for both.
  private static func stickered(_ picture: CIImage, look: StickerLook) -> CIImage {
    let side = min(picture.extent.width, picture.extent.height)
    let border = max(side * look.border, 0)
    let silhouette = CIImage(color: .white).cropped(to: picture.extent.insetBy(
      dx: -border * 2,
      dy: -border * 2,
    ))
    .applyingFilter("CIBlendWithAlphaMask", parameters: [
      kCIInputBackgroundImageKey: CIImage.empty(),
      kCIInputMaskImageKey: picture.applyingFilter(
        "CIMorphologyMaximum",
        parameters: [kCIInputRadiusKey: border],
      ),
    ])
    var sticker = picture.composited(over: border > 0 ? silhouette : CIImage.empty())
    if look.paper {
      sticker = paperGrain(over: sticker.extent).applyingFilter(
        "CIMultiplyCompositing",
        parameters: [kCIInputBackgroundImageKey: sticker],
      )
    }
    if look.shadow {
      let shadow = sticker
        .applyingFilter("CIColorMatrix", parameters: [
          "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0),
          "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
          "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0),
          "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0.45),
        ])
        .applyingGaussianBlur(sigma: side * 0.02)
        .transformed(by: CGAffineTransform(translationX: side * 0.015, y: -side * 0.025))
      sticker = sticker.composited(over: shadow)
    }
    return sticker.cropped(to: picture.extent.insetBy(dx: -side * 0.12, dy: -side * 0.12))
  }

  /// Soft grey speckle from 75% to 100% white, opaque, filling `extent`. Multiplying by it keeps
  /// the sticker's own alpha, and the same noise every time keeps preview and export alike.
  private static func paperGrain(over extent: CGRect) -> CIImage {
    let noise = CIFilter(name: "CIRandomGenerator")?.outputImage ?? CIImage(color: .white)
    // why: the generator's values run far past 1, which would multiply into white speckles.
    return noise.applyingFilter("CIColorClamp")
      .applyingFilter("CIColorMatrix", parameters: [
        "inputRVector": CIVector(x: 0.25, y: 0, z: 0, w: 0),
        "inputGVector": CIVector(x: 0.25, y: 0, z: 0, w: 0),
        "inputBVector": CIVector(x: 0.25, y: 0, z: 0, w: 0),
        "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0),
        "inputBiasVector": CIVector(x: 0.75, y: 0.75, z: 0.75, w: 1),
      ])
      .applyingGaussianBlur(sigma: 0.8)
      .cropped(to: extent)
  }

}
