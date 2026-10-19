import ShadesCore

/// Moves the timeline's camera: zoom, pan, rotate, tilt and dolly over time, seen by every track
/// that follows the camera.
public struct SetCamera: ToolCommand {

  // MARK: Lifecycle

  public init(keyframes: [SetKeyframes.Key], clear: Bool? = nil) {
    self.keyframes = keyframes
    self.clear = clear
  }

  // MARK: Public

  public static let title = "Move Camera"
  public static let name = "set_camera"
  public static let summary = "Move the camera over the whole picture with keyframes at timeline "
    + "times: scale zooms (2 is twice as close), x and y pan (fractions of the frame), rotation "
    + "turns, tiltX and tiltY tilt with perspective, depth dollies in (positive) or out. Video "
    + "tracks follow it; text tracks don't unless set_track says so. clear removes every move "
    + "first."
  public static let parameters = JSONSchema.object(
    [
      "keyframes": JSONSchema.array(
        "The camera's values at moments",
        items: JSONSchema.object(
          [
            "property": JSONSchema.string(
              "What moves",
              values: AnimatedProperty.allCases.filter { $0.isVisual && $0 != .opacity }
                .map(\.rawValue),
            ),
            "at": Fields.time("When"),
            "value": JSONSchema.number("The value at that moment"),
            "easing": JSONSchema.string(
              "How it moves on to the next keyframe. Default easeInOut",
              values: Easing.allCases.map(\.rawValue),
            ),
          ],
          required: ["property", "at", "value"],
        ),
      ),
      "clear": JSONSchema.boolean("Remove the camera's existing moves first"),
    ],
    required: ["keyframes"],
  )

  public let keyframes: [SetKeyframes.Key]
  public let clear: Bool?

  public func apply(to project: inout Project) throws(CommandError) {
    if clear == true {
      project.timeline.camera = []
    }
    for key in keyframes {
      guard key.property.isVisual, key.property != .opacity else {
        throw rejected(.invalidValue("the camera has no opacity or volume"))
      }
      guard key.property != .scale || (0.1 ... 20).contains(key.value) else {
        throw rejected(.invalidValue("camera zoom (scale) goes from 0.1 to 20"))
      }
      let keyframe = Keyframe(
        property: key.property,
        time: project.onFrame(key.at),
        value: key.value,
        easing: key.easing ?? .easeInOut,
      )
      project.timeline.camera.removeAll {
        $0.property == keyframe.property && $0.time == keyframe.time
      }
      project.timeline.camera.append(keyframe)
    }
    project.timeline.camera.sort { $0.time < $1.time }
  }

}
