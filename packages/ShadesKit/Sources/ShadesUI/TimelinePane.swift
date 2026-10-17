import ShadesCommands
import ShadesCore
import ShadesEngine
import SwiftUI

/// The timeline: a title bar, the ruler, and the tracks (video stacked upward, then audio) with
/// the playhead. Scrolls both ways; track headers and the ruler stay put.
struct TimelinePane: View {

  // MARK: Internal

  /// Width of the track headers on the left.
  static let headerWidth = 76.0

  @Binding var settings: TimelineSettings

  let onError: (String) -> Void

  var body: some View {
    VStack(spacing: 0) {
      Hairline()
      TimelineTitleBar(settings: $settings)
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

  /// Video tracks top-down (highest first), then audio tracks.
  private var rows: [Track] {
    let tracks = editor.project.timeline.tracks
    return tracks.filter { $0.kind == .video }.reversed() + tracks.filter { $0.kind == .audio }
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

  /// The ruler, pinned on top: click or drag in it to move the playhead.
  private func rulerRow(scale: TimelineScale, width: Double) -> some View {
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
