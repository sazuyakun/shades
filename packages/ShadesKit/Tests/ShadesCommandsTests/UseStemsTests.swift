import ShadesCommands
import ShadesCore
import Testing

struct UseStemsTests {

  // MARK: Internal

  @Test
  func `a video clip goes quiet and its voice and music line up under it`() throws {
    var project = Project(media: [video])
    try AppendClip(mediaID: video.id).apply(to: &project)
    let clipID = try #require(project.timeline.allClips.first?.id)
    try SetClip(clipID: clipID, volume: 0.5, fadeIn: seconds(1)).apply(to: &project)
    try SetKeyframes(clipID: clipID, keyframes: [
      .init(property: .volume, at: seconds(2), value: 0.2, easing: nil),
      .init(property: .scale, at: seconds(2), value: 2, easing: nil),
    ]).apply(to: &project)
    try UseStems(clipID: clipID, stems: [voice, music]).apply(to: &project)
    #expect(project.timeline.allClips.first { $0.id == clipID }?.isAudioEnabled == false)
    let audio = project.timeline.tracks.filter { $0.kind == .audio }.flatMap(\.clips)
    #expect(audio.map(\.mediaID) == [voice.id, music.id])
    #expect(audio.allSatisfy { $0.volume == 0.5 && $0.fadeIn == seconds(1) })
    #expect(audio.allSatisfy { $0.keyframes.map(\.property) == [.volume] })
    #expect(project.media.count == 3)
  }

  @Test
  func `a video clip whose sound was detached has none to separate`() throws {
    var project = Project(media: [video])
    try AppendClip(mediaID: video.id).apply(to: &project)
    let clipID = try #require(project.timeline.allClips.first?.id)
    try DetachAudio(clipID: clipID).apply(to: &project)
    #expect(throws: CommandError.noAudio(clipID)) {
      try UseStems(clipID: clipID, stems: [voice, music]).apply(to: &project)
    }
  }

  @Test
  func `a sound clip is replaced by its stems`() throws {
    let sound = makeMedia(seconds: 4, hasVideo: false)
    var project = Project(media: [sound])
    try AppendClip(mediaID: sound.id).apply(to: &project)
    let clipID = try #require(project.timeline.allClips.first?.id)
    try UseStems(clipID: clipID, stems: [voice, music]).apply(to: &project)
    #expect(project.timeline.allClips.map(\.mediaID) == [voice.id, music.id])
  }

  // MARK: Private

  private let video = makeMedia(seconds: 4)
  private let voice = makeMedia(seconds: 4, hasVideo: false)
  private let music = makeMedia(seconds: 4, hasVideo: false)

}
