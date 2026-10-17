import ShadesMedia
import SwiftUI

// MARK: - TasksRing

/// The toolbar's background-tasks ring: shows while proxies, transcripts or analysis run, with
/// overall progress. Click it for each job and a way to cancel.
struct TasksRing: View {

  // MARK: Internal

  var body: some View {
    let jobs = workspace.jobs
    if !jobs.activeJobs.isEmpty {
      Button {
        isShowingDetails = true
      } label: {
        HStack(spacing: 6) {
          ProgressRing(progress: overallProgress(jobs.activeJobs))
            .frame(width: 13, height: 13)
          Text(verbatim: "\(jobs.activeJobs.count)")
            .monospacedDigit()
        }
      }
      .help("Background work: \(jobs.activeJobs.count) job\(jobs.activeJobs.count == 1 ? "" : "s")")
      .popover(isPresented: $isShowingDetails, arrowEdge: .bottom) {
        JobList(queue: jobs)
      }
    }
  }

  // MARK: Private

  @Environment(Workspace.self) private var workspace
  @State private var isShowingDetails = false

  /// The average progress of jobs that report it; `nil` when none can tell.
  private func overallProgress(_ jobs: [Job]) -> Double? {
    let values = jobs.compactMap { job -> Double? in
      switch job.state {
      case .queued: 0
      case .running(let progress): progress
      default: nil
      }
    }
    return values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
  }

}

// MARK: - ProgressRing

/// A small circular progress indicator; spins when progress is unknown.
private struct ProgressRing: View {
  let progress: Double?

  var body: some View {
    ZStack {
      Circle().stroke(Theme.strongHairline, lineWidth: 2)
      if let progress {
        Circle()
          .trim(from: 0, to: max(progress, 0.03))
          .stroke(Theme.text, style: StrokeStyle(lineWidth: 2, lineCap: .round))
          .rotationEffect(.degrees(-90))
      } else {
        ProgressView().controlSize(.mini)
      }
    }
  }
}
