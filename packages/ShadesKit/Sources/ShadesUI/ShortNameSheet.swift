import ShadesCommands
import ShadesCore
import SwiftUI

/// ⌥N: renames a short, the name its export file gets.
struct ShortNameSheet: View {

  // MARK: Internal

  let shortID: Short.ID

  var body: some View {
    Form {
      TextField("Short name", text: $name, prompt: Text("Short 1 · Chul ka keeda"))
      if let problem {
        Text(problem).foregroundStyle(Theme.negative)
      }
    }
    .formStyle(.grouped)
    .frame(width: 360)
    .onAppear {
      name = editor.project.timeline.shorts.first { $0.id == shortID }?.name ?? ""
    }
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Cancel") { dismiss() }
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("Rename") { rename() }
      }
    }
  }

  // MARK: Private

  @Environment(Editor.self) private var editor
  @Environment(\.dismiss) private var dismiss
  @State private var name = ""
  @State private var problem: String?

  private func rename() {
    do {
      try editor.perform(SetShort(shortID: shortID, name: name))
      dismiss()
    } catch {
      problem = error.errorDescription
    }
  }

}
