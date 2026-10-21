import ShadesCommands
import ShadesCore
import ShadesEngine
import SwiftUI

// MARK: - TimelinePane

/// The timeline: a title bar, the shorts and the ruler, and the tracks (video stacked upward,
/// then audio) with the playhead. Scrolls both ways; track headers and the ruler stay put.
struct TimelinePane: View {

  // MARK: Internal

  /// Width of the track headers on the left.
  static let headerWidth = 76.0

  @Binding var settings: TimelineSettings

  let onRun: (EditorAction) -> Void
  let onError: (String) -> Void

  var body: some View {
    VStack(spacing: 0) {
      Hairline()
      TimelineTitleBar(settings: $settings, onRun: onRun, onError: onError)
      Hairline()
      GeometryReader { geometry in
        let scale = scale(fitting: geometry.size.width)
        // why: room past the end only when zoomed in; fitted, the whole timeline shows.
        let tail = settings.pointsPerSecond == nil ? 0.0 : 240
        let contentWidth = max(
          scale.x(at: editor.project.timeline.duration) + tail,
          geometry.size.width - Self.headerWidth,
        )
        ScrollView([.horizontal, .vertical]) {
          LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
            Section {
              ForEach(rows) { track in
                TrackRow(
                  track: track,
                  rows: rows,
                  scale: scale,
                  settings: settings,
                  headerOffset: visibleStart,
                  onError: onError,
                )
              }
            } header: {
              rulerRow(scale: scale, width: geometry.size.width)
            }
          }
          .frame(width: Self.headerWidth + contentWidth, alignment: .topLeading)
          .frame(minHeight: geometry.size.height, alignment: .top)
          .overlay(alignment: .topLeading) {
            if
              let short = editor.project.timeline.shorts.first(where: {
                $0.id == settings.selectedShort
              })
            {
              ShortBand(width: scale.x(at: short.range.duration))
                .offset(x: Self.headerWidth + scale.x(at: short.range.start))
                .allowsHitTesting(false)
            }
          }
          .overlay(alignment: .topLeading) {
            Playhead()
              .offset(x: Self.headerWidth + scale.x(atSeconds: player.currentTime) - 6)
              .allowsHitTesting(false)
          }
        }
        .scrollPosition($scrollPosition)
        .onScrollGeometryChange(for: Double.self) { $0.contentOffset.x } action: { _, offset in
          visibleStart = max(offset, 0)
        }
        .onChange(of: player.currentTime) {
          follow(playhead: scale.x(atSeconds: player.currentTime), width: geometry.size.width)
        }
      }
    }
    .background(Theme.background)
  }

  // MARK: Private

  @Environment(Editor.self) private var editor
  @Environment(Player.self) private var player
  @State private var visibleStart = 0.0
  @State private var scrollPosition = ScrollPosition(edge: .leading)

  /// Text tracks then video tracks top-down (highest first), then audio tracks.
  private var rows: [Track] {
    let tracks = editor.project.timeline.tracks
    let text = tracks.filter { $0.kind == .text }.reversed()
    let video = tracks.filter { $0.kind == .video }.reversed()
    return Array(text) + Array(video) + tracks.filter { $0.kind == .audio }
  }

  private func scale(fitting width: Double) -> TimelineScale {
    if let zoom = settings.pointsPerSecond {
      return TimelineScale(pointsPerSecond: zoom)
    }
    let usable = max(width - Self.headerWidth - 60, 100)
    return TimelineScale(pointsPerSecond: usable / max(
      editor.project.timeline.duration.seconds,
      10,
    ))
  }

  /// The shorts and the ruler, pinned on top: click or drag in the ruler to move the playhead.
  private func rulerRow(scale: TimelineScale, width: Double) -> some View {
    let shorts = editor.project.timeline.shorts
    return VStack(spacing: 0) {
      if !shorts.isEmpty {
        HStack(spacing: 0) {
          Color.clear.frame(width: Self.headerWidth)
          ShortLane(
            shorts: shorts,
            scale: scale,
            visibleStart: visibleStart,
            selection: $settings.selectedShort,
            onRun: onRun,
            onError: onError,
          )
          .frame(width: max(width - Self.headerWidth, 1))
          .offset(x: visibleStart)
          Spacer(minLength: 0)
        }
        .frame(height: ShortLane.height)
      }
      HStack(spacing: 0) {
        Color.clear.frame(width: Self.headerWidth)
        TimelineRuler(
          scale: scale,
          markers: editor.project.timeline.markers,
          visibleStart: visibleStart,
        )
        .frame(width: max(width - Self.headerWidth, 1))
        .offset(x: visibleStart)
        .contentShape(.rect)
        .gesture(
          DragGesture(minimumDistance: 0).onChanged { drag in
            let seconds = scale.seconds(atX: drag.location.x + visibleStart)
            Task { await player.seek(toSeconds: seconds) }
          }
        )
        Spacer(minLength: 0)
      }
      .frame(height: TimelineRuler.height)
    }
    .background(Theme.background)
    .overlay(alignment: .bottom) { Hairline() }
  }

  /// Keeps the playhead in view while playing: when it runs off the right, page forward.
  private func follow(playhead x: Double, width: Double) {
    let visibleWidth = width - Self.headerWidth
    guard player.isPlaying, x < visibleStart || x > visibleStart + visibleWidth - 40 else {
      return
    }
    scrollPosition.scrollTo(x: max(x - 80, 0))
  }

}

// MARK: - ShortBand

/// The picked short's stretch, tinted across every track.
private struct ShortBand: View {
  let width: Double

  var body: some View {
    Rectangle()
      .fill(Color.accentColor.opacity(0.07))
      .overlay(alignment: .leading) { Color.accentColor.opacity(0.7).frame(width: 1) }
      .overlay(alignment: .trailing) { Color.accentColor.opacity(0.7).frame(width: 1) }
      .frame(width: max(width, 1))
      .frame(maxHeight: .infinity)
  }
}
