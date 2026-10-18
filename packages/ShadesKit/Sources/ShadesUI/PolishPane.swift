import ShadesCore
import ShadesEngine
import ShadesPolish
import SwiftUI

/// The Polish checklist: each kind of edit with a count and a switch, its items underneath, and
/// Apply (one undo step) or Discard. Click an item to jump to it.
struct PolishPane: View {

  // MARK: Internal

  let onError: (String) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      SectionLabel(title: "Polish", detail: workspace.polishPlan.map { "\($0.track)" })
      if let plan = workspace.polishPlan {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 14) {
            ForEach(PolishKind.allCases, id: \.self) { kind in
              let items = plan.items.filter { $0.kind == kind }
              if !items.isEmpty {
                PolishGroup(kind: kind, items: items, onSeek: seek)
              }
            }
          }
          .padding(14)
        }
        Hairline()
        HStack {
          Button("Discard") { workspace.discardPolish() }
          Spacer()
          Button("Apply") { apply() }
            .keyboardShortcut(.defaultAction)
        }
        .buttonStyle(CapsuleButtonStyle())
        .padding(14)
      } else {
        Text("Select clips and choose Polish Selection (⌥P), or ask Claude to polish a stretch.")
          .font(.callout)
          .foregroundStyle(Theme.faintText)
          .padding(14)
        Spacer()
      }
    }
    .background(Theme.background)
  }

  // MARK: Private

  @Environment(Workspace.self) private var workspace
  @Environment(Player.self) private var player

  private func seek(_ time: MediaTime) {
    Task { await player.seek(toSeconds: time.seconds) }
  }

  private func apply() {
    do {
      _ = try workspace.applyPolish(ids: nil, kinds: nil)
    } catch {
      onError(error.errorDescription ?? "Polish couldn't be applied.")
    }
  }

}
