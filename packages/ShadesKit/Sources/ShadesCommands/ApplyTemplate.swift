import ShadesCore

/// Places a plugin's template at a moment: each text and sticker layer on a free track, styled,
/// placed and moving as the template says, with its sounds. The plugin's styles and the media of
/// its stickers and sounds come resolved, by name.
public struct ApplyTemplate: Command {

  // MARK: Lifecycle

  public init(
    _ template: Template,
    at time: MediaTime,
    fields: [String: String],
    styles: [String: TextStyle],
    media: [String: Media.ID],
  ) {
    self.template = template
    at = time
    self.fields = fields
    self.styles = styles
    self.media = media
  }

  // MARK: Public

  public static let title = "Apply Template"

  public let template: Template
  public let at: MediaTime
  /// The text for each `{field}`.
  public let fields: [String: String]
  public let styles: [String: TextStyle]
  /// Imported media for the template's stickers and sounds, by their names.
  public let media: [String: Media.ID]

  public func apply(to project: inout Project) throws(CommandError) {
    let missing = template.fields.filter { fields[$0] == nil }
    guard missing.isEmpty else {
      throw rejected(.invalidArguments("fill the template's fields: " + missing
          .joined(separator: ", ")))
    }
    for layer in template.layers {
      let start = project.onFrame(at + MediaTime(seconds: layer.start ?? 0))
      let length = MediaTime(seconds: layer.duration ?? template.duration)
      if let clipID = try place(layer, at: start, for: length, in: &project) {
        try animate(clipID, as: layer, from: start, in: &project)
      }
      if let sound = layer.sound {
        let id = try mediaID(named: sound)
        let media = try project.requireMedia(id)
        project.placeOnTop(
          media,
          range: try project.sourceRange(of: media, from: nil, to: nil),
          at: start,
        )
      }
    }
  }

  // MARK: Private

  /// Adds the layer's text or sticker clip, and returns its ID (`nil` for a sound-only layer).
  private func place(
    _ layer: TemplateLayer,
    at start: MediaTime,
    for length: MediaTime,
    in project: inout Project,
  ) throws(CommandError) -> Clip.ID? {
    if let text = layer.text {
      let style = try layer.style.map { name throws(CommandError) in
        guard let style = styles[name] else {
          throw rejected(
            .invalidArguments("the template uses a style called \(name) that isn't there")
          )
        }
        return style
      }
      let filled = fields.reduce(text) { $0.replacing("{\($1.key)}", with: $1.value) }
      let end = start + length
      let index = project.timeline.tracks.indices.first { index in
        project.timeline.tracks[index].kind == .text
          && project.timeline.tracks[index].isClear(from: start, to: end)
      } ?? project.addTrack(.text)
      let clip = Clip(
        source: .text(TextContent(
          text: filled,
          style: style ?? .caption,
          reveal: layer.reveal ?? .none,
        )),
        sourceStart: .zero,
        duration: length,
        timelineStart: start,
        transform: layer.transform ?? .identity,
        depth: layer.depthSlot ?? .inFront,
      )
      project.timeline.tracks[index].add(clip)
      return clip.id
    }
    if let sticker = layer.sticker {
      let media = try project.requireMedia(try mediaID(named: sticker))
      let id = project.placeOnTop(media, range: (.zero, length), at: start)
      let location = try project.requireClip(id)
      project.timeline.tracks[location.track].clips[location.clip].transform = layer.transform
        ?? ClipTransform(scale: 0.35)
      project.timeline.tracks[location.track].clips[location.clip].sticker = layer
        .look ?? StickerLook()
      project.timeline.tracks[location.track].clips[location.clip].depth = layer
        .depthSlot ?? .inFront
      return id
    }
    return nil
  }

  /// Gives the clip the layer's keyframes, then its motion preset.
  private func animate(
    _ clipID: Clip.ID,
    as layer: TemplateLayer,
    from start: MediaTime,
    in project: inout Project,
  ) throws(CommandError) {
    if let keyframes = layer.keyframes, !keyframes.isEmpty {
      try SetKeyframes(clipID: clipID, keyframes: keyframes.map { keyframe in
        SetKeyframes.Key(
          property: keyframe.property,
          at: start + MediaTime(seconds: keyframe.at),
          value: keyframe.value,
          easing: keyframe.easing,
        )
      }).apply(to: &project)
    }
    if let name = layer.motion {
      guard let preset = MotionPreset(rawValue: name) else {
        throw rejected(
          .invalidArguments("the template uses a motion called \(name) that Shades doesn't have")
        )
      }
      try ApplyMotion(clipIDs: [clipID], preset: preset, at: start).apply(to: &project)
    }
  }

  private func mediaID(named name: String) throws(CommandError) -> Media.ID {
    guard let id = media[name] else {
      throw rejected(.invalidArguments("the template uses \(name), which its plugin doesn't have"))
    }
    return id
  }

}
