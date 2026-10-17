import SwiftUI

/// ⌘S: names a checkpoint, a snapshot to come back to with File › Revert To.
struct CheckpointSheet: View {

  // MARK: Internal

  var body: some View {
    Form {
      TextField("Checkpoint name", text: $name, prompt: Text("Rough cut"))
    }
    .formStyle(.grouped)
    .frame(width: 360)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Cancel") { dismiss() }
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("Save Checkpoint") {
          let name = name
          Task { await workspace.checkpoint(named: name) }
          dismiss()
        }
      }
    }
  }

  // MARK: Private

  @Environment(Workspace.self) private var workspace
  @Environment(\.dismiss) private var dismiss
  @State private var name = ""

}
