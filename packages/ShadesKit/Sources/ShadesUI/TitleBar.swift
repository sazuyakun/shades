import SwiftUI

/// The window's top bar: Import on the left, the title pill centred, and the side-pane switch
/// and Claude's connection on the right. Drag it to move the window.
struct TitleBar: View {
  @Binding var sidePane: SidePane

  let onImport: () -> Void

  var body: some View {
    ZStack {
      HStack(spacing: 8) {
        CapsuleGroup {
          Button("Import", systemImage: "square.and.arrow.down", action: onImport)
            .help("Import media (⌘I)")
        }
        Spacer()
        CapsuleGroup {
          Button("Inspector") { sidePane = .inspector }
            .buttonStyle(CapsuleButtonStyle(isOn: sidePane == .inspector))
          Button("History") { sidePane = sidePane == .history ? .inspector : .history }
            .buttonStyle(CapsuleButtonStyle(isOn: sidePane == .history))
            .help("Show or hide Claude's changes (⌘L)")
        }
        CapsuleGroup {
          ClaudeStatusPill()
        }
      }
      TitlePill()
    }
    .buttonStyle(CapsuleButtonStyle())
    .padding(.leading, 84)
    .padding(.trailing, 12)
    .frame(height: 46)
    .background(Theme.background)
    .gesture(WindowDragGesture())
  }
}
