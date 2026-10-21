import ShadesCommands
import ShadesCore
import SwiftUI

/// Video tab for a clip: where it sits, how big, its rotation, opacity (each animatable), crop,
/// depth slot and motion blur.
struct ClipVideoInspector: View {

  // MARK: Internal

  let clip: Clip
  let onError: (String) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      if let content = clip.text {
        TextInspector(clip: clip, content: content, onError: onError)
        Hairline()
      }
      if let drawing = clip.drawing {
        DrawingInspector(clip: clip, drawing: drawing, onError: onError)
        Hairline()
      }
      ForEach(AnimatedProperty.allCases.filter { $0.isShown(for: clip) }, id: \.self) { property in
        AnimatedSlider(clip: clip, property: property, onError: onError)
      }
      if clip.source != .adjustment {
        CropControls(clip: clip, onError: onError)
      }
      if clip.isFrozen {
        Text("A freeze frame holds one frame. Trim it to change how long.")
          .foregroundStyle(Theme.faintText)
      } else if isMoving {
        AnimatedSlider(clip: clip, property: .speed, onError: onError)
      }
      Picker("Depth", selection: Binding(
        get: { clip.depth },
        set: { perform([SetClip(clipID: clip.id, depthSlot: $0)], title: SetClip.title) },
      )) {
        Text("In front").tag(DepthSlot.inFront)
        Text("Behind subject").tag(DepthSlot.behindSubject)
        Text("Inside subject").tag(DepthSlot.insideSubject)
        Text("Replace background").tag(DepthSlot.replaceBackground)
      }
      .help("Where this layer sits relative to the person cut out of the clips below it")
      MotionBlurControls(clip: clip, onError: onError)
      HStack {
        Button("Reset Transform") {
          resetTransform()
        }
        if clip.mediaID != nil {
          Menu("Reframe") {
            Button("Locked on the Subject") { reframe(locked: true) }
          } primaryAction: {
            reframe(locked: false)
          }
          .menuStyle(.button)
          .fixedSize()
          .help("Zoom to fill the 4:3 frame, panning with the subject (or locked on it)")
          Button(hasCutout ? "Cut Out Again" : "Cut Out Subject") { cutOut() }
            .help("Find the subject so layers can go behind or inside it")
        }
        Button("Follow Subject") { followSubject() }
          .help("Move with the cut-out subject of the video under this layer")
      }
      .buttonStyle(CapsuleButtonStyle())
    }
  }

  // MARK: Private

  @Environment(Editor.self) private var editor
  @Environment(Workspace.self) private var workspace

  /// Whether it plays moving media, which has a speed (stills and text don't).
  private var isMoving: Bool {
    clip.mediaID.flatMap(editor.project.media(withID:)).map { !$0.isStill } ?? false
  }

  private var hasCutout: Bool {
    clip.mediaID.flatMap { workspace.analysis.analyses[$0]?.matte } != nil
  }

  private func reframe(locked: Bool) {
    do {
      _ = try workspace.autoReframe([clip.id], locked: locked)

    } catch {
      onError(error.errorDescription ?? "The clip couldn't be reframed.")
    }
  }

  private func followSubject() {
    do {
      try workspace.followSubject(clip.id)
    } catch {
      onError(error.errorDescription ?? "The layer couldn't follow the subject.")
    }
  }

  private func cutOut() {
    guard let mediaID = clip.mediaID else {
      return
    }
    _ = workspace.makeCutouts([mediaID], engine: .visionPerson)
  }

  /// Puts the clip back upright, centered and solid, dropping its motion (its speed stays).
  private func resetTransform() {
    let reset = SetClip(clipID: clip.id, x: 0, y: 0, scale: 1, rotation: 0, opacity: 1)
    let animated = AnimatedProperty.allCases.filter { property in
      property.isVisual && clip.keyframes.contains { $0.property == property }
    }
    let commands: [any Command] = [reset]
      + animated.map { RemoveKeyframes(clipID: clip.id, property: $0) }
    perform(commands, title: "Reset Transform")
  }

  private func perform(_ commands: [any Command], title: String) {
    do {
      try editor.perform(commands, title: title)
    } catch {
      onError(error.errorDescription ?? "The clip couldn't be changed.")
    }
  }

}
