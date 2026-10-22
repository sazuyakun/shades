import CoreVideo
import Foundation

// MARK: - DistanceField

/// How far each pixel of a picture is from the edge of what's drawn in it: positive inside,
/// negative outside. Solid 3D text reads it to cut its bevel and to light its sides.
enum DistanceField {

  // MARK: Internal

  /// The signed distance of each pixel of `picture` to the edge of its ink (where it's half
  /// see-through), one byte a pixel: 128 at the edge, one step per `unit` pixels. `nil` if it
  /// can't be made.
  static func make(from picture: CVPixelBuffer, unit: Double) -> CVPixelBuffer? {
    let width = CVPixelBufferGetWidth(picture)
    let height = CVPixelBufferGetHeight(picture)
    CVPixelBufferLockBaseAddress(picture, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(picture, .readOnly) }
    guard
      let source = CVPixelBufferGetBaseAddress(picture)?.assumingMemoryBound(to: UInt8.self),
      let field = buffer(width: width, height: height)
    else {
      return nil
    }
    let sourceRow = CVPixelBufferGetBytesPerRow(picture)
    var inside = [Bool](repeating: false, count: width * height)
    for y in 0 ..< height {
      for x in 0 ..< width {
        inside[y * width + x] = source[y * sourceRow + x * 4 + 3] >= 128
      }
    }
    let toOutside = squaredDistances(width: width, height: height, to: false, in: inside)
    let toInside = squaredDistances(width: width, height: height, to: true, in: inside)
    CVPixelBufferLockBaseAddress(field, [])
    defer { CVPixelBufferUnlockBaseAddress(field, []) }
    guard let target = CVPixelBufferGetBaseAddress(field)?.assumingMemoryBound(to: UInt8.self)
    else {
      return nil
    }
    let targetRow = CVPixelBufferGetBytesPerRow(field)
    let steps = Float(1 / unit)
    for y in 0 ..< height {
      for x in 0 ..< width {
        let index = y * width + x
        // why: half a pixel each way puts the edge between the last pixel in and the first out.
        let distance = inside[index]
          ? toOutside[index].squareRoot() - 0.5
          : 0.5 - toInside[index].squareRoot()
        target[y * targetRow + x] = UInt8(min(max(128 + distance * steps, 0), 255).rounded())
      }
    }
    return field
  }

  /// The squared distance from every pixel to the nearest one whose `inside` is `side`, in two
  /// passes, down the columns then along the rows (Felzenszwalb and Huttenlocher), each pass
  /// spread over the Mac's cores.
  static func squaredDistances(
    width: Int,
    height: Int,
    to side: Bool,
    in inside: [Bool],
  ) -> [Float] {
    var grid = inside.map { $0 == side ? 0 : far }
    grid.withUnsafeMutableBufferPointer { grid in
      sweep(lines: width, length: height) { column, scratch in
        scratch.run(grid.baseAddress.unsafelyUnwrapped + column, stride: width, count: height)
      }
      sweep(lines: height, length: width) { row, scratch in
        scratch.run(grid.baseAddress.unsafelyUnwrapped + row * width, stride: 1, count: width)
      }
    }
    return grid
  }

  // MARK: Private

  /// Stands for "no target in reach"; finite so the envelope's sums stay numbers.
  private static let far: Float = 1e20

  /// Runs `pass` over every line, the lines split into one batch per core, each batch with its
  /// own scratch space.
  private static func sweep(
    lines: Int,
    length: Int,
    pass: (Int, inout EnvelopeScratch) -> Void,
  ) {
    let batches = min(ProcessInfo.processInfo.activeProcessorCount, lines)
    // why: a blocking fan-out on GCD's own threads; text is drawn off Swift's cooperative pool.
    DispatchQueue.concurrentPerform(iterations: batches) { batch in
      var scratch = EnvelopeScratch(length: length)
      for line in stride(from: batch, to: lines, by: batches) {
        pass(line, &scratch)
      }
    }
  }

  /// A one-byte-a-pixel buffer the GPU can read.
  private static func buffer(width: Int, height: Int) -> CVPixelBuffer? {
    var made: CVPixelBuffer?
    CVPixelBufferCreate(
      nil,
      width,
      height,
      kCVPixelFormatType_OneComponent8,
      [
        kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary,
        kCVPixelBufferMetalCompatibilityKey: true,
      ] as CFDictionary,
      &made,
    )
    return made
  }

}

// MARK: - EnvelopeScratch

/// Room for one line's pass, reused line after line.
private struct EnvelopeScratch {

  // MARK: Lifecycle

  init(length: Int) {
    heights = [Float](repeating: 0, count: length)
    vertices = [Int](repeating: 0, count: length)
    bounds = [Float](repeating: 0, count: length + 1)
  }

  // MARK: Internal

  /// Replaces the `count` values at `line` (`stride` apart) with, for each place, the least of
  /// every `value[q] + (place - q)²`, read off the lower envelope of those parabolas.
  mutating func run(_ line: UnsafeMutablePointer<Float>, stride: Int, count: Int) {
    for place in 0 ..< count {
      heights[place] = line[place * stride]
    }
    var last = 0
    vertices[0] = 0
    bounds[0] = -.infinity
    bounds[1] = .infinity
    for place in 1 ..< max(count, 1) {
      var meet = crossing(place, vertices[last])
      while meet <= bounds[last] {
        last -= 1
        meet = crossing(place, vertices[last])
      }
      last += 1
      vertices[last] = place
      bounds[last] = meet
      bounds[last + 1] = .infinity
    }
    var vertex = 0
    for place in 0 ..< count {
      while bounds[vertex + 1] < Float(place) {
        vertex += 1
      }
      let offset = Float(place - vertices[vertex])
      line[place * stride] = offset * offset + heights[vertices[vertex]]
    }
  }

  // MARK: Private

  private var heights: [Float]
  private var vertices: [Int]
  /// Where each parabola of the envelope takes over from the one before.
  private var bounds: [Float]

  /// Where the parabolas from `place` and `vertex` cross.
  private func crossing(_ place: Int, _ vertex: Int) -> Float {
    (heights[place] + Float(place * place) - heights[vertex] - Float(vertex * vertex))
      / Float(2 * (place - vertex))
  }

}
