import ShadesCore
import ShadesPolish
import SwiftUI

/// One kind of Polish edit: a switch for the whole group with its count, then each item.
struct PolishGroup: View {

  // MARK: Internal

  let kind: PolishKind
  let items: [PolishItem]
  let onSeek: (MediaTime) -> Void

  var body: some View {
    let enabled = items.count(where: \.isEnabled)
    VStack(alignment: .leading, spacing: 6) {
      Toggle(isOn: Binding(
        get: { enabled > 0 },
        set: { workspace.setPolish($0, kind: kind) },
      )) {
        HStack {
          Circle().fill(PolishColors.color(of: kind)).frame(width: 7, height: 7)
          Text(kind.title).font(.callout.weight(.medium))
          Spacer()
          Text(verbatim: "\(enabled)/\(items.count)")
            .font(.caption.monospacedDigit())
            .foregroundStyle(Theme.secondaryText)
        }
      }
      ForEach(items) { item in
        HStack(spacing: 6) {
          Toggle("", isOn: Binding(
            get: { item.isEnabled },
            set: { workspace.setPolish($0, ids: [item.id]) },
          ))
          .labelsHidden()
          .controlSize(.small)
          Text(Timecode.short(item.range.start.seconds))
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(Theme.faintText)
          Text(item.detail)
            .font(.caption)
            .foregroundStyle(item.isEnabled ? Theme.text : Theme.faintText)
            .lineLimit(1)
          Spacer()
        }
        .padding(.leading, 14)
        .contentShape(.rect)
        .onTapGesture { onSeek(item.range.start) }
      }
    }
  }

  // MARK: Private

  @Environment(Workspace.self) private var workspace

}
