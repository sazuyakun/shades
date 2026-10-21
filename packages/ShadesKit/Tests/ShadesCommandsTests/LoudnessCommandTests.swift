import ShadesCommands
import ShadesCore
import Testing

struct LoudnessCommandTests {

  // MARK: Internal

  @Test
  func `normalising sets the master level and the limiter in time order`() throws {
    var project = Project()
    try NormalizeLoudness(gain: 2.5, limiter: [point(1, 0.5), point(0, 1), point(2, 1)])
      .apply(to: &project)
    #expect(project.timeline.gain == 2.5)
    #expect(project.timeline.limiter == [point(0, 1), point(1, 0.5), point(2, 1)])
  }

  @Test
  func `a limiter that turns the sound up or a level past 8 is refused`() {
    var project = Project()
    #expect(throws: CommandError.self) {
      try NormalizeLoudness(gain: 1, limiter: [point(0, 1.5)]).apply(to: &project)
    }
    #expect(throws: CommandError.self) {
      try NormalizeLoudness(gain: 9, limiter: []).apply(to: &project)
    }
    #expect(project.timeline.gain == 1)
    #expect(project.timeline.limiter.isEmpty)
  }

  @Test
  func `setting the master level by hand removes the limiter worked out for the old one`() throws {
    var project = Project()
    try NormalizeLoudness(gain: 2, limiter: [point(0, 1), point(1, 0.5)]).apply(to: &project)
    try SetMasterGain(gain: 1).apply(to: &project)
    #expect(project.timeline.gain == 1)
    #expect(project.timeline.limiter.isEmpty)
  }

  // MARK: Private

  private func point(_ time: Double, _ gain: Double) -> GainPoint {
    GainPoint(time: seconds(time), gain: gain)
  }

}
