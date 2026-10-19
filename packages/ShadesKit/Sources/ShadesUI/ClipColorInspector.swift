import AppKit
import ShadesCommands
import ShadesCore
import ShadesPlugins
import SwiftUI

// MARK: - ClipColorInspector

/// Color tab for a clip: its grade, LUT, film-look effects, key and blend mode. For an
/// adjustment clip these change everything under it.
struct ClipColorInspector: View {

  // MARK: Internal

  let clip: Clip
  let onError: (String) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if !looks.isEmpty {
        Menu("Plugin Look") {
          ForEach(looks, id: \.self) { name in
            Button(name) { use(look: name) }
          }
        }
        .fixedSize()
      }
      ForEach(GradeControl.allCases, id: \.self) { control in
        InspectorSlider(
          label: control.label,
          value: grade[keyPath: control.field],
          range: control.range,
          format: control.format,
          onChange: { value in
            var changed = grade
            changed[keyPath: control.field] = value
            set(grade: changed)
          },
          onEnd: editor.endCoalescing,
        )
      }
      LUTMenu(selected: grade.lut, luts: allLUTs) { path in
        var changed = grade
        changed.lut = path
        set(grade: changed)
      }
      Hairline()
      ForEach(EffectControl.allCases, id: \.self) { control in
        InspectorSlider(
          label: control.label,
          value: effects[keyPath: control.field],
          range: 0 ... 1,
          format: { "\(Int(($0 * 100).rounded()))%" },
          onChange: { value in
            var changed = effects
            changed[keyPath: control.field] = value
            set(effects: changed)
          },
          onEnd: editor.endCoalescing,
        )
      }
      Toggle("Key out green", isOn: Binding(get: { effects.key != nil }, set: { isOn in
        var changed = effects
        changed.key = isOn ? ChromaKey() : nil
        set(effects: changed)
      }))
      Picker("Blend", selection: Binding(
        get: { clip.blend },
        set: { perform(SetLook(clipIDs: [clip.id], blend: $0), coalescing: nil) },
      )) {
        ForEach(BlendMode.allCases, id: \.self) { mode in
          Text(mode.rawValue.capitalized).tag(mode)
        }
      }
      Button("Reset Color") {
        perform(SetLook(clipIDs: [clip.id], blend: .normal, clear: true), coalescing: nil)
      }
      .buttonStyle(CapsuleButtonStyle())
    }
  }

  // MARK: Private

  @Environment(Editor.self) private var editor
  @Environment(PluginLibrary.self) private var plugins

  private var grade: Grade {
    clip.grade ?? Grade()
  }

  private var effects: Effects {
    clip.effects ?? Effects()
  }

  /// Every plugin's LUTs, by name.
  private var allLUTs: [(name: String, path: String)] {
    plugins.plugins.flatMap { plugin in
      plugin.luts.map { (name: "\(plugin.name) / \($0.key)", path: $0.value.path) }
    }.sorted { $0.name < $1.name }
  }

  /// Every plugin's looks, as `plugin/name`.
  private var looks: [String] {
    plugins.plugins.flatMap { plugin in plugin.looks.keys.map { "\(plugin.name)/\($0)" } }.sorted()
  }

  private func use(look name: String) {
    guard let look = plugins.look(named: name) else {
      return
    }
    perform(
      SetLook(
        clipIDs: [clip.id],
        grade: look.grade,
        effects: look.effects,
        blend: look.blend,
        clear: true,
      ),
      coalescing: nil,
    )
  }

  private func set(grade: Grade) {
    perform(SetLook(clipIDs: [clip.id], grade: grade), coalescing: "\(clip.id).grade")
  }

  private func set(effects: Effects) {
    perform(SetLook(clipIDs: [clip.id], effects: effects), coalescing: "\(clip.id).effects")
  }

  private func perform(_ command: SetLook, coalescing: String?) {
    do {
      try editor.perform(command, coalescing: coalescing)
    } catch {
      onError(error.errorDescription ?? "The look couldn't be changed.")
    }
  }

}

// MARK: - GradeControl

/// A grade slider: its label, field, range and how its value reads.
private enum GradeControl: CaseIterable {
  case exposure
  case contrast
  case saturation
  case temperature
  case tint
  case lift
  case gamma
  case gain

  // MARK: Internal

  var label: String {
    switch self {
    case .exposure: "Exposure"
    case .contrast: "Contrast"
    case .saturation: "Saturation"
    case .temperature: "Temperature"
    case .tint: "Tint"
    case .lift: "Shadows"
    case .gamma: "Midtones"
    case .gain: "Highlights"
    }
  }

  var field: WritableKeyPath<Grade, Double> {
    switch self {
    case .exposure: \.exposure
    case .contrast: \.contrast
    case .saturation: \.saturation
    case .temperature: \.temperature
    case .tint: \.tint
    case .lift: \.lift
    case .gamma: \.gamma
    case .gain: \.gain
    }
  }

  var range: ClosedRange<Double> {
    switch self {
    case .exposure: -3 ... 3
    case .contrast,
         .saturation,
         .gamma,
         .gain: 0 ... 2
    case .temperature,
         .tint: -1 ... 1
    case .lift: -0.5 ... 0.5
    }
  }

  func format(_ value: Double) -> String {
    self == .exposure ? String(format: "%+.1f", value) : String(format: "%.2f", value)
  }
}

// MARK: - EffectControl

/// A film-look effect slider.
private enum EffectControl: CaseIterable {
  case grain
  case vignette
  case halation
  case blur

  // MARK: Internal

  var label: String {
    switch self {
    case .grain: "Grain"
    case .vignette: "Vignette"
    case .halation: "Halation"
    case .blur: "Blur"
    }
  }

  var field: WritableKeyPath<Effects, Double> {
    switch self {
    case .grain: \.grain
    case .vignette: \.vignette
    case .halation: \.halation
    case .blur: \.blur
    }
  }
}
