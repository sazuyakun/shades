import CoreVideo
import Foundation
import IOSurface
import Metal
import ShadesCore
import Synchronization

// MARK: - MetalRenderer

/// Draws video frames as layers of one output frame on the GPU, without copying pixels through
/// the CPU: each graded, keyed and given its effects, blended by its mode, honouring depth slots
/// with the base clip's cut-out.
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
      blending: true,
    )
    replacingPipeline = try Self.makePipeline(
      device: device,
      library: library,
      fragment: "layerFragment",
      blending: false,
    )
    mattePipeline = try Self.makePipeline(
      device: device,
      library: library,
      fragment: "matteFragment",
      blending: false,
      format: .r8Unorm,
    )
    // why: in a 2×2×2 grid, red changes fastest, then green, then blue: each corner maps to itself.
    let identity: [Float] = (0 ..< 8).flatMap { (corner: Int) -> [Float] in
      let red = Float(corner & 1)
      let green = Float((corner >> 1) & 1)
      let blue = Float((corner >> 2) & 1)
      return [red, green, blue, 1]
    }
    defaults = try Mutex(DefaultTextures(
      lut: Self.makeLUT(device: device, size: 2, values: identity),
      curves: Self.makeCurves(device: device, curves: Curves()),
      blank: Self.makeBlank(device: device),
    ))
  }

  // MARK: Internal

  /// Draws `layers` (bottom to top) over black: each upright, fitted inside `output`, placed by
  /// its transform, graded and blended, in depth-slot order. `seed` changes each frame (grain).
  /// With no layers (a gap), the output is black.
  func draw(
    _ layers: [RenderLayer],
    into output: CVPixelBuffer,
    seed: Double = 0,
  ) throws(EngineError) {
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
    let backdrop = try layers.contains(where: \.needsBackdrop)
      ? makeBackdrop(like: outputTexture)
      : nil
    let blank = defaults.withLock { $0.blank }
    var encoder = try startPass(on: outputTexture, clearing: true, commands: commands)
    for step in order.steps {
      let index: Int
      let isMasked: Bool
      switch step {
      case .plain(let plain):
        index = plain
        isMasked = false

      case .cutOut(let masked),
           .masked(let masked):
        index = masked
        isMasked = mask != nil
      }
      let layer = layers[index]
      if layer.needsBackdrop, let backdrop {
        encoder.endEncoding()
        try copy(outputTexture, to: backdrop, commands: commands)
        encoder = try startPass(on: outputTexture, clearing: false, commands: commands)
      }
      encoder.setRenderPipelineState(layer.needsBackdrop ? replacingPipeline : pipeline)
      encoder.setFragmentTexture(isMasked ? mask : blank, index: 1)
      encoder.setFragmentTexture(backdrop ?? blank, index: 2)
      try encode(
        layer,
        size: outputSize,
        isMasked: isMasked,
        seed: seed,
        backdrop: backdrop,
        encoder: encoder,
      )
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

  /// LUTs and curves kept at most; a LUT is up to a few megabytes on the GPU.
  private static let lookCacheLimit = 16

  private let device: any MTLDevice
  private let queue: any MTLCommandQueue
  private let pipeline: any MTLRenderPipelineState
  private let replacingPipeline: any MTLRenderPipelineState
  private let mattePipeline: any MTLRenderPipelineState
  /// Textures bound when a layer has no LUT, curves, mask or backdrop. Held in a lock because
  /// Metal textures can't be shared freely between threads.
  private let defaults: Mutex<DefaultTextures>
  private let luts = Mutex<[URL: any MTLTexture]>([:])
  /// LUTs that couldn't be read, so they're tried (and logged) once, not every frame.
  private let unreadableLUTs = Mutex<Set<URL>>([])
  private let curves = Mutex<[Curves: any MTLTexture]>([:])

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

  /// A pipeline drawing with `fragment`: mixed over what's there by alpha (`blending`), or
  /// writing its result as is (blend modes and adjustments mix with the backdrop themselves).
  private static func makePipeline(
    device: any MTLDevice,
    library: any MTLLibrary,
    fragment: String,
    blending: Bool,
    format: MTLPixelFormat = .bgra8Unorm,
  ) throws(EngineError) -> any MTLRenderPipelineState {
    let descriptor = MTLRenderPipelineDescriptor()
    descriptor.vertexFunction = library.makeFunction(name: "layerVertex")
    descriptor.fragmentFunction = library.makeFunction(name: fragment)
    descriptor.colorAttachments[0].pixelFormat = format
    if blending {
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

  private static func makeLUT(
    device: any MTLDevice,
    size: Int,
    values: [Float],
  ) throws(EngineError) -> any MTLTexture {
    let descriptor = MTLTextureDescriptor()
    descriptor.textureType = .type3D
    descriptor.pixelFormat = .rgba32Float
    descriptor.width = size
    descriptor.height = size
    descriptor.depth = size
    descriptor.usage = .shaderRead
    guard let texture = device.makeTexture(descriptor: descriptor) else {
      logger.error("lut.failed reason=texture")
      throw .renderFailed
    }
    values.withUnsafeBytes { bytes in
      guard let base = bytes.baseAddress else {
        return
      }
      texture.replace(
        region: MTLRegionMake3D(0, 0, 0, size, size, size),
        mipmapLevel: 0,
        slice: 0,
        withBytes: base,
        bytesPerRow: size * 16,
        bytesPerImage: size * size * 16,
      )
    }
    return texture
  }

  /// The curves as a 256-wide strip: each channel's output for each input, master curve after.
  private static func makeCurves(
    device: any MTLDevice,
    curves: Curves,
  ) throws(EngineError) -> any MTLTexture {
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: .rgba8Unorm,
      width: 256,
      height: 1,
      mipmapped: false,
    )
    descriptor.usage = .shaderRead
    guard let texture = device.makeTexture(descriptor: descriptor) else {
      logger.error("curves.failed reason=texture")
      throw .renderFailed
    }
    var bytes = [UInt8]()
    for step in 0 ..< 256 {
      let input = Double(step) / 255
      for channel in [curves.red, curves.green, curves.blue] {
        let value = Curves.value(of: curves.master, at: Curves.value(of: channel, at: input))
        bytes.append(UInt8((min(max(value, 0), 1) * 255).rounded()))
      }
      bytes.append(255)
    }
    texture.replace(
      region: MTLRegionMake2D(0, 0, 256, 1),
      mipmapLevel: 0,
      withBytes: bytes,
      bytesPerRow: 256 * 4,
    )
    return texture
  }

  private static func makeBlank(device: any MTLDevice) throws(EngineError) -> any MTLTexture {
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: .bgra8Unorm,
      width: 1,
      height: 1,
      mipmapped: false,
    )
    descriptor.usage = .shaderRead
    guard let texture = device.makeTexture(descriptor: descriptor) else {
      logger.fault("metal.setupFailed reason=blank")
      throw .metalUnavailable
    }
    texture.replace(
      region: MTLRegionMake2D(0, 0, 1, 1),
      mipmapLevel: 0,
      withBytes: [UInt8](repeating: 0, count: 4),
      bytesPerRow: 4,
    )
    return texture
  }

  private func startPass(
    on output: any MTLTexture,
    clearing: Bool,
    commands: any MTLCommandBuffer,
  ) throws(EngineError) -> any MTLRenderCommandEncoder {
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = output
    pass.colorAttachments[0].loadAction = clearing ? .clear : .load
    pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
    pass.colorAttachments[0].storeAction = .store
    guard let encoder = commands.makeRenderCommandEncoder(descriptor: pass) else {
      logger.error("frame.renderFailed reason=encoder")
      throw .renderFailed
    }
    return encoder
  }

  /// A texture to hold the frame so far, for layers that mix with what's under them.
  private func makeBackdrop(like output: any MTLTexture) throws(EngineError) -> any MTLTexture {
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: output.pixelFormat,
      width: output.width,
      height: output.height,
      mipmapped: false,
    )
    descriptor.usage = .shaderRead
    descriptor.storageMode = .private
    guard let texture = device.makeTexture(descriptor: descriptor) else {
      logger.error("frame.renderFailed reason=backdrop")
      throw .renderFailed
    }
    return texture
  }

  private func copy(
    _ source: any MTLTexture,
    to destination: any MTLTexture,
    commands: any MTLCommandBuffer,
  ) throws(EngineError) {
    guard let blit = commands.makeBlitCommandEncoder() else {
      logger.error("frame.renderFailed reason=blit")
      throw .renderFailed
    }
    blit.copy(from: source, to: destination)
    blit.endEncoding()
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
    guard let mask = device.makeTexture(descriptor: descriptor) else {
      logger.error("frame.renderFailed reason=maskTexture")
      throw .renderFailed
    }
    let pass = MTLRenderPassDescriptor()
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
      camera: layer.camera,
      opacity: 1,
      depth: .inFront,
      matte: nil,
      isNaturalSize: false,
    )
    try placeQuad(matteLayer, size: size, encoder: encoder)
    encoder.endEncoding()
    return mask
  }

  private func encode(
    _ layer: RenderLayer,
    size: CGSize,
    isMasked: Bool,
    seed: Double,
    backdrop: (any MTLTexture)?,
    encoder: any MTLRenderCommandEncoder,
  ) throws(EngineError) {
    let lut = layer.grade?.lut.flatMap { lutTexture(at: URL(filePath: $0)) }
    let curveTexture = layer.grade?.curves.flatMap(curvesTexture)
    var look = LayerLook(
      size: size,
      grade: layer.grade,
      effects: layer.effects,
      blend: layer.blend,
      isMasked: isMasked,
      isAdjustment: layer.isAdjustment,
      hasLUT: lut != nil,
      hasCurves: curveTexture != nil,
      seed: seed,
    )
    let neutral = defaults.withLock { ($0.lut, $0.curves) }
    encoder.setFragmentTexture(lut ?? neutral.0, index: 3)
    encoder.setFragmentTexture(curveTexture ?? neutral.1, index: 4)
    encoder.setFragmentBytes(&look, length: MemoryLayout<LayerLook>.stride, index: 0)
    try placeQuad(layer, size: size, backdrop: backdrop, encoder: encoder)
  }

  /// Positions the layer's quad (its picture bound as texture 0) and draws it.
  private func placeQuad(
    _ layer: RenderLayer,
    size: CGSize,
    backdrop: (any MTLTexture)? = nil,
    encoder: any MTLRenderCommandEncoder,
  ) throws(EngineError) {
    let picture: any MTLTexture =
      switch layer.source {
      case .frame(let buffer): try texture(for: buffer)
      case .surface(let surface): try texture(for: surface)
      case .backdrop: backdrop ?? defaults.withLock { $0.blank }
      }
    var uniforms = FrameUniforms(
      stored: layer.isAdjustment ? size : CGSize(width: picture.width, height: picture.height),
      rotation: layer.rotation,
      output: size,
      transform: layer.transform,
      camera: layer.camera,
      opacity: layer.opacity,
      isNaturalSize: layer.isNaturalSize,
    )
    encoder.setVertexBytes(&uniforms, length: MemoryLayout<FrameUniforms>.stride, index: 0)
    encoder.setFragmentTexture(picture, index: 0)
    encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
  }

  /// The LUT at `url` on the GPU, read the first time it's used; `nil` if it can't be read.
  private func lutTexture(at url: URL) -> (any MTLTexture)? {
    if let cached = luts.withLock({ $0[url] }) {
      return cached
    }
    guard !unreadableLUTs.withLock({ $0.contains(url) }) else {
      return nil
    }
    guard let cube = CubeLUT(contentsOf: url) else {
      logger.error("lut.unreadable path=\(url.path, privacy: .private)")
      unreadableLUTs.withLock { _ = $0.insert(url) }
      return nil
    }
    let device = device
    luts.withLock { cache in
      if cache.count >= Self.lookCacheLimit {
        cache.removeAll()
      }
      // why: a LUT the GPU can't hold is drawn without, like an unreadable file (already logged).
      cache[url] = try? Self.makeLUT(device: device, size: cube.size, values: cube.values)
    }
    return luts.withLock { $0[url] }
  }

  private func curvesTexture(for curves: Curves) -> (any MTLTexture)? {
    if let cached = self.curves.withLock({ $0[curves] }) {
      return cached
    }
    let device = device
    self.curves.withLock { cache in
      if cache.count >= Self.lookCacheLimit {
        cache.removeAll()
      }
      // why: curves the GPU can't hold are drawn straight; makeCurves logs the failure.
      cache[curves] = try? Self.makeCurves(device: device, curves: curves)
    }
    return self.curves.withLock { $0[curves] }
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

  // MARK: Lifecycle

  init(
    source: LayerPicture,
    rotation: CGAffineTransform,
    transform: ClipTransform,
    camera: ClipTransform,
    opacity: Double,
    depth: DepthSlot,
    matte: LayerPicture?,
    isNaturalSize: Bool,
    grade: Grade? = nil,
    effects: Effects? = nil,
    blend: BlendMode = .normal,
  ) {
    self.source = source
    self.rotation = rotation
    self.transform = transform
    self.camera = camera
    self.opacity = opacity
    self.depth = depth
    self.matte = matte
    self.isNaturalSize = isNaturalSize
    self.grade = grade
    self.effects = effects
    self.blend = blend
  }

  // MARK: Internal

  let source: LayerPicture
  let rotation: CGAffineTransform
  let transform: ClipTransform
  /// The timeline camera's move this frame, or identity for layers that don't follow it.
  let camera: ClipTransform
  let opacity: Double
  let depth: DepthSlot
  /// The layer's cut-out for this frame (upright), when it has one.
  let matte: LayerPicture?
  /// Drawn at its own pixel size (text) rather than fitted inside the frame.
  let isNaturalSize: Bool
  let grade: Grade?
  let effects: Effects?
  let blend: BlendMode

  /// Whether this is an adjustment clip, working on the frame drawn so far.
  var isAdjustment: Bool {
    if case .backdrop = source {
      return true
    }
    return false
  }

  /// Whether drawing it needs the frame so far: its blend mode mixes with it, or it adjusts it.
  var needsBackdrop: Bool {
    blend != .normal || isAdjustment
  }

}

// MARK: - LayerPicture

/// A layer's picture: a video frame for this moment, a surface drawn earlier (text, stills,
/// drawings), or the frame drawn so far (adjustment clips).
enum LayerPicture {
  case frame(CVPixelBuffer)
  case surface(IOSurface)
  case backdrop
}

// MARK: - DefaultTextures

/// Textures that stand in when a layer has nothing of its own: a LUT that changes nothing,
/// straight curves, and a clear pixel.
private struct DefaultTextures {
  let lut: any MTLTexture
  let curves: any MTLTexture
  let blank: any MTLTexture
}
