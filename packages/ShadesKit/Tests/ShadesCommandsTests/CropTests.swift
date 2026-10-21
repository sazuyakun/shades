import ShadesCommands
import ShadesCore
import Testing

struct CropTests {

  // MARK: Internal

  @Test
  func `set_clip crops each edge and replaces the whole crop`() throws {
    var project = try oneClip()
    let id = try #require(project.timeline.allClips.first?.id)
    try SetClip(clipID: id, crop: Crop(left: 0.1, top: 0.2)).apply(to: &project)
    #expect(project.timeline.clip(withID: id)?.crop == Crop(left: 0.1, top: 0.2))
    try SetClip(clipID: id, crop: Crop(right: 0.3)).apply(to: &project)
    #expect(project.timeline.clip(withID: id)?.crop == Crop(right: 0.3))
    try SetClip(clipID: id, x: 0.2).apply(to: &project)
    #expect(project.timeline.clip(withID: id)?.crop == Crop(right: 0.3))
  }

  @Test
  func `a crop that leaves no picture or goes negative is refused`() throws {
    var project = try oneClip()
    let id = try #require(project.timeline.allClips.first?.id)
    #expect(throws: CommandError.self) {
      try SetClip(clipID: id, crop: Crop(left: 0.6, right: 0.4)).apply(to: &project)
    }
    #expect(throws: CommandError.self) {
      try SetClip(clipID: id, crop: Crop(top: -0.1)).apply(to: &project)
    }
    #expect(project.timeline.clip(withID: id)?.crop == Crop.none)
  }

  @Test
  func `a split keeps the crop on both halves`() throws {
    var project = try oneClip()
    let id = try #require(project.timeline.allClips.first?.id)
    try SetClip(clipID: id, crop: Crop(bottom: 0.2)).apply(to: &project)
    try SplitClip(clipID: id, at: seconds(2)).apply(to: &project)
    #expect(project.timeline.allClips.map(\.crop) == [Crop(bottom: 0.2), Crop(bottom: 0.2)])
  }

  // MARK: Private

  private let video = makeMedia(seconds: 4)

  private func oneClip() throws -> Project {
    var project = Project(media: [video])
    try AppendClip(mediaID: video.id).apply(to: &project)
    return project
  }

}
