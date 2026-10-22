import ShadesCommands
import ShadesCore
import ShadesEngine
import SwiftUI

/// A clip's slider for one animatable property. Once the property has keyframes, dragging sets
/// the keyframe at the playhead.
struct AnimatedSlider: View {

  // MARK: Internal

  let clip: Clip
  let property: AnimatedProperty
  let onError: (String) -> Void

  var body: some View {
    let playhead = MediaTime(seconds: player.currentTime)
      .roundedToFrame(at: editor.project.timeline.format.framesPerSecond)
    let isInside = clip.timelineStart <= playhead && playhead <= clip.timelineEnd
    let keyHere = keys.first { $0.time == clip.sourceTime(at: playhead) }
    KeyframeSlider(
      property: property,
      value: clip.value(of: property, at: playhead),
      keyHere: keyHere,
      isAnimated: !keys.isEmpty,
      canKey: isInside,
      onChange: { change(to: $0, at: playhead, isInside: isInside) },
      onEnd: editor.endCoalescing,
      onToggleKey: { toggleKeyframe(at: playhead, removing: keyHere != nil) },
      onEase: { key, easing in
        perform(setKey(key.value, at: playhead, easing: easing), coalescing: nil)
      },
    )
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
      perform(property.fixedEdit(value, on: clip), coalescing: coalescing)
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

  /// A keyframe at the playhead; without an easing it keeps the one in force there.
  private func setKey(
    _ value: Double,
    at playhead: MediaTime,
    easing: Easing? = nil,
  ) -> SetKeyframes {
    let easing = easing ?? keys.last { $0.time <= clip.sourceTime(at: playhead) }?.easing
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
