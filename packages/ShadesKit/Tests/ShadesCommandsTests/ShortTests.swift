import ShadesCommands
import ShadesCore
import Testing

struct ShortTests {

  // MARK: Internal

  @Test
  func `a short is a named stretch of the timeline, snapped to frames`() throws {
    var project = try timeline()
    try AddShort(name: "Short 1", start: seconds(1.01), end: seconds(3)).apply(to: &project)
    let short = try #require(project.timeline.shorts.first)
    #expect(short.name == "Short 1")
    #expect(short.range == TimeRange(start: seconds(1), end: seconds(3)))
  }

  @Test
  func `a short must end after it starts and within the timeline`() throws {
    var project = try timeline()
    #expect(throws: CommandError.invalidRange("a short needs an end after its start")) {
      try AddShort(name: "Backwards", start: seconds(2), end: seconds(1)).apply(to: &project)
    }
    #expect(throws: CommandError.invalidRange("the short ends after the timeline does")) {
      try AddShort(name: "Long", start: seconds(1), end: seconds(9)).apply(to: &project)
    }
  }

  @Test
  func `removing a short leaves the timeline alone`() throws {
    var project = try timeline()
    try AddShort(name: "Short 1", start: seconds(0), end: seconds(2)).apply(to: &project)
    let before = project.timeline.tracks
    let id = try #require(project.timeline.shorts.first?.id)
    try RemoveShort(shortID: id).apply(to: &project)
    #expect(project.timeline.shorts.isEmpty)
    #expect(project.timeline.tracks == before)
    #expect(throws: CommandError.shortNotFound(id)) {
      try RemoveShort(shortID: id).apply(to: &project)
    }
  }

  // MARK: Private

  private func timeline() throws -> Project {
    let video = makeMedia(seconds: 4)
    var project = Project(media: [video])
    try AppendClip(mediaID: video.id).apply(to: &project)
    return project
  }

}
