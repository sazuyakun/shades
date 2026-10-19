import AppKit
import ShadesCommands
import ShadesCore
import ShadesPlugins
import SwiftUI

/// The words, look and reveal of a text clip.
struct TextInspector: View {

  // MARK: Internal

  let clip: Clip
  let content: TextContent
  let onError: (String) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      TextField("Words", text: $words)
        .textFieldStyle(.roundedBorder)
        .onSubmit { perform(SetText(clipID: clip.id, text: words), coalescing: nil) }
        .onAppear { words = content.text }
        .onChange(of: content.text) { words = content.text }
      if !pluginStyles.isEmpty {
        Menu("Plugin Style") {
          ForEach(pluginStyles, id: \.name) { item in
            Button(item.name) {
              perform(SetText(clipID: clip.id, style: item.style), coalescing: nil)
            }
          }
        }
        .fixedSize()
      }
      // why: a pop-up is as wide as its longest font name; a menu is as wide as the current one.
      Menu {
        Button("System Bold") { style(\.font).wrappedValue = nil }
        ForEach(Self.families, id: \.self) { family in
          Button(family) { style(\.font).wrappedValue = family }
        }
      } label: {
        Text(content.style.font ?? "System Bold").lineLimit(1)
      }
      InspectorSlider(
        label: "Size",
        value: content.style.size,
        range: 0.02 ... 0.4,
        format: { "\(Int(($0 * 100).rounded()))%" },
        onChange: change { $0.size = $1 },
        onEnd: editor.endCoalescing,
      )
      HStack {
        ColorPicker("Fill", selection: color(\.color)).fixedSize()
        Spacer()
        ColorPicker("Outline", selection: color(\.outlineColor)).fixedSize()
      }
      Toggle("Shadow", isOn: style(\.shadow))
      InspectorSlider(
        label: "Outline",
        value: content.style.outline,
        range: 0 ... 0.2,
        format: { "\(Int(($0 * 100).rounded()))%" },
        onChange: change { $0.outline = $1 },
        onEnd: editor.endCoalescing,
      )
      InspectorSlider(
        label: "Bend",
        value: content.style.arc,
        range: -180 ... 180,
        format: { "\(Int($0.rounded()))°" },
        onChange: change { $0.arc = $1.rounded() },
        onEnd: editor.endCoalescing,
      )
      Text("Align").foregroundStyle(Theme.secondaryText)
      Picker("Align", selection: style(\.align)) {
        ForEach(TextAlign.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      Text("Place").foregroundStyle(Theme.secondaryText)
      Picker("Place", selection: style(\.anchor)) {
        Text("Bottom").tag(TextAnchor.bottom)
        Text("Middle").tag(TextAnchor.center)
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      Picker("Reveal", selection: Binding(
        get: { content.reveal },
        set: { perform(SetText(clipID: clip.id, reveal: $0), coalescing: nil) },
      )) {
        Text("All at once").tag(TextReveal.none)
        Text("Pop word by word").tag(TextReveal.pop)
        Text("Highlight the spoken word").tag(TextReveal.highlight)
        Text("Typewriter").tag(TextReveal.typewriter)
      }
    }
  }

  // MARK: Private

  /// The Mac's font families, read once.
  private static let families = NSFontManager.shared.availableFontFamilies.sorted()

  @Environment(Editor.self) private var editor
  @Environment(PluginLibrary.self) private var plugins
  @State private var words = ""

  /// Every plugin's text styles, by `plugin / name`.
  private var pluginStyles: [(name: String, style: TextStyle)] {
    plugins.plugins.flatMap { plugin in
      plugin.styles.map { (name: "\(plugin.name) / \($0.key)", style: $0.value) }
    }.sorted { $0.name < $1.name }
  }

  /// A binding to one style field; setting it restyles the clip.
  private func style<Value>(_ field: WritableKeyPath<TextStyle, Value>) -> Binding<Value> {
    Binding(get: { content.style[keyPath: field] }, set: { value in
      var style = content.style
      style[keyPath: field] = value
      perform(SetText(clipID: clip.id, style: style), coalescing: nil)
    })
  }

  /// A binding to one style colour, through SwiftUI's colour picker.
  private func color(_ field: WritableKeyPath<TextStyle, HexColor>) -> Binding<Color> {
    Binding(get: {
      let color = content.style[keyPath: field]
      return Color(
        .sRGB,
        red: color.red,
        green: color.green,
        blue: color.blue,
        opacity: color.alpha,
      )
    }, set: { picked in
      guard let rgb = NSColor(picked).usingColorSpace(.sRGB) else {
        return
      }
      var style = content.style
      style[keyPath: field] = HexColor(
        red: rgb.redComponent,
        green: rgb.greenComponent,
        blue: rgb.blueComponent,
        alpha: rgb.alphaComponent,
      )
      perform(SetText(clipID: clip.id, style: style), coalescing: "\(clip.id).textColor")
    })
  }

  /// A slider change to the style; a whole drag is one undo step.
  private func change(_ edit: @escaping (inout TextStyle, Double) -> Void) -> (Double) -> Void {
    { value in
      var style = content.style
      edit(&style, value)
      perform(SetText(clipID: clip.id, style: style), coalescing: "\(clip.id).textStyle")
    }
  }

  private func perform(_ command: SetText, coalescing: String?) {
    do {
      try editor.perform(command, coalescing: coalescing)
    } catch {
      onError(error.errorDescription ?? "The text couldn't be changed.")
    }
  }

}
