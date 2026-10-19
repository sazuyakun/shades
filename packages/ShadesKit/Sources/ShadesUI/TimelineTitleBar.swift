import ShadesCommands
import SwiftUI

/// The bar above the timeline: the timeline's name, the tools and snapping, plugin templates, and
/// the timeline's length.
struct TimelineTitleBar: View {

  // MARK: Internal

  @Binding var settings: TimelineSettings

  let onError: (String) -> Void

  var body: some View {
    HStack(spacing: 10) {
      Text(editor.project.timeline.name)
        .font(.callout)
        .padding(.horizontal, 11)
        .frame(height: 24)
        .background(Theme.raised, in: .capsule)
        .overlay(Capsule().strokeBorder(Theme.strongHairline))
      CapsuleGroup {
        Button("Select", systemImage: "cursorarrow") { settings.tool = .select }
          .buttonStyle(CapsuleButtonStyle(isOn: settings.tool == .select))
          .help("Select tool (A)")
        Button("Trim", systemImage: "arrow.left.and.right") { settings.tool = .trim }
          .buttonStyle(CapsuleButtonStyle(isOn: settings.tool == .trim))
          .help("Trim tool: edges ripple (T)")
        Button("Blade", systemImage: "scissors") { settings.tool = .blade }
          .buttonStyle(CapsuleButtonStyle(isOn: settings.tool == .blade))
          .help("Blade tool (B)")
        Button("Draw", systemImage: "pencil.tip") { settings.isDrawing.toggle() }
          .buttonStyle(CapsuleButtonStyle(isOn: settings.isDrawing))
          .help("Draw tool: drag in the viewer to draw over the picture (P)")
      }
      .labelStyle(.iconOnly)
      Button("Snapping", systemImage: "arrow.right.to.line") { settings.isSnapping.toggle() }
        .labelStyle(.iconOnly)
        .buttonStyle(CapsuleButtonStyle(isOn: settings.isSnapping))
        .help("Snapping (N)")
      TemplatesMenu(onError: onError)
      Spacer()
      Text(Timecode.full(
        editor.project.timeline.duration.seconds,
        framesPerSecond: editor.project.timeline.format.framesPerSecond,
      ))
      .font(.system(size: 11, design: .monospaced))
      .foregroundStyle(Theme.faintText)
    }
    .padding(.horizontal, 12)
    .frame(height: 40)
  }

  // MARK: Private

  @Environment(Editor.self) private var editor

}
