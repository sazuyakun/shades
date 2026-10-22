import ShadesCommands
import ShadesCore
import ShadesMatting
import SwiftUI

/// Video tab for a clip: where it sits, how big, its rotation, opacity (each animatable), crop,
/// masks, depth slot, motion blur, the transition into it, and its cut-out and what it follows.
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
      Hairline()
      MaskInspector(clip: clip, onError: onError)
      Hairline()
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
      if let outgoing = editor.project.timeline.clip(cuttingInto: clip) {
        TransitionControls(clip: clip, outgoing: outgoing, onError: onError)
      }
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
        }
      }
      .buttonStyle(CapsuleButtonStyle())
      HStack {
        if clip.mediaID != nil {
          Menu(hasCutout ? "Cut Out Again" : "Cut Out") {
            Button("A Person") { cutOut(.visionPerson) }
            Button("Any Object") { cutOut(.visionForeground) }
          }
          .help("Find the subject so layers can go behind or inside it")
        }
        Menu("Follow") {
          Button("The Cut-Out Subject") { follow(path: nil) }
          ForEach(workspace.paths(under: clip.id), id: \.self) { name in
            Button("Tracked \(name)") { follow(path: name) }
          }
        }
        .help("Move with something in the video under this layer: its cut-out subject, or a "
          + "path drawn with the Track tool (⌥T)")
      }
      .menuStyle(.button)
      .buttonStyle(CapsuleButtonStyle())
      .fixedSize()
      if hasCutout {
        CutoutEdgeControls(clip: clip, onError: onError)
      }
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

  private func follow(path: String?) {
    do {
      try workspace.follow(clip.id, path: path)
    } catch {
      onError(error.errorDescription ?? "The layer couldn't follow that.")
    }
  }

  private func cutOut(_ engine: MatteEngine) {
    guard let mediaID = clip.mediaID else {
      return
    }
    _ = workspace.makeCutouts([mediaID], engine: engine)
  }

  /// Puts the clip back upright, centered and solid, dropping its motion (its speed stays).
  private func resetTransform() {
    let reset = SetClip(clipID: clip.id, x: 0, y: 0, scale: 1, rotation: 0, bend: 0, opacity: 1)
    let animated = (AnimatedProperty.cameraMoves + [.bend, .opacity]).filter { property in
      clip.keyframes.contains { $0.property == property }
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
