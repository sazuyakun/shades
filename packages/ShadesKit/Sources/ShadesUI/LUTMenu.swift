import AppKit
import SwiftUI

/// Picks a LUT: none, one from a plugin, or a `.cube` file anywhere.
struct LUTMenu: View {

  // MARK: Internal

  let selected: String?
  let luts: [(name: String, path: String)]
  let onChoose: (String?) -> Void

  var body: some View {
    HStack {
      Text("LUT").foregroundStyle(Theme.secondaryText)
      Spacer()
      Menu {
        Button("None") { onChoose(nil) }
        ForEach(luts, id: \.path) { lut in
          Button(lut.name) { onChoose(lut.path) }
        }
        Divider()
        Button("Choose File…") { isChoosing = true }
      } label: {
        Text(selected.map { URL(filePath: $0).deletingPathExtension().lastPathComponent } ?? "None")
          .lineLimit(1)
      }
      .fixedSize()
    }
    .fileImporter(isPresented: $isChoosing, allowedContentTypes: [.data]) { result in
      if case .success(let url) = result {
        onChoose(url.path)
      }
    }
  }

  // MARK: Private

  @State private var isChoosing = false

}
