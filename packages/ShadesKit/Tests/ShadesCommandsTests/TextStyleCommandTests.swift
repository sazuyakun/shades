import Foundation
import ShadesCommands
import ShadesCore
import Testing

struct TextStyleCommandTests {
  @Test
  func `text can be styled and revealed without changing its words`() throws {
    var project = Project()
    try AddText(
      text: "title",
      at: .zero,
      duration: seconds(2),
      style: TextStyle(size: 0.2, anchor: .center),
    ).apply(to: &project)
    let clip = try #require(project.timeline.allClips.first)
    #expect(clip.text?.style.anchor == .center)
    try SetText(clipID: clip.id, reveal: .pop).apply(to: &project)
    let content = try #require(project.timeline.allClips.first?.text)
    #expect(content.text == "title")
    #expect(content.reveal == .pop)
    #expect(content.style.size == 0.2)
  }

  @Test
  func `text can be made solid 3D letters within sensible depths and bevels`() throws {
    var project = Project()
    try AddText(
      text: "solid",
      at: .zero,
      duration: seconds(2),
      style: TextStyle(extrusion: TextExtrusion(depth: 0.5, bevel: 0.05)),
    ).apply(to: &project)
    let clip = try #require(project.timeline.allClips.first)
    #expect(clip.text?.style.extrusion?.depth == 0.5)
    for extrusion in [TextExtrusion(depth: 9), TextExtrusion(bevel: 0.9)] {
      #expect(throws: CommandError.self) {
        try SetText(clipID: clip.id, style: TextStyle(extrusion: extrusion)).apply(to: &project)
      }
    }
  }

  @Test
  func `undrawable sizes and outlines are refused`() throws {
    var project = Project()
    #expect(throws: CommandError.self) {
      try AddText(text: "x", at: .zero, duration: seconds(1), style: TextStyle(size: 2))
        .apply(to: &project)
    }
    try AddText(text: "x", at: .zero, duration: seconds(1)).apply(to: &project)
    let clip = try #require(project.timeline.allClips.first)
    #expect(throws: CommandError.self) {
      try SetText(clipID: clip.id, style: TextStyle(outline: 1)).apply(to: &project)
    }
    #expect(throws: CommandError.self) {
      try SetText(clipID: clip.id, style: TextStyle(arc: 400)).apply(to: &project)
    }
  }
}
