import ShadesCore
import SwiftUI

/// A media file's length, size, audio and any colour conversion, as label / value-field rows in
/// the inspector.
struct MediaInfo: View {
  let media: Media
  /// Frame rate the duration is shown at: the timeline's.
  let framesPerSecond: Int

  var body: some View {
    VStack(spacing: 10) {
      InspectorRow(
        label: "Duration",
        value: Timecode.full(media.duration.seconds, framesPerSecond: framesPerSecond),
      )
      InspectorRow(
        label: "Size",
        value: media.hasVideo
          ? "\(media.width)×\(media.height)"
          : "Sound only",
      )
      InspectorRow(label: "Audio", value: media.hasAudio ? "Yes" : "None")
      if let conversion = media.color?.conversion {
        InspectorRow(label: "Colour", value: conversion)
      }
    }
  }
}
