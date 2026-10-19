import ShadesCore
import ShadesEngine
import ShadesPlugins
import SwiftUI

// MARK: - TemplatesMenu

/// Places a plugin's template at the playhead, asking for its text fields first.
struct TemplatesMenu: View {

  // MARK: Internal

  let onError: (String) -> Void

  var body: some View {
    Menu {
      if templates.isEmpty {
        Text("No templates yet: add a plugin folder in Settings")
      }
      ForEach(templates, id: \.self) { name in
        Button(name) { chosen = ChosenTemplate(name: name) }
      }
    } label: {
      Label("Templates", systemImage: "rectangle.stack")
    }
    .menuStyle(.button)
    .menuIndicator(.hidden)
    .buttonStyle(CapsuleButtonStyle())
    .fixedSize()
    .help("Place a plugin's title or motion template at the playhead")
    .sheet(item: $chosen) { chosen in
      TemplateSheet(
        name: chosen.name,
        fields: plugins.template(named: chosen.name)?.template.fields ?? [],
        onPlace: { place(chosen.name, fields: $0) },
      )
    }
  }

  // MARK: Private

  /// A template picked from the menu, waiting for its fields.
  private struct ChosenTemplate: Identifiable {
    let name: String

    var id: String {
      name
    }
  }

  @Environment(PluginLibrary.self) private var plugins
  @Environment(Workspace.self) private var workspace
  @Environment(Player.self) private var player
  @State private var chosen: ChosenTemplate?

  /// Every template, as `plugin/name`.
  private var templates: [String] {
    plugins.plugins.flatMap { plugin in plugin.templates.keys.map { "\(plugin.name)/\($0)" } }
      .sorted()
  }

  private func place(_ name: String, fields: [String: String]) {
    let time = MediaTime(seconds: player.currentTime)
    Task {
      do {
        _ = try await workspace.applyTemplate(named: name, at: time, fields: fields)
      } catch {
        onError(error.localizedDescription)
      }
    }
  }

}

// MARK: - TemplateSheet

/// Asks for a template's text fields.
private struct TemplateSheet: View {

  // MARK: Internal

  let name: String
  let fields: [String]
  let onPlace: ([String: String]) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(name).font(.headline)
      ForEach(fields, id: \.self) { field in
        TextField(field.capitalized, text: Binding(
          get: { values[field] ?? "" },
          set: { values[field] = $0 },
        ))
        .textFieldStyle(.roundedBorder)
      }
      HStack {
        Spacer()
        Button("Cancel") { dismiss() }
          .keyboardShortcut(.cancelAction)
        Button("Place at Playhead") {
          dismiss()
          onPlace(values)
        }
        .keyboardShortcut(.defaultAction)
        .disabled(fields.contains { (values[$0] ?? "").isEmpty })
      }
    }
    .padding(20)
    .frame(width: 360)
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss
  @State private var values = [String: String]()

}
