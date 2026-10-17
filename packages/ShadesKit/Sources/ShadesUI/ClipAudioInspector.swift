import ShadesCommands
import ShadesCore
import SwiftUI

/// Audio tab for a clip: its volume, and whether a video clip plays its own sound.
struct ClipAudioInspector: View {

  // MARK: Internal

  let clip: Clip
  let isVideoTrack: Bool
  let onError: (String) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      InspectorSlider(
        label: "Volume",
        value: clip.volume,
        range: 0 ... 4,
        format: decibels,
        onChange: { set(SetClip(clipID: clip.id, volume: $0), coalescing: "volume") },
        onEnd: editor.endCoalescing,
      )
      if isVideoTrack {
        Toggle("Play the clip's own sound", isOn: Binding(
          get: { clip.isAudioEnabled },
          set: { set(SetClip(clipID: clip.id, audioEnabled: $0), coalescing: nil) },
        ))
      }
    }
  }

  // MARK: Private

  @Environment(Editor.self) private var editor

  /// Linear gain as decibels: 1 → "0 dB", 2 → "+6 dB", 0 → "−∞".
  private func decibels(_ gain: Double) -> String {
    guard gain > 0.001 else {
      return "−∞ dB"
    }
    let value = 20 * log10(gain)
    return String(format: "%+.1f dB", value)
  }

  private func set(_ command: SetClip, coalescing key: String?) {
    do {
      try editor.perform(command, coalescing: key.map { "\(clip.id).\($0)" })
    } catch {
      onError(error.errorDescription ?? "The clip couldn't be changed.")
    }
  }

}
