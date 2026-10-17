import SwiftUI

/// Cursor-style section header: a small grey uppercase title with optional detail on the right.
struct SectionLabel: View {
  let title: String
  var detail: String?

  var body: some View {
    HStack {
      Text(title.uppercased())
        .font(.system(size: 10.5, weight: .semibold))
        .tracking(0.7)
        .foregroundStyle(Theme.secondaryText)
      Spacer()
      if let detail {
        Text(detail)
          .font(.caption)
          .foregroundStyle(Theme.faintText)
      }
    }
    .padding(.horizontal, 14)
    .padding(.top, 12)
    .padding(.bottom, 8)
  }
}
