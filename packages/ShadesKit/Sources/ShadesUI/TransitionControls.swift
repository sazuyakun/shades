import ShadesCommands
import ShadesCore
import SwiftUI

/// How a clip comes in from the clip that ends where it starts: a plain cut or a transition,
/// and how long it takes.
struct TransitionControls: View {

  // MARK: Internal

  let clip: Clip
  /// The clip before the cut.
  let outgoing: Clip
  let onError: (String) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Picker("Transition In", selection: Binding(
        get: { clip.transitionIn?.kind },
        set: { kind in
          let length = clip.transitionIn?.duration.seconds ?? min(0.5, longest)
          set(kind, seconds: length, coalescing: false)
        },
      )) {
        Text("Cut").tag(TransitionKind?.none)
        ForEach(TransitionKind.allCases, id: \.self) { kind in
          Text(Self.label(of: kind)).tag(TransitionKind?.some(kind))
        }
      }
      .help("How this clip comes in from the one before it, centred on the cut")
      if let transition = clip.transitionIn {
        InspectorSlider(
          label: "Transition Length",
          value: transition.duration.seconds,
          range: frame ... max(longest, frame),
          format: { String(format: "%.2f s", $0) },
          onChange: { set(transition.kind, seconds: $0, coalescing: true) },
          onEnd: editor.endCoalescing,
        )
      }
    }
  }

  // MARK: Private

  @Environment(Editor.self) private var editor

  private var frame: Double {
    editor.project.timeline.format.frameDuration.seconds
  }

  /// A transition lasts at most the shorter of the two clips.
  private var longest: Double {
    min(clip.duration, outgoing.duration).seconds
  }

  private static func label(of kind: TransitionKind) -> String {
    switch kind {
    case .dissolve: "Dissolve"
    case .dipToBlack: "Dip to Black"
    case .flash: "Flash"
    case .whip: "Whip Pan"
    case .push: "Push"
    case .slices: "Slices"
    case .tiles: "Tiles"
    case .iris: "Iris"
    case .portal: "Portal (Zoom Through)"
    }
  }

  private func set(_ kind: TransitionKind?, seconds: Double, coalescing: Bool) {
    do {
      try editor.perform(
        SetTransition(clipID: clip.id, kind: kind, duration: MediaTime(seconds: seconds)),
        coalescing: coalescing ? "\(clip.id).transition" : nil,
      )
    } catch {
      onError(error.errorDescription ?? "The transition couldn't be set.")
    }
  }

}
