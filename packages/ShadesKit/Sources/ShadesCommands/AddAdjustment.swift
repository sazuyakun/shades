import ShadesCore

/// Adds an adjustment clip on top of everything: its grade and effects change every layer under
/// it for as long as it lasts (a film look, a colour pass over a whole sequence).
public struct AddAdjustment: ToolCommand {

  // MARK: Lifecycle

  public init(
    at time: MediaTime,
    duration: MediaTime,
    grade: Grade? = nil,
    effects: Effects? = nil,
  ) {
    at = time
    self.duration = duration
    self.grade = grade
    self.effects = effects
  }

  // MARK: Public

  public static let title = "Add Adjustment"
  public static let name = "add_adjustment"
  public static let summary = "Add an adjustment clip on the top video track: its grade and "
    + "effects change everything under it for its length, like a film look over a whole "
    + "sequence. Text tracks above (captions) stay untouched."
  public static let parameters = JSONSchema.object(
    [
      "at": Fields.time("Where it starts"),
      "duration": JSONSchema.number("How long it lasts, in seconds", minimum: 0.04),
      "grade": LookFields.grade,
      "effects": LookFields.effects,
    ],
    required: ["at", "duration"],
  )

  public let at: MediaTime
  public let duration: MediaTime
  public let grade: Grade?
  public let effects: Effects?

  public func apply(to project: inout Project) throws(CommandError) {
    try grade?.validate()
    try effects?.validate()
    let start = project.onFrame(at)
    let length = max(project.onFrame(duration), project.timeline.format.frameDuration)
    let videos = project.timeline.tracks.indices
      .filter { project.timeline.tracks[$0].kind == .video }
    let index = videos.last.flatMap { top in
      project.timeline.tracks[top].isClear(from: start, to: start + length)
        && project.timeline.tracks[top].clips.allSatisfy { $0.source == .adjustment }
        ? top
        : nil
    } ?? project.addTrack(.video)
    project.timeline.tracks[index].add(Clip(
      source: .adjustment,
      sourceStart: .zero,
      duration: length,
      timelineStart: start,
      grade: grade,
      effects: effects,
    ))
  }

}
