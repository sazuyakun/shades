import ShadesCommands
import ShadesCore
import SwiftUI

/// How much is cut off each edge of a clip's picture.
struct CropControls: View {

  // MARK: Internal

  let clip: Clip
  let onError: (String) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      ForEach(Edge.allCases, id: \.self) { edge in
        InspectorSlider(
          label: "Crop \(edge.title)",
          value: clip.crop[keyPath: edge.keyPath],
          range: 0 ... 0.95,
          format: { "\(Int(($0 * 100).rounded()))%" },
          onChange: { set(edge, to: $0) },
          onEnd: editor.endCoalescing,
        )
      }
    }
  }

  // MARK: Private

  /// One side of the picture, and where the crop keeps it.
  private enum Edge: CaseIterable {
    case left
    case right
    case top
    case bottom

    // MARK: Internal

    var title: String {
      switch self {
      case .left: "Left"
      case .right: "Right"
      case .top: "Top"
      case .bottom: "Bottom"
      }
    }

    var keyPath: WritableKeyPath<Crop, Double> {
      switch self {
      case .left: \.left
      case .right: \.right
      case .top: \.top
      case .bottom: \.bottom
      }
    }

    /// The edge across from it, which together with it must leave some picture.
    var opposite: WritableKeyPath<Crop, Double> {
      switch self {
      case .left: \.right
      case .right: \.left
      case .top: \.bottom
      case .bottom: \.top
      }
    }
  }

  @Environment(Editor.self) private var editor

  /// Crops `edge` to `value`, stopping short of the opposite edge.
  private func set(_ edge: Edge, to value: Double) {
    var crop = clip.crop
    crop[keyPath: edge.keyPath] = min(value, 0.95 - crop[keyPath: edge.opposite])
    do {
      try editor.perform(SetClip(clipID: clip.id, crop: crop), coalescing: "\(clip.id).crop")
    } catch {
      onError(error.errorDescription ?? "The crop couldn't be changed.")
    }
  }

}
