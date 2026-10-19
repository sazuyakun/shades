import Foundation

// MARK: - LoudnessMeter

/// Measures loudness the way streaming platforms do (ITU-R BS.1770 / EBU R128): K-weighted,
/// in 400 ms blocks, gated to ignore silence and quiet passages.
public enum LoudnessMeter {

  // MARK: Public

  /// The integrated loudness and peak of stereo audio at 48 kHz, read as interleaved left/right
  /// chunks from `next` until it returns `nil`.
  @concurrent
  public static func measure<Failure: Error>(
    next: @Sendable () async throws(Failure) -> [Float]?
  ) async throws(Failure) -> Loudness {
    var meter = Meter()
    while let chunk = try await next() {
      meter.add(chunk)
    }
    return meter.result()
  }

  // MARK: Internal

  /// The measurement in progress: filters, the current block, and every block's energy.
  struct Meter {

    // MARK: Internal

    mutating func add(_ interleaved: [Float]) {
      var index = 0
      while index + 1 < interleaved.count {
        let left = Double(interleaved[index])
        let right = Double(interleaved[index + 1])
        peak = max(peak, abs(left), abs(right))
        let weightedLeft = leftFilter.process(left)
        let weightedRight = rightFilter.process(right)
        energy[step % Self.blockSteps] += weightedLeft * weightedLeft + weightedRight *
          weightedRight
        sample += 1
        if sample == Self.step {
          sample = 0
          step += 1
          if step >= Self.blockSteps {
            // why: a block is four quarter-blocks, so blocks overlap by 75% as the standard asks.
            blocks.append(energy.reduce(0, +) / Double(Self.step * Self.blockSteps))
          }
          energy[step % Self.blockSteps] = 0
        }
        index += 2
      }
    }

    func result() -> Loudness {
      let loud = blocks.filter { Self.lufs($0) > -70 }
      guard !loud.isEmpty else {
        return Loudness(integrated: -.infinity, peak: Self.decibels(peak))
      }
      let threshold = Self.lufs(loud.reduce(0, +) / Double(loud.count)) - 10
      let gated = loud.filter { Self.lufs($0) > threshold }
      return Loudness(
        integrated: Self.lufs(gated.reduce(0, +) / Double(max(gated.count, 1))),
        peak: Self.decibels(peak),
      )
    }

    // MARK: Private

    /// 100 ms of samples at 48 kHz: a quarter of a 400 ms block.
    private static let step = 4800
    private static let blockSteps = 4

    private var leftFilter = KWeighting()
    private var rightFilter = KWeighting()
    private var energy = [Double](repeating: 0, count: blockSteps)
    private var sample = 0
    private var step = 0
    private var blocks = [Double]()
    private var peak = 0.0

    private static func lufs(_ meanSquare: Double) -> Double {
      -0.691 + 10 * log10(max(meanSquare, 1e-12))
    }

    private static func decibels(_ level: Double) -> Double {
      20 * log10(max(level, 1e-9))
    }

  }

}

// MARK: - Loudness

/// How loud a mix is.
public struct Loudness: Sendable {
  /// Integrated loudness in LUFS (YouTube plays at about −14, Instagram about −14 to −16).
  public let integrated: Double
  /// The loudest sample, in dBFS (0 is the most a file can hold).
  public let peak: Double
}

// MARK: - KWeighting

/// The BS.1770 K-weighting filter at 48 kHz: a high shelf (the head's effect) then a high-pass.
private struct KWeighting {

  // MARK: Internal

  mutating func process(_ input: Double) -> Double {
    highPass.process(shelf.process(input))
  }

  // MARK: Private

  private var shelf = Biquad(
    b: (1.53512485958697, -2.69169618940638, 1.19839281085285),
    a: (-1.69065929318241, 0.73248077421585),
  )
  private var highPass = Biquad(b: (1, -2, 1), a: (-1.99004745483398, 0.99007225036621))

}

// MARK: - Biquad

/// A second-order filter (direct form I).
private struct Biquad {

  // MARK: Lifecycle

  /// A filter with feed-forward coefficients `b` and feedback coefficients `a` (a0 is 1).
  init(b: (Double, Double, Double), a: (Double, Double)) {
    self.b = b
    self.a = a
  }

  // MARK: Internal

  let b: (Double, Double, Double)
  let a: (Double, Double)

  mutating func process(_ input: Double) -> Double {
    let result = b.0 * input + b.1 * x1 + b.2 * x2 - a.0 * y1 - a.1 * y2
    x2 = x1
    x1 = input
    y2 = y1
    y1 = result
    return result
  }

  // MARK: Private

  private var x1 = 0.0
  private var x2 = 0.0
  private var y1 = 0.0
  private var y2 = 0.0

}
