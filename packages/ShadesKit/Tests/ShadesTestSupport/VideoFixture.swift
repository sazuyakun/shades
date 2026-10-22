import AVFoundation

// MARK: - VideoFixture

/// Writes small test videos, so tests never depend on real footage.
public enum VideoFixture {

  // MARK: Public

  /// Writes a silent `.mov` of one solid color and returns its URL.
  public static func make(
    red: UInt8,
    green: UInt8,
    blue: UInt8,
    seconds: Int = 1,
    width: Int = 320,
    height: Int = 180,
  ) async throws(FixtureError) -> URL {
    let color = FixtureColor(red: red, green: green, blue: blue)
    return try await make(left: color, right: color, seconds: seconds, width: width, height: height)
  }

  /// Writes a silent `.mov` whose stored frames are `left` on the left half and `right` on the
  /// right half, tagged with `transform` the way an iPhone tags portrait video. ProRes 4444 by
  /// default: unlike H.264 it decodes the same on every machine, so golden frames stay stable.
  public static func make(
    left: FixtureColor,
    right: FixtureColor,
    seconds: Int = 1,
    width: Int = 320,
    height: Int = 180,
    transform: CGAffineTransform = .identity,
    codec: AVVideoCodecType = .proRes4444,
  ) async throws(FixtureError) -> URL {
    let frame = try splitFrame(left: left, right: right, width: width, height: height)
    return try await write(
      seconds: seconds,
      width: width,
      height: height,
      transform: transform,
      codec: codec,
    ) { _ in frame }
  }

  /// Writes a silent `.mov` whose frames are numbered by their colour, so a rendered frame tells
  /// which source frame it shows (read it back with `countedFrame(in:)`). Up to 64 frames: 2
  /// seconds at 30 fps.
  public static func makeCounting(
    seconds: Int = 2,
    width: Int = 320,
    height: Int = 240,
  ) async throws(FixtureError) -> URL {
    try await write(seconds: seconds, width: width, height: height) { index throws(FixtureError) in
      let color = FixtureColor(
        red: UInt8(index % 4 * 85),
        green: UInt8(index / 4 % 4 * 85),
        blue: UInt8(index / 16 * 85),
      )
      return try splitFrame(left: color, right: color, width: width, height: height)
    }
  }

  /// The number of the `makeCounting` frame a rendered PNG shows in its middle.
  public static func countedFrame(in png: Data) throws(FixtureError) -> Int {
    // why: each channel holds a digit in steps of 85, so rounding shrugs off colour conversion.
    let color = try PixelProbe.color(of: png, x: 0.5, y: 0.5)
    let digit = { (level: UInt8) in Int((Double(level) / 85).rounded()) }
    return digit(color.blue) * 16 + digit(color.green) * 4 + digit(color.red)
  }

  /// The `makeCounting` frame shown at `seconds` of its source, or `nil` when that moment is
  /// within a sixth of a frame of a frame's edge, where a renderer asked for a hair earlier or
  /// later may land on either side.
  public static func countedFrame(atSource seconds: Double) -> Int? {
    let position = seconds * 30
    let inside = position - position.rounded(.down)
    return (1.0 / 6 ... 5.0 / 6).contains(inside) ? Int(position) : nil
  }

  /// Writes a `.mov` of a bright orange disc in the middle of a dark frame: an obvious subject
  /// for cut-out tests.
  public static func makeDisc(
    seconds: Int = 1,
    width: Int = 640,
    height: Int = 360,
  ) async throws(FixtureError) -> URL {
    let frame = try picture(width: width, height: height) { context in
      context.setFillColor(CGColor(red: 1, green: 0.55, blue: 0.1, alpha: 1))
      let radius = Double(height) * 0.32
      context.fillEllipse(in: CGRect(
        x: Double(width) / 2 - radius,
        y: Double(height) / 2 - radius,
        width: radius * 2,
        height: radius * 2,
      ))
    }
    return try await write(seconds: seconds, width: width, height: height) { _ in frame }
  }

  /// Writes a `.mov` of a test chart: six colour bars (red, yellow, green, cyan, blue, magenta)
  /// over a grey ramp from black to white, so grades and effects show on every hue and level.
  public static func makeChart(
    seconds: Int = 1,
    width: Int = 320,
    height: Int = 240,
  ) async throws(FixtureError) -> URL {
    let bars: [(red: Double, green: Double, blue: Double)] = [
      (1, 0, 0),
      (1, 1, 0),
      (0, 1, 0),
      (0, 1, 1),
      (0, 0, 1),
      (1, 0, 1),
    ]
    let rampHeight = Double(height) / 3
    let frame = try picture(width: width, height: height) { context in
      let barWidth = Double(width) / Double(bars.count)
      for (index, bar) in bars.enumerated() {
        context.setFillColor(CGColor(red: bar.red, green: bar.green, blue: bar.blue, alpha: 1))
        context.fill(CGRect(
          x: Double(index) * barWidth,
          y: rampHeight,
          width: barWidth,
          height: Double(height) - rampHeight,
        ))
      }
      let ramp = CGGradient(
        colorsSpace: space,
        colors: [CGColor(gray: 0, alpha: 1), CGColor(gray: 1, alpha: 1)] as CFArray,
        locations: [0, 1],
      )
      context.clip(to: CGRect(x: 0, y: 0, width: Double(width), height: rampHeight))
      if let ramp {
        context.drawLinearGradient(
          ramp,
          start: .zero,
          end: CGPoint(x: Double(width), y: 0),
          options: [],
        )
      }
    }
    return try await write(seconds: seconds, width: width, height: height) { _ in frame }
  }

  /// Writes a `.mov` of a checkered square sliding from the left third to the right third of a
  /// dark frame over its length, staying vertically centred (or, `diagonal`, also sliding from
  /// the top third to the bottom third): something to track or blur.
  public static func makeMovingSquare(
    seconds: Int = 1,
    width: Int = 640,
    height: Int = 360,
    diagonal: Bool = false,
  ) async throws(FixtureError) -> URL {
    let side = Double(height) * 0.3
    let frames = seconds * 30
    return try await write(
      seconds: seconds,
      width: width,
      height: height,
    ) { index throws(FixtureError) in
      let travel = Double(index) / Double(max(frames - 1, 1)) / 3
      let centerX = Double(width) * (1 / 3 + travel)
      // why: pictures are drawn bottom-up, so sliding down the frame lowers y.
      let centerY = Double(height) * (diagonal ? 2 / 3 - travel : 0.5)
      return try picture(width: width, height: height) { context in
        let origin = CGPoint(x: centerX - side / 2, y: centerY - side / 2)
        for row in 0 ..< 4 {
          for column in 0 ..< 4 {
            let isLight = (row + column).isMultiple(of: 2)
            context.setFillColor(CGColor(gray: isLight ? 0.95 : 0.35, alpha: 1))
            context.fill(CGRect(
              x: origin.x + Double(column) * side / 4,
              y: origin.y + Double(row) * side / 4,
              width: side / 4,
              height: side / 4,
            ))
          }
        }
      }
    }
  }

  // MARK: Private

  /// sRGB, so fixtures draw the same pixels on every Mac: device RGB follows the screen's
  /// profile, which differs between the dev machine and CI's headless runner.
  private static let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

  /// Writes `seconds` at 30 fps, asking `frame` for each frame's picture by its index.
  private static func write(
    seconds: Int,
    width: Int,
    height: Int,
    transform: CGAffineTransform = .identity,
    codec: AVVideoCodecType = .proRes4444,
    frame: (Int) throws(FixtureError) -> CVPixelBuffer,
  ) async throws(FixtureError) -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("mov")
    let writer: AVAssetWriter
    do {
      writer = try AVAssetWriter(outputURL: url, fileType: .mov)
    } catch {
      throw .writerFailed
    }
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
      AVVideoCodecKey: codec,
      AVVideoWidthKey: width,
      AVVideoHeightKey: height,
    ])
    input.transform = transform
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
      assetWriterInput: input,
      sourcePixelBufferAttributes: nil,
    )
    writer.add(input)
    guard writer.startWriting() else {
      throw .writerFailed
    }
    writer.startSession(atSourceTime: .zero)
    for index in 0 ..< seconds * 30 {
      while !input.isReadyForMoreMediaData {
        try? await Task.sleep(for: .milliseconds(5)) // why: a cancelled sleep just polls again.
      }
      guard
        try adaptor.append(
          frame(index),
          withPresentationTime: CMTime(value: Int64(index), timescale: 30),
        )
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

  /// A frame of a dark background with `draw` drawn over it (bottom-left origin).
  private static func picture(
    width: Int,
    height: Int,
    draw: (CGContext) -> Void,
  ) throws(FixtureError) -> CVPixelBuffer {
    var buffer: CVPixelBuffer?
    CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32BGRA, nil, &buffer)
    guard let buffer else {
      throw .writerFailed
    }
    CVPixelBufferLockBaseAddress(buffer, [])
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
    guard
      let context = CGContext(
        data: CVPixelBufferGetBaseAddress(buffer),
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
        space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little
          .rawValue,
      )
    else {
      throw .writerFailed
    }
    context.setFillColor(CGColor(red: 0.08, green: 0.09, blue: 0.12, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    draw(context)
    return buffer
  }

  private static func splitFrame(
    left: FixtureColor,
    right: FixtureColor,
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
        let color = column < width / 2 ? left : right
        let offset = row * bytesPerRow + column * 4
        pixels[offset] = color.blue
        pixels[offset + 1] = color.green
        pixels[offset + 2] = color.red
        pixels[offset + 3] = 255
      }
    }
    return buffer
  }

}
