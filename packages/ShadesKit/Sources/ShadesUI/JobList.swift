import ShadesMedia
import SwiftUI

/// The ring's popover: every background job with its progress, and Cancel.
struct JobList: View {

  // MARK: Internal

  let queue: JobQueue

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      SectionLabel(title: "Background work")
      ForEach(queue.jobs) { job in
        HStack(spacing: 8) {
          VStack(alignment: .leading, spacing: 4) {
            Text(job.title).lineLimit(1)
            status(of: job)
          }
          Spacer()
          if !job.state.isFinished {
            Button("Cancel") { queue.cancel(job.id) }
              .buttonStyle(CapsuleButtonStyle())
          }
        }
        .padding(.horizontal, 14)
      }
      if let reason = queue.pauseReason {
        Text(reason)
          .font(.caption)
          .foregroundStyle(Theme.secondaryText)
          .padding(.horizontal, 14)
      }
    }
    .padding(.bottom, 14)
    .frame(width: 320)
  }

  // MARK: Private

  @ViewBuilder
  private func status(of job: Job) -> some View {
    switch job.state {
    case .queued:
      Text("Waiting").font(.caption).foregroundStyle(Theme.faintText)

    case .running(let progress):
      if let progress {
        ProgressView(value: progress).controlSize(.small)
      } else {
        ProgressView().progressViewStyle(.linear).controlSize(.small)
      }

    case .done:
      Text("Done").font(.caption).foregroundStyle(Theme.positive)

    case .failed(let message):
      Text(message).font(.caption).foregroundStyle(Theme.negative).lineLimit(2)

    case .cancelled:
      Text("Cancelled").font(.caption).foregroundStyle(Theme.faintText)
    }
  }

}
