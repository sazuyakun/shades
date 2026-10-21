import ShadesEngine
import SwiftUI

/// Picks how big playback is drawn (Auto, Full or Half), in the viewer's corner. Under Auto it
/// says when playback has dropped to half size.
struct PreviewQualityMenu: View {

  // MARK: Internal

  var body: some View {
    @Bindable var player = player
    Menu {
      Picker("Preview Quality", selection: $player.previewQuality) {
        ForEach(PreviewQuality.allCases, id: \.self) { quality in
          Text(quality.title).tag(quality)
        }
      }
      .pickerStyle(.inline)
    } label: {
      Text(label)
        .font(.system(size: 10.5, weight: .semibold))
        .foregroundStyle(Theme.secondaryText)
    }
    .menuStyle(.button)
    .buttonStyle(.plain)
    .fixedSize()
    .padding(.horizontal, 8)
    .padding(.vertical, 3)
    .background(Theme.raised, in: .capsule)
    .help(
      "Preview quality (⌥H). Half draws a quarter of the pixels so heavy timelines play "
        + "smoothly; Auto drops to half only while playing can't keep up. Export is always "
        + "full size."
    )
  }

  // MARK: Private

  @Environment(Player.self) private var player

  private var label: String {
    if player.previewQuality == .auto, player.isHalfSize {
      "Auto · Half"
    } else {
      player.previewQuality.title
    }
  }

}
