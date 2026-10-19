import ShadesCommands
import ShadesCore
import SwiftUI

/// The selected clip (or, with none, the media chosen in the browser) under Video / Color /
/// Audio / Info tabs.
struct InspectorPane: View {

  // MARK: Internal

  let selection: Media.ID?
  let onError: (String) -> Void

  var body: some View {
    let timeline = editor.project.timeline
    let clip = editor.selection.count == 1
      ? editor.selection.first.flatMap(timeline.clip(withID:))
      : nil
    let media = (clip?.mediaID ?? selection).flatMap(editor.project.media(withID:))
    VStack(alignment: .leading, spacing: 0) {
      SectionLabel(title: media?.name ?? "Inspector", detail: clip.map { _ in "Clip" })
      CapsuleGroup {
        ForEach(InspectorTab.allCases, id: \.self) { item in
          Button(item.rawValue) { tab = item }
            .buttonStyle(CapsuleButtonStyle(isOn: tab == item))
        }
      }
      .padding(.horizontal, 14)
      .padding(.bottom, 10)
      Hairline()
      ScrollView {
        content(clip: clip, media: media)
          .font(.callout)
          .padding(14)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .background(Theme.background)
  }

  // MARK: Private

  @Environment(Editor.self) private var editor
  @State private var tab = InspectorTab.video

  @ViewBuilder
  private func content(clip: Clip?, media: Media?) -> some View {
    let kind = clip.flatMap { editor.project.timeline.location(ofClip: $0.id) }
      .map { editor.project.timeline.tracks[$0.track].kind }
    let isVideoTrack = kind == .video
    switch tab {
    case .video:
      if clip?.source == .adjustment {
        hint("An adjustment changes everything under it. Set its look in the Color tab.")
      } else if let clip, kind == .video || kind == .text {
        ClipVideoInspector(clip: clip, onError: onError)
      } else {
        hint(clip == nil
          ? "Select a clip on the timeline to adjust it."
          : "Sound clips have no picture.")
      }

    case .color:
      if let clip, kind == .video {
        ClipColorInspector(clip: clip, onError: onError)
      } else {
        hint(clip == nil
          ? "Select a clip on the timeline to grade it."
          : "Text keeps its own colours; change them in the Video tab.")
      }

    case .audio:
      if let clip, media?.hasAudio == true {
        ClipAudioInspector(clip: clip, isVideoTrack: isVideoTrack, onError: onError)
      } else {
        hint(clip == nil
          ? "Select a clip on the timeline to adjust its sound."
          : "This clip has no sound.")
      }

    case .info:
      if let media {
        MediaInfo(media: media, framesPerSecond: editor.project.timeline.format.framesPerSecond)
      } else {
        hint("Select a clip to see its details.")
      }
    }
  }

  private func hint(_ text: String) -> some View {
    Text(text).foregroundStyle(Theme.faintText)
  }

}
