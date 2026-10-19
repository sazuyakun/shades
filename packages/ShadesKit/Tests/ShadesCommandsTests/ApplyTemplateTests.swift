import Foundation
import ShadesCommands
import ShadesCore
import Testing

struct ApplyTemplateTests {

  // MARK: Internal

  @Test
  func `a template's fields are found in its text, in order`() {
    #expect(lowerThird.fields == ["name", "role"])
  }

  @Test
  func `a lower third places styled text and a popping sticker with its sound`() throws {
    var project = try footage()
    try ApplyTemplate(
      lowerThird,
      at: seconds(2),
      fields: ["name": "Soham", "role": "Editor"],
      styles: ["chul": TextStyle(size: 0.1, anchor: .center)],
      media: ["camera": camera.id, "pop": pop.id],
    ).apply(to: &project)
    let texts = project.timeline.tracks.filter { $0.kind == .text }.flatMap(\.clips)
    #expect(texts.compactMap(\.text?.text).sorted() == ["Editor", "Soham"])
    let name = try #require(texts.first { $0.text?.text == "Soham" })
    #expect(name.text?.style.size == 0.1)
    #expect(name.text?.reveal == .pop)
    #expect(name.timelineStart == seconds(2))
    #expect(name.transform.y == 0.3)
    #expect(name.value(of: .x, at: seconds(2)) == -0.4)
    let role = try #require(texts.first { $0.text?.text == "Editor" })
    #expect(role.timelineStart == seconds(2.5))
    let sticker = try #require(project.timeline.allClips.first { $0.mediaID == camera.id })
    #expect(sticker.sticker != nil)
    #expect(sticker.value(of: .scale, at: seconds(2)) < 0.05)
    #expect(project.timeline.allClips.contains { $0.mediaID == pop.id })
  }

  @Test
  func `missing fields and unknown pieces are named in the error`() throws {
    var project = try footage()
    #expect(throws: CommandError.invalidArguments("fill the template's fields: role")) {
      try ApplyTemplate(
        lowerThird,
        at: .zero,
        fields: ["name": "Soham"],
        styles: ["chul": .caption],
        media: ["camera": camera.id, "pop": pop.id],
      ).apply(to: &project)
    }
    #expect(throws: CommandError.self) {
      try ApplyTemplate(
        lowerThird,
        at: .zero,
        fields: ["name": "a", "role": "b"],
        styles: [:],
        media: [:],
      ).apply(to: &project)
    }
  }

  // MARK: Private

  private let camera = Media(
    url: URL(filePath: "/tmp/camera.png"),
    duration: Media.stillLength,
    width: 400,
    height: 400,
    hasAudio: false,
    isStill: true,
  )
  private let pop = makeMedia(seconds: 0.5, hasVideo: false)

  private var lowerThird: Template {
    Template(duration: 3, layers: [
      TemplateLayer(
        text: "{name}",
        style: "chul",
        reveal: .pop,
        transform: ClipTransform(y: 0.3),
        keyframes: [
          TemplateKeyframe(property: .x, at: 0, value: -0.4, easing: .spring),
          TemplateKeyframe(property: .x, at: 0.5, value: 0),
        ],
      ),
      TemplateLayer(text: "{role}", start: 0.5, transform: ClipTransform(y: 0.38)),
      TemplateLayer(sticker: "camera", sound: "pop", motion: "pop"),
    ])
  }

  private func footage() throws -> Project {
    let video = makeMedia(seconds: 10)
    var project = Project(media: [video, camera, pop])
    try AppendClip(mediaID: video.id).apply(to: &project)
    return project
  }

}
