/// One layer of a template: text or a sticker, where it sits, how it looks and how it moves.
/// Times are seconds from the template's start.
public struct TemplateLayer: Codable, Hashable, Sendable {

  // MARK: Lifecycle

  public init(
    text: String? = nil,
    sticker: String? = nil,
    sound: String? = nil,
    style: String? = nil,
    reveal: TextReveal? = nil,
    start: Double? = nil,
    duration: Double? = nil,
    transform: ClipTransform? = nil,
    look: StickerLook? = nil,
    motion: String? = nil,
    keyframes: [TemplateKeyframe]? = nil,
    depthSlot: DepthSlot? = nil,
  ) {
    self.text = text
    self.sticker = sticker
    self.sound = sound
    self.style = style
    self.reveal = reveal
    self.start = start
    self.duration = duration
    self.transform = transform
    self.look = look
    self.motion = motion
    self.keyframes = keyframes
    self.depthSlot = depthSlot
  }

  // MARK: Public

  /// Words to show, with `{field}` placeholders.
  public var text: String?
  /// A sticker picture from the plugin's `stickers` folder, by file name without extension.
  public var sticker: String?
  /// A sound from the plugin's `sounds` folder to play as the layer appears.
  public var sound: String?
  /// A text style from the plugin, by name.
  public var style: String?
  public var reveal: TextReveal?
  public var start: Double?
  public var duration: Double?
  public var transform: ClipTransform?
  public var look: StickerLook?
  /// A motion preset's name, like pop or slideIn.
  public var motion: String?
  public var keyframes: [TemplateKeyframe]?
  public var depthSlot: DepthSlot?

}
