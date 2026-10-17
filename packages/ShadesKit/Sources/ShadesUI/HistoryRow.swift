import ShadesMCP
import SwiftUI

/// One History entry: what Claude did, the tool's answer, when, and a button to jump to it.
struct HistoryRow: View {
  let entry: ActivityEntry
  let onShow: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 6) {
        Circle()
          .fill(entry.isError ? Theme.negative : Theme.claude)
          .frame(width: 6, height: 6)
        Text(entry.title)
          .font(.callout.weight(.medium))
        Spacer()
        Text(entry.date, style: .relative)
          .font(.caption)
          .foregroundStyle(Theme.faintText)
      }
      Text(entry.summary)
        .font(.caption)
        .foregroundStyle(entry.isError ? Theme.negative : Theme.secondaryText)
        .lineLimit(3)
      if !entry.changedClipIDs.isEmpty {
        Button("Show", action: onShow)
          .buttonStyle(CapsuleButtonStyle())
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
  }
}
