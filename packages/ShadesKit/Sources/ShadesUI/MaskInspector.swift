import ShadesCommands
import ShadesCore
import ShadesEngine
import SwiftUI

// MARK: - MaskInspector

/// A clip's masks: add a rectangle or ellipse (paths are drawn on the viewer), then shape each
/// one's edge, how it joins the others, its keyframes and what it follows.
struct MaskInspector: View {

  // MARK: Internal

  let clip: Clip
  let onError: (String) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Text("Masks").foregroundStyle(Theme.secondaryText)
        Spacer()
        Menu("Add Mask") {
          Button("Rectangle") { add(.rectangle) }
          Button("Ellipse") { add(.ellipse) }
        }
        .fixedSize()
        .help("Add a mask; draw a free one on the viewer with Draw Mask")
      }
      ForEach(clip.masks.indices, id: \.self) { index in
        MaskRow(clip: clip, index: index, mask: clip.masks[index], onError: onError)
      }
    }
  }

  // MARK: Private

  @Environment(Editor.self) private var editor

  private func add(_ shape: MaskShape) {
    do {
      try editor.perform(SetMask(clipID: clip.id, shape: shape))
    } catch {
      onError(error.errorDescription ?? "The mask couldn't be added.")
    }
  }

}

// MARK: - MaskRow

/// One mask's controls.
private struct MaskRow: View {

  // MARK: Internal

  let clip: Clip
  let index: Int
  let mask: LayerMask
  let onError: (String) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text(title).foregroundStyle(Theme.text)
        Spacer()
        Button("Remove", systemImage: "trash") {
          perform(SetMask(clipID: clip.id, index: index, remove: true))
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .help("Remove this mask")
      }
      HStack {
        Picker("Mode", selection: Binding(
          get: { mask.mode },
          set: { perform(SetMask(clipID: clip.id, index: index, mode: $0)) },
        )) {
          Text("Add").tag(MaskMode.add)
          Text("Subtract").tag(MaskMode.subtract)
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        Toggle("Invert", isOn: Binding(
          get: { mask.inverted },
          set: { perform(SetMask(clipID: clip.id, index: index, inverted: $0)) },
        ))
      }
      InspectorSlider(
        label: "Feather",
        value: mask.feather,
        range: 0 ... 0.3,
        format: percent,
        onChange: { perform(SetMask(clipID: clip.id, index: index, feather: $0), dragging: true) },
        onEnd: editor.endCoalescing,
      )
      InspectorSlider(
        label: "Expansion",
        value: mask.expansion,
        range: -0.2 ... 0.2,
        format: percent,
        onChange: {
          perform(SetMask(clipID: clip.id, index: index, expansion: $0), dragging: true)
        },
        onEnd: editor.endCoalescing,
      )
      InspectorSlider(
        label: "Opacity",
        value: mask.opacity,
        range: 0 ... 1,
        format: percent,
        onChange: { perform(SetMask(clipID: clip.id, index: index, opacity: $0), dragging: true) },
        onEnd: editor.endCoalescing,
      )
      HStack {
        Button("Keyframe") {
          perform(SetMask(clipID: clip.id, index: index, at: playhead))
        }
        .help("Keep the mask where it is now at the playhead; move it elsewhere to animate it")
        let fps = editor.project.timeline.format.framesPerSecond
        let here = clip.sourceTime(at: playhead.roundedToFrame(at: fps))
        if let keyHere = mask.keyframes.first(where: { $0.time == here }) {
          EasingMenu(easing: keyHere.easing) { easing in
            perform(SetMask(clipID: clip.id, index: index, at: playhead, easing: easing))
          }
        }
        if !mask.keyframes.isEmpty {
          Button("Clear Keyframes") {
            perform(SetMask(clipID: clip.id, index: index, clearKeyframes: true))
          }
        }
        if !paths.isEmpty {
          Menu("Follow") {
            ForEach(paths, id: \.self) { name in
              Button(name ?? "Subject") { follow(name) }
            }
          }
          .fixedSize()
          .help("Move the mask with the cut-out's subject or a tracked path")
        }
      }
      .buttonStyle(CapsuleButtonStyle())
    }
  }

  // MARK: Private

  @Environment(Editor.self) private var editor
  @Environment(Player.self) private var player
  @Environment(Workspace.self) private var workspace

  private var title: String {
    let shape =
      switch mask.shape {
      case .rectangle: "Rectangle"
      case .ellipse: "Ellipse"
      case .path: "Path"
      }
    return "\(index + 1). \(shape)"
  }

  private var playhead: MediaTime {
    MediaTime(seconds: player.currentTime)
  }

  /// What the mask can follow: the cut-out's subject (`nil`) and the clip's tracked paths.
  private var paths: [String?] {
    let analysis = clip.mediaID.flatMap { workspace.analysis.analyses[$0] }
    let subject: [String?] = analysis?.subjectPath == nil ? [] : [nil]
    return subject + (analysis?.tracks?.keys.sorted() ?? [])
  }

  private func percent(_ value: Double) -> String {
    "\(Int((value * 100).rounded()))%"
  }

  private func follow(_ name: String?) {
    do {
      try workspace.followShape(clipID: clip.id, shape: .mask(index), path: name)
    } catch {
      onError(error.errorDescription ?? "The mask couldn't follow that.")
    }
  }

  private func perform(_ command: SetMask, dragging: Bool = false) {
    do {
      try editor.perform(command, coalescing: dragging ? "\(clip.id).mask\(index)" : nil)
    } catch {
      onError(error.errorDescription ?? "The mask couldn't be changed.")
    }
  }

}
