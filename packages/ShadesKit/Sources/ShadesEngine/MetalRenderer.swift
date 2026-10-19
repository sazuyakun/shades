import CoreVideo
import Foundation
import IOSurface
import Metal
import ShadesCore

// MARK: - MetalRenderer

/// Draws video frames as layers of one output frame on the GPU, without copying pixels through
/// the CPU, honouring depth slots with the base clip's cut-out.
final class MetalRenderer: Sendable {

  // MARK: Lifecycle

  init() throws(EngineError) {
    guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
      logger.fault("metal.setupFailed reason=noDevice")
      throw .metalUnavailable
    }
    self.device = device
    self.queue = queue
    let library = try Self.makeLibrary(device: device)
    pipeline = try Self.makePipeline(
      device: device,
      library: library,
      fragment: "layerFragment",
      format: .bgra8Unorm,
    )
    maskedPipeline = try Self.makePipeline(
      device: device,
      library: library,
      fragment: "maskedLayerFragment",
      format: .bgra8Unorm,
    )
    mattePipeline = try Self.makePipeline(
      device: device,
      library: library,
      fragment: "matteFragment",
      format: .r8Unorm,
    )
  }

  // MARK: Internal

  /// Draws `layers` (bottom to top) over black: each upright, fitted inside `output`, then placed
  /// and blended by its clip's transform and opacity, in depth-slot order. With no layers (a
  /// gap), the output is black.
  func draw(_ layers: [RenderLayer], into output: CVPixelBuffer) throws(EngineError) {
    let outputTexture = try texture(for: output)
    let outputSize = CGSize(width: outputTexture.width, height: outputTexture.height)
    let order = DepthOrder.steps(
      depths: layers.map(\.depth),
      hasMatte: layers.map { $0.matte != nil },
    )
    guard let commands = queue.makeCommandBuffer() else {
      logger.error("frame.renderFailed reason=commandBuffer")
      throw .renderFailed
    }
    var mask: (any MTLTexture)?
    if let base = order.maskBase {
      mask = try drawMask(of: layers[base], size: outputSize, commands: commands)
    }
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = outputTexture
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
    pass.colorAttachments[0].storeAction = .store
    guard let encoder = commands.makeRenderCommandEncoder(descriptor: pass) else {
      logger.error("frame.renderFailed reason=encoder")
      throw .renderFailed
    }
    for step in order.steps {
      switch step {
      case .plain(let index):
        encoder.setRenderPipelineState(pipeline)
        try encode(layers[index], size: outputSize, encoder: encoder)

      case .cutOut(let index),
           .masked(let index):
        encoder.setRenderPipelineState(mask == nil ? pipeline : maskedPipeline)
        encoder.setFragmentTexture(mask, index: 1)
        try encode(layers[index], size: outputSize, encoder: encoder)
      }
    }
    encoder.endEncoding()
    commands.commit()
    commands.waitUntilCompleted()
  }

  /// Wraps a pixel buffer's IOSurface as a Metal texture: the GPU uses the same memory directly.
  func texture(for buffer: CVPixelBuffer) throws(EngineError) -> any MTLTexture {
    guard let surface = CVPixelBufferGetIOSurface(buffer)?.takeUnretainedValue() else {
      logger.error("frame.renderFailed reason=noSurface")
      throw .renderFailed
    }
    return try texture(for: surface)
  }

  // MARK: Private

  private let device: any MTLDevice
  private let queue: any MTLCommandQueue
  private let pipeline: any MTLRenderPipelineState
  private let maskedPipeline: any MTLRenderPipelineState
  private let mattePipeline: any MTLRenderPipelineState

  private static func makeLibrary(device: any MTLDevice) throws(EngineError) -> any MTLLibrary {
    guard
      let url = Bundle.module.url(
        forResource: "Layers",
        withExtension: "metal",
        subdirectory: "Shaders",
      )
    else {
      logger.fault("metal.setupFailed reason=shaderMissing")
      throw .metalUnavailable
    }
    do {
      return try device.makeLibrary(source: String(contentsOf: url, encoding: .utf8), options: nil)
    } catch {
      logger.fault("metal.setupFailed reason=shaderCompile")
      throw .metalUnavailable
    }
  }

  private static func makePipeline(
    device: any MTLDevice,
    library: any MTLLibrary,
    fragment: String,
    format: MTLPixelFormat,
  ) throws(EngineError) -> any MTLRenderPipelineState {
    let descriptor = MTLRenderPipelineDescriptor()
    descriptor.vertexFunction = library.makeFunction(name: "layerVertex")
    descriptor.fragmentFunction = library.makeFunction(name: fragment)
    descriptor.colorAttachments[0].pixelFormat = format
    if format == .bgra8Unorm {
      descriptor.colorAttachments[0].isBlendingEnabled = true
      descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
      descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
      descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
      descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
    }
    do {
      return try device.makeRenderPipelineState(descriptor: descriptor)
    } catch {
      logger.fault("metal.setupFailed reason=pipeline fragment=\(fragment, privacy: .public)")
      throw .metalUnavailable
    }
  }

  /// Draws the base layer's cut-out, placed like the layer, into a half-size mask of the frame.
  private func drawMask(
    of layer: RenderLayer,
    size: CGSize,
    commands: any MTLCommandBuffer,
  ) throws(EngineError) -> (any MTLTexture)? {
    guard let matte = layer.matte else {
      return nil
    }
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: .r8Unorm,
      width: max(Int(size.width) / 2, 1),
      height: max(Int(size.height) / 2, 1),
      mipmapped: false,
    )
    descriptor.usage = [.renderTarget, .shaderRead]
    descriptor.storageMode = .private
    let pass = MTLRenderPassDescriptor()
    guard let mask = device.makeTexture(descriptor: descriptor) else {
      logger.error("frame.renderFailed reason=maskTexture")
      throw .renderFailed
    }
    pass.colorAttachments[0].texture = mask
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
    pass.colorAttachments[0].storeAction = .store
    guard let encoder = commands.makeRenderCommandEncoder(descriptor: pass) else {
      logger.error("frame.renderFailed reason=maskEncoder")
      throw .renderFailed
    }
    encoder.setRenderPipelineState(mattePipeline)
    // why: the matte is already upright, so it's drawn with the layer's placement but no rotation.
    let matteLayer = RenderLayer(
      source: matte,
      rotation: .identity,
      transform: layer.transform,
      opacity: 1,
      depth: .inFront,
      matte: nil,
      isNaturalSize: false,
    )
    try encode(matteLayer, size: size, encoder: encoder)
    encoder.endEncoding()
    return mask
  }

  private func encode(
    _ layer: RenderLayer,
    size: CGSize,
    encoder: any MTLRenderCommandEncoder,
  ) throws(EngineError) {
    let sourceTexture =
      switch layer.source {
      case .frame(let buffer): try texture(for: buffer)
      case .surface(let surface): try texture(for: surface)
      }
    var uniforms = FrameUniforms(
      stored: CGSize(width: sourceTexture.width, height: sourceTexture.height),
      rotation: layer.rotation,
      output: size,
      transform: layer.transform,
      opacity: layer.opacity,
      isNaturalSize: layer.isNaturalSize,
    )
    encoder.setVertexBytes(&uniforms, length: MemoryLayout<FrameUniforms>.size, index: 0)
    encoder.setFragmentTexture(sourceTexture, index: 0)
    encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
  }

  /// Wraps a BGRA IOSurface as a Metal texture without copying.
  private func texture(for surface: IOSurface) throws(EngineError) -> any MTLTexture {
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: .bgra8Unorm,
      width: surface.width,
      height: surface.height,
      mipmapped: false,
    )
    descriptor.usage = [.shaderRead, .renderTarget]
    guard let texture = device.makeTexture(descriptor: descriptor, iosurface: surface, plane: 0)
    else {
      logger.error("frame.renderFailed reason=texture")
      throw .renderFailed
    }
    return texture
  }

}

// MARK: - RenderLayer

/// One source picture to draw, and how.
struct RenderLayer {
  let source: LayerPicture
  let rotation: CGAffineTransform
  let transform: ClipTransform
  let opacity: Double
  let depth: DepthSlot
  /// The layer's cut-out for this frame (upright), when it has one.
  let matte: LayerPicture?
  /// Drawn at its own pixel size (text) rather than fitted inside the frame.
  let isNaturalSize: Bool
}

// MARK: - LayerPicture

/// A layer's picture: a video frame for this moment, or a surface drawn earlier (text).
enum LayerPicture {
  case frame(CVPixelBuffer)
  case surface(IOSurface)
}
