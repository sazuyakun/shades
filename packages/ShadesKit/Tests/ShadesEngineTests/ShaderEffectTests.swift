import Foundation
import ShadesCore
import ShadesEngine
import ShadesTestSupport
import Testing

/// Metal shader effects written as files (by plugins or Claude), compiled at runtime.
struct ShaderEffectTests {

  // MARK: Internal

  @Test
  func `a shader effect changes a layer's colour by its amount`() async throws {
    let shader = try write("""
      float4 effect(
        float4 color, float2 uv, float time, float amount, texture2d<half> source, sampler s
      ) {
        return float4(mix(color.rgb, 1.0 - color.rgb, amount), color.a);
      }
      """)
    let png = try await frame(effects: Effects(shader: shader.path, shaderAmount: 1))
    let center = try PixelProbe.color(of: png, x: 0.5, y: 0.5)
    #expect(center.red < 40 && center.green > 200 && center.blue > 200)
  }

  @Test
  func `a broken shader reports its errors, and compiles once fixed`() throws {
    let context = try RenderContext()
    let shader = try write("float4 effect( this is not metal")
    let problem = try #require(context.shaderProblem(at: shader))
    #expect(problem.contains("error"))
    // why: the fix must look like a newer file; file dates are only kept to the second.
    let later = Date().addingTimeInterval(5)
    try """
      float4 effect(
        float4 color, float2 uv, float time, float amount, texture2d<half> source, sampler s
      ) {
        return color;
      }
      """.write(to: shader, atomically: false, encoding: .utf8)
    try FileManager.default.setAttributes([.modificationDate: later], ofItemAtPath: shader.path)
    #expect(context.shaderProblem(at: shader) == nil)
  }

  // MARK: Private

  private func write(_ source: String) throws -> URL {
    let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).metal")
    try source.write(to: url, atomically: true, encoding: .utf8)
    return url
  }

  /// A red clip with `effects`, rendered.
  private func frame(effects: Effects) async throws -> Data {
    let url = try await VideoFixture.make(red: 255, green: 0, blue: 0)
    let media = Media(
      url: url,
      duration: MediaTime(seconds: 1),
      width: 320,
      height: 180,
      hasAudio: false,
    )
    let clip = Clip(
      mediaID: media.id,
      sourceStart: .zero,
      duration: media.duration,
      timelineStart: .zero,
      effects: effects,
    )
    let project = Project(
      media: [media],
      timeline: Timeline(format: .half, tracks: [Track(kind: .video, clips: [clip])]),
    )
    return try await FrameRenderer.png(of: project, atSeconds: 0.5, maxSide: 320)
  }

}
