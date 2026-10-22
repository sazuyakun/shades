import ShadesCommands
import ShadesCore
import SwiftUI

/// How the clip's cut-out edge is refined: its feather, choke and smoothing.
struct CutoutEdgeControls: View {

  // MARK: Internal

  let clip: Clip
  let onError: (String) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      InspectorSlider(
        label: "Cut-out Feather",
        value: clip.cutoutEdge.feather,
        range: 0 ... 0.05,
        format: { String(format: "%.1f%%", $0 * 100) },
        onChange: { value in set { $0.feather = value } },
        onEnd: editor.endCoalescing,
      )
      .help("Softens the cut-out's edge")
      InspectorSlider(
        label: "Cut-out Choke",
        value: clip.cutoutEdge.choke,
        range: -0.03 ... 0.03,
        format: { String(format: "%+.1f%%", $0 * 100) },
        onChange: { value in set { $0.choke = value } },
        onEnd: editor.endCoalescing,
      )
      .help("Pulls the cut-out's edge in (positive) or pushes it out (negative)")
      InspectorSlider(
        label: "Cut-out Smoothing",
        value: clip.cutoutEdge.smoothing,
        range: 0 ... 1,
        format: { "\(Int(($0 * 100).rounded()))%" },
        onChange: { value in set { $0.smoothing = value } },
        onEnd: editor.endCoalescing,
      )
      .help("Rounds off a jagged cut-out edge and fills small holes")
    }
  }

  // MARK: Private

  @Environment(Editor.self) private var editor

  private func set(_ change: (inout CutoutEdge) -> Void) {
    var edge = clip.cutoutEdge
    change(&edge)
    do {
      try editor.perform(SetClip(clipID: clip.id, cutoutEdge: edge), coalescing: "\(clip.id).edge")
    } catch {
      onError(error.errorDescription ?? "The cut-out edge couldn't be changed.")
    }
  }

}
