import AVFoundation
import ImageIO
import ShadesCore
import ShadesEngine
import UniformTypeIdentifiers

/// Exports single frames as PNGs and short moments as looping GIFs, drawn by the same
/// compositor that plays the timeline.
public enum StillExporter {

  /// The longest stretch a GIF is made of.
  public static let longestGIF = 30.0

  /// Writes the frame at `seconds` to `url` as a full-size PNG.
  @MainActor
  public static func frame(
    of project: Project,
    atSeconds seconds: Double,
    to url: URL,
    mattes: [Media.ID: URL] = [:],
    flows: [Media.ID: URL] = [:],
  ) async throws(ExportError) {
    let format = project.timeline.format
    let png: Data
    do {
      png = try await FrameRenderer.png(
        of: project,
        atSeconds: seconds,
        maxSide: max(format.width, format.height),
        mattes: mattes,
        flows: flows,
      )
    } catch {
      throw .renderFailed(error)
    }
    try MovieExporter.moveAside(url)
    do {
      try png.write(to: url)
    } catch {
      logger.error("frame.failed reason=write path=\(url.path, privacy: .private)")
      throw .unwritable(url)
    }
  }

  /// Writes `range` of the timeline to `url` as a looping GIF, `framesPerSecond` a second and
  /// no wider or taller than `maxSide` pixels.
  @MainActor
  public static func gif(
    of project: Project,
    range: TimeRange,
    to url: URL,
    maxSide: Int = 640,
    framesPerSecond: Double = 15,
    mattes: [Media.ID: URL] = [:],
    flows: [Media.ID: URL] = [:],
    progress: @escaping @Sendable (Double) -> Void,
  ) async throws(ExportError) {
    guard range.duration.seconds <= longestGIF else {
      throw .tooLong(seconds: range.duration.seconds, limit: longestGIF)
    }
    guard range.end > range.start, project.timeline.duration > .zero else {
      throw .nothingToExport("the timeline is empty")
    }
    let composition: Composition
    do {
      composition = try await Composition.forRendering(project, mattes: mattes, flows: flows)
    } catch {
      throw .renderFailed(error)
    }
    let generator = AVAssetImageGenerator(asset: composition.asset)
    generator.videoComposition = composition.videoComposition
    generator.maximumSize = CGSize(width: maxSide, height: maxSide)
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero
    let times = stride(from: range.start.seconds, to: range.end.seconds, by: 1 / framesPerSecond)
      .map { CMTime(seconds: $0, preferredTimescale: 600) }
    try MovieExporter.moveAside(url)
    guard
      let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.gif.identifier as CFString,
        times.count,
        nil,
      )
    else {
      logger.error("gif.failed reason=destination path=\(url.path, privacy: .private)")
      throw .unwritable(url)
    }
    CGImageDestinationSetProperties(destination, [
      kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]
    ] as CFDictionary)
    let frameProperties = [
      kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1 / framesPerSecond]
    ] as CFDictionary
    var done = 0
    for await result in generator.images(for: times) {
      guard !Task.isCancelled else {
        throw .cancelled
      }
      let image: CGImage
      do {
        image = try result.image
      } catch {
        logger.error("gif.failed reason=frame seconds=\(result.requestedTime.seconds)")
        throw .encodingFailed
      }
      CGImageDestinationAddImage(destination, image, frameProperties)
      done += 1
      progress(Double(done) / Double(times.count))
    }
    guard CGImageDestinationFinalize(destination) else {
      logger.error("gif.failed reason=finalize path=\(url.path, privacy: .private)")
      throw .unwritable(url)
    }
  }

}
