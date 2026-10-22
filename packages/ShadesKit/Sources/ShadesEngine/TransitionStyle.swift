import Foundation
import ShadesCore

/// How a clip looks partway through a transition: faded, moved, blurred, dipped to a colour or
/// wiped in. Pure maths, so preview and export agree.
struct TransitionStyle: Equatable {

  // MARK: Lifecycle

  /// The look of the outgoing or incoming clip (`isIncoming`) of a `kind` transition at
  /// `progress` (0 to 1).
  init(kind: TransitionKind, progress: Double, isIncoming: Bool) {
    let firstHalf = progress < 0.5
    switch kind {
    case .dissolve:
      opacity = isIncoming ? progress : 1

    case .dipToBlack,
         .flash:
      opacity = isIncoming == !firstHalf ? 1 : 0
      dip = 1 - abs(2 * progress - 1)
      dipsToWhite = kind == .flash
      if kind == .flash {
        dip = max(0, 1 - abs(2 * progress - 1) * 1.6)
      }

    case .whip:
      // why: a whip is a push so fast it smears; easing in hard keeps the shots joined.
      let swing = Easing.easeInOut.progress(Easing.easeInOut.progress(progress))
      offsetX = isIncoming ? 1 - swing : -swing
      blur = 0.9 * (1 - abs(2 * progress - 1))

    case .push:
      let travel = Easing.easeInOut.progress(progress)
      offsetX = isIncoming ? 1 - travel : -travel

    case .portal:
      // why: the outgoing shot grows exactly as fast as the frame of the next one, so the view
      // seems to fly in through it; growing by powers keeps the speed steady.
      let travel = Easing.easeInOut.progress(progress)
      scale = pow(Self.portalZoom, isIncoming ? travel - 1 : travel)
      opacity = isIncoming ? min(progress / 0.15, 1) : 1

    case .slices,
         .tiles,
         .iris:
      if isIncoming {
        wipe = kind
        wipeProgress = progress
      }
    }
  }

  // MARK: Internal

  var opacity = 1.0
  /// Grows the clip about its centre.
  var scale = 1.0
  /// Moves the clip sideways, in frame widths.
  var offsetX = 0.0
  var blur = 0.0
  /// How far the clip is faded to black (or white), 0 to 1.
  var dip = 0.0
  var dipsToWhite = false
  /// The pattern the incoming clip is revealed through, if any.
  var wipe: TransitionKind?
  var wipeProgress = 0.0

  // MARK: Private

  /// How much smaller the next shot's frame starts than the picture, in a portal.
  private static let portalZoom = 6.0

}
