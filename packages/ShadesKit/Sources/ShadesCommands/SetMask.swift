import ShadesCore

// MARK: - SetMask

/// Adds, changes or removes one of a clip's masks. Fields left out stay as they are; with `at`,
/// the position, size and outline given are keyframed at that moment.
public struct SetMask: ToolCommand {

  // MARK: Lifecycle

  public init(
    clipID: Clip.ID,
    index: Int? = nil,
    remove: Bool? = nil,
    shape: MaskShape? = nil,
    x: Double? = nil,
    y: Double? = nil,
    width: Double? = nil,
    height: Double? = nil,
    points: [DrawingPoint]? = nil,
    svgPath: String? = nil,
    feather: Double? = nil,
    expansion: Double? = nil,
    inverted: Bool? = nil,
    opacity: Double? = nil,
    mode: MaskMode? = nil,
    at time: MediaTime? = nil,
    easing: Easing? = nil,
    clearKeyframes: Bool? = nil,
  ) {
    self.clipID = clipID
    self.index = index
    self.remove = remove
    self.shape = shape
    self.x = x
    self.y = y
    self.width = width
    self.height = height
    self.points = points
    self.svgPath = svgPath
    self.feather = feather
    self.expansion = expansion
    self.inverted = inverted
    self.opacity = opacity
    self.mode = mode
    at = time
    self.easing = easing
    self.clearKeyframes = clearKeyframes
  }

  // MARK: Public

  /// The most masks one clip can have.
  public static let maskLimit = 8
  /// The most points a path mask's outline can have.
  public static let pointLimit = 256

  public static let title = "Change Mask"
  public static let name = "set_mask"
  public static let summary = "Hide or reveal part of a layer with a shape mask: a rectangle, an "
    + "ellipse or a free path (points or SVG path data, like a bezier around a face). Masks sit "
    + "on the layer's own picture and move with it. Each has a feather (soft edge), expansion, "
    + "invert and opacity; several masks join in order, each adding to or subtracting from "
    + "what shows. Leave out index to add one; give at to keyframe its position, size and "
    + "outline (keyframes override the fixed ones). follow makes a mask follow a track_motion "
    + "path. Leave out what shouldn't change."
  public static let parameters = JSONSchema.object(
    [
      "clip_id": Fields.clipID,
      "index": JSONSchema.number(
        "Which mask to change, from 0 in get_project's order; leave out to add a new one",
        minimum: 0,
      ),
      "remove": ShapeFields.remove,
      "shape": JSONSchema.string(
        "The outline (default ellipse; path when points or svg_path are given)",
        values: MaskShape.allCases.map(\.rawValue),
      ),
      "x": JSONSchema.number("Centre, 0 left to 1 right of the layer's picture (default 0.5)"),
      "y": JSONSchema.number("Centre, 0 top to 1 bottom of the picture (default 0.5)"),
      "width": JSONSchema.number("Width of its box as a fraction of the picture", minimum: 0),
      "height": JSONSchema.number("Height of its box as a fraction of the picture", minimum: 0),
      "points": JSONSchema.array(
        "A path's outline as [x, y] points inside the box (0 to 1 from its top left), at least 3",
        items: JSONSchema.array("[x, y]", items: JSONSchema.number("A coordinate")),
      ),
      "svg_path": JSONSchema.string(
        "A path's outline as SVG path data (M L H V C Q Z) inside the box, its view box 1 by 1; "
          + "curves are followed in short steps"
      ),
      "feather": JSONSchema.number(
        "How far the edge fades, as a fraction of the picture's height (default 0, hard)",
        minimum: 0,
        maximum: 1,
      ),
      "expansion": JSONSchema.number(
        "Pushes the edge out (positive) or pulls it in, as a fraction of the picture's height",
        minimum: -1,
        maximum: 1,
      ),
      "inverted": JSONSchema.boolean("Work on everything outside the shape instead"),
      "opacity": JSONSchema.number("How strongly it reveals or hides", minimum: 0, maximum: 1),
      "mode": JSONSchema.string(
        "add shows the layer inside it too; subtract hides the layer inside it. A layer whose "
          + "first mask subtracts starts fully shown",
        values: MaskMode.allCases.map(\.rawValue),
      ),
      "at": ShapeFields.at,
      "easing": ShapeFields.easing,
      "clear_keyframes": ShapeFields.clearKeyframes,
    ],
    required: ["clip_id"],
  )

  public let clipID: Clip.ID
  public let index: Int?
  public let remove: Bool?
  public let shape: MaskShape?
  public let x: Double?
  public let y: Double?
  public let width: Double?
  public let height: Double?
  public let points: [DrawingPoint]?
  public let svgPath: String?
  public let feather: Double?
  public let expansion: Double?
  public let inverted: Bool?
  public let opacity: Double?
  public let mode: MaskMode?
  public let at: MediaTime?
  public let easing: Easing?
  public let clearKeyframes: Bool?

  public func apply(to project: inout Project) throws(CommandError) {
    let location = try project.requireClip(clipID)
    guard project.timeline.tracks[location.track].kind != .audio else {
      throw rejected(.invalidValue("masks hide part of a picture; this clip is only sound"))
    }
    var clip = project.timeline.tracks[location.track].clips[location.clip]
    if let index, !clip.masks.indices.contains(index) {
      throw rejected(.invalidValue(
        "the clip has \(clip.masks.count) mask\(clip.masks.count == 1 ? "" : "s"); index "
          + "\(index) isn't one of them"
      ))
    }
    if remove == true {
      guard let index else {
        throw rejected(.invalidValue("say which mask to remove with index"))
      }
      clip.masks.remove(at: index)
      try project.replaceClip(at: location, with: clip)
      return
    }
    guard index != nil || clip.masks.count < Self.maskLimit else {
      throw rejected(.invalidValue("a clip can have at most \(Self.maskLimit) masks"))
    }
    var mask = index.map { clip.masks[$0] } ?? LayerMask()
    let outline = try outlinePoints()
    mask.shape = shape ?? (outline == nil ? mask.shape : .path)
    mask.feather = feather ?? mask.feather
    mask.expansion = expansion ?? mask.expansion
    mask.inverted = inverted ?? mask.inverted
    mask.opacity = opacity ?? mask.opacity
    mask.mode = mode ?? mask.mode
    if clearKeyframes == true {
      mask.keyframes = []
    }
    if let at {
      var key = try mask.keyframe(
        at: project.shapeKeyframeTime(at: at, in: clip),
        easing: easing ?? .linear,
      )
      key.x = x ?? key.x
      key.y = y ?? key.y
      key.width = width ?? key.width
      key.height = height ?? key.height
      key.points = mask.shape == .path ? outline ?? key.points : []
      mask.keyframes.set(key)
      // why: a path keyframed from the start still needs a fixed outline to fall back on.
      mask.points = mask.points.isEmpty ? key.points : mask.points
    } else {
      mask.x = x ?? mask.x
      mask.y = y ?? mask.y
      mask.width = width ?? mask.width
      mask.height = height ?? mask.height
      mask.points = outline ?? mask.points
    }
    try mask.validate()
    if let index {
      clip.masks[index] = mask
    } else {
      clip.masks.append(mask)
    }
    try project.replaceClip(at: location, with: clip)
  }

  // MARK: Private

  /// The path outline given as points or SVG path data, if either was.
  private func outlinePoints() throws(CommandError) -> [DrawingPoint]? {
    guard let svgPath else {
      return points
    }
    guard points == nil else {
      throw rejected(.invalidValue("give a path's outline as points or svg_path, not both"))
    }
    let strokes = try SVGPath.strokes(from: svgPath, viewBox: (1, 1))
    guard let outline = strokes.first, strokes.count == 1 else {
      throw rejected(.invalidValue("a mask's svg_path draws one closed outline (one M)"))
    }
    return outline
  }

}

// MARK: - LayerMask + Validation

extension LayerMask {
  /// Refuses a mask that can't be drawn or whose amounts are out of range.
  func validate() throws(CommandError) {
    let boxes = [(width, height)] + keyframes.map { ($0.width, $0.height) }
    guard boxes.allSatisfy({ $0.0 > 0 && $0.1 > 0 }) else {
      throw rejected(.invalidValue("a mask needs a width and height above 0"))
    }
    guard (0 ... 1).contains(feather), (-1 ... 1).contains(expansion), (0 ... 1).contains(opacity)
    else {
      throw rejected(.invalidValue(
        "feather goes from 0 to 1, expansion from -1 to 1 and opacity from 0 to 1"
      ))
    }
    guard shape == .path else {
      return
    }
    let outlines = [points] + keyframes.map(\.points).filter { !$0.isEmpty }
    guard outlines.allSatisfy({ (3 ... SetMask.pointLimit).contains($0.count) }) else {
      throw rejected(.invalidValue(
        "a path mask's outline needs 3 to \(SetMask.pointLimit) points (points or svg_path)"
      ))
    }
  }
}
