import ShadesCommands
import ShadesCore
import SwiftUI

/// Video tab for a clip: where it sits, how big, its rotation, opacity and depth slot.
struct ClipVideoInspector: View {

  // MARK: Internal

  let clip: Clip
  let onError: (String) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      InspectorSlider(
        label: "Position X",
        value: clip.transform.x,
        range: -1 ... 1,
        format: percent,
        onChange: { set(SetClip(clipID: clip.id, x: $0), "x") },
        onEnd: editor.endCoalescing,
      )
      InspectorSlider(
        label: "Position Y",
        value: clip.transform.y,
        range: -1 ... 1,
        format: percent,
        onChange: { set(SetClip(clipID: clip.id, y: $0), "y") },
        onEnd: editor.endCoalescing,
      )
      InspectorSlider(
        label: "Scale",
        value: clip.transform.scale,
        range: 0.05 ... 4,
        format: percent,
        onChange: { set(SetClip(clipID: clip.id, scale: $0), "scale") },
        onEnd: editor.endCoalescing,
      )
      InspectorSlider(
        label: "Rotation",
        value: clip.transform.rotation,
        range: -180 ... 180,
        format: { "\(Int($0.rounded()))°" },
        onChange: { set(SetClip(clipID: clip.id, rotation: $0), "rotation") },
        onEnd: editor.endCoalescing,
      )
      InspectorSlider(
        label: "Opacity",
        value: clip.opacity,
        range: 0 ... 1,
        format: percent,
        onChange: { set(SetClip(clipID: clip.id, opacity: $0), "opacity") },
        onEnd: editor.endCoalescing,
      )
      Picker("Depth", selection: Binding(
        get: { clip.depth },
        set: { set(SetClip(clipID: clip.id, depth: $0), nil) },
      )) {
        Text("In front").tag(DepthSlot.inFront)
        Text("Behind subject").tag(DepthSlot.behindSubject)
        Text("Inside subject").tag(DepthSlot.insideSubject)
        Text("Replace background").tag(DepthSlot.replaceBackground)
      }
      .help("Where this layer sits relative to the person cut out of the clips below it")
      HStack {
        Button("Reset Transform") {
          set(SetClip(clipID: clip.id, x: 0, y: 0, scale: 1, rotation: 0, opacity: 1), nil)
        }
        Button("Reframe") { reframe() }
          .help("Zoom to fill the 4:3 frame, keeping the subject in view")
        Button(hasCutout ? "Cut Out Again" : "Cut Out Subject") { cutOut() }
          .help("Find the subject so layers can go behind or inside it")
      }
      .buttonStyle(CapsuleButtonStyle())
    }
  }

  // MARK: Private

  @Environment(Editor.self) private var editor
  @Environment(Workspace.self) private var workspace

  private var hasCutout: Bool {
    clip.mediaID.flatMap { workspace.analysis.analyses[$0]?.matte } != nil
  }

  private func reframe() {
    do {
      _ = try workspace.autoReframe([clip.id])
    } catch {
      onError(error.errorDescription ?? "The clip couldn't be reframed.")
    }
  }

  private func cutOut() {
    guard let mediaID = clip.mediaID else {
      return
    }
    _ = workspace.makeCutouts([mediaID], engine: .visionPerson)
  }

  private func percent(_ value: Double) -> String {
    "\(Int((value * 100).rounded()))%"
  }

  /// Applies an edit; drags on one control (`key`) merge into one undo step.
  private func set(_ command: SetClip, _ key: String?) {
    do {
      try editor.perform(command, coalescing: key.map { "\(clip.id).\($0)" })
    } catch {
      onError(error.errorDescription ?? "The clip couldn't be changed.")
    }
  }

}
