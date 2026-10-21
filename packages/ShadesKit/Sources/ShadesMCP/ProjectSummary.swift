import Foundation
import ShadesCommands
import ShadesCore

/// The project as Claude sees it: seconds instead of exact fractions, track labels, and only
/// the fields that matter for editing.
enum ProjectSummary {

  // MARK: Internal

  static func json(of project: Project, playhead: Double, selection: Set<Clip.ID>) -> JSONValue {
    let timeline = project.timeline
    let mediaByID = Dictionary(uniqueKeysWithValues: project.media.map { ($0.id, $0) })
    return [
      "timeline": [
        "name": .string(timeline.name),
        "width": .number(Double(timeline.format.width)),
        "height": .number(Double(timeline.format.height)),
        "fps": .number(Double(timeline.format.framesPerSecond)),
        "duration": seconds(timeline.duration),
        "master_gain": rounded(timeline.gain),
        "camera": .array(timeline.camera.map { keyframe in
          [
            "property": .string(keyframe.property.rawValue),
            "at": seconds(keyframe.time),
            "value": rounded(keyframe.value),
            "easing": .string(keyframe.easing.rawValue),
          ]
        }),
      ],
      "playhead": rounded(playhead),
      "selection": .array(selection.map { .string($0.uuidString) }),
      "media": .array(project.media.map(json)),
      "tracks": .array(timeline.tracks.map { track in
        [
          "label": .string(timeline.label(of: track)),
          "kind": .string(track.kind.rawValue),
          "muted": .bool(track.isMuted),
          "hidden": .bool(track.isHidden),
          "follows_camera": .bool(track.followsCamera),
          "volume": rounded(track.volume),
          "clips": .array(track.clips
            .map { json(of: $0, media: $0.mediaID.flatMap { mediaByID[$0] }) }),
        ]
      }),
      "markers": .array(timeline.markers.map { marker in
        [
          "id": .string(marker.id.uuidString),
          "time": seconds(marker.time),
          "name": .string(marker.name),
        ]
      }),
      "shorts": .array(timeline.shorts.map { short in
        [
          "id": .string(short.id.uuidString),
          "name": .string(short.name),
          "start": seconds(short.range.start),
          "end": seconds(short.range.end),
        ]
      }),
    ]
  }

  /// One line per clip, for tool results: "ID on V1 at 2.0–4.5 s".
  static func describe(_ clip: Clip, in timeline: Timeline) -> String {
    let label = timeline.tracks.first { $0.clips.contains(clip) }.map(timeline.label(of:)) ?? "?"
    return "\(clip.id) on \(label) at \(format(clip.timelineStart))–\(format(clip.timelineEnd)) s"
  }

  // MARK: Private

  private static func json(_ media: Media) -> JSONValue {
    [
      "id": .string(media.id.uuidString),
      "name": .string(media.name),
      "path": .string(media.url.path),
      "duration": seconds(media.duration),
      "width": .number(Double(media.width)),
      "height": .number(Double(media.height)),
      "has_video": .bool(media.hasVideo),
      "has_audio": .bool(media.hasAudio),
    ]
  }

  private static func json(of clip: Clip, media: Media?) -> JSONValue {
    var fields: [String: JSONValue] = [
      "id": .string(clip.id.uuidString),
      "start": seconds(clip.timelineStart),
      "end": seconds(clip.timelineEnd),
      "source_start": seconds(clip.sourceStart),
      "source_end": seconds(clip.sourceEnd),
      "x": rounded(clip.transform.x),
      "y": rounded(clip.transform.y),
      "scale": rounded(clip.transform.scale),
      "rotation": rounded(clip.transform.rotation),
      "opacity": rounded(clip.opacity),
      "tilt_x": rounded(clip.transform.tiltX),
      "tilt_y": rounded(clip.transform.tiltY),
      "depth": rounded(clip.transform.depth),
      "depth_slot": .string(clip.depth.rawValue),
      "volume": rounded(clip.volume),
      "audio_enabled": .bool(clip.isAudioEnabled),
    ]
    switch clip.source {
    case .media(let id):
      fields["media_id"] = .string(id.uuidString)
      fields["media_name"] = .string(media?.name ?? "missing")

    case .text(let content):
      fields["text"] = .string(content.text)
      if let word = content.word {
        fields["word"] = .string(content.shownText)
        fields["word_index"] = .number(Double(word))
      }
      fields["style"] = .string(content.style.font ?? "system bold")
      fields["reveal"] = .string(content.reveal.rawValue)
      if let path = content.path {
        fields["path"] = [
          "points": .number(Double(path.points.count)),
          "offset": rounded(path.offset),
        ]
      }

    case .drawing(let drawing):
      fields["drawing"] = [
        "strokes": .number(Double(drawing.strokes.count)),
        "color": .string(drawing.color.hex),
        "width": rounded(drawing.width),
        "glow": rounded(drawing.glow),
        "boil": rounded(drawing.boil),
        "write_on": rounded(drawing.writeOn),
        "erase_off": rounded(drawing.eraseOff),
      ]

    case .adjustment:
      fields["adjustment"] = .bool(true)
    }
    if let transition = clip.transitionIn {
      fields["transition_in"] = [
        "kind": .string(transition.kind.rawValue),
        "duration": seconds(transition.duration),
      ]
    }
    if clip.fadeIn > .zero || clip.fadeOut > .zero {
      fields["fade_in"] = seconds(clip.fadeIn)
      fields["fade_out"] = seconds(clip.fadeOut)
    }
    if clip.isFrozen {
      fields["freeze_frame"] = .bool(true)
    } else if clip.speed != 1 {
      fields["speed"] = rounded(clip.speed)
    }
    if clip.blend != .normal {
      fields["blend"] = .string(clip.blend.rawValue)
    }
    // why: our own value types always encode; a failure would only drop the field from the summary.
    fields["grade"] = clip.grade.flatMap { try? JSONValue(encoding: $0) }
    fields["effects"] = clip.effects.flatMap { try? JSONValue(encoding: $0) }
    fields["sticker"] = clip.sticker.flatMap { try? JSONValue(encoding: $0) }
    if !clip.keyframes.isEmpty {
      fields["keyframes"] = .array(clip.keyframes.map { keyframe in
        .object([
          "property": .string(keyframe.property.rawValue),
          "at": seconds(clip.timelineTime(atSource: keyframe.time)),
          "value": rounded(keyframe.value),
          "easing": .string(keyframe.easing.rawValue),
        ])
      })
    }
    return .object(fields)
  }

  private static func seconds(_ time: MediaTime) -> JSONValue {
    rounded(time.seconds)
  }

  private static func rounded(_ value: Double) -> JSONValue {
    .number((value * 1000).rounded() / 1000)
  }

  private static func format(_ time: MediaTime) -> String {
    String(format: "%.3f", time.seconds)
  }

}
