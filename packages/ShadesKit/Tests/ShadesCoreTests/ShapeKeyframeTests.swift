import ShadesCore
import Testing

struct ShapeKeyframeTests {
  @Test
  func `a mask moves and reshapes between its keyframes and holds outside them`() {
    let mask = LayerMask(
      shape: .path,
      points: [DrawingPoint(x: 0, y: 0), DrawingPoint(x: 1, y: 0), DrawingPoint(x: 0, y: 1)],
      keyframes: [
        ShapeKeyframe(
          time: MediaTime(seconds: 1),
          x: 0.2,
          y: 0.5,
          width: 0.2,
          height: 0.2,
          points: [DrawingPoint(x: 0, y: 0), DrawingPoint(x: 1, y: 0), DrawingPoint(x: 0, y: 1)],
        ),
        ShapeKeyframe(
          time: MediaTime(seconds: 2),
          x: 0.6,
          y: 0.5,
          width: 0.4,
          height: 0.2,
          points: [DrawingPoint(x: 0, y: 0), DrawingPoint(x: 1, y: 0), DrawingPoint(x: 1, y: 1)],
        ),
      ],
    )
    let halfway = mask.placed(at: MediaTime(seconds: 1.5))
    #expect(abs(halfway.x - 0.4) < 0.0001)
    #expect(abs(halfway.width - 0.3) < 0.0001)
    #expect(abs((halfway.points.last?.x ?? 0) - 0.5) < 0.0001)
    #expect(mask.placed(at: .zero).x == 0.2)
    #expect(mask.placed(at: MediaTime(seconds: 3)).x == 0.6)
  }

  @Test
  func `a shape without keyframes stays where it's fixed`() {
    let window = GradeWindow(x: 0.3, y: 0.7)
    #expect(window.placed(at: MediaTime(seconds: 5)) == window)
    #expect(window.keyframe(at: .zero).x == 0.3)
  }

  @Test
  func `an outline with a different number of points jumps at the next keyframe`() {
    let three = [DrawingPoint(x: 0, y: 0), DrawingPoint(x: 1, y: 0), DrawingPoint(x: 0, y: 1)]
    let four = three + [DrawingPoint(x: 1, y: 1)]
    let from = ShapeKeyframe(time: .zero, x: 0, y: 0, width: 1, height: 1, points: three)
    let to = ShapeKeyframe(
      time: MediaTime(seconds: 1),
      x: 0,
      y: 0,
      width: 1,
      height: 1,
      points: four,
    )
    #expect(from.value(towards: to, at: 0.9).points == three)
    #expect(from.value(towards: to, at: 1).points == four)
  }

  @Test
  func `setting a keyframe replaces the one at the same moment and keeps time order`() {
    var keys = [
      ShapeKeyframe(time: MediaTime(seconds: 2), x: 0, y: 0, width: 1, height: 1),
      ShapeKeyframe(time: MediaTime(seconds: 1), x: 0, y: 0, width: 1, height: 1),
    ]
    keys.set(ShapeKeyframe(time: MediaTime(seconds: 2), x: 0.5, y: 0, width: 1, height: 1))
    keys.set(ShapeKeyframe(time: .zero, x: 0.1, y: 0, width: 1, height: 1))
    #expect(keys.map(\.time.seconds) == [0, 1, 2])
    #expect(keys.last?.x == 0.5)
  }
}
