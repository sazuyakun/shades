import ShadesMCP
import ShadesMedia
import SwiftUI

// MARK: - HistoryRow

/// One Claude request: what was asked, when, what it came to ("+2 clips"), its steps while it's
/// the latest (✓ done, ✗ failed, ◌ still running in the background), and Undo / Show / Stop.
struct HistoryRow: View {

  // MARK: Internal

  let request: ClaudeRequest
  /// Whether it's the newest request, whose steps show.
  let isLatest: Bool
  /// Background jobs it started that are still listed.
  let jobs: [Job]
  let onUndo: () -> Void
  let onShow: () -> Void
  let onStop: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .firstTextBaseline) {
        Text(request.title)
          .font(.callout.weight(.medium))
          .lineLimit(2)
        Spacer()
        Text(request.date, style: .relative)
          .font(.caption)
          .foregroundStyle(Theme.faintText)
      }
      HistoryResult(request: request)
      if isLatest || !running.isEmpty {
        ForEach(isLatest ? request.steps.suffix(Self.stepsShown) : []) { step in
          HistoryStep(
            symbol: step.isError ? "xmark.circle" : "checkmark.circle",
            color: step.isError ? Theme.negative : Theme.positive,
            text: step.isError ? "\(step.title): \(step.summary)" : step.title,
          )
        }
        ForEach(running) { job in
          HistoryStep(symbol: "circle.dashed", color: Theme.claude, text: progress(of: job))
        }
      }
      HStack(spacing: 6) {
        if request.hasChanges {
          Button("Undo", action: onUndo)
            .help("Take back everything this request changed, keeping later edits")
        }
        if !request.changedClipIDs.isEmpty {
          Button("Show", action: onShow)
            .help("Select its clips and move the playhead to them")
        }
        if !running.isEmpty {
          Button("Stop", action: onStop)
            .help("Cancel its background work")
        }
      }
      .buttonStyle(CapsuleButtonStyle())
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
  }

  // MARK: Private

  /// How many of the latest request's steps show; earlier ones are summed up in the result.
  private static let stepsShown = 6

  private var running: [Job] {
    jobs.filter { !$0.state.isFinished }
  }

  private func progress(of job: Job) -> String {
    if case .running(let fraction?) = job.state {
      return "\(job.title)… \(Int(fraction * 100))%"
    }
    return "\(job.title)…"
  }

}

// MARK: - HistoryResult

/// What a request came to: clips added in green, clips removed and failed steps in red, and how
/// many steps it took.
private struct HistoryResult: View {

  // MARK: Internal

  let request: ClaudeRequest

  var body: some View {
    HStack(spacing: 4) {
      ForEach(parts.indices, id: \.self) { index in
        Text(index == 0 ? parts[index].text : "· " + parts[index].text)
          .foregroundStyle(parts[index].color)
      }
    }
    .font(.caption)
  }

  // MARK: Private

  private var parts: [(text: String, color: Color)] {
    let added = request.addedClipCount
    let removed = request.removedClipCount
    let steps = request.steps.count
    let failed = request.steps.count { $0.isError }
    return [
      added > 0 ? ("+\(added) clip\(added == 1 ? "" : "s")", Theme.positive) : nil,
      removed > 0 ? ("−\(removed) clip\(removed == 1 ? "" : "s")", Theme.negative) : nil,
      steps > 0 ? ("\(steps) step\(steps == 1 ? "" : "s")", Theme.secondaryText) : nil,
      failed > 0 ? ("\(failed) failed", Theme.negative) : nil,
    ].compactMap(\.self)
  }

}

// MARK: - HistoryStep

/// One quiet line under a request: a step done, failed or still running.
private struct HistoryStep: View {
  let symbol: String
  let color: Color
  let text: String

  var body: some View {
    Label {
      Text(text)
        .foregroundStyle(Theme.secondaryText)
        .lineLimit(2)
    } icon: {
      Image(systemName: symbol).foregroundStyle(color)
    }
    .font(.caption)
  }
}
