import ShadesCore

/// Places, animates or removes the window a clip's grade is limited to. Fields left out stay as
/// they are; with `at`, the position and size given are keyframed at that moment.
public struct SetWindow: ToolCommand {

  // MARK: Lifecycle

  public init(
    clipID: Clip.ID,
    remove: Bool? = nil,
    shape: MaskShape? = nil,
    x: Double? = nil,
    y: Double? = nil,
    width: Double? = nil,
    height: Double? = nil,
    softness: Double? = nil,
    inverted: Bool? = nil,
    at time: MediaTime? = nil,
    easing: Easing? = nil,
    clearKeyframes: Bool? = nil,
  ) {
    self.clipID = clipID
    self.remove = remove
    self.shape = shape
    self.x = x
    self.y = y
    self.width = width
    self.height = height
    self.softness = softness
    self.inverted = inverted
    at = time
    self.easing = easing
    self.clearKeyframes = clearKeyframes
  }

  // MARK: Public

  public static let title = "Change Window"
  public static let name = "set_window"
  public static let summary = "Limit a clip's grade (from set_look) to a soft ellipse or "
    + "rectangle in the frame, like a vignette on a face, and animate it: give at to keyframe "
    + "its position and size (keyframes override the fixed ones). follow makes it follow a "
    + "track_motion path. Leave out what shouldn't change."
  public static let parameters = JSONSchema.object(
    [
      "clip_id": Fields.clipID,
      "remove": ShapeFields.remove,
      "shape": JSONSchema.string(
        "ellipse (default) or rectangle",
        values: [MaskShape.ellipse.rawValue, MaskShape.rectangle.rawValue],
      ),
      "x": JSONSchema.number("Centre, 0 left to 1 right of the frame (default 0.5)"),
      "y": JSONSchema.number("Centre, 0 top to 1 bottom of the frame (default 0.5)"),
      "width": JSONSchema.number("Width as a fraction of the frame", minimum: 0),
      "height": JSONSchema.number("Height as a fraction of the frame", minimum: 0),
      "softness": JSONSchema.number(
        "How far the edge fades, as a fraction of the shape's size (default 0.2)",
        minimum: 0,
        maximum: 1,
      ),
      "inverted": JSONSchema.boolean("Grade outside the shape instead of inside"),
      "at": ShapeFields.at,
      "easing": ShapeFields.easing,
      "clear_keyframes": ShapeFields.clearKeyframes,
    ],
    required: ["clip_id"],
  )

  public let clipID: Clip.ID
  public let remove: Bool?
  public let shape: MaskShape?
  public let x: Double?
  public let y: Double?
  public let width: Double?
  public let height: Double?
  public let softness: Double?
  public let inverted: Bool?
  public let at: MediaTime?
  public let easing: Easing?
  public let clearKeyframes: Bool?

  public func apply(to project: inout Project) throws(CommandError) {
    let location = try project.requireClip(clipID)
    var clip = project.timeline.tracks[location.track].clips[location.clip]
    guard clip.text == nil, project.timeline.tracks[location.track].kind != .audio else {
      throw rejected(.invalidValue("a window limits a grade, which text and sound don't have"))
    }
    var grade = clip.grade ?? Grade()
    guard remove != true else {
      grade.window = nil
      clip.grade = grade
      try project.replaceClip(at: location, with: clip)
      return
    }
    guard shape != .path else {
      throw rejected(
        .invalidValue("a window is an ellipse or a rectangle; mask paths with set_mask")
      )
    }
    var window = grade.window ?? GradeWindow()
    window.isEllipse = shape.map { $0 == .ellipse } ?? window.isEllipse
    window.softness = softness ?? window.softness
    window.inverted = inverted ?? window.inverted
    if clearKeyframes == true {
      window.keyframes = []
    }
    if let at {
      var key = try window.keyframe(
        at: project.shapeKeyframeTime(at: at, in: clip),
        easing: easing ?? .linear,
      )
      key.x = x ?? key.x
      key.y = y ?? key.y
      key.width = width ?? key.width
      key.height = height ?? key.height
      window.keyframes.set(key)
    } else {
      window.x = x ?? window.x
      window.y = y ?? window.y
      window.width = width ?? window.width
      window.height = height ?? window.height
    }
    let boxes = [(window.width, window.height)] + window.keyframes.map { ($0.width, $0.height) }
    guard boxes.allSatisfy({ $0.0 > 0 && $0.1 > 0 }), (0 ... 1).contains(window.softness) else {
      throw rejected(.invalidValue(
        "a window needs a width and height above 0, and softness from 0 to 1"
      ))
    }
    grade.window = window
    clip.grade = grade
    try project.replaceClip(at: location, with: clip)
  }

}
