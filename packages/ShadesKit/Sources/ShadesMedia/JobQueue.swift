import Foundation
import Observation

/// Runs heavy background work one job at a time at low priority, so editing never waits on it.
/// Jobs pause while the Mac is hot or in Low Power Mode. The toolbar's ring and Claude read it.
@MainActor
@Observable
public final class JobQueue {

  // MARK: Lifecycle

  public init() { }

  // MARK: Public

  /// Reports how far a job has got, from 0 to 1. Safe to call from any thread.
  public typealias Progress = @Sendable (Double) -> Void
  /// The work itself; it throws `JobError` (wrapping its own error) to fail.
  public typealias Work = @Sendable (_ progress: @escaping Progress) async throws(JobError) -> Void

  /// Finished jobs kept for the ring's list.
  public static let finishedKept = 5

  /// Jobs waiting, running and recently finished, oldest first.
  public private(set) var jobs = [Job]()
  /// Why jobs are paused right now, if they are.
  public private(set) var pauseReason: String?

  /// Jobs not finished yet.
  public var activeJobs: [Job] {
    jobs.filter { !$0.state.isFinished }
  }

  /// Adds work to the end of the queue and returns its ID.
  @discardableResult
  public func enqueue(_ title: String, work: @escaping Work) -> Job.ID {
    let job = Job(id: UUID(), title: title, state: .queued)
    jobs.append(job)
    pending.append((job.id, work))
    startIfIdle()
    return job.id
  }

  /// Cancels a job: a queued one never starts; a running one is asked to stop.
  public func cancel(_ id: Job.ID) {
    if let index = pending.firstIndex(where: { $0.id == id }) {
      pending.remove(at: index)
      update(id, to: .cancelled)
    } else if id == running?.id {
      running?.work.cancel()
    }
  }

  /// Waits until every job has finished (for tests and quitting).
  public func waitUntilIdle() async {
    while runner != nil {
      try? await Task.sleep(for: .milliseconds(20)) // why: a cancelled wait just checks again.
    }
  }

  // MARK: Private

  @ObservationIgnored private var pending = [(id: Job.ID, work: Work)]()
  @ObservationIgnored private var runner: Task<Void, Never>?
  /// The job running now, in its own task so cancelling it leaves the loop and later jobs alone.
  @ObservationIgnored private var running: (id: Job.ID, work: Task<JobState, Never>)?

  private static func currentPauseReason() -> String? {
    let info = ProcessInfo.processInfo
    if info.thermalState == .serious || info.thermalState == .critical {
      return "Paused while your Mac cools down."
    }
    if info.isLowPowerModeEnabled {
      return "Paused in Low Power Mode."
    }
    return nil
  }

  private func startIfIdle() {
    guard runner == nil else {
      return
    }
    runner = Task(priority: .utility) {
      while let next = pending.first {
        pending.removeFirst()
        await waitWhilePaused()
        update(next.id, to: .running(progress: nil))
        let work = Task { await run(next.work, id: next.id) }
        running = (next.id, work)
        update(next.id, to: await work.value)
        running = nil
      }
      runner = nil
      trimFinished()
    }
  }

  private func run(_ work: Work, id: Job.ID) async -> JobState {
    let report: Progress = { [weak self] fraction in
      Task { @MainActor in self?.report(fraction, for: id) }
    }
    do throws(JobError) {
      try await work(report)
      return Task.isCancelled ? .cancelled : .done
    } catch {
      switch error {
      case .cancelled: return .cancelled
      case .failed(let message): return .failed(message)
      }
    }
  }

  private func report(_ fraction: Double, for id: Job.ID) {
    guard
      let index = jobs.firstIndex(where: { $0.id == id }),
      case .running = jobs[index].state
    else {
      return
    }
    jobs[index].state = .running(progress: min(max(fraction, 0), 1))
  }

  private func update(_ id: Job.ID, to state: JobState) {
    guard let index = jobs.firstIndex(where: { $0.id == id }) else {
      return
    }
    jobs[index].state = state
    trimFinished()
  }

  /// Keeps only the last few finished jobs.
  private func trimFinished() {
    let finished = jobs.filter(\.state.isFinished)
    if finished.count > Self.finishedKept {
      let dropped = Set(finished.prefix(finished.count - Self.finishedKept).map(\.id))
      jobs.removeAll { dropped.contains($0.id) }
    }
  }

  /// Holds the next job while the Mac is hot or saving power.
  private func waitWhilePaused() async {
    while let reason = Self.currentPauseReason() {
      pauseReason = reason
      try? await Task.sleep(for: .seconds(5)) // why: a cancelled wait just checks again.
    }
    pauseReason = nil
  }

}
