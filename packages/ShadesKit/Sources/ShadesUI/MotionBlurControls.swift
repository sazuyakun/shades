import ShadesCommands
import ShadesCore
import ShadesMatting
import SwiftUI

/// A clip's motion blur, as a share of the timeline's shutter, whether its footage blurs along its
/// own motion, and the timeline's shutter itself.
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
      if let footage {
        Toggle("Blur movement in the footage", isOn: Binding(
          get: { clip.footageBlur },
          set: { perform(SetClip(clipID: clip.id, footageBlur: $0), key: nil) },
        ))
        .help("Smear what moves inside the video (a pan, a running subject) along its motion")
        if
          clip.footageBlur,
          workspace.analysis.analyses[footage.id]?.flow != FlowMaker.fileName(for: footage.id)
        {
          Text("Measuring the motion first; the blur shows when it's done.")
            .foregroundStyle(Theme.faintText)
        }
      }
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
  @Environment(Workspace.self) private var workspace

  /// The clip's video, when it plays some (footage blur needs moving pictures).
  private var footage: Media? {
    clip.mediaID.flatMap(editor.project.media(withID:)).flatMap { media in
      media.hasVideo && !media.isStill ? media : nil
    }
  }

  private func perform(_ command: some Command, key: String?) {
    do {
      try editor.perform(command, coalescing: key)
    } catch {
      onError(error.errorDescription ?? "The motion blur couldn't be changed.")
    }
  }

}
