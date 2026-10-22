import ShadesCommands
import ShadesCore
import ShadesEngine
import SwiftUI

// MARK: - GradeWindowControls

/// Limits a clip's grade to a soft ellipse or rectangle (or keeps it out of one), and animates
/// it: once it has keyframes, changes keyframe it at the playhead.
struct GradeWindowControls: View {

  // MARK: Internal

  let clip: Clip
  let onError: (String) -> Void

  var body: some View {
    let window = clip.grade?.window
    VStack(alignment: .leading, spacing: 12) {
      Toggle("Only change inside a shape", isOn: Binding(
        get: { window != nil },
        set: { perform($0 ? SetWindow(clipID: clip.id) : SetWindow(clipID: clip.id, remove: true))
        },
      ))
      .help("A window: the grade changes only inside (or outside) a soft shape, like a face")
      if let window {
        let source = clip.sourceTime(at: playhead)
        let placed = window.placed(at: source)
        let keyHere = window.keyframes.first { $0.time == source }
        Picker("Shape", selection: Binding(
          get: { window.isEllipse },
          set: { perform(SetWindow(clipID: clip.id, shape: $0 ? .ellipse : .rectangle)) },
        )) {
          Text("Ellipse").tag(true)
          Text("Rectangle").tag(false)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        ForEach(WindowField.allCases, id: \.self) { field in
          InspectorSlider(
            label: field.label,
            value: placed[keyPath: field.keyPath],
            range: field.range,
            format: { "\(Int(($0 * 100).rounded()))%" },
            onChange: { value in
              let keyed = !window.keyframes.isEmpty && field != .softness
              perform(
                field.edit(
                  value,
                  on: clip.id,
                  at: keyed ? playhead : nil,
                  easing: keyHere?.easing,
                ),
                dragging: true,
              )
            },
            onEnd: editor.endCoalescing,
          )
        }
        Toggle("Change outside the shape instead", isOn: Binding(
          get: { window.inverted },
          set: { perform(SetWindow(clipID: clip.id, inverted: $0)) },
        ))
        HStack {
          Button("Keyframe") { perform(SetWindow(clipID: clip.id, at: playhead)) }
            .help(
              "Keep the window where it is now at the playhead; move it elsewhere to animate it"
            )
          if let keyHere {
            EasingMenu(easing: keyHere.easing) { easing in
              perform(SetWindow(clipID: clip.id, at: playhead, easing: easing))
            }
          }
          if !window.keyframes.isEmpty {
            Button("Clear Keyframes") { perform(SetWindow(clipID: clip.id, clearKeyframes: true)) }
          }
          if !paths.isEmpty {
            Menu("Follow") {
              ForEach(paths, id: \.self) { name in
                Button(name ?? "Subject") { follow(name) }
              }
            }
            .fixedSize()
            .help("Move the window with the cut-out's subject or a tracked path")
          }
        }
        .buttonStyle(CapsuleButtonStyle())
      }
    }
  }

  // MARK: Private

  @Environment(Editor.self) private var editor
  @Environment(Player.self) private var player
  @Environment(Workspace.self) private var workspace

  private var playhead: MediaTime {
    MediaTime(seconds: player.currentTime)
      .roundedToFrame(at: editor.project.timeline.format.framesPerSecond)
  }

  /// What the window can follow: the cut-out's subject (`nil`) and the clip's tracked paths.
  private var paths: [String?] {
    let analysis = clip.mediaID.flatMap { workspace.analysis.analyses[$0] }
    let subject: [String?] = analysis?.subjectPath == nil ? [] : [nil]
    return subject + (analysis?.tracks?.keys.sorted() ?? [])
  }

  private func follow(_ name: String?) {
    do {
      try workspace.followShape(clipID: clip.id, shape: .window, path: name)
    } catch {
      onError(error.errorDescription ?? "The window couldn't follow that.")
    }
  }

  private func perform(_ command: SetWindow, dragging: Bool = false) {
    do {
      try editor.perform(command, coalescing: dragging ? "\(clip.id).window" : nil)
    } catch {
      onError(error.errorDescription ?? "The window couldn't be changed.")
    }
  }

}

// MARK: - WindowField

/// A window slider.
private enum WindowField: CaseIterable {
  case x
  case y
  case width
  case height
  case softness

  // MARK: Internal

  var label: String {
    switch self {
    case .x: "Across"
    case .y: "Down"
    case .width: "Width"
    case .height: "Height"
    case .softness: "Softness"
    }
  }

  var keyPath: KeyPath<GradeWindow, Double> {
    switch self {
    case .x: \.x
    case .y: \.y
    case .width: \.width
    case .height: \.height
    case .softness: \.softness
    }
  }

  var range: ClosedRange<Double> {
    switch self {
    case .x,
         .y,
         .softness: 0 ... 1
    case .width,
         .height: 0.02 ... 1.5
    }
  }

  /// The edit that sets this field, keyframed at `time` when given (softness never is).
  func edit(_ value: Double, on clip: Clip.ID, at time: MediaTime?, easing: Easing?) -> SetWindow {
    switch self {
    case .x: SetWindow(clipID: clip, x: value, at: time, easing: easing)
    case .y: SetWindow(clipID: clip, y: value, at: time, easing: easing)
    case .width: SetWindow(clipID: clip, width: value, at: time, easing: easing)
    case .height: SetWindow(clipID: clip, height: value, at: time, easing: easing)
    case .softness: SetWindow(clipID: clip, softness: value)
    }
  }
}
