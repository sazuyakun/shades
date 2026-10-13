import CoreVideo
import Foundation
import Metal

/// Draws one video frame into another on the GPU, without copying pixels through the CPU.
final class MetalRenderer: Sendable {

  // MARK: Lifecycle

  init() throws(EngineError) {
    guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
      logger.fault("metal.setupFailed reason=noDevice")
      throw .metalUnavailable
    }
    self.device = device
    self.queue = queue
    pipeline = try Self.makePipeline(device: device)
  }

  // MARK: Internal

  /// Draws `source` upright (applying `transform`, its rotation) and scaled to fit inside
  /// `output`, with black bars where they differ in shape. With no source (a gap in the
  /// timeline), the output is just black.
  func draw(
    _ source: CVPixelBuffer?,
    transform: CGAffineTransform,
    into output: CVPixelBuffer,
  ) throws(EngineError) {
    let outputTexture = try texture(for: output)
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = outputTexture
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
    pass.colorAttachments[0].storeAction = .store
    guard
      let commands = queue.makeCommandBuffer(),
      let encoder = commands.makeRenderCommandEncoder(descriptor: pass)
    else {
      logger.error("frame.renderFailed reason=commandBuffer")
      throw .renderFailed
    }
    if let source {
      let sourceTexture = try texture(for: source)
      var uniforms = FrameUniforms(
        stored: CGSize(width: sourceTexture.width, height: sourceTexture.height),
        transform: transform,
        output: CGSize(width: outputTexture.width, height: outputTexture.height),
      )
      encoder.setRenderPipelineState(pipeline)
      encoder.setVertexBytes(&uniforms, length: MemoryLayout<FrameUniforms>.size, index: 0)
      encoder.setFragmentTexture(sourceTexture, index: 0)
      encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }
    encoder.endEncoding()
    commands.commit()
    commands.waitUntilCompleted()
  }

  // MARK: Private

  private let device: any MTLDevice
  private let queue: any MTLCommandQueue
  private let pipeline: any MTLRenderPipelineState

  private static func makePipeline(device: any MTLDevice) throws(EngineError)
    -> any MTLRenderPipelineState
  {
    guard
      let url = Bundle.module.url(
        forResource: "Passthrough",
        withExtension: "metal",
        subdirectory: "Shaders",
      )
    else {
      logger.fault("metal.setupFailed reason=shaderMissing")
      throw .metalUnavailable
    }
    let descriptor = MTLRenderPipelineDescriptor()
    descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
    do {
      let library = try device.makeLibrary(
        source: String(contentsOf: url, encoding: .utf8),
        options: nil,
      )
      descriptor.vertexFunction = library.makeFunction(name: "fitVertex")
      descriptor.fragmentFunction = library.makeFunction(name: "passthroughFragment")
      return try device.makeRenderPipelineState(descriptor: descriptor)
    } catch {
      logger.fault("metal.setupFailed reason=shaderCompile")
      throw .metalUnavailable
    }
  }

  /// Wraps a pixel buffer's IOSurface as a Metal texture: the GPU uses the same memory directly.
  private func texture(for buffer: CVPixelBuffer) throws(EngineError) -> any MTLTexture {
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: .bgra8Unorm,
      width: CVPixelBufferGetWidth(buffer),
      height: CVPixelBufferGetHeight(buffer),
      mipmapped: false,
    )
    descriptor.usage = [.shaderRead, .renderTarget]
    guard
      let surface = CVPixelBufferGetIOSurface(buffer)?.takeUnretainedValue(),
      let texture = device.makeTexture(descriptor: descriptor, iosurface: surface, plane: 0)
    else {
      logger.error("frame.renderFailed reason=texture")
      throw .renderFailed
    }
    return texture
  }

}
