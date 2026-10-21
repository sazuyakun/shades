import AppKit
import ShadesCommands
import ShadesCore
import SwiftUI

/// The look of a drawing clip: colour, width, glow, how fast it boils and how long it takes to
/// draw itself on and off.
struct DrawingInspector: View {

  // MARK: Internal

  let clip: Clip
  let drawing: Drawing
  let onError: (String) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      ColorPicker("Colour", selection: color).fixedSize()
      InspectorSlider(
        label: "Width",
        value: drawing.width,
        range: 0.001 ... 0.04,
        format: { "\(Int(($0 * 1000).rounded()))" },
        onChange: { change(SetDrawing(clipID: clip.id, width: $0)) },
        onEnd: editor.endCoalescing,
      )
      InspectorSlider(
        label: "Glow",
        value: drawing.glow,
        range: 0 ... 1,
        format: { "\(Int(($0 * 100).rounded()))%" },
        onChange: { change(SetDrawing(clipID: clip.id, glow: $0)) },
        onEnd: editor.endCoalescing,
      )
      InspectorSlider(
        label: "Boil",
        value: drawing.boil,
        range: 0 ... 24,
        format: { $0 < 0.5 ? "Still" : "\(Int($0.rounded())) a second" },
        onChange: { change(SetDrawing(clipID: clip.id, boil: $0.rounded())) },
        onEnd: editor.endCoalescing,
      )
      InspectorSlider(
        label: "Write On",
        value: drawing.writeOn,
        range: 0 ... 3,
        format: { $0 < 0.05 ? "Off" : String(format: "%.1f s", $0) },
        onChange: { change(SetDrawing(clipID: clip.id, writeOn: $0)) },
        onEnd: editor.endCoalescing,
      )
      InspectorSlider(
        label: "Erase Off",
        value: drawing.eraseOff,
        range: 0 ... 3,
        format: { $0 < 0.05 ? "Off" : String(format: "%.1f s", $0) },
        onChange: { change(SetDrawing(clipID: clip.id, eraseOff: $0)) },
        onEnd: editor.endCoalescing,
      )
    }
  }

  // MARK: Private

  @Environment(Editor.self) private var editor

  private var color: Binding<Color> {
    Binding(get: {
      Color(
        .sRGB,
        red: drawing.color.red,
        green: drawing.color.green,
        blue: drawing.color.blue,
        opacity: drawing.color.alpha,
      )
    }, set: { picked in
      guard let rgb = NSColor(picked).usingColorSpace(.sRGB) else {
        return
      }
      change(SetDrawing(clipID: clip.id, color: HexColor(
        red: rgb.redComponent,
        green: rgb.greenComponent,
        blue: rgb.blueComponent,
        alpha: rgb.alphaComponent,
      )))
    })
  }

  /// Applies a change; a drag on one control is one undo step.
  private func change(_ command: SetDrawing) {
    do {
      try editor.perform(command, coalescing: "\(clip.id).drawing")
    } catch {
      onError(error.errorDescription ?? "The drawing couldn't be changed.")
    }
  }

}
