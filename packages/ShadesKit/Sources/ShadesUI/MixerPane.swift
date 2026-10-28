import ShadesAudio
import ShadesCommands
import ShadesCore
import ShadesEngine
import SwiftUI

/// The mixer: a strip for every track that makes sound (video tracks carry their clips' own),
/// then the master. Meters move while playing.
struct MixerPane: View {

  // MARK: Internal

  let onError: (String) -> Void

  var body: some View {
    let levels = soundTracks.map { level(of: $0) }
    VStack(alignment: .leading, spacing: 0) {
      SectionLabel(title: "Mixer")
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          ForEach(Array(zip(soundTracks, levels)), id: \.0.id) { track, level in
            MixerStrip(track: track, level: level, onError: onError)
          }
          Hairline()
          MasterStrip(level: master(of: levels), onError: onError)
        }
        .padding(14)
      }
    }
    .background(Theme.background)
  }

  // MARK: Private

  @Environment(Editor.self) private var editor
  @Environment(Player.self) private var player
  @Environment(Workspace.self) private var workspace

  private var soundTracks: [Track] {
    editor.project.timeline.tracks.filter(editor.project.hasSound)
  }

  /// How loud `track` plays at the playhead: its waveform's reading through its clip's volume,
  /// its own level and the master's.
  private func level(of track: Track) -> MeterLevel? {
    let timeline = editor.project.timeline
    let time = MediaTime(seconds: player.currentTime)
    guard
      player.isPlaying,
      let reading = TrackMeter.level(
        of: track,
        in: timeline,
        at: time,
        waveforms: workspace.analysis.analyses.compactMapValues(\.waveform),
      ),
      let clip = track.clip(at: time)
    else {
      return nil
    }
    let gain = clip.gain(at: time) * track.volume * timeline.gain
    return MeterLevel(left: reading.left * gain, right: reading.right * gain)
  }

  /// The tracks' levels added up as power, as unrelated sounds add.
  private func master(of levels: [MeterLevel?]) -> MeterLevel? {
    let heard = levels.compactMap(\.self)
    guard !heard.isEmpty else {
      return nil
    }
    let sum = { (channel: (MeterLevel) -> Double) in
      heard.reduce(0) { $0 + channel($1) * channel($1) }.squareRoot()
    }
    return MeterLevel(left: sum(\.left), right: sum(\.right))
  }

}
