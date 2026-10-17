import ShadesDocument
import SwiftUI

/// The small window shown when no project is open: New Project, Open, and recent projects.
public struct WelcomeView: View {

  // MARK: Lifecycle

  public init() { }

  // MARK: Public

  public var body: some View {
    HStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 14) {
        Text("Shades")
          .font(.system(size: 28, weight: .semibold))
        Text("An AI-native video editor. Claude edits over MCP; you see every change.")
          .font(.callout)
          .foregroundStyle(Theme.secondaryText)
          .fixedSize(horizontal: false, vertical: true)
        Spacer()
        Button("New Project…") { isCreating = true }
          .keyboardShortcut("n")
          .buttonStyle(.borderedProminent)
        Button("Open…") { isOpening = true }
          .keyboardShortcut("o")
      }
      .padding(24)
      .frame(width: 260, alignment: .leading)
      Hairline(vertical: true)
      RecentProjects(onOpen: open)
        .frame(width: 380)
    }
    .frame(height: 380)
    .background(Theme.background)
    .foregroundStyle(Theme.text)
    .preferredColorScheme(.dark)
    .onChange(of: workspace.documentURL) { showEditor() }
    .task { await workspace.restoreLastProject() }
    .sheet(isPresented: $isCreating) {
      NewProjectSheet { name, format in
        Task { await workspace.create(named: name, format: format) }
      }
    }
    .fileImporter(isPresented: $isOpening, allowedContentTypes: [.folder]) { result in
      if case .success(let url) = result {
        open(url)
      }
    }
    .alert(
      "Something went wrong",
      isPresented: Binding(get: { workspace.errorMessage != nil }, set: { isShown in
        if !isShown {
          workspace.errorMessage = nil
        }
      }),
      actions: { Button("OK") { } },
      message: { Text(workspace.errorMessage ?? "") },
    )
  }

  // MARK: Private

  @Environment(Workspace.self) private var workspace
  @Environment(\.openWindow) private var openWindow
  @Environment(\.dismissWindow) private var dismissWindow
  @State private var isCreating = false
  @State private var isOpening = false

  private func open(_ url: URL) {
    Task { await workspace.open(url) }
  }

  private func showEditor() {
    guard workspace.documentURL != nil else {
      return
    }
    openWindow(id: WindowID.editor)
    dismissWindow(id: WindowID.welcome)
  }

}
