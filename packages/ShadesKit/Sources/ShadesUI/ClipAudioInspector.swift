import ShadesCommands
import ShadesCore
import SwiftUI

/// Audio tab for a clip: its volume (with keyframes), fades, noise reduction and stem separation,
/// whether a video clip plays its own sound, and the levels of its track and the whole mix.
struct ClipAudioInspector: View {

  // MARK: Internal

  let clip: Clip
  let track: Track
  let onError: (String) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      AnimatedSlider(clip: clip, property: .volume, onError: onError)
      if track.kind == .audio {
        AnimatedSlider(clip: clip, property: .speed, onError: onError)
      }
      InspectorSlider(
        label: "Fade In",
        value: clip.fadeIn.seconds,
        range: 0 ... longestFade,
        format: seconds,
        onChange: { perform(SetClip(clipID: clip.id, fadeIn: MediaTime(seconds: $0)), "fadeIn") },
        onEnd: editor.endCoalescing,
      )
      InspectorSlider(
        label: "Fade Out",
        value: clip.fadeOut.seconds,
        range: 0 ... longestFade,
        format: seconds,
        onChange: { perform(SetClip(clipID: clip.id, fadeOut: MediaTime(seconds: $0)), "fadeOut") },
        onEnd: editor.endCoalescing,
      )
      Toggle("Reduce background noise", isOn: Binding(
        get: { clip.cleanSound },
        set: { cleanSound($0) },
      ))
      if track.kind == .video {
        Toggle("Play the clip's own sound", isOn: Binding(
          get: { clip.isAudioEnabled },
          set: { perform(SetClip(clipID: clip.id, audioEnabled: $0), nil) },
        ))
      }
      Button("Separate Voice and Music") { separateStems() }
        .help("Puts the clip's voice and its music on their own tracks underneath")
      Divider()
      InspectorSlider(
        label: "Track \(trackLabel) Level",
        value: track.volume,
        range: 0 ... 2,
        format: decibels,
        onChange: { perform(SetTrack(track: trackLabel, volume: $0), "track.\(track.id)") },
        onEnd: editor.endCoalescing,
      )
      InspectorSlider(
        label: "Master Level",
        value: editor.project.timeline.gain,
        range: 0 ... 2,
        format: decibels,
        onChange: { perform(SetMasterGain(gain: $0), "master") },
        onEnd: editor.endCoalescing,
      )
    }
  }

  // MARK: Private

  @Environment(Editor.self) private var editor
  @Environment(Workspace.self) private var workspace

  private var trackLabel: String {
    editor.project.timeline.label(of: track)
  }

  /// Fades can run up to half the clip each, and never past 5 s.
  private var longestFade: Double {
    max(min(clip.duration.seconds / 2, 5), 0.1)
  }

  /// Linear gain as decibels: 1 → "0 dB", 2 → "+6 dB", 0 → "−∞".
  private func decibels(_ gain: Double) -> String {
    guard gain > 0.001 else {
      return "−∞ dB"
    }
    return String(format: "%+.1f dB", 20 * log10(gain))
  }

  private func seconds(_ value: Double) -> String {
    String(format: "%.1f s", value)
  }

  private func cleanSound(_ isOn: Bool) {
    do {
      _ = try workspace.reduceNoise([clip.id], strength: isOn ? 0.7 : 0)
    } catch {
      onError(error.errorDescription ?? "The sound couldn't be cleaned.")
    }
  }

  private func separateStems() {
    do {
      _ = try workspace.separateStems([clip.id])
    } catch {
      onError(error.errorDescription ?? "The sound couldn't be separated.")
    }
  }

  private func perform(_ command: some Command, _ key: String?) {
    do {
      try editor.perform(command, coalescing: key.map { "\(clip.id).\($0)" })
    } catch {
      onError(error.errorDescription ?? "The clip couldn't be changed.")
    }
  }

}
