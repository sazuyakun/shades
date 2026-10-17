import SwiftUI

/// Every change Claude made over MCP, newest first: a read-only edit log, not a chat.
struct HistoryPane: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      SectionLabel(title: "History")
      Text("Changes Claude makes over MCP appear here.")
        .font(.callout)
        .foregroundStyle(Theme.faintText)
        .padding(.horizontal, 14)
      Spacer()
    }
    .background(Theme.background)
  }
}
