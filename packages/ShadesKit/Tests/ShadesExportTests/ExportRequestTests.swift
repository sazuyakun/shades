import Foundation
import ShadesCore
import ShadesExport
import Testing

struct ExportRequestTests {

  // MARK: Internal

  @Test
  func `shorts export one file each, named after them and safe for the finder`() {
    var timeline = timeline()
    timeline.shorts = [
      Short(name: "Short 1 · Chul/keeda", range: range(1, 3)),
      Short(name: "Short 2", range: range(5, 8)),
    ]
    let outputs = request(.shorts).outputs(for: timeline)
    #expect(outputs.map(\.url.lastPathComponent) == [
      "Vlog - Short 1 · Chul-keeda.mp4",
      "Vlog - Short 2.mp4",
    ])
    #expect(outputs.map(\.range) == [range(1, 3), range(5, 8)])
  }

  @Test
  func `without shorts, the whole timeline goes vertical in one file`() {
    let outputs = request(.shorts).outputs(for: timeline())
    #expect(outputs.map(\.url) == [folder.appending(path: "Vlog.mp4")])
    #expect(outputs.map(\.range) == [range(0, 10)])
  }

  @Test
  func `a frame is one png at its moment, a gif its range`() {
    let frame = ExportRequest(kind: .frame, folder: folder, name: "Thumb", time: seconds(4))
    #expect(frame.outputs(for: timeline()).map(\.url) == [folder.appending(path: "Thumb.png")])
    #expect(frame.outputs(for: timeline()).map(\.range) == [range(4, 4)])
    let gif = ExportRequest(kind: .gif, folder: folder, name: "Loop", range: range(2, 5))
    #expect(gif.outputs(for: timeline()).map(\.range) == [range(2, 5)])
  }

  // MARK: Private

  private let folder = URL(filePath: "/tmp/exports")

  private func request(_ kind: ExportKind) -> ExportRequest {
    ExportRequest(kind: kind, folder: folder, name: "Vlog")
  }

  private func seconds(_ value: Double) -> MediaTime {
    MediaTime(seconds: value)
  }

  private func range(_ start: Double, _ end: Double) -> TimeRange {
    TimeRange(start: seconds(start), end: seconds(end))
  }

  /// A 10-second timeline.
  private func timeline() -> Timeline {
    let media = Media(
      url: URL(filePath: "/tmp/clip.mov"),
      duration: seconds(10),
      width: 1920,
      height: 1080,
      hasAudio: false,
    )
    return Timeline(tracks: [Track(kind: .video, clips: [Clip(
      mediaID: media.id,
      sourceStart: .zero,
      duration: media.duration,
      timelineStart: .zero,
    )])])
  }

}
