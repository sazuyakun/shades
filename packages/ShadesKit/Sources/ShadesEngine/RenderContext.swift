/// The GPU setup shared by everything that draws frames (the player, frame grabs for Claude):
/// made once, because compiling shaders and opening the GPU is slow.
public final class RenderContext: Sendable {

  // MARK: Lifecycle

  /// Opens the GPU and compiles the shaders.
  public init() throws(EngineError) {
    renderer = try MetalRenderer()
  }

  // MARK: Internal

  let renderer: MetalRenderer

}
