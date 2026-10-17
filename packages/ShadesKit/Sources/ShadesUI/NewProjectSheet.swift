import ShadesCore
import ShadesDocument
import SwiftUI

/// Names a new project and picks its 4:3 size and frame rate.
struct NewProjectSheet: View {

  // MARK: Internal

  let onCreate: (String, VideoFormat) -> Void

  var body: some View {
    Form {
      TextField("Name", text: $name)
      Picker("Size", selection: $isHalfSize) {
        Text(verbatim: "2880×2160").tag(false)
        Text(verbatim: "1440×1080").tag(true)
      }
      .pickerStyle(.segmented)
      Picker("Frame rate", selection: $framesPerSecond) {
        ForEach(VideoFormat.frameRates, id: \.self) { rate in
          Text(verbatim: "\(rate) fps").tag(rate)
        }
      }
      .pickerStyle(.segmented)
    }
    .formStyle(.grouped)
    .frame(width: 400)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Cancel") { dismiss() }
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("Create") {
          let size: VideoFormat = isHalfSize ? .half : .standard
          onCreate(name, size.withFrameRate(framesPerSecond))
          dismiss()
        }
        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
      }
    }
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss
  @State private var name = ProjectLibrary.unusedName()
  @State private var isHalfSize = false
  @State private var framesPerSecond = 24

}
