import Foundation
import ShadesCommands
import ShadesCore
@testable import ShadesPolish
import Testing

/// Polish's sound items (noise, ducking, loudness) and its Hindi fillers.
struct PolishSoundTests {

  // MARK: Internal

  @Test
  func `normalising keeps Devanagari vowel signs and viramas, dropping only punctuation`() {
    #expect(PolishPlanner.normalized("हम्म।") == "हम्म")
    #expect(PolishPlanner.normalized("कि,") == "कि")
    #expect(PolishPlanner.normalized("कि") != PolishPlanner.normalized("की"))
    #expect(PolishPlanner.normalized("मतलब") == "मतलब")
  }

  @Test
  func `Devanagari hesitations are fillers, but the word हम (we) is not`() {
    let words = [("तो", 0.0), ("मतलब।", 0.4), ("हम", 0.8), ("हम्म", 1.2), ("चलें", 1.6)]
    let (project, analyses) = talking(words: words)
    let plan = PolishPlanner.plan(
      project.timeline,
      analyses: analyses,
      range: whole,
      options: options(fillers: true),
    )
    #expect(plan.items.map(\.detail) == ["“मतलब।”", "“हम्म”"])
  }

  @Test
  func `a noisy background is proposed for cleaning, a quiet one isn't`() {
    let noisy = plan(noiseFloor: -40, options: options(noise: true))
    #expect(noisy.items.map(\.kind) == [.noise])
    #expect(noisy.items.first?.media != nil)
    let quiet = plan(noiseFloor: -70, options: options(noise: true))
    #expect(quiet.items.isEmpty)
  }

  @Test
  func `applying a noise item makes every clip playing that sound play it cleaned`() throws {
    var (project, analyses) = speaking(noiseFloor: -40)
    try DetachAudio(clipID: talk(project).id).apply(to: &project)
    let plan = PolishPlanner.plan(
      project.timeline,
      analyses: analyses,
      range: whole,
      options: options(noise: true),
    )
    try ApplyPolish(plan: plan).apply(to: &project)
    let sound = try #require(project.timeline.partners(of: talk(project).id).first)
    #expect(sound.cleanSound)
    #expect(try !talk(project).cleanSound)
  }

  @Test
  func `the music ducks under the speech where it lands after the cuts`() throws {
    var (project, analyses) = speaking(noiseFloor: -70)
    let plan = PolishPlanner.plan(
      project.timeline,
      analyses: analyses,
      range: whole,
      options: options(silences: true, duck: true),
    )
    #expect(plan.music == "A1")
    #expect(plan.items.contains { $0.kind == .duck })
    try ApplyPolish(plan: plan).apply(to: &project)
    let music = try #require(project.timeline.tracks.first { $0.kind == .audio }?.clips.first)
    // why: the second line moved from 4 s to about 2.4 s, so the music is back up by 5 s.
    #expect(abs(music.gain(at: MediaTime(seconds: 3)) - 0.25) < 0.01)
    #expect(abs(music.gain(at: MediaTime(seconds: 5)) - 1) < 0.01)
  }

  @Test
  func `loudness is set for the chosen platform, only while its item is on`() throws {
    let (project, analyses) = speaking(noiseFloor: -70)
    var plan = PolishPlanner.plan(
      project.timeline,
      analyses: analyses,
      range: whole,
      options: options(loudness: .podcast),
    )
    #expect(plan.items.map(\.kind) == [.loudness])
    #expect(plan.items.first?.detail.contains("-16 LUFS") == true)
    let level = NormalizeLoudness(gain: 2, limiter: [])
    var on = project
    try ApplyPolish(plan: plan, loudness: level).apply(to: &on)
    #expect(on.timeline.gain == 2)
    plan.items[0].isEnabled = false
    var off = project
    try ApplyPolish(plan: plan, loudness: level).apply(to: &off)
    #expect(off.timeline.gain == 1)
  }

  // MARK: Private

  private let whole = TimeRange(start: .zero, end: MediaTime(seconds: 6))

  /// The plan for a talking clip whose background is at `noiseFloor` dBFS.
  private func plan(noiseFloor: Double, options: PolishOptions) -> PolishPlan {
    let (project, analyses) = speaking(noiseFloor: noiseFloor)
    return PolishPlanner.plan(project.timeline, analyses: analyses, range: whole, options: options)
  }

  /// 6 s of talking on V1 (speech 0.5–2 s and 4–5.5 s, background at `noiseFloor`) over music
  /// with beats on A1.
  private func speaking(noiseFloor: Double) -> (Project, [Media.ID: MediaAnalysis]) {
    let talk = media("talk.mov", hasVideo: true)
    let song = media("song.m4a", hasVideo: false)
    var project = Project(media: [talk, song])
    project.timeline.tracks[0].clips = [clip(of: talk)]
    project.timeline.tracks[1].clips = [clip(of: song)]
    let speech = [
      TimeRange(start: MediaTime(seconds: 0.5), end: MediaTime(seconds: 2)),
      TimeRange(start: MediaTime(seconds: 4), end: MediaTime(seconds: 5.5)),
    ]
    return (project, [
      talk.id: MediaAnalysis(speech: speech, noiseFloor: noiseFloor),
      song.id: MediaAnalysis(beats: BeatGrid(beatsPerMinute: 60, beats: [MediaTime(seconds: 1)])),
    ])
  }

  /// A talking clip on V1 whose transcript has `words` (text, start; each 0.3 s long).
  private func talking(words: [(String, Double)]) -> (Project, [Media.ID: MediaAnalysis]) {
    let talk = media("talk.mov", hasVideo: true)
    var project = Project(media: [talk])
    project.timeline.tracks[0].clips = [clip(of: talk)]
    let spoken = words.map { text, start in
      TranscriptWord(
        text: text,
        start: MediaTime(seconds: start, timescale: 1000),
        end: MediaTime(seconds: start + 0.3, timescale: 1000),
      )
    }
    let transcript = Transcript(
      segments: [TranscriptSegment(text: "", start: .zero, end: whole.end, words: spoken)],
      language: "hi",
    )
    return (project, [talk.id: MediaAnalysis(transcript: transcript)])
  }

  private func media(_ name: String, hasVideo: Bool) -> Media {
    Media(
      url: URL(filePath: "/tmp/\(name)"),
      duration: whole.end,
      width: hasVideo ? 1920 : 0,
      height: hasVideo ? 1080 : 0,
      hasVideo: hasVideo,
      hasAudio: true,
    )
  }

  private func clip(of media: Media) -> Clip {
    Clip(mediaID: media.id, sourceStart: .zero, duration: media.duration, timelineStart: .zero)
  }

  private func talk(_ project: Project) throws -> Clip {
    try #require(project.timeline.tracks[0].clips.first)
  }

  /// Polish with only the given kinds switched on.
  private func options(
    silences: Bool = false,
    fillers: Bool = false,
    noise: Bool = false,
    duck: Bool = false,
    loudness: LoudnessTarget? = nil,
  ) -> PolishOptions {
    PolishOptions(
      silences: silences,
      fillers: fillers,
      retakes: false,
      beatSnap: false,
      punchIn: false,
      duck: duck,
      noise: noise,
      loudness: loudness,
    )
  }

}
