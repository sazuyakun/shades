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
    layersSource = try Self.layersSource()
    let library = try Self.makeLibrary(device: device, source: layersSource)
    pipeline = try Self.makePipeline(
      device: device,
      library: library,
      fragment: "layerFragment",
      mixing: .over,
    )
    replacingPipeline = try Self.makePipeline(
      device: device,
      library: library,
      fragment: "layerFragment",
      mixing: .replace,
    )
    mattePipeline = try Self.makePipeline(
      device: device,
      library: library,
      fragment: "matteFragment",
      mixing: .replace,
      format: .r8Unorm,
    )
    samplePipeline = try Self.makePipeline(
      device: device,
      library: library,
      fragment: "sampleFragment",
      mixing: .add,
      format: Self.trailFormat,
    )
    trailPipeline = try Self.makePipeline(
      device: device,
      library: library,
      fragment: "trailFragment",
      mixing: .over,
    )
    replacingTrailPipeline = try Self.makePipeline(
      device: device,
      library: library,
      fragment: "trailFragment",
      mixing: .replace,
    )
    reachPipeline = try Self.makePipeline(
      device: device,
      library: library,
      fragment: "reachFragment",
      mixing: .replace,
      format: Self.travelFormat,
    )
    solidPipeline = try Self.makePipeline(
      device: device,
      library: library,
      vertex: "solidVertex",
      fragment: "solidFragment",
      mixing: .stack,
      format: Self.trailFormat,
    )
    addPipeline = try Self.makePipeline(
      device: device,
      library: library,
      fragment: "addFragment",
      mixing: .add,
      format: Self.trailFormat,
    )
    seedPipeline = try Self.makeKernel(device: device, library: library, named: "edgeSeeds")
    floodPipeline = try Self.makeKernel(device: device, library: library, named: "jumpFlood")
    fieldPipeline = try Self.makeKernel(device: device, library: library, named: "signedDistance")
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
  /// `scale` is how big `output` is next to the full-size picture (0.5 for a half-size preview),
  /// so blurs and glows cover the same part of it. With no layers (a gap), the output is black.
  func draw(
    _ layers: [RenderLayer],
    into output: CVPixelBuffer,
    seed: Double = 0,
    scale: Double = 1,
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
    let travels = try layers.map { layer throws(EngineError) in
      try layer.footageBlur.map { footage throws(EngineError) in
        try travel(of: footage, commands: commands)
      }
    }
    var mask: (any MTLTexture)?
    if let base = order.maskBase {
      mask = try drawMask(of: layers[base], size: outputSize, commands: commands)
    }
    let backdrop = try layers.contains(where: \.needsBackdrop)
      ? makeBackdrop(like: outputTexture)
      : nil
    let blank = defaults.withLock { $0.blank }
    // why: still solid titles are stacked before the frame's pass begins, each only over its
    // box, so that pass runs unbroken instead of storing and reloading the whole frame.
    var stacked = [Int: StackedSolid]()
    for (index, layer) in layers.enumerated() {
      guard let solid = layer.solid else {
        continue
      }
      let reach = (layer.effects?.blur ?? 0) * 24 / scale + 2
      if let box = screenBox(of: layer, solid, size: outputSize, reach: reach) {
        stacked[index] = try StackedSolid(
          texture: stackSolid(layer, solid, over: box, size: outputSize, commands: commands),
          box: box,
        )
      }
    }
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
      let effect = layer.effects?.shader.flatMap { effectPipelines(at: URL(filePath: $0)) }
      if let stack = stacked[index] {
        encoder.setRenderPipelineState(layer.needsBackdrop
          ? replacingTrailPipeline
          : trailPipeline)
        encoder.setFragmentTexture(isMasked ? mask : blank, index: 1)
        encoder.setFragmentTexture(backdrop ?? blank, index: 2)
        try drawTrail(
          stack.texture,
          of: layer,
          size: outputSize,
          box: stack.box,
          scale: scale,
          opacity: layer.opacity,
          // why: solid letters skip the layer shader, where other layers take their blur.
          blur: layer.effects?.blur ?? 0,
          isMasked: isMasked,
          encoder: encoder,
        )
        continue
      }
      if let solid = layer.solid {
        encoder.endEncoding()
        let trail = try keptTexture(.trail, like: outputTexture)
        try drawSolid(layer, solid, into: trail, commands: commands)
        encoder = try startPass(on: outputTexture, clearing: false, commands: commands)
        encoder.setRenderPipelineState(layer.needsBackdrop
          ? replacingTrailPipeline
          : trailPipeline)
        encoder.setFragmentTexture(isMasked ? mask : blank, index: 1)
        encoder.setFragmentTexture(backdrop ?? blank, index: 2)
        try drawTrail(
          trail,
          of: layer,
          size: outputSize,
          box: nil,
          scale: scale,
          opacity: layer.shutter.count > 1 ? 1 : layer.opacity,
          blur: layer.effects?.blur ?? 0,
          isMasked: isMasked,
          encoder: encoder,
        )
        continue
      }
      if layer.shutter.count > 1 {
        encoder.endEncoding()
        let trail = try keptTexture(.trail, like: outputTexture)
        try accumulate(
          layer,
          into: trail,
          sampling: effect?.sampling ?? samplePipeline,
          seed: seed,
          scale: scale,
          travel: travels[index],
          commands: commands,
        )
        encoder = try startPass(on: outputTexture, clearing: false, commands: commands)
        encoder.setRenderPipelineState(layer.needsBackdrop
          ? replacingTrailPipeline
          : trailPipeline)
        encoder.setFragmentTexture(isMasked ? mask : blank, index: 1)
        encoder.setFragmentTexture(backdrop ?? blank, index: 2)
        try drawTrail(
          trail,
          of: layer,
          size: outputSize,
          box: nil,
          scale: scale,
          opacity: 1,
          blur: 0,
          isMasked: isMasked,
          encoder: encoder,
        )
        continue
      }
      encoder.setRenderPipelineState(layer.needsBackdrop
        ? effect?.replacing ?? replacingPipeline
        : effect?.blending ?? pipeline)
      encoder.setFragmentTexture(isMasked ? mask : blank, index: 1)
      encoder.setFragmentTexture(backdrop ?? blank, index: 2)
      try encode(
        layer,
        size: outputSize,
        scale: scale,
        isMasked: isMasked,
        seed: seed,
        backdrop: backdrop,
        travel: travels[index],
        encoder: encoder,
      )
    }
    encoder.endEncoding()
    commands.commit()
    commands.waitUntilCompleted()
  }

  /// Why the shader effect at `url` can't be used (its compiler errors, or that it can't be
  /// read), or `nil` when it compiles.
  func shaderProblem(at url: URL) -> String? {
    _ = effectPipelines(at: url)
    return effectProblems.withLock { $0[FileVersion(url)] }
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

  /// Half floats, so dozens of faint moments add up without banding.
  private static let trailFormat = MTLPixelFormat.rgba16Float

  /// Two half floats: how far footage travels across and down, in uv.
  private static let travelFormat = MTLPixelFormat.rg16Float

  /// The fragment that runs a plugin's or Claude's `effect` function between shading and
  /// compositing a layer (its signature is in docs/SYSTEM.md, Plugins).
  private static let effectWrapper = """

    fragment float4 effectFragment(
      VertexOut in [[stage_in]],
      texture2d<half> source [[texture(0)]],
      texture2d<half> mask [[texture(1)]],
      texture2d<half> backdrop [[texture(2)]],
      texture3d<float> lut [[texture(3)]],
      texture2d<float> curves [[texture(4)]],
      texture2d<float> travel [[texture(5)]],
      constant LayerLook &look [[buffer(0)]],
      constant LayerMaskShape *masks [[buffer(1)]],
      constant float2 *points [[buffer(2)]]
    ) {
      constexpr sampler linearSampler(filter::linear, address::clamp_to_edge);
      float2 uv = look.isAdjustment != 0 ? in.screen : in.uv;
      texture2d<half> picture = look.isAdjustment != 0 ? backdrop : source;
      float4 shaded = shade(
        in, picture, travel, uv, lut, curves, look, masks, points, linearSampler
      );
      float4 changed = effect(
        shaded, uv, look.effectTime, look.effectAmount, picture, linearSampler
      );
      return composite(changed, in, mask, backdrop, look, linearSampler);
    }

    fragment float4 effectSampleFragment(
      VertexOut in [[stage_in]],
      texture2d<half> source [[texture(0)]],
      texture3d<float> lut [[texture(3)]],
      texture2d<float> curves [[texture(4)]],
      texture2d<float> travel [[texture(5)]],
      constant LayerLook &look [[buffer(0)]],
      constant LayerMaskShape *masks [[buffer(1)]],
      constant float2 *points [[buffer(2)]]
    ) {
      constexpr sampler linearSampler(filter::linear, address::clamp_to_edge);
      float4 shaded = shade(
        in, source, travel, in.uv, lut, curves, look, masks, points, linearSampler
      );
      float4 changed = effect(
        shaded, in.uv, look.effectTime, look.effectAmount, source, linearSampler
      );
      return weighted(changed, in);
    }
    """

  private let layersSource: String
  private let device: any MTLDevice
  private let queue: any MTLCommandQueue
  private let pipeline: any MTLRenderPipelineState
  private let replacingPipeline: any MTLRenderPipelineState
  private let mattePipeline: any MTLRenderPipelineState
  /// Adds one moment of a moving layer into its trail.
  private let samplePipeline: any MTLRenderPipelineState
  /// Draws a moving layer's averaged trail over the frame, or in place (blend modes).
  private let trailPipeline: any MTLRenderPipelineState
  private let replacingTrailPipeline: any MTLRenderPipelineState
  /// Works out, from a flow frame, how far the footage smearing onto each point travels.
  private let reachPipeline: any MTLRenderPipelineState
  /// Stacks the slices of solid 3D letters, back to front.
  private let solidPipeline: any MTLRenderPipelineState
  /// Adds one moment of a moving solid layer into its trail.
  private let addPipeline: any MTLRenderPipelineState
  /// Find solid letters' distance field: marks their edge, spreads it, measures to it.
  private let seedPipeline: any MTLComputePipelineState
  private let floodPipeline: any MTLComputePipelineState
  private let fieldPipeline: any MTLComputePipelineState
  /// The buffer moving layers' moments are summed in, kept between frames: at full size it's
  /// tens of megabytes. Frames are drawn in order on one queue, so sharing it is safe.
  private let kept = Mutex<[KeptTexture: any MTLTexture]>([:])
  /// Textures bound when a layer has no LUT, curves, mask or backdrop. Held in a lock because
  /// Metal textures can't be shared freely between threads.
  private let defaults: Mutex<DefaultTextures>
  private let luts = Mutex<[FileVersion: any MTLTexture]>([:])
  /// LUTs that couldn't be read, so they're tried (and logged) once, not every frame.
  private let unreadableLUTs = Mutex<Set<FileVersion>>([])
  private let curves = Mutex<[Curves: any MTLTexture]>([:])
  /// Compiled shader effects by file, and why the ones that failed didn't compile.
  private let effects = Mutex<[FileVersion: EffectPipelines]>([:])
  private let effectProblems = Mutex<[FileVersion: String]>([:])

  private static func layersSource() throws(EngineError) -> String {
    guard
      let url = Bundle.module.url(
        forResource: "Layers",
        withExtension: "metal",
        subdirectory: "Shaders",
      ),
      let source = try? String(contentsOf: url, encoding: .utf8)
    else {
      logger.fault("metal.setupFailed reason=shaderMissing")
      throw .metalUnavailable
    }
    return source
  }

  private static func makeLibrary(
    device: any MTLDevice,
    source: String,
  ) throws(EngineError) -> any MTLLibrary {
    do {
      return try device.makeLibrary(source: source, options: nil)
    } catch {
      logger.fault("metal.setupFailed reason=shaderCompile")
      throw .metalUnavailable
    }
  }

  /// A compute pipeline running the kernel `name`.
  private static func makeKernel(
    device: any MTLDevice,
    library: any MTLLibrary,
    named name: String,
  ) throws(EngineError) -> any MTLComputePipelineState {
    guard let function = library.makeFunction(name: name) else {
      logger.fault("metal.setupFailed reason=kernelMissing kernel=\(name, privacy: .public)")
      throw .metalUnavailable
    }
    do {
      return try device.makeComputePipelineState(function: function)
    } catch {
      logger.fault("metal.setupFailed reason=kernel kernel=\(name, privacy: .public)")
      throw .metalUnavailable
    }
  }

  /// A pipeline drawing with `fragment` into `format`, its result mixed with what's there by
  /// `mixing`.
  private static func makePipeline(
    device: any MTLDevice,
    library: any MTLLibrary,
    vertex: String = "layerVertex",
    fragment: String,
    mixing: Mixing,
    format: MTLPixelFormat = .bgra8Unorm,
  ) throws(EngineError) -> any MTLRenderPipelineState {
    let descriptor = MTLRenderPipelineDescriptor()
    descriptor.vertexFunction = library.makeFunction(name: vertex)
    descriptor.fragmentFunction = library.makeFunction(name: fragment)
    let attachment = descriptor.colorAttachments[0]
    attachment?.pixelFormat = format
    switch mixing {
    case .over:
      attachment?.isBlendingEnabled = true
      attachment?.sourceRGBBlendFactor = .sourceAlpha
      attachment?.destinationRGBBlendFactor = .oneMinusSourceAlpha
      attachment?.sourceAlphaBlendFactor = .one
      attachment?.destinationAlphaBlendFactor = .oneMinusSourceAlpha

    case .stack:
      attachment?.isBlendingEnabled = true
      attachment?.sourceRGBBlendFactor = .one
      attachment?.destinationRGBBlendFactor = .oneMinusSourceAlpha
      attachment?.sourceAlphaBlendFactor = .one
      attachment?.destinationAlphaBlendFactor = .oneMinusSourceAlpha

    case .add:
      attachment?.isBlendingEnabled = true
      attachment?.sourceRGBBlendFactor = .one
      attachment?.destinationRGBBlendFactor = .one
      attachment?.sourceAlphaBlendFactor = .one
      attachment?.destinationAlphaBlendFactor = .one

    case .replace:
      break
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

  /// Starts drawing into `output`: over what's there, or over `clearing` to black (or `clear`,
  /// see-through).
  private func startPass(
    on output: any MTLTexture,
    clearing: Bool,
    toClear clear: Bool = false,
    commands: any MTLCommandBuffer,
  ) throws(EngineError) -> any MTLRenderCommandEncoder {
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = output
    pass.colorAttachments[0].loadAction = clearing ? .clear : .load
    pass.colorAttachments[0].clearColor = MTLClearColor(
      red: 0,
      green: 0,
      blue: 0,
      alpha: clear ? 0 : 1,
    )
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

  /// How far the footage smearing onto each point of a footage-blurred layer travels while the
  /// shutter is open, worked out from its flow frame at the flow's own (small) size.
  private func travel(
    of footage: FootageBlur,
    commands: any MTLCommandBuffer,
  ) throws(EngineError) -> any MTLTexture {
    let flow = try texture(for: footage.flow)
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: Self.travelFormat,
      width: flow.width,
      height: flow.height,
      mipmapped: false,
    )
    descriptor.usage = [.renderTarget, .shaderRead]
    descriptor.storageMode = .private
    guard let travel = device.makeTexture(descriptor: descriptor) else {
      logger.error("frame.renderFailed reason=travel")
      throw .renderFailed
    }
    let size = CGSize(width: flow.width, height: flow.height)
    var look = LayerLook(
      size: size,
      grade: nil,
      effects: nil,
      crop: .none,
      maskCount: 0,
      blend: .normal,
      isMasked: false,
      isAdjustment: false,
      hasLUT: false,
      hasCurves: false,
      seed: 0,
      transition: nil,
      clipTime: 0,
      footage: footage,
    )
    var uniforms = FrameUniforms(stored: size, rotation: .identity, output: size)
    let encoder = try startPass(on: travel, clearing: true, toClear: true, commands: commands)
    encoder.setRenderPipelineState(reachPipeline)
    encoder.setVertexBytes(&uniforms, length: MemoryLayout<FrameUniforms>.stride, index: 0)
    encoder.setFragmentBytes(&look, length: MemoryLayout<LayerLook>.stride, index: 0)
    encoder.setFragmentTexture(flow, index: 0)
    encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    encoder.endEncoding()
    return travel
  }

  /// A frame-sized half-float buffer kept for `purpose` between frames, made again only when the
  /// frame size changes.
  private func keptTexture(
    _ purpose: KeptTexture,
    like output: any MTLTexture,
  ) throws(EngineError) -> any MTLTexture {
    let device = device
    // why: solid letters' sides are soft shading, drawn at half size (a quarter of the work).
    let divisor = purpose == .solidSides ? 2 : 1
    let width = max(output.width / divisor, 1)
    let height = max(output.height / divisor, 1)
    let texture = kept.withLock { kept -> (any MTLTexture)? in
      if let current = kept[purpose], current.width == width, current.height == height {
        return current
      }
      let descriptor = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: Self.trailFormat,
        width: width,
        height: height,
        mipmapped: false,
      )
      descriptor.usage = [.renderTarget, .shaderRead]
      descriptor.storageMode = .private
      kept[purpose] = device.makeTexture(descriptor: descriptor)
      return kept[purpose]
    }
    guard let texture else {
      logger.error("frame.renderFailed reason=keptTexture")
      throw .renderFailed
    }
    return texture
  }

  /// Draws `layer`'s solid letters into `target`, a frame-sized buffer (cleared first,
  /// premultiplied): where the layer is, or averaged over its moments inside the shutter when it
  /// moves.
  private func drawSolid(
    _ layer: RenderLayer,
    _ solid: SolidText,
    into target: any MTLTexture,
    commands: any MTLCommandBuffer,
  ) throws(EngineError) {
    guard case .surface(let surface) = layer.source else {
      logger.fault("frame.invariantBroken reason=solidWithoutText")
      assertionFailure("only text is drawn solid")
      return
    }
    let size = CGSize(width: target.width, height: target.height)
    let picture = try texture(for: surface)
    let field = try distanceField(of: picture, reach: solid.bevel + 4, commands: commands)
    let sides = try keptTexture(.solidSides, like: target)
    guard layer.shutter.count > 1 else {
      try stack(
        layer,
        solid,
        picture: picture,
        field: field,
        at: LayerPose(transform: layer.transform, camera: layer.camera),
        size: size,
        box: nil,
        sides: sides,
        into: target,
        commands: commands,
      )
      return
    }
    let moment = try keptTexture(.solidMoment, like: target)
    try startPass(on: target, clearing: true, toClear: true, commands: commands).endEncoding()
    var uniforms = FrameUniforms(
      stored: size,
      rotation: .identity,
      output: size,
      opacity: layer.opacity / Double(layer.shutter.count),
    )
    for pose in layer.shutter {
      // why: text travelling its path is a new picture each moment, with its own field.
      var posed = (picture: picture, field: field)
      if case .surface(let surface) = pose.picture {
        let moved = try texture(for: surface)
        posed = try (moved, distanceField(of: moved, reach: solid.bevel + 4, commands: commands))
      }
      try stack(
        layer,
        solid,
        picture: posed.picture,
        field: posed.field,
        at: pose,
        size: size,
        box: nil,
        sides: sides,
        into: moment,
        commands: commands,
      )
      let adding = try startPass(on: target, clearing: false, commands: commands)
      adding.setRenderPipelineState(addPipeline)
      adding.setVertexBytes(&uniforms, length: MemoryLayout<FrameUniforms>.stride, index: 0)
      adding.setFragmentTexture(moment, index: 0)
      adding.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: uniforms.vertexCount)
      adding.endEncoding()
    }
  }

  /// `layer`'s solid letters stacked into a buffer covering just `box` of a `size` frame, where
  /// they land.
  private func stackSolid(
    _ layer: RenderLayer,
    _ solid: SolidText,
    over box: CGRect,
    size: CGSize,
    commands: any MTLCommandBuffer,
  ) throws(EngineError) -> any MTLTexture {
    guard case .surface(let surface) = layer.source else {
      logger.fault("frame.invariantBroken reason=solidWithoutText")
      assertionFailure("only text is drawn solid")
      throw .renderFailed
    }
    let picture = try texture(for: surface)
    let target = try scratchTexture(width: Int(box.width), height: Int(box.height))
    try stack(
      layer,
      solid,
      picture: picture,
      field: distanceField(of: picture, reach: solid.bevel + 4, commands: commands),
      at: LayerPose(transform: layer.transform, camera: layer.camera),
      size: size,
      box: box,
      sides: scratchTexture(width: (target.width + 1) / 2, height: (target.height + 1) / 2),
      into: target,
      commands: commands,
    )
    return target
  }

  /// A half-float buffer for one frame's drawing.
  private func scratchTexture(width: Int, height: Int) throws(EngineError) -> any MTLTexture {
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: Self.trailFormat,
      width: max(width, 1),
      height: max(height, 1),
      mipmapped: false,
    )
    descriptor.usage = [.renderTarget, .shaderRead]
    descriptor.storageMode = .private
    guard let texture = device.makeTexture(descriptor: descriptor) else {
      logger.error("frame.renderFailed reason=scratchTexture")
      throw .renderFailed
    }
    return texture
  }

  /// Stacks `layer`'s solid letters, placed at `pose` in a `size` frame, into `target` (cleared
  /// first; covering just `box` of the frame when given): every slice but the last drawn into
  /// `sides`, at half size, then the face in view over them at full size.
  private func stack(
    _ layer: RenderLayer,
    _ solid: SolidText,
    picture: any MTLTexture,
    field: any MTLTexture,
    at pose: LayerPose,
    size: CGSize,
    box: CGRect?,
    sides: any MTLTexture,
    into target: any MTLTexture,
    commands: any MTLCommandBuffer,
  ) throws(EngineError) {
    let behind = try startPass(on: sides, clearing: true, toClear: true, commands: commands)
    try encodeSolid(
      layer,
      solid,
      picture: picture,
      field: field,
      at: pose,
      size: size,
      box: box,
      part: .sides,
      encoder: behind,
    )
    behind.endEncoding()
    let encoder = try startPass(on: target, clearing: true, toClear: true, commands: commands)
    let covered = CGSize(width: target.width, height: target.height)
    var whole = FrameUniforms(stored: covered, rotation: .identity, output: covered)
    encoder.setRenderPipelineState(addPipeline)
    encoder.setVertexBytes(&whole, length: MemoryLayout<FrameUniforms>.stride, index: 0)
    encoder.setFragmentTexture(sides, index: 0)
    encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: whole.vertexCount)
    try encodeSolid(
      layer,
      solid,
      picture: picture,
      field: field,
      at: pose,
      size: size,
      box: box,
      part: .face,
      encoder: encoder,
    )
    encoder.endEncoding()
  }

  /// The part of a `size` frame a still, flat-cut solid layer can cover, `reach` pixels round its
  /// letters' corners front and back (whole pixels), so it's drawn there alone; `nil` when its
  /// corners don't bound it (a bend, motion blur) or it's off the frame.
  private func screenBox(
    of layer: RenderLayer,
    _ solid: SolidText,
    size: CGSize,
    reach: Double,
  ) -> CGRect? {
    guard
      layer.shutter.count < 2, layer.transform.bend == 0,
      case .surface(let surface) = layer.source
    else {
      return nil
    }
    let corners = SolidUniforms.screenCorners(
      solid,
      picture: CGSize(width: surface.width, height: surface.height),
      transform: layer.transform,
      camera: layer.camera,
      output: size,
    )
    let points = corners.front + corners.back
    let xs = points.map { Double($0.x) + size.width / 2 }
    let ys = points.map { size.height / 2 - Double($0.y) }
    let left = max(Int(((xs.min() ?? 0) - reach).rounded(.down)), 0)
    let top = max(Int(((ys.min() ?? 0) - reach).rounded(.down)), 0)
    let right = min(Int(((xs.max() ?? 0) + reach).rounded(.up)), Int(size.width))
    let bottom = min(Int(((ys.max() ?? 0) + reach).rounded(.up)), Int(size.height))
    guard right > left, bottom > top else {
      return nil
    }
    return CGRect(x: left, y: top, width: right - left, height: bottom - top)
  }

  /// The signed distance, in pixels, from each pixel of `picture` to the edge of its ink (positive
  /// inside), out to `reach` pixels: jump flooding on the GPU, in a few passes over the picture.
  private func distanceField(
    of picture: any MTLTexture,
    reach: Double,
    commands: any MTLCommandBuffer,
  ) throws(EngineError) -> any MTLTexture {
    let made = { (format: MTLPixelFormat) throws(EngineError) -> any MTLTexture in
      let descriptor = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: format,
        width: picture.width,
        height: picture.height,
        mipmapped: false,
      )
      descriptor.usage = [.shaderRead, .shaderWrite]
      descriptor.storageMode = .private
      guard let texture = self.device.makeTexture(descriptor: descriptor) else {
        logger.error("frame.renderFailed reason=distanceField")
        throw .renderFailed
      }
      return texture
    }
    var seeds = try made(.rg16Uint)
    var spread = try made(.rg16Uint)
    let field = try made(.r16Float)
    guard let encoder = commands.makeComputeCommandEncoder() else {
      logger.error("frame.renderFailed reason=computeEncoder")
      throw .renderFailed
    }
    let grid = MTLSize(width: picture.width, height: picture.height, depth: 1)
    let group = MTLSize(width: 16, height: 16, depth: 1)
    encoder.setComputePipelineState(seedPipeline)
    encoder.setTexture(picture, index: 0)
    encoder.setTexture(seeds, index: 1)
    encoder.dispatchThreads(grid, threadsPerThreadgroup: group)
    // why: seeds further than `reach` don't matter, so the jumps start just past it.
    var step = Int32(1) << Int32(ceil(log2(max(reach, 1))))
    encoder.setComputePipelineState(floodPipeline)
    while step >= 1 {
      encoder.setTexture(seeds, index: 0)
      encoder.setTexture(spread, index: 1)
      encoder.setBytes(&step, length: MemoryLayout<Int32>.stride, index: 0)
      encoder.dispatchThreads(grid, threadsPerThreadgroup: group)
      swap(&seeds, &spread)
      step /= 2
    }
    var limit = Float(reach)
    encoder.setComputePipelineState(fieldPipeline)
    encoder.setTexture(picture, index: 0)
    encoder.setTexture(seeds, index: 1)
    encoder.setTexture(field, index: 2)
    encoder.setBytes(&limit, length: MemoryLayout<Float>.stride, index: 0)
    encoder.dispatchThreads(grid, threadsPerThreadgroup: group)
    encoder.endEncoding()
    return field
  }

  /// Draws `part` of the slices of `layer`'s solid letters, from `picture` with its distance
  /// `field`, placed at `pose` in a `size` frame (just its `box` filling the target, when given),
  /// from the back forward.
  private func encodeSolid(
    _ layer: RenderLayer,
    _ solid: SolidText,
    picture: any MTLTexture,
    field: any MTLTexture,
    at pose: LayerPose,
    size: CGSize,
    box: CGRect?,
    part: SolidPart,
    encoder: any MTLRenderCommandEncoder,
  ) throws(EngineError) {
    var uniforms = FrameUniforms(
      stored: CGSize(width: picture.width, height: picture.height),
      rotation: .identity,
      output: size,
      transform: pose.transform,
      camera: pose.camera,
      isNaturalSize: true,
      box: box,
    )
    var shape = SolidUniforms(
      solid,
      picture: CGSize(width: picture.width, height: picture.height),
      transform: pose.transform,
      camera: pose.camera,
      output: size,
    )
    let masks = LayerMaskShape.shapes(of: layer.masks)
    var look = LayerLook(
      size: size,
      grade: nil,
      effects: nil,
      crop: layer.crop,
      maskCount: masks.shapes.count,
      blend: .normal,
      isMasked: false,
      isAdjustment: false,
      hasLUT: false,
      hasCurves: false,
      seed: 0,
      transition: nil,
      clipTime: 0,
    )
    encoder.setRenderPipelineState(solidPipeline)
    encoder.setVertexBytes(&uniforms, length: MemoryLayout<FrameUniforms>.stride, index: 0)
    encoder.setVertexBytes(&shape, length: MemoryLayout<SolidUniforms>.stride, index: 1)
    encoder.setFragmentBytes(&look, length: MemoryLayout<LayerLook>.stride, index: 0)
    try encoder.setFragmentBuffer(buffer(of: masks.shapes), offset: 0, index: 1)
    try encoder.setFragmentBuffer(buffer(of: masks.points), offset: 0, index: 2)
    encoder.setFragmentBytes(&shape, length: MemoryLayout<SolidUniforms>.stride, index: 3)
    encoder.setFragmentTexture(picture, index: 0)
    encoder.setFragmentTexture(field, index: 5)
    let last = Int(shape.slices) - 1
    let instances = part == .sides ? 0 ..< last : last ..< last + 1
    guard !instances.isEmpty else {
      return
    }
    encoder.drawPrimitives(
      type: .triangleStrip,
      vertexStart: 0,
      vertexCount: uniforms.vertexCount,
      instanceCount: instances.count,
      baseInstance: instances.lowerBound,
    )
  }

  /// Sums the moving layer's moments inside the shutter into `trail`, each weighted equally,
  /// premultiplied: the layer's motion blur before it's masked, wiped and mixed.
  private func accumulate(
    _ layer: RenderLayer,
    into trail: any MTLTexture,
    sampling: any MTLRenderPipelineState,
    seed: Double,
    scale: Double,
    travel: (any MTLTexture)?,
    commands: any MTLCommandBuffer,
  ) throws(EngineError) {
    let encoder = try startPass(on: trail, clearing: true, toClear: true, commands: commands)
    encoder.setRenderPipelineState(sampling)
    let size = CGSize(width: trail.width, height: trail.height)
    let weight = layer.opacity / Double(layer.shutter.count)
    for pose in layer.shutter {
      var effects = layer.effects
      if let travel = pose.portalTravel {
        effects?.portal?.travel = travel
      }
      let moment = RenderLayer(
        source: pose.picture ?? layer.source,
        rotation: layer.rotation,
        transform: pose.transform,
        camera: pose.camera,
        opacity: weight,
        depth: layer.depth,
        matte: nil,
        isNaturalSize: layer.isNaturalSize,
        grade: layer.grade,
        effects: effects,
        crop: layer.crop,
        masks: layer.masks,
        transition: layer.transition,
        clipTime: layer.clipTime,
        footageBlur: layer.footageBlur,
      )
      try encode(
        moment,
        size: size,
        scale: scale,
        isMasked: false,
        seed: seed,
        backdrop: nil,
        travel: travel,
        encoder: encoder,
      )
    }
    encoder.endEncoding()
  }

  /// Draws a moving layer's summed `trail` (or a solid layer's stacked slices) over the whole
  /// frame, or over `box` when it covers only that, softened by `blur`, then masks, wipes, dips
  /// and mixes it like a still layer.
  private func drawTrail(
    _ trail: any MTLTexture,
    of layer: RenderLayer,
    size: CGSize,
    box: CGRect?,
    scale: Double,
    opacity: Double,
    blur: Double,
    isMasked: Bool,
    encoder: any MTLRenderCommandEncoder,
  ) throws(EngineError) {
    let covered = box?.size ?? size
    var look = LayerLook(
      size: CGSize(width: covered.width / scale, height: covered.height / scale),
      grade: nil,
      effects: blur > 0 ? Effects(blur: blur) : nil,
      crop: .none,
      maskCount: 0,
      blend: layer.blend,
      isMasked: isMasked,
      isAdjustment: false,
      hasLUT: false,
      hasCurves: false,
      seed: 0,
      transition: layer.transition,
      clipTime: layer.clipTime,
    )
    // why: a trail over only `box` is drawn as a picture of its own size placed on the box.
    var uniforms = FrameUniforms(
      stored: covered,
      rotation: .identity,
      output: size,
      transform: ClipTransform(
        x: box.map { ($0.midX - size.width / 2) / size.width } ?? 0,
        y: box.map { ($0.midY - size.height / 2) / size.height } ?? 0,
      ),
      opacity: opacity,
      isNaturalSize: true,
    )
    encoder.setVertexBytes(&uniforms, length: MemoryLayout<FrameUniforms>.stride, index: 0)
    encoder.setFragmentBytes(&look, length: MemoryLayout<LayerLook>.stride, index: 0)
    encoder.setFragmentTexture(trail, index: 0)
    encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: uniforms.vertexCount)
  }

  /// Draws the base layer's cut-out, placed like the layer and its edge refined, into a half-size
  /// mask of the frame.
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
    let edge = layer.cutoutEdge
    var refinement = SIMD4(Float(edge.feather), Float(edge.choke), Float(edge.smoothing), 0)
    encoder.setFragmentBytes(&refinement, length: MemoryLayout<SIMD4<Float>>.stride, index: 0)
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

  /// Draws `layer` into a `size` frame that's `scale` times the full-size picture.
  private func encode(
    _ layer: RenderLayer,
    size: CGSize,
    scale: Double,
    isMasked: Bool,
    seed: Double,
    backdrop: (any MTLTexture)?,
    travel: (any MTLTexture)?,
    encoder: any MTLRenderCommandEncoder,
  ) throws(EngineError) {
    let lut = layer.grade?.lut.flatMap { lutTexture(at: URL(filePath: $0)) }
    let curveTexture = layer.grade?.curves.flatMap(curvesTexture)
    let masks = LayerMaskShape.shapes(of: layer.masks)
    var look = LayerLook(
      size: CGSize(width: size.width / scale, height: size.height / scale),
      grade: layer.grade,
      effects: layer.effects,
      crop: layer.crop,
      maskCount: masks.shapes.count,
      blend: layer.blend,
      isMasked: isMasked,
      isAdjustment: layer.isAdjustment,
      hasLUT: lut != nil,
      hasCurves: curveTexture != nil,
      seed: seed,
      transition: layer.transition,
      clipTime: layer.clipTime,
      footage: layer.footageBlur,
    )
    if case .frame(let frame) = layer.source {
      let color = SourceColor(of: frame)
      look.transfer = color.transfer.rawValue
      look.primaries = color.primaries.rawValue
    }
    let neutral = defaults.withLock { ($0.lut, $0.curves, $0.blank) }
    encoder.setFragmentTexture(lut ?? neutral.0, index: 3)
    encoder.setFragmentTexture(curveTexture ?? neutral.1, index: 4)
    encoder.setFragmentTexture(travel ?? neutral.2, index: 5)
    encoder.setFragmentBytes(&look, length: MemoryLayout<LayerLook>.stride, index: 0)
    try encoder.setFragmentBuffer(buffer(of: masks.shapes), offset: 0, index: 1)
    try encoder.setFragmentBuffer(buffer(of: masks.points), offset: 0, index: 2)
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
    encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: uniforms.vertexCount)
  }

  /// `values` in a GPU buffer, which holds at least one (blank) value so it can always be bound.
  private func buffer<Value>(of values: [Value]) throws(EngineError) -> any MTLBuffer {
    let length = max(values.count, 1) * MemoryLayout<Value>.stride
    guard let buffer = device.makeBuffer(length: length, options: .storageModeShared) else {
      logger.error("frame.renderFailed reason=buffer")
      throw .renderFailed
    }
    values.withUnsafeBytes { bytes in
      if let base = bytes.baseAddress {
        buffer.contents().copyMemory(from: base, byteCount: bytes.count)
      }
    }
    return buffer
  }

  /// The LUT at `url` on the GPU, read the first time it's used and again after the file
  /// changes; `nil` if it can't be read.
  private func lutTexture(at url: URL) -> (any MTLTexture)? {
    let file = FileVersion(url)
    if let cached = luts.withLock({ $0[file] }) {
      return cached
    }
    guard !unreadableLUTs.withLock({ $0.contains(file) }) else {
      return nil
    }
    guard let cube = CubeLUT(contentsOf: url) else {
      logger.error("lut.unreadable path=\(url.path, privacy: .private)")
      unreadableLUTs.withLock { _ = $0.insert(file) }
      return nil
    }
    let device = device
    luts.withLock { cache in
      if cache.count >= Self.lookCacheLimit {
        cache.removeAll()
      }
      // why: a LUT the GPU can't hold is drawn without, like an unreadable file (already logged).
      cache[file] = try? Self.makeLUT(device: device, size: cube.size, values: cube.values)
    }
    return luts.withLock { $0[file] }
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

  /// The pipelines for the shader effect at `url`, compiled the first time; `nil` when it
  /// doesn't compile (the reason is kept for `shaderProblem`).
  private func effectPipelines(at url: URL) -> EffectPipelines? {
    let file = FileVersion(url)
    if let compiled = effects.withLock({ $0[file] }) {
      return compiled
    }
    guard effectProblems.withLock({ $0[file] }) == nil else {
      return nil
    }
    // why: an unreadable file is reported to whoever set the effect, like a compile error.
    guard let effect = try? String(contentsOf: url, encoding: .utf8) else {
      effectProblems.withLock { $0[file] = "the shader file can't be read" }
      return nil
    }
    do {
      let library = try device.makeLibrary(
        source: layersSource + "\n" + effect + "\n" + Self.effectWrapper,
        options: nil,
      )
      let pipelines = try EffectPipelines(
        blending: Self.makePipeline(
          device: device,
          library: library,
          fragment: "effectFragment",
          mixing: .over,
        ),
        replacing: Self.makePipeline(
          device: device,
          library: library,
          fragment: "effectFragment",
          mixing: .replace,
        ),
        sampling: Self.makePipeline(
          device: device,
          library: library,
          fragment: "effectSampleFragment",
          mixing: .add,
          format: Self.trailFormat,
        ),
      )
      effects.withLock { $0[file] = pipelines }
      return pipelines
    } catch {
      logger.error("effect.compileFailed path=\(url.path, privacy: .private)")
      effectProblems.withLock { $0[file] = error.localizedDescription }
      return nil
    }
  }

  /// Wraps an IOSurface (BGRA unless `format` says otherwise) as a Metal texture without copying.
  private func texture(
    for surface: IOSurface,
    format: MTLPixelFormat = .bgra8Unorm,
  ) throws(EngineError) -> any MTLTexture {
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: format,
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
    crop: Crop = .none,
    masks: [LayerMask] = [],
    cutoutEdge: CutoutEdge = .none,
    blend: BlendMode = .normal,
    transition: TransitionStyle? = nil,
    clipTime: Double = 0,
    shutter: [LayerPose] = [],
    footageBlur: FootageBlur? = nil,
    solid: SolidText? = nil,
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
    self.crop = crop
    self.masks = masks
    self.cutoutEdge = cutoutEdge
    self.blend = blend
    self.transition = transition
    self.clipTime = clipTime
    self.shutter = shutter
    self.footageBlur = footageBlur
    self.solid = solid
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
  /// What's cut off the edges of its upright picture.
  let crop: Crop
  /// Shapes hiding or revealing parts of its picture, placed for this frame.
  let masks: [LayerMask]
  /// How its cut-out's edge is refined.
  let cutoutEdge: CutoutEdge
  let blend: BlendMode
  /// How a transition it's part of shapes it this frame.
  let transition: TransitionStyle?
  /// Seconds into the clip, for shader effects that move.
  let clipTime: Double
  /// Where it is at the moments the shutter is open, when it moves enough to blur; drawn once
  /// at `transform` otherwise.
  let shutter: [LayerPose]
  /// How its footage smears along its own motion, when it's switched on and the flow is made.
  let footageBlur: FootageBlur?
  /// Drawn as solid 3D letters (extruded text), when it is.
  let solid: SolidText?

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

// MARK: - EffectPipelines

/// A shader effect compiled three ways: mixed over by alpha, written as is, or added into a
/// moving layer's trail.
private struct EffectPipelines {
  let blending: any MTLRenderPipelineState
  let replacing: any MTLRenderPipelineState
  let sampling: any MTLRenderPipelineState
}

// MARK: - Mixing

/// How a pipeline's result meets what's already drawn.
private enum Mixing {
  /// Over it, by alpha.
  case over
  /// Instead of it: the fragment mixed with the backdrop itself.
  case replace
  /// Over it, already premultiplied: solid letters' slices.
  case stack
  /// Added to it, summing a moving layer's moments.
  case add
}

// MARK: - FileVersion

/// A LUT's or shader effect's file as it is now, so an edited file is read again.
private struct FileVersion: Hashable {
  init(_ url: URL) {
    self.url = url
    // why: a missing file has no date; reading it then reports it can't be read.
    modified = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate]
      as? Date
  }

  let url: URL
  let modified: Date?
}

// MARK: - KeptTexture

/// What a texture kept between frames is for.
private enum KeptTexture {
  /// A moving layer's moments summed (or a solid layer's slices stacked).
  case trail
  /// One moment of a moving solid layer, before it's added to its trail.
  case solidMoment
  /// Solid letters' sides, at half size, before their face is drawn over them.
  case solidSides
}

// MARK: - StackedSolid

/// A still solid title's slices, stacked before the frame's pass over just the box they cover.
private struct StackedSolid {
  let texture: any MTLTexture
  let box: CGRect
}

// MARK: - SolidPart

/// Which slices of solid letters a pass draws.
private enum SolidPart {
  /// All but the last drawn: the sides, and faces hidden behind them.
  case sides
  /// The last drawn: the face in view.
  case face
}
