import ShadesCore
import SwiftUI

// MARK: - CurvesEditor

/// Tone curves for the master and each colour: click to add a point, drag to move it, drag it
/// out of the box to take it away.
struct CurvesEditor: View {

  // MARK: Internal

  let curves: Curves
  let onChange: (Curves) -> Void
  let onEnd: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Curves").foregroundStyle(Theme.secondaryText)
        Spacer()
        Button("Reset") { set(nil) }
          .buttonStyle(CapsuleButtonStyle())
          .disabled(curves[keyPath: channel.field] == nil)
      }
      Picker("Channel", selection: $channel) {
        ForEach(CurveChannel.allCases, id: \.self) { Text($0.label).tag($0) }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      GeometryReader { geometry in
        let size = geometry.size
        Canvas { context, _ in
          draw(in: context, size: size)
        }
        .contentShape(.rect)
        .gesture(DragGesture(minimumDistance: 0)
          .onChanged { moveGrabbed($0, size: size) }
          .onEnded { finishGrab($0, size: size) })
      }
      .aspectRatio(1, contentMode: .fit)
      .background(Theme.raised, in: .rect(cornerRadius: 6))
      .help(
        "Click to add a point, drag to bend the curve, drag a point out of the box to remove it"
      )
    }
  }

  // MARK: Private

  /// How close a click must be to a point to grab it, in points.
  private static let grabDistance = 10.0
  /// How far outside the box a point is dropped to remove it, in points.
  private static let removeDistance = 16.0

  @State private var channel = CurveChannel.master
  @State private var grabbed: Int?

  /// The channel's points, from dark to light; a straight line when it has none.
  private var points: [DrawingPoint] {
    curves[keyPath: channel.field] ?? [DrawingPoint(x: 0, y: 0), DrawingPoint(x: 1, y: 1)]
  }

  private func draw(in context: GraphicsContext, size: CGSize) {
    var grid = Path()
    for step in 1 ..< 4 {
      let fraction = Double(step) / 4
      grid.move(to: CGPoint(x: fraction * size.width, y: 0))
      grid.addLine(to: CGPoint(x: fraction * size.width, y: size.height))
      grid.move(to: CGPoint(x: 0, y: fraction * size.height))
      grid.addLine(to: CGPoint(x: size.width, y: fraction * size.height))
    }
    context.stroke(grid, with: .color(Theme.hairline))
    let current = points
    var curve = Path()
    for step in 0 ... 64 {
      let input = Double(step) / 64
      let spot = location(
        of: DrawingPoint(x: input, y: Curves.value(of: current, at: input)),
        in: size,
      )
      if step == 0 {
        curve.move(to: spot)
      } else {
        curve.addLine(to: spot)
      }
    }
    context.stroke(curve, with: .color(channel.color), lineWidth: 1.5)
    for point in current {
      let spot = location(of: point, in: size)
      context.fill(
        Path(ellipseIn: CGRect(x: spot.x - 4, y: spot.y - 4, width: 8, height: 8)),
        with: .color(channel.color),
      )
    }
  }

  /// Grabs the point under the drag's start (adding one there if none is close), then moves it
  /// between its neighbours.
  private func moveGrabbed(_ drag: DragGesture.Value, size: CGSize) {
    var current = points
    if grabbed == nil {
      let start = drag.startLocation
      grabbed = current.indices.first { index in
        let spot = location(of: current[index], in: size)
        return hypot(spot.x - start.x, spot.y - start.y) < Self.grabDistance
      }
      if grabbed == nil {
        let added = value(at: start, in: size)
        let index = current.firstIndex { $0.x > added.x } ?? current.endIndex
        current.insert(added, at: index)
        grabbed = index
      }
    }
    guard let index = grabbed else {
      return
    }
    let moved = value(at: drag.location, in: size)
    let low = index > 0 ? current[index - 1].x + 0.01 : 0
    let high = index < current.count - 1 ? current[index + 1].x - 0.01 : 1
    current[index] = DrawingPoint(x: min(max(moved.x, low), high), y: moved.y)
    set(current)
  }

  private func finishGrab(_ drag: DragGesture.Value, size: CGSize) {
    defer {
      grabbed = nil
      onEnd()
    }
    let bounds = CGRect(origin: .zero, size: size)
      .insetBy(dx: -Self.removeDistance, dy: -Self.removeDistance)
    guard let index = grabbed, !bounds.contains(drag.location), points.count > 2 else {
      return
    }
    var current = points
    current.remove(at: index)
    set(current)
  }

  private func set(_ points: [DrawingPoint]?) {
    var changed = curves
    changed[keyPath: channel.field] = points
    onChange(changed)
  }

  /// Where a curve point sits in the box: input across, output up.
  private func location(of point: DrawingPoint, in size: CGSize) -> CGPoint {
    CGPoint(x: point.x * size.width, y: (1 - point.y) * size.height)
  }

  /// The curve point at a spot in the box, kept inside 0…1.
  private func value(at location: CGPoint, in size: CGSize) -> DrawingPoint {
    DrawingPoint(
      x: min(max(location.x / max(size.width, 1), 0), 1),
      y: min(max(1 - location.y / max(size.height, 1), 0), 1),
    )
  }

}

// MARK: - CurveChannel

/// The curve being edited.
private enum CurveChannel: CaseIterable {
  case master
  case red
  case green
  case blue

  // MARK: Internal

  var label: String {
    switch self {
    case .master: "All"
    case .red: "Red"
    case .green: "Green"
    case .blue: "Blue"
    }
  }

  var field: WritableKeyPath<Curves, [DrawingPoint]?> {
    switch self {
    case .master: \.master
    case .red: \.red
    case .green: \.green
    case .blue: \.blue
    }
  }

  var color: Color {
    switch self {
    case .master: Theme.text
    case .red: .red
    case .green: .green
    case .blue: .blue
    }
  }
}
