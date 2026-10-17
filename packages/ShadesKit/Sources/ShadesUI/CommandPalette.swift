import SwiftUI

/// ⌘K: every action by name. Type to filter, ↑↓ to choose, Return to run, Esc to close.
struct CommandPalette: View {

  // MARK: Internal

  let onRun: (EditorAction) -> Void

  var body: some View {
    VStack(spacing: 0) {
      TextField("Type an action…", text: $query)
        .textFieldStyle(.plain)
        .font(.system(size: 15))
        .padding(14)
        .focused($isSearchFocused)
        .onSubmit(runHighlighted)
        .onKeyPress(.downArrow) { move(1) }
        .onKeyPress(.upArrow) { move(-1) }
        .onChange(of: query) { highlighted = 0 }
      Hairline()
      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack(spacing: 0) {
            ForEach(Array(matches.enumerated()), id: \.element) { index, action in
              PaletteRow(action: action, isHighlighted: index == highlighted)
                .id(action)
                .onTapGesture { run(action) }
            }
          }
          .padding(6)
        }
        .onChange(of: highlighted) {
          if matches.indices.contains(highlighted) {
            proxy.scrollTo(matches[highlighted])
          }
        }
      }
      .frame(height: 320)
    }
    .frame(width: 480)
    .background(Theme.raised)
    .onAppear { isSearchFocused = true }
    .onExitCommand { dismiss() }
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss
  @State private var query = ""
  @State private var highlighted = 0
  @FocusState private var isSearchFocused: Bool

  /// Actions whose name contains every typed word.
  private var matches: [EditorAction] {
    let words = query.lowercased().split(separator: " ")
    return EditorAction.allCases.filter { action in
      words.allSatisfy { action.title.lowercased().contains($0) }
    }
  }

  private func move(_ offset: Int) -> KeyPress.Result {
    highlighted = min(max(highlighted + offset, 0), max(matches.count - 1, 0))
    return .handled
  }

  private func runHighlighted() {
    if matches.indices.contains(highlighted) {
      run(matches[highlighted])
    }
  }

  private func run(_ action: EditorAction) {
    dismiss()
    onRun(action)
  }

}
