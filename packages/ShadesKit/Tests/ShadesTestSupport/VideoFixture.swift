import AVFoundation

/// Writes small solid-color test videos, so tests never depend on real footage.
public enum VideoFixture {

  // MARK: Public

  /// Writes a silent H.264 `.mov` of one solid color to a temporary file and returns its URL.
  public static func make(
    red: UInt8,
    green: UInt8,
    blue: UInt8,
    seconds: Int = 1,
    width: Int = 320,
    height: Int = 180,
  ) async throws(FixtureError) -> URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("mov")
    let writer: AVAssetWriter
    do {
      writer = try AVAssetWriter(outputURL: url, fileType: .mov)
    } catch {
      throw .writerFailed
    }
    let input = AVAssetWriterInput(
      mediaType: .video,
      outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: width,
        AVVideoHeightKey: height,
      ],
    )
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
      assetWriterInput: input,
      sourcePixelBufferAttributes: nil,
    )
    writer.add(input)
    guard writer.startWriting() else {
      throw .writerFailed
    }
    writer.startSession(atSourceTime: .zero)
    let frame = try solidFrame(red: red, green: green, blue: blue, width: width, height: height)
    for index in 0 ..< seconds * 30 {
      while !input.isReadyForMoreMediaData {
        try? await Task.sleep(for: .milliseconds(5)) // why: a cancelled sleep just polls again.
      }
      guard adaptor.append(frame, withPresentationTime: CMTime(value: Int64(index), timescale: 30))
      else {
        throw .writerFailed
      }
    }
    input.markAsFinished()
    await withCheckedContinuation { continuation in
      writer.finishWriting { continuation.resume() }
    }
    guard writer.status == .completed else {
      throw .writerFailed
    }
    return url
  }

  // MARK: Private

  private static func solidFrame(
    red: UInt8,
    green: UInt8,
    blue: UInt8,
    width: Int,
    height: Int,
  ) throws(FixtureError) -> CVPixelBuffer {
    var buffer: CVPixelBuffer?
    CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32BGRA, nil, &buffer)
    guard let buffer else {
      throw .writerFailed
    }
    CVPixelBufferLockBaseAddress(buffer, [])
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
    guard let base = CVPixelBufferGetBaseAddress(buffer) else {
      throw .writerFailed
    }
    let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
    let pixels = base.assumingMemoryBound(to: UInt8.self)
    for row in 0 ..< height {
      for column in 0 ..< width {
        let offset = row * bytesPerRow + column * 4
        pixels[offset] = blue
        pixels[offset + 1] = green
        pixels[offset + 2] = red
        pixels[offset + 3] = 255
      }
    }
    return buffer
  }

}
