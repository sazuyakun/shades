import ShadesCommands
import ShadesCore
import SwiftUI

/// Video tab for a clip: where it sits, how big, its rotation, opacity (each animatable) and depth
/// slot.
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
      ForEach(AnimatedProperty.allCases, id: \.self) { property in
        AnimatedSlider(clip: clip, property: property, onError: onError)
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
      HStack {
        Button("Reset Transform") {
          resetTransform()
        }
        if clip.mediaID != nil {
          Button("Reframe") { reframe() }
            .help("Zoom to fill the 4:3 frame, keeping the subject in view")
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

  private var hasCutout: Bool {
    clip.mediaID.flatMap { workspace.analysis.analyses[$0]?.matte } != nil
  }

  private func reframe() {
    do {
      _ = try workspace.autoReframe([clip.id])
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

  /// Puts the clip back upright, centered and solid, dropping its animation.
  private func resetTransform() {
    let reset = SetClip(clipID: clip.id, x: 0, y: 0, scale: 1, rotation: 0, opacity: 1)
    let commands: [any Command] = clip.keyframes.isEmpty
      ? [reset]
      : [reset, RemoveKeyframes(clipID: clip.id)]
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
