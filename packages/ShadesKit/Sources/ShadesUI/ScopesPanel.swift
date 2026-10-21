import ShadesCommands
import ShadesCore
import ShadesEngine
import SwiftUI

// MARK: - ScopesPanel

/// Waveform, vectorscope and histogram of the paused frame, beside the viewer.
struct ScopesPanel: View {

  // MARK: Internal

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      SectionLabel(title: "Scopes", detail: nil)
      if let picture {
        Image(decorative: picture, scale: 1)
          .resizable()
          .interpolation(.medium)
          .aspectRatio(contentMode: .fit)
          .padding(.horizontal, 14)
      }
      if let reading {
        ScopeNumbers(reading: reading).padding(14)
      } else {
        Text(player.isPlaying ? "Pause to read the scopes." : "Reading the frame…")
          .font(.callout)
          .foregroundStyle(Theme.faintText)
          .padding(14)
      }
      Spacer()
    }
    .background(Theme.background)
    .task(id: Moment(
      seconds: player.currentTime,
      project: editor.project,
      isPlaying: player.isPlaying,
    )) {
      await measure()
    }
  }

  // MARK: Private

  /// What the scopes depend on.
  private struct Moment: Equatable {
    let seconds: Double
    let project: Project
    let isPlaying: Bool
  }

  @Environment(Editor.self) private var editor
  @Environment(Player.self) private var player
  @State private var picture: CGImage?
  @State private var reading: ScopeReading?

  /// Measures the frame at the playhead once things have settled for a moment.
  private func measure() async {
    guard !player.isPlaying else {
      return
    }
    // why: a quick pause lets scrubbing and dragging sliders finish before measuring again.
    try? await Task.sleep(for: .milliseconds(150))
    guard !Task.isCancelled, !editor.project.timeline.allClips.isEmpty else {
      return
    }
    do {
      let frame = try await FrameRenderer.image(
        of: editor.project,
        atSeconds: player.currentTime,
        maxSide: 480,
        context: player.renderContext(),
        mattes: player.mattes,
        flows: player.flows,
      )
      (picture, reading) = try Scopes.measure(frame)
    } catch {
      reading = nil
    }
  }

}

// MARK: - ScopeNumbers

/// The scopes' numbers in words.
private struct ScopeNumbers: View {
  let reading: ScopeReading

  var body: some View {
    Grid(alignment: .leading, verticalSpacing: 4) {
      row("Brightness", reading.averageBrightness)
      row("Clipped", reading.clippedHighlights)
      row("Crushed", reading.crushedShadows)
      row("Saturation", reading.averageSaturation)
    }
    .font(.callout)
  }

  private func row(_ label: String, _ value: Double) -> some View {
    GridRow {
      Text(label).foregroundStyle(Theme.secondaryText)
      Text("\(Int((value * 100).rounded()))%").monospacedDigit().foregroundStyle(Theme.text)
    }
  }
}
