import AVFoundation

/// Writes analysis frames (cut-outs, optical flow) into a small H.264 video, one at a time.
struct FrameWriter {

  // MARK: Lifecycle

  /// Opens `url` for `width`×`height` frames in `pixelFormat`, replacing any file there.
  init(url: URL, width: Int, height: Int, pixelFormat: OSType) throws(MattingError) {
    self.url = url
    do {
      try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true,
      )
      // why: there may be no old file; that's the common case.
      try? FileManager.default.removeItem(at: url)
      writer = try AVAssetWriter(outputURL: url, fileType: .mov)
    } catch {
      logger.error("frames.failed reason=writer path=\(url.path, privacy: .private)")
      throw .unwritable(url)
    }
    input = AVAssetWriterInput(mediaType: .video, outputSettings: [
      AVVideoCodecKey: AVVideoCodecType.h264,
      AVVideoWidthKey: width,
      AVVideoHeightKey: height,
    ])
    input.expectsMediaDataInRealTime = false
    adaptor = AVAssetWriterInputPixelBufferAdaptor(
      assetWriterInput: input,
      sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: pixelFormat,
        kCVPixelBufferWidthKey as String: width,
        kCVPixelBufferHeightKey as String: height,
      ],
    )
    writer.add(input)
    guard writer.startWriting() else {
      logger.error("frames.failed reason=start path=\(url.path, privacy: .private)")
      throw .unwritable(url)
    }
    writer.startSession(atSourceTime: .zero)
  }

  // MARK: Internal

  /// Appends one frame at `time`; `fill` writes its pixels into the locked buffer.
  func append(at time: CMTime, fill: (CVPixelBuffer) -> Void) async throws(MattingError) {
    while !input.isReadyForMoreMediaData {
      try? await Task.sleep(for: .milliseconds(2)) // why: a cancelled wait just polls again.
    }
    guard let pool = adaptor.pixelBufferPool else {
      logger.error("frames.failed reason=pool path=\(url.path, privacy: .private)")
      throw .unwritable(url)
    }
    var made: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, pool, &made)
    guard let buffer = made else {
      logger.error("frames.failed reason=buffer path=\(url.path, privacy: .private)")
      throw .unwritable(url)
    }
    CVPixelBufferLockBaseAddress(buffer, [])
    fill(buffer)
    CVPixelBufferUnlockBaseAddress(buffer, [])
    guard adaptor.append(buffer, withPresentationTime: time) else {
      logger.error("frames.failed reason=append path=\(url.path, privacy: .private)")
      throw .unwritable(url)
    }
  }

  /// Stops writing and leaves the file unfinished, for a cancelled job.
  func cancel() {
    writer.cancelWriting()
  }

  /// Closes the file.
  func finish() async throws(MattingError) {
    input.markAsFinished()
    let writer = writer
    await withCheckedContinuation { continuation in
      writer.finishWriting { continuation.resume() }
    }
    guard writer.status == .completed else {
      logger.error("frames.failed reason=finish path=\(url.path, privacy: .private)")
      throw .unwritable(url)
    }
  }

  // MARK: Private

  private let url: URL
  private let writer: AVAssetWriter
  private let input: AVAssetWriterInput
  private let adaptor: AVAssetWriterInputPixelBufferAdaptor

}
