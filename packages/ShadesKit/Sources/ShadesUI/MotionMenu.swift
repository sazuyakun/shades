import ShadesCommands
import ShadesCore
import SwiftUI

/// Animates the selected clips with a ready-made move (pop, slide in, float, orbit, scatter,
/// stack), written as keyframes from each clip's start.
struct MotionMenu: View {

  // MARK: Internal

  let onError: (String) -> Void

  var body: some View {
    Menu {
      ForEach(MotionPreset.allCases, id: \.self) { preset in
        Button(Self.label(of: preset)) { apply(preset) }
      }
    } label: {
      Label("Motion", systemImage: "wand.and.rays")
    }
    .menuStyle(.button)
    .menuIndicator(.hidden)
    .buttonStyle(CapsuleButtonStyle())
    .fixedSize()
    .disabled(editor.selection.isEmpty)
    .help("Animate the selected clips with a ready-made move; orbit, scatter and stack move "
      + "several together")
  }

  // MARK: Private

  @Environment(Editor.self) private var editor

  private static func label(of preset: MotionPreset) -> String {
    switch preset {
    case .pop: "Pop In"
    case .slideIn: "Slide In"
    case .float: "Float"
    case .orbit: "Orbit"
    case .scatter: "Scatter"
    case .stack: "Stack"
    }
  }

  private func apply(_ preset: MotionPreset) {
    let selected = editor.project.timeline.allClips.filter { editor.selection.contains($0.id) }
    do {
      try editor.perform(ApplyMotion(clipIDs: selected.map(\.id), preset: preset))
    } catch {
      onError(error.errorDescription ?? "The motion couldn't be applied.")
    }
  }

}
