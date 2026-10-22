import Foundation
import IOKit.ps
import Observation

/// Runs heavy background work one job at a time at low priority, so editing never waits on it.
/// Jobs pause while the Mac is hot, in Low Power Mode or (except exports) on battery: before
/// they start, and between chunks of work at each `pausePoint()`. The toolbar's ring and Claude
/// read it.
@MainActor
@Observable
public final class JobQueue {

  // MARK: Lifecycle

  /// `pauseCheck` says why jobs should wait right now, given whether the job pauses on battery
  /// (`nil` to run), asked again every `checkInterval` while paused; tests pass their own.
  public init(
    pauseCheck: @escaping @Sendable (_ pausesOnBattery: Bool) -> String? = JobQueue.systemPause,
    checkInterval: Duration = .seconds(5),
  ) {
    self.pauseCheck = pauseCheck
    self.checkInterval = checkInterval
  }

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

  /// Why background work would pause now, from the Mac's heat, Low Power Mode and power source.
  public nonisolated static func systemPause(pausesOnBattery: Bool) -> String? {
    let info = ProcessInfo.processInfo
    if info.thermalState == .serious || info.thermalState == .critical {
      return "Paused while your Mac cools down."
    }
    if info.isLowPowerModeEnabled {
      return "Paused in Low Power Mode."
    }
    if pausesOnBattery, isOnBattery() {
      return "Paused on battery power. Plug in to carry on."
    }
    return nil
  }

  /// Waits while the job running this code should pause; work calls it between chunks (frames,
  /// segments). Outside a job it returns at once.
  public nonisolated static func pausePoint() async {
    await pauseGate.get()?()
  }

  /// Adds work to the end of the queue and returns its ID. Work the user is waiting for, like an
  /// export, passes `pausesOnBattery: false`.
  @discardableResult
  public func enqueue(
    _ title: String,
    pausesOnBattery: Bool = true,
    work: @escaping Work,
  ) -> Job.ID {
    let job = Job(id: UUID(), title: title, state: .queued)
    jobs.append(job)
    pending.append((job.id, pausesOnBattery, work))
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

  /// The running job's way to wait while paused, for `pausePoint()`.
  private nonisolated static let pauseGate = TaskLocal<(@Sendable () async -> Void)?>(
    wrappedValue: nil
  )

  @ObservationIgnored private let pauseCheck: @Sendable (_ pausesOnBattery: Bool) -> String?
  @ObservationIgnored private let checkInterval: Duration
  @ObservationIgnored private var pending = [(id: Job.ID, pausesOnBattery: Bool, work: Work)]()
  @ObservationIgnored private var runner: Task<Void, Never>?
  /// The job running now, in its own task so cancelling it leaves the loop and later jobs alone.
  @ObservationIgnored private var running: (id: Job.ID, work: Task<JobState, Never>)?

  /// Whether the Mac is running on its battery.
  private nonisolated static func isOnBattery() -> Bool {
    let sources = IOPSCopyPowerSourcesInfo().takeRetainedValue()
    // why: a Mac with no power source info (a virtual machine) counts as plugged in.
    let providing = IOPSGetProvidingPowerSourceType(sources)?.takeUnretainedValue() as String?
    return providing == kIOPSBatteryPowerValue
  }

  private func startIfIdle() {
    guard runner == nil else {
      return
    }
    runner = Task(priority: .utility) {
      while let first = pending.first {
        // why: a paused job stays queued (so it can be cancelled) while one that may run, like
        // an export on battery, goes ahead of it.
        guard let index = pending.firstIndex(where: { pauseCheck($0.pausesOnBattery) == nil })
        else {
          pauseReason = pauseCheck(first.pausesOnBattery)
          try? await Task.sleep(for: checkInterval) // why: this task is never cancelled.
          continue
        }
        pauseReason = nil
        let next = pending.remove(at: index)
        update(next.id, to: .running(progress: nil))
        let work = Task {
          await run(next.work, id: next.id, pausesOnBattery: next.pausesOnBattery)
        }
        running = (next.id, work)
        update(next.id, to: await work.value)
        running = nil
      }
      runner = nil
      trimFinished()
    }
  }

  private func run(_ work: Work, id: Job.ID, pausesOnBattery: Bool) async -> JobState {
    let report: Progress = { [weak self] fraction in
      Task { @MainActor in self?.report(fraction, for: id) }
    }
    let pause: @Sendable () async -> Void = { [weak self] in
      await self?.waitWhilePaused(pausesOnBattery: pausesOnBattery)
    }
    return await Self.pauseGate.withValue(pause) {
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

  /// Holds a running job at a pause point while the Mac is hot or saving power, until it's
  /// cancelled.
  private func waitWhilePaused(pausesOnBattery: Bool) async {
    while !Task.isCancelled, let reason = pauseCheck(pausesOnBattery) {
      pauseReason = reason
      try? await Task.sleep(for: checkInterval) // why: a cancelled wait just stops.
    }
    pauseReason = nil
  }

}
