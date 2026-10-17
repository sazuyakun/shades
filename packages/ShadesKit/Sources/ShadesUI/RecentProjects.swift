import ShadesDocument
import SwiftUI

/// The projects in `~/Shades`, newest first, each with its thumbnail.
struct RecentProjects: View {

  // MARK: Internal

  let onOpen: (URL) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      SectionLabel(title: "Recent", detail: entries.isEmpty ? nil : "\(entries.count)")
      if entries.isEmpty {
        Text("Projects you create appear here.")
          .font(.callout)
          .foregroundStyle(Theme.faintText)
          .padding(.horizontal, 14)
        Spacer()
      } else {
        ScrollView {
          LazyVStack(spacing: 2) {
            ForEach(entries) { entry in
              RecentProjectRow(entry: entry)
                .contentShape(.rect)
                .onTapGesture(count: 2) { onOpen(entry.url) }
                .onTapGesture { onOpen(entry.url) }
            }
          }
          .padding(.horizontal, 8)
        }
      }
    }
    .task { entries = await ProjectLibrary.projects() }
  }

  // MARK: Private

  @State private var entries = [LibraryEntry]()

}
