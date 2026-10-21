import ShadesCommands
import ShadesCore
import SwiftUI

/// A clip's motion blur, as a share of the timeline's shutter, and the timeline's shutter itself.
struct MotionBlurControls: View {

  // MARK: Internal

  let clip: Clip
  let onError: (String) -> Void

  var body: some View {
    let shutter = editor.project.timeline.shutterAngle
    VStack(alignment: .leading, spacing: 14) {
      InspectorSlider(
        label: "Motion Blur",
        value: clip.motionBlur,
        range: 0 ... 2,
        format: { $0 * shutter < 0.5 ? "Off" : "\(Int(($0 * shutter).rounded()))°" },
        onChange: { perform(SetClip(clipID: clip.id, motionBlur: $0), key: "\(clip.id).blur") },
        onEnd: editor.endCoalescing,
      )
      .help("How long this clip blurs as it moves, as a share of the timeline's shutter")
      InspectorSlider(
        label: "Timeline Shutter",
        value: shutter,
        range: 0 ... 360,
        format: { "\(Int($0.rounded()))°" },
        onChange: { perform(SetShutter(angle: $0.rounded()), key: "shutter") },
        onEnd: editor.endCoalescing,
      )
      .help("How long everything moving blurs for: 180° is film's look, 0° none")
    }
  }

  // MARK: Private

  @Environment(Editor.self) private var editor

  private func perform(_ command: some Command, key: String) {
    do {
      try editor.perform(command, coalescing: key)
    } catch {
      onError(error.errorDescription ?? "The motion blur couldn't be changed.")
    }
  }

}
