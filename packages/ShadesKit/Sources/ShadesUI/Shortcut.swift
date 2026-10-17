import SwiftUI

/// A key plus modifiers that triggers an action, and how it's written ("⇧⌘L").
struct Shortcut: Equatable {

  // MARK: Lifecycle

  init(_ key: KeyEquivalent, _ modifiers: EventModifiers = []) {
    self.key = key
    self.modifiers = modifiers
  }

  // MARK: Internal

  let key: KeyEquivalent
  let modifiers: EventModifiers

  /// The shortcut as the Mac writes it, e.g. "⌥⌘J".
  var label: String {
    var text = ""
    if modifiers.contains(.control) {
      text += "⌃"
    }
    if modifiers.contains(.option) {
      text += "⌥"
    }
    if modifiers.contains(.shift) {
      text += "⇧"
    }
    if modifiers.contains(.command) {
      text += "⌘"
    }
    return text + keyName
  }

  static func ==(lhs: Shortcut, rhs: Shortcut) -> Bool {
    lhs.key.character == rhs.key.character && lhs.modifiers == rhs.modifiers
  }

  /// Whether a key press is this shortcut. Shifted punctuation ("<") counts as its key (",").
  func matches(_ press: KeyPress) -> Bool {
    let pressed = press.modifiers.intersection([.command, .option, .control, .shift])
    guard pressed == modifiers else {
      return false
    }
    let character = Self
      .unshifted[press.key.character] ?? Character(press.key.character.lowercased())
    return character == key.character
  }

  // MARK: Private

  private static let unshifted: [Character: Character] = ["<": ",", ">": ".", "+": "="]

  private var keyName: String {
    switch key {
    case .space: "Space"
    case .delete: "⌫"
    case .escape: "Esc"
    case .leftArrow: "←"
    case .rightArrow: "→"
    case .upArrow: "↑"
    case .downArrow: "↓"
    default: String(key.character).uppercased()
    }
  }

}
