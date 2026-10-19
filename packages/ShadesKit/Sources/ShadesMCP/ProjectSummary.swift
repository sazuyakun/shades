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
      "source_end": seconds(clip.sourceStart + clip.duration),
      "x": rounded(clip.transform.x),
      "y": rounded(clip.transform.y),
      "scale": rounded(clip.transform.scale),
      "rotation": rounded(clip.transform.rotation),
      "opacity": rounded(clip.opacity),
      "depth": .string(clip.depth.rawValue),
      "volume": rounded(clip.volume),
      "audio_enabled": .bool(clip.isAudioEnabled),
    ]
    switch clip.source {
    case .media(let id):
      fields["media_id"] = .string(id.uuidString)
      fields["media_name"] = .string(media?.name ?? "missing")

    case .text(let content):
      fields["text"] = .string(content.text)
    }
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
