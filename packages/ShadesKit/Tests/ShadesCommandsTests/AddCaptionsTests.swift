import ShadesCommands
import ShadesCore
import Testing

struct AddCaptionsTests {

  // MARK: Internal

  @Test
  func `captions stay together on one track, beside a title rather than over it`() throws {
    var project = Project()
    try AddText(text: "TITLE", at: seconds(1), duration: seconds(1)).apply(to: &project)
    try AddCaptions(
      lines: [line("one", 0, 1), line("two", 1, 2), line("three", 2, 3)],
      style: nil,
      reveal: .highlight,
    ).apply(to: &project)
    let tracks = project.timeline.tracks.filter { $0.kind == .text }
    #expect(tracks.map { $0.clips.map { $0.text?.text } } == [["TITLE"], ["one", "two", "three"]])
    #expect(tracks[1].clips.allSatisfy { $0.text?.reveal == .highlight })
  }

  @Test
  func `captions use a free text track that's already there`() throws {
    var project = Project()
    try AddText(text: "TITLE", at: seconds(5), duration: seconds(1)).apply(to: &project)
    try AddCaptions(lines: [line("one", 0, 1)], style: nil, reveal: .none).apply(to: &project)
    #expect(project.timeline.tracks.count(where: { $0.kind == .text }) == 1)
  }

  // MARK: Private

  private func line(_ text: String, _ start: Double, _ end: Double) -> AddCaptions.Line {
    AddCaptions.Line(text: text, start: seconds(start), end: seconds(end), words: [])
  }

}
