import ShadesDocument
import SwiftUI

/// File › Revert To: every snapshot, newest first. Reverting is one undoable edit.
struct RevertSheet: View {

  // MARK: Internal

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      SectionLabel(title: "Revert To", detail: snapshots.isEmpty ? nil : "\(snapshots.count)")
      List(snapshots, selection: $selection) { snapshot in
        HStack {
          Text(snapshot.label)
          Spacer()
          Text(snapshot.date, format: .dateTime.day().month().hour().minute())
            .foregroundStyle(.secondary)
        }
        .tag(snapshot)
      }
      .overlay {
        if snapshots.isEmpty {
          Text("Snapshots are kept every 10 minutes, before Claude edits, and with ⌘S.")
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding()
        }
      }
    }
    .frame(width: 420, height: 360)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Cancel") { dismiss() }
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("Revert") {
          if let selection {
            Task { await workspace.revert(to: selection) }
          }
          dismiss()
        }
        .disabled(selection == nil)
      }
    }
    .task { snapshots = await workspace.snapshots() }
  }

  // MARK: Private

  @Environment(Workspace.self) private var workspace
  @Environment(\.dismiss) private var dismiss
  @State private var snapshots = [Snapshot]()
  @State private var selection: Snapshot?

}
