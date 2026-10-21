import ShadesCommands
import ShadesEngine
import SwiftUI

/// The bar above the timeline: the timeline's name and its shorts, the tools and snapping, plugin
/// templates, motion presets and sounds, and the timeline's length.
struct TimelineTitleBar: View {

  // MARK: Internal

  @Binding var settings: TimelineSettings

  let onRun: (EditorAction) -> Void
  let onError: (String) -> Void

  var body: some View {
    HStack(spacing: 10) {
      Text(editor.project.timeline.name)
        .font(.callout)
        .padding(.horizontal, 11)
        .frame(height: 24)
        .background(Theme.raised, in: .capsule)
        .overlay(Capsule().strokeBorder(Theme.strongHairline))
      ForEach(editor.project.timeline.shorts) { short in
        Button(short.name) {
          settings.selectedShort = short.id
          Task { await player.seek(toSeconds: short.range.start.seconds) }
        }
        .buttonStyle(.plain)
        .font(.callout)
        .lineLimit(1)
        .foregroundStyle(settings.selectedShort == short.id ? Theme.text : Theme.secondaryText)
        .help("Pick this short and jump to it")
      }
      Button("+ range") { onRun(.markShort) }
        .buttonStyle(.plain)
        .font(.callout)
        .foregroundStyle(Theme.faintText)
        .help("Mark the selected clips' stretch as a short (⌥M)")
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
        Button("Draw", systemImage: "pencil.tip") {
          settings.isDrawing.toggle()
          settings.isTracking = false
        }
        .buttonStyle(CapsuleButtonStyle(isOn: settings.isDrawing))
        .help("Draw tool: drag in the viewer to draw over the picture (P)")
        Button("Track", systemImage: "viewfinder") {
          settings.isTracking.toggle()
          settings.isDrawing = false
        }
        .buttonStyle(CapsuleButtonStyle(isOn: settings.isTracking))
        .help("Track tool: drag a box in the viewer around something to follow it (⌥T)")
      }
      .labelStyle(.iconOnly)
      Button("Snapping", systemImage: "arrow.right.to.line") { settings.isSnapping.toggle() }
        .labelStyle(.iconOnly)
        .buttonStyle(CapsuleButtonStyle(isOn: settings.isSnapping))
        .help("Snapping (N)")
      TemplatesMenu(onError: onError)
      OverlaysMenu(onError: onError)
      MotionMenu(onError: onError)
      SoundsMenu(onError: onError)
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
  @Environment(Player.self) private var player

}
