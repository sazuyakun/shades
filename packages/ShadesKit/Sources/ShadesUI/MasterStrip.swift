import ShadesAudio
import ShadesCommands
import ShadesCore
import ShadesEngine
import ShadesMCP
import SwiftUI

/// The mixer's master: the whole mix's meter and level, and loudness normalising for a
/// platform, which also sets the limiter.
struct MasterStrip: View {

  // MARK: Internal

  /// How loud the whole mix plays at the playhead.
  let level: MeterLevel?
  let onError: (String) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Master").font(.caption.weight(.semibold))
        Spacer()
        if !editor.project.timeline.limiter.isEmpty {
          Text("Limiter on")
            .font(.caption)
            .foregroundStyle(Theme.secondaryText)
            .help("Normalising set a limiter that keeps true peaks under −1 dBTP")
        }
      }
      LevelMeter(level: level)
      InspectorSlider(
        label: "Level",
        value: editor.project.timeline.gain,
        range: 0 ... 2,
        format: Level.decibels,
        onChange: { level($0) },
        onEnd: editor.endCoalescing,
      )
      HStack {
        Picker("Loudness for", selection: $platform) {
          ForEach(LoudnessTarget.allCases, id: \.self) { target in
            Text(verbatim: "\(target.title) (\(Int(target.lufs)) LUFS)").tag(target)
          }
        }
        .controlSize(.small)
        Button("Normalize") { normalize() }
          .disabled(isNormalizing)
      }
      if let report {
        Text(report)
          .font(.caption)
          .foregroundStyle(Theme.secondaryText)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  // MARK: Private

  @Environment(Editor.self) private var editor
  @Environment(Workspace.self) private var workspace
  @State private var platform = LoudnessTarget.youtube
  @State private var isNormalizing = false
  @State private var report: String?

  private func level(_ gain: Double) {
    do {
      try editor.perform(SetMasterGain(gain: gain), coalescing: "master")
    } catch {
      onError(error.errorDescription ?? "The master level couldn't be changed.")
    }
  }

  private func normalize() {
    isNormalizing = true
    Task {
      do throws(ToolError) {
        report = try await workspace.normalizeLoudness(target: platform.lufs)
      } catch {
        onError(error.errorDescription ?? "The loudness couldn't be measured.")
      }
      isNormalizing = false
    }
  }

}
