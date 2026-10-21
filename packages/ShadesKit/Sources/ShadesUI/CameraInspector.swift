import ShadesCommands
import ShadesCore
import ShadesEngine
import SwiftUI

/// The timeline's camera, shown when no clip is selected: zoom, pan, rotate, tilt and dolly the
/// whole picture with keyframes at the playhead.
struct CameraInspector: View {

  // MARK: Internal

  let onError: (String) -> Void

  var body: some View {
    let timeline = editor.project.timeline
    let playhead = MediaTime(seconds: player.currentTime)
      .roundedToFrame(at: timeline.format.framesPerSecond)
    VStack(alignment: .leading, spacing: 14) {
      Text("Camera: moves the whole picture. Select a clip to adjust it instead.")
        .foregroundStyle(Theme.faintText)
      ForEach(AnimatedProperty.cameraMoves, id: \.self) { property in
        let keys = timeline.camera.filter { $0.property == property }
        let keyHere = keys.first { $0.time == playhead }
        KeyframeSlider(
          property: property,
          value: timeline.camera.value(of: property, at: playhead, fixed: Self.rest(property)),
          keyHere: keyHere,
          isAnimated: !keys.isEmpty,
          canKey: true,
          onChange: { value in
            let easing = keys.last { $0.time <= playhead }?.easing
            move(property, to: value, at: playhead, easing: easing, coalescing: true)
          },
          onEnd: editor.endCoalescing,
          onToggleKey: {
            if let keyHere {
              remove(keyHere)
            } else {
              let value = timeline.camera.value(
                of: property,
                at: playhead,
                fixed: Self.rest(property),
              )
              move(property, to: value, at: playhead, easing: nil, coalescing: false)
            }
          },
          onEase: { key, easing in
            move(property, to: key.value, at: playhead, easing: easing, coalescing: false)
          },
        )
      }
      Button("Reset Camera") { perform(SetCamera(keyframes: [], clear: true), coalescing: false) }
        .buttonStyle(CapsuleButtonStyle())
        .disabled(timeline.camera.isEmpty)
    }
  }

  // MARK: Private

  @Environment(Editor.self) private var editor
  @Environment(Player.self) private var player

  /// Where the camera rests with no keyframes.
  private static func rest(_ property: AnimatedProperty) -> Double {
    property == .scale ? 1 : 0
  }

  private func move(
    _ property: AnimatedProperty,
    to value: Double,
    at time: MediaTime,
    easing: Easing?,
    coalescing: Bool,
  ) {
    perform(
      SetCamera(keyframes: [
        SetKeyframes.Key(property: property, at: time, value: value, easing: easing)
      ]),
      coalescing: coalescing,
    )
  }

  /// Takes out one keyframe, keeping the rest.
  private func remove(_ keyframe: Keyframe) {
    let rest = editor.project.timeline.camera.filter { $0 != keyframe }.map {
      SetKeyframes.Key(property: $0.property, at: $0.time, value: $0.value, easing: $0.easing)
    }
    perform(SetCamera(keyframes: rest, clear: true), coalescing: false)
  }

  private func perform(_ command: SetCamera, coalescing: Bool) {
    do {
      try editor.perform(command, coalescing: coalescing ? "camera" : nil)
    } catch {
      onError(error.errorDescription ?? "The camera couldn't be moved.")
    }
  }

}
