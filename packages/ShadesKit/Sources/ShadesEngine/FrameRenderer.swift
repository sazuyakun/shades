import AVFoundation
import ImageIO
import ShadesCore
import UniformTypeIdentifiers

/// Renders single frames of the timeline through the same compositor that plays it.
public enum FrameRenderer {

  /// Renders the frame at `seconds` as PNG data, no wider or taller than `maxSide` pixels, with
  /// cut-outs from `mattes` for depth slots and optical flow from `flows` for footage blur. Pass
  /// a long-lived `context` when rendering often; a new one compiles the shaders again.
  @MainActor
  public static func png(
    of project: Project,
    atSeconds seconds: Double,
    maxSide: Int,
    context: RenderContext? = nil,
    mattes: [Media.ID: URL] = [:],
    flows: [Media.ID: URL] = [:],
  ) async throws(EngineError) -> Data {
    try await pngData(from: image(
      of: project,
      atSeconds: seconds,
      maxSide: maxSide,
      context: context,
      mattes: mattes,
      flows: flows,
    ))
  }

  /// Renders the frame at `seconds` as an image, like `png`.
  @MainActor
  public static func image(
    of project: Project,
    atSeconds seconds: Double,
    maxSide: Int,
    context: RenderContext? = nil,
    mattes: [Media.ID: URL] = [:],
    flows: [Media.ID: URL] = [:],
  ) async throws(EngineError) -> CGImage {
    let composition = try await Composition.forRendering(
      project,
      context: context,
      mattes: mattes,
      flows: flows,
    )
    let generator = AVAssetImageGenerator(asset: composition.asset)
    generator.videoComposition = composition.videoComposition
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero
    generator.maximumSize = CGSize(width: maxSide, height: maxSide)
    let time = CMTime(seconds: seconds, preferredTimescale: 600)
    // why: the callback API keeps the generator on the main actor; the async API would have to
    // send it to another thread, which Swift can't prove is safe.
    let image: CGImage? = await withCheckedContinuation { continuation in
      generator.generateCGImageAsynchronously(for: time) { image, _, _ in
        continuation.resume(returning: image)
      }
    }
    // why: the generator must stay alive until its callback has run.
    withExtendedLifetime(generator) { }
    guard let image else {
      logger.error("frame.renderFailed reason=noFrame seconds=\(seconds, privacy: .public)")
      throw .frameUnavailable(seconds: seconds)
    }
    return image
  }

  /// `image` encoded as PNG.
  public static func pngData(from image: CGImage) throws(EngineError) -> Data {
    let data = NSMutableData()
    guard
      let destination = CGImageDestinationCreateWithData(
        data,
        UTType.png.identifier as CFString,
        1,
        nil,
      )
    else {
      logger.error("frame.encodeFailed reason=destination")
      throw .imageEncodingFailed
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
      logger.error("frame.encodeFailed reason=finalize")
      throw .imageEncodingFailed
    }
    return data as Data
  }

}
