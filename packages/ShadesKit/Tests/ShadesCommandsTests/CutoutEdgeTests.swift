import ShadesCommands
import ShadesCore
import Testing

struct CutoutEdgeTests {

  // MARK: Internal

  @Test
  func `set_clip refines the cut-out edge and replaces it whole`() throws {
    var project = try oneClip()
    let id = try #require(project.timeline.allClips.first?.id)
    try SetClip(clipID: id, cutoutEdge: CutoutEdge(feather: 0.02, choke: -0.01))
      .apply(to: &project)
    #expect(project.timeline.clip(withID: id)?.cutoutEdge == CutoutEdge(
      feather: 0.02,
      choke: -0.01,
    ))
    try SetClip(clipID: id, cutoutEdge: CutoutEdge(smoothing: 0.5)).apply(to: &project)
    #expect(project.timeline.clip(withID: id)?.cutoutEdge == CutoutEdge(smoothing: 0.5))
  }

  @Test
  func `edge values out of range are refused and a split keeps the edge`() throws {
    var project = try oneClip()
    let id = try #require(project.timeline.allClips.first?.id)
    for edge in [CutoutEdge(feather: 0.2), CutoutEdge(choke: 0.1), CutoutEdge(smoothing: -1)] {
      #expect(throws: CommandError.self) {
        try SetClip(clipID: id, cutoutEdge: edge).apply(to: &project)
      }
    }
    try SetClip(clipID: id, cutoutEdge: CutoutEdge(choke: 0.02)).apply(to: &project)
    try SplitClip(clipID: id, at: seconds(2)).apply(to: &project)
    #expect(project.timeline.allClips.map(\.cutoutEdge) == [
      CutoutEdge(choke: 0.02),
      CutoutEdge(choke: 0.02),
    ])
  }

  // MARK: Private

  private let video = makeMedia(seconds: 4)

  private func oneClip() throws -> Project {
    var project = Project(media: [video])
    try AppendClip(mediaID: video.id).apply(to: &project)
    return project
  }

}
