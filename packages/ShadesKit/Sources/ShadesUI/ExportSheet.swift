import ShadesCommands
import ShadesCore
import ShadesEngine
import ShadesExport
import SwiftUI

// MARK: - ExportSheet

/// ⌘E: picks what to export (YouTube, shorts, a frame, a GIF or captions), its name and folder,
/// and queues it. Editing carries on while it exports.
struct ExportSheet: View {

  // MARK: Internal

  var body: some View {
    Form {
      Picker("Export", selection: $kind) {
        ForEach(ExportKind.allCases, id: \.self) { kind in
          Text(kind.title).tag(kind)
        }
      }
      .pickerStyle(.segmented)
      TextField("Name", text: $name)
      LabeledContent("Folder") {
        HStack {
          Text(folder.path(percentEncoded: false).replacing(NSHomeDirectory(), with: "~"))
            .lineLimit(1)
            .truncationMode(.middle)
          Button("Choose…") { isChoosingFolder = true }
        }
      }
      if kind == .youtube || kind == .shorts {
        Picker("Codec", selection: $codec) {
          Text(verbatim: "HEVC").tag(VideoCodec.hevc)
          Text(verbatim: "H.264").tag(VideoCodec.h264)
        }
        .pickerStyle(.segmented)
      }
      Text(detail)
        .foregroundStyle(Theme.secondaryText)
        .fixedSize(horizontal: false, vertical: true)
      if let problem {
        Text(problem).foregroundStyle(.red)
      }
    }
    .formStyle(.grouped)
    .frame(width: 460)
    .fileImporter(isPresented: $isChoosingFolder, allowedContentTypes: [.folder]) { result in
      if case .success(let url) = result {
        folder = url
      }
    }
    .onAppear { name = workspace.projectName }
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Cancel") { dismiss() }
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("Export") { export() }
          .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
      }
    }
  }

  // MARK: Private

  @Environment(Workspace.self) private var workspace
  @Environment(Editor.self) private var editor
  @Environment(Player.self) private var player
  @Environment(\.dismiss) private var dismiss
  @State private var kind = ExportKind.youtube
  @State private var name = ""
  @State private var folder = URL.moviesDirectory
  @State private var codec = VideoCodec.hevc
  @State private var isChoosingFolder = false
  @State private var problem: String?

  /// The selected clips' stretch, for a GIF; `nil` exports all of the timeline.
  private var selectedRange: TimeRange? {
    let clips = editor.project.timeline.allClips.filter { editor.selection.contains($0.id) }
    guard let start = clips.map(\.timelineStart).min(), let end = clips.map(\.timelineEnd).max()
    else {
      return nil
    }
    return TimeRange(start: start, end: end)
  }

  /// What the chosen export will make, in words.
  private var detail: String {
    let timeline = editor.project.timeline
    let format = timeline.format
    switch kind {
    case .youtube:
      let size = Canvas.youtube.size(for: format)
      return "The \(format.width)×\(format.height) picture centred on \(Int(size.width))×"
        + "\(Int(size.height)) black, \(Timecode.short(timeline.duration.seconds)) long."

    case .shorts:
      guard !timeline.shorts.isEmpty else {
        return "No shorts are marked, so the whole timeline exports on 1080×1920. Mark shorts "
          + "with Claude (add_short)."
      }
      return "\(timeline.shorts.count) short\(timeline.shorts.count == 1 ? "" : "s"), each its "
        + "own file on 1080×1920: " + timeline.shorts.map(\.name).joined(separator: ", ") + "."

    case .frame:
      return "The frame at the playhead (\(Timecode.short(player.currentTime))) as a full-size PNG."

    case .gif:
      let range = selectedRange ?? TimeRange(start: .zero, end: timeline.duration)
      return "\(selectedRange == nil ? "The whole timeline" : "The selected clips") "
        + "(\(Timecode.short(range.duration.seconds))) as a looping GIF, 640 px at 15 fps. GIFs "
        + "can be up to \(Int(StillExporter.longestGIF)) s."

    case .srt:
      return "The captions as subtitles (SRT) for YouTube: the caption clips, or lines made from "
        + "the transcript."
    }
  }

  private func export() {
    let request = ExportRequest(
      kind: kind,
      folder: folder,
      name: name.trimmingCharacters(in: .whitespaces),
      codec: codec,
      time: MediaTime(seconds: player.currentTime)
        .roundedToFrame(at: editor.project.timeline.format.framesPerSecond),
      range: kind == .gif ? selectedRange : nil,
    )
    do {
      _ = try workspace.export(request)
      dismiss()
    } catch {
      problem = error.errorDescription
    }
  }

}

extension ExportKind {
  /// The kind's name in the export sheet.
  var title: String {
    switch self {
    case .youtube: "YouTube"
    case .shorts: "Shorts"
    case .frame: "Frame"
    case .gif: "GIF"
    case .srt: "SRT"
    }
  }
}
