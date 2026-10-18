import Foundation
import ShadesCommands
import ShadesCore
import ShadesPolish
import Testing

struct PolishPlannerTests {

  // MARK: Internal

  @Test
  func `long pauses between words become silence cuts with padding`() throws {
    let (project, analyses) = talking(
      [("Hello", 0.2), ("world.", 0.6), ("Again", 2.6), ("here.", 3.0)],
      length: 4,
    )
    let plan = PolishPlanner.plan(
      project.timeline,
      analyses: analyses,
      range: whole(4),
      options: only(silences: true),
    )
    let silences = plan.items.filter { $0.kind == .silence }
    // The 1.7 s pause between "world." (ends 0.9) and "Again" (2.6), less 0.12 s padding each side.
    let gap = try #require(silences.first { $0.range.start.seconds > 0.5 })
    #expect(abs(gap.range.start.seconds - 1.02) < 0.01)
    #expect(abs(gap.range.end.seconds - 2.48) < 0.01)
  }

  @Test
  func `fillers are found, including matlab`() {
    let (project, analyses) = talking(
      [("So", 0), ("um,", 0.4), ("matlab", 0.8), ("yes.", 1.2)],
      length: 2,
    )
    let plan = PolishPlanner.plan(
      project.timeline,
      analyses: analyses,
      range: whole(2),
      options: only(fillers: true),
    )
    #expect(plan.items.map(\.detail) == ["“um,”", "“matlab”"])
  }

  @Test
  func `a restarted line removes the first attempt`() throws {
    let words = [
      ("I", 0.0),
      ("went", 0.3),
      ("to", 0.6),
      ("the", 0.9),
      ("I", 2.0),
      ("went", 2.3),
      ("to", 2.6),
      ("the", 2.9),
      ("shop.", 3.2),
    ]
    let (project, analyses) = talking(words, length: 4)
    let plan = PolishPlanner.plan(
      project.timeline,
      analyses: analyses,
      range: whole(4),
      options: only(retakes: true),
    )
    let retake = try #require(plan.items.first)
    #expect(retake.kind == .retake)
    #expect(retake.range.start == MediaTime(seconds: 0, timescale: 1000))
    #expect(abs(retake.range.end.seconds - 2.0) < 0.001)
  }

  @Test
  @MainActor
  func `applying the plan removes the cut time in one undo step`() throws {
    let (project, analyses) = talking(
      [("Hello", 0.2), ("world.", 0.6), ("Again", 2.6), ("here.", 3.0)],
      length: 4,
    )
    let editor = Editor(project: project)
    let plan = PolishPlanner.plan(
      project.timeline,
      analyses: analyses,
      range: whole(4),
      options: only(silences: true),
    )
    let removed = plan.items.reduce(0) { $0 + $1.range.duration.seconds }
    try editor.perform(ApplyPolish(plan: plan))
    #expect(abs(editor.project.timeline.duration.seconds - (4 - removed)) < 0.05)
    try editor.undo()
    #expect(editor.project.timeline.duration == MediaTime(seconds: 4))
  }

  @Test
  func `switched-off items are left alone`() throws {
    let (project, analyses) = talking(
      [("Hello", 0.2), ("world.", 0.6), ("Again", 2.6), ("here.", 3.0)],
      length: 4,
    )
    var plan = PolishPlanner.plan(
      project.timeline,
      analyses: analyses,
      range: whole(4),
      options: only(silences: true),
    )
    for index in plan.items.indices {
      plan.items[index].isEnabled = false
    }
    var edited = project
    try ApplyPolish(plan: plan).apply(to: &edited)
    #expect(edited == project)
  }

  @Test
  func `punch-ins zoom every second stretch between cuts`() throws {
    let words = [("One.", 0.2), ("Two.", 1.6), ("Three.", 3.0)]
    let (project, analyses) = talking(words, length: 4)
    var options = only(silences: true)
    options.punchIn = true
    let plan = PolishPlanner.plan(
      project.timeline,
      analyses: analyses,
      range: whole(4),
      options: options,
    )
    var edited = project
    try ApplyPolish(plan: plan).apply(to: &edited)
    let scales = edited.timeline.tracks[0].clips.map(\.transform.scale)
    #expect(scales.contains(1))
    #expect(scales.contains { abs($0 - 1.15) < 0.001 })
  }

  @Test
  func `punch-ins land on their stretch even when cuts fall between frames`() throws {
    let words = [("One.", 0.21), ("Two.", 1.63), ("Three.", 3.07)]
    let (project, analyses) = talking(words, length: 4)
    var options = only(silences: true)
    options.punchIn = true
    let plan = PolishPlanner.plan(
      project.timeline,
      analyses: analyses,
      range: whole(4),
      options: options,
    )
    var edited = project
    try ApplyPolish(plan: plan).apply(to: &edited)
    let zoomed = edited.timeline.tracks[0].clips.filter { abs($0.transform.scale - 1.15) < 0.001 }
    #expect(zoomed.count == plan.items.count { $0.kind == .punchIn })
  }

  @Test
  func `a cut near a music beat moves onto it`() throws {
    var (project, analyses) = talking(
      [("Hello", 0.2), ("world.", 0.6), ("Again", 2.6), ("here.", 3.0)],
      length: 4,
    )
    let music = Media(
      url: URL(filePath: "/tmp/music.wav"),
      duration: MediaTime(seconds: 4),
      width: 0,
      height: 0,
      hasVideo: false,
      hasAudio: true,
    )
    project.media.append(music)
    project.timeline.tracks[1].clips = [Clip(
      mediaID: music.id,
      sourceStart: .zero,
      duration: MediaTime(seconds: 4),
      timelineStart: .zero,
    )]
    analyses[music.id] = MediaAnalysis(beats: BeatGrid(
      beatsPerMinute: 60,
      beats: [MediaTime(seconds: 1.15, timescale: 1000)],
    ))
    var options = only(silences: true)
    options.beatSnap = true
    let plan = PolishPlanner.plan(
      project.timeline,
      analyses: analyses,
      range: whole(4),
      options: options,
    )
    let snap = try #require(plan.items.first { $0.kind == .beatSnap })
    #expect(abs(snap.range.start.seconds - 1.15) < 0.01)
  }

  @Test
  func `without a transcript, speech activity finds the pauses`() {
    let media = Media(
      url: URL(filePath: "/tmp/a.mov"),
      duration: MediaTime(seconds: 6),
      width: 1920,
      height: 1080,
      hasAudio: true,
    )
    var project = Project(media: [media])
    project.timeline.tracks[0].clips = [Clip(
      mediaID: media.id,
      sourceStart: .zero,
      duration: MediaTime(seconds: 6),
      timelineStart: .zero,
    )]
    let speech = [
      TimeRange(start: MediaTime(seconds: 0.5), end: MediaTime(seconds: 2)),
      TimeRange(start: MediaTime(seconds: 4), end: MediaTime(seconds: 5.5)),
    ]
    let plan = PolishPlanner.plan(
      project.timeline,
      analyses: [media.id: MediaAnalysis(speech: speech)],
      range: whole(6),
      options: only(silences: true),
    )
    #expect(plan.items.count == 3)
  }

  // MARK: Private

  /// A 1-track talking clip whose transcript has `words` (text, start; each 0.3 s long).
  private func talking(
    _ words: [(String, Double)],
    length: Double,
  ) -> (Project, [Media.ID: MediaAnalysis]) {
    let media = Media(
      url: URL(filePath: "/tmp/talk.mov"),
      duration: MediaTime(seconds: length),
      width: 1920,
      height: 1080,
      hasAudio: true,
    )
    var project = Project(media: [media])
    project.timeline.tracks[0].clips = [Clip(
      mediaID: media.id,
      sourceStart: .zero,
      duration: MediaTime(seconds: length),
      timelineStart: .zero,
    )]
    let spoken = words.map { text, start in
      TranscriptWord(
        text: text,
        start: MediaTime(seconds: start, timescale: 1000),
        end: MediaTime(seconds: start + 0.3, timescale: 1000),
      )
    }
    let transcript = Transcript(
      segments: [TranscriptSegment(
        text: "",
        start: .zero,
        end: MediaTime(seconds: length),
        words: spoken,
      )],
      language: "en",
    )
    return (project, [media.id: MediaAnalysis(transcript: transcript)])
  }

  private func whole(_ seconds: Double) -> TimeRange {
    TimeRange(start: .zero, end: MediaTime(seconds: seconds))
  }

  private func only(
    silences: Bool = false,
    fillers: Bool = false,
    retakes: Bool = false,
  ) -> PolishOptions {
    PolishOptions(
      silences: silences,
      fillers: fillers,
      retakes: retakes,
      beatSnap: false,
      punchIn: false,
    )
  }

}
