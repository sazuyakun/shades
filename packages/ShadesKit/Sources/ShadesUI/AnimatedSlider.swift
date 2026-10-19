import ShadesCommands
import ShadesCore
import ShadesEngine
import SwiftUI

/// A slider for one animatable property, with a diamond that adds or removes a keyframe at the
/// playhead. Once the property has keyframes, dragging sets the keyframe at the playhead.
struct AnimatedSlider: View {

  // MARK: Internal

  let clip: Clip
  let property: AnimatedProperty
  let onError: (String) -> Void

  var body: some View {
    let playhead = MediaTime(seconds: player.currentTime)
      .roundedToFrame(at: editor.project.timeline.format.framesPerSecond)
    let isInside = clip.timelineStart <= playhead && playhead <= clip.timelineEnd
    let keyHere = keys.contains { $0.time == clip.sourceTime(at: playhead) }
    HStack(alignment: .bottom, spacing: 8) {
      InspectorSlider(
        label: property.label,
        value: clip.value(of: property, at: playhead),
        range: property.range,
        format: property.format,
        onChange: { change(to: $0, at: playhead, isInside: isInside) },
        onEnd: editor.endCoalescing,
      )
      Button {
        toggleKeyframe(at: playhead, removing: keyHere)
      } label: {
        Image(systemName: keyHere ? "diamond.fill" : "diamond")
          .foregroundStyle(keys.isEmpty ? Theme.faintText : Theme.text)
      }
      .buttonStyle(.plain)
      .disabled(!isInside)
      .help(keyHere ? "Remove the keyframe at the playhead" : "Add a keyframe at the playhead")
    }
  }

  // MARK: Private

  @Environment(Editor.self) private var editor
  @Environment(Player.self) private var player

  private var keys: [Keyframe] {
    clip.keyframes.filter { $0.property == property }
  }

  private func change(to value: Double, at playhead: MediaTime, isInside: Bool) {
    let coalescing = "\(clip.id).\(property.rawValue)"
    if keys.isEmpty || !isInside {
      perform(property.fixedEdit(value, on: clip.id), coalescing: coalescing)
    } else {
      perform(setKey(value, at: playhead), coalescing: coalescing)
    }
  }

  private func toggleKeyframe(at playhead: MediaTime, removing: Bool) {
    if removing {
      perform(RemoveKeyframes(clipID: clip.id, property: property, at: playhead), coalescing: nil)
    } else {
      perform(setKey(clip.value(of: property, at: playhead), at: playhead), coalescing: nil)
    }
  }

  private func setKey(_ value: Double, at playhead: MediaTime) -> SetKeyframes {
    let easing = keys.last { $0.time <= clip.sourceTime(at: playhead) }?.easing
    return SetKeyframes(clipID: clip.id, keyframes: [
      SetKeyframes.Key(property: property, at: playhead, value: value, easing: easing)
    ])
  }

  private func perform(_ command: some ToolCommand, coalescing: String?) {
    do {
      try editor.perform(command, coalescing: coalescing)
    } catch {
      onError(error.errorDescription ?? "The clip couldn't be changed.")
    }
  }

}
