import ShadesCore

// MARK: - SetLook

/// Sets clips' colour grade, effects or blend mode. A grade or effects given replace the old
/// ones whole (anything left out is neutral); leave a field out to keep it.
public struct SetLook: ToolCommand {

  // MARK: Lifecycle

  public init(
    clipIDs: [Clip.ID],
    grade: Grade? = nil,
    effects: Effects? = nil,
    blend: BlendMode? = nil,
    clear: Bool? = nil,
  ) {
    self.clipIDs = clipIDs
    self.grade = grade
    self.effects = effects
    self.blend = blend
    self.clear = clear
  }

  // MARK: Public

  public static let title = "Change Look"
  public static let name = "set_look"
  public static let summary = "Grade clips (exposure, contrast, saturation, temperature, tint, "
    + "lift, gamma, gain, curves, a LUT), give them film-look effects (grain, vignette, halation, "
    + "blur) or a green-screen key, or set how they blend (screen, multiply, overlay…). A grade "
    + "or effects given replace the old ones whole; clear removes both."
  public static let parameters = JSONSchema.object(
    [
      "clip_ids": Fields.clipIDs,
      "grade": LookFields.grade,
      "effects": LookFields.effects,
      "blend": JSONSchema.string(
        "How the clip mixes with what's under it",
        values: BlendMode.allCases.map(\.rawValue),
      ),
      "clear": JSONSchema.boolean("Remove the grade and effects first"),
    ],
    required: ["clip_ids"],
  )

  public let clipIDs: [Clip.ID]
  public let grade: Grade?
  public let effects: Effects?
  public let blend: BlendMode?
  public let clear: Bool?

  public func apply(to project: inout Project) throws(CommandError) {
    try grade?.validate()
    try effects?.validate()
    for id in clipIDs {
      let location = try project.requireClip(id)
      var clip = project.timeline.tracks[location.track].clips[location.clip]
      guard clip.text == nil || grade == nil && effects == nil else {
        throw rejected(.invalidValue("text keeps its own colours; restyle it with set_text"))
      }
      if clear == true {
        clip.grade = nil
        clip.effects = nil
      }
      clip.grade = grade ?? clip.grade
      clip.effects = effects ?? clip.effects
      clip.blend = blend ?? clip.blend
      project.timeline.tracks[location.track].clips[location.clip] = clip
    }
  }

}

// MARK: - Grade + Validation

extension Grade {
  /// Refuses values outside what the grade can sensibly do.
  func validate() throws(CommandError) {
    let checks: [(Double, ClosedRange<Double>, String)] = [
      (exposure, -6 ... 6, "exposure goes from -6 to 6 stops"),
      (contrast, 0 ... 3, "contrast goes from 0 to 3"),
      (saturation, 0 ... 3, "saturation goes from 0 to 3"),
      (temperature, -1 ... 1, "temperature goes from -1 to 1"),
      (tint, -1 ... 1, "tint goes from -1 to 1"),
      (lift, -1 ... 1, "lift goes from -1 to 1"),
      (gamma, 0.1 ... 5, "gamma goes from 0.1 to 5"),
      (gain, 0 ... 4, "gain goes from 0 to 4"),
      (lutAmount, 0 ... 1, "lut_amount goes from 0 to 1"),
    ]
    if let failed = checks.first(where: { !$0.1.contains($0.0) }) {
      throw rejected(.invalidValue(failed.2))
    }
  }
}

// MARK: - Effects + Validation

extension Effects {
  /// Refuses values outside 0 to 1.
  func validate() throws(CommandError) {
    let amounts = [grain, vignette, halation, blur, key?.tolerance ?? 0, key?.softness ?? 0]
    guard amounts.allSatisfy({ (0 ... 1).contains($0) }) else {
      throw rejected(.invalidValue("effect amounts go from 0 to 1"))
    }
  }
}
