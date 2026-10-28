import ShadesAudio
import ShadesCommands
import ShadesCore
import ShadesEngine
import SwiftUI

/// One track in the mixer: its name, mute and solo, its meter, level and pan.
struct MixerStrip: View {

  // MARK: Internal

  let track: Track
  /// How loud the track plays at the playhead, after its level.
  let level: MeterLevel?
  let onError: (String) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 6) {
        Text(label).font(.caption.weight(.semibold))
        Spacer()
        Button("M") { perform(SetTrack(track: label, muted: !track.isMuted), key: nil) }
          .buttonStyle(CapsuleButtonStyle(isOn: track.isMuted))
          .help("Mute this track")
        Button("S") { perform(SetTrack(track: label, soloed: !track.isSoloed), key: nil) }
          .buttonStyle(CapsuleButtonStyle(isOn: track.isSoloed))
          .help("Solo: hear only soloed tracks")
      }
      LevelMeter(level: level)
      InspectorSlider(
        label: "Level",
        value: track.volume,
        range: 0 ... 2,
        format: Level.decibels,
        onChange: { perform(SetTrack(track: label, volume: $0), key: "volume") },
        onEnd: editor.endCoalescing,
      )
      InspectorSlider(
        label: "Pan",
        value: track.pan,
        range: -1 ... 1,
        format: Level.pan,
        onChange: { perform(SetTrack(track: label, pan: $0), key: "pan") },
        onEnd: editor.endCoalescing,
      )
    }
  }

  // MARK: Private

  @Environment(Editor.self) private var editor

  private var label: String {
    editor.project.timeline.label(of: track)
  }

  private func perform(_ command: SetTrack, key: String?) {
    do {
      try editor.perform(command, coalescing: key.map { "track.\(track.id).\($0)" })
    } catch {
      onError(error.errorDescription ?? "The track couldn't be changed.")
    }
  }

}
