import Foundation
import ShadesMedia
import Synchronization
import Testing

@MainActor
struct JobQueueTests {
  @Test
  func `jobs run one at a time in order`() async {
    let queue = JobQueue()
    let order = Mutex<[Int]>([])
    for number in 1 ... 3 {
      queue.enqueue("Job \(number)") { _ in
        order.withLock { $0.append(number) }
        try? await Task.sleep(for: .milliseconds(10)) // why: just lets jobs overlap if they could.
        order.withLock { $0.append(-number) }
      }
    }
    await queue.waitUntilIdle()
    #expect(order.withLock { $0 } == [1, -1, 2, -2, 3, -3])
    #expect(queue.jobs.allSatisfy { $0.state == .done })
  }

  @Test
  func `a failing job keeps its message and the next one still runs`() async {
    let queue = JobQueue()
    queue.enqueue("Breaks") { _ throws(JobError) in throw .failed("The file is gone.") }
    queue.enqueue("Works") { _ in }
    await queue.waitUntilIdle()
    #expect(queue.jobs.map(\.state) == [.failed("The file is gone."), .done])
  }

  @Test
  func `on battery analysis waits, cancellable, while an export goes ahead`() async {
    let queue = JobQueue(
      pauseCheck: { pausesOnBattery in pausesOnBattery ? "on battery" : nil },
      checkInterval: .milliseconds(10),
    )
    let analysis = queue.enqueue("Transcribing") { _ in }
    queue.enqueue("Exporting", pausesOnBattery: false) { _ in }
    while queue.jobs.last?.state != .done {
      try? await Task.sleep(for: .milliseconds(10)) // why: a cancelled wait just checks again.
    }
    #expect(queue.jobs.first?.state == .queued)
    #expect(queue.pauseReason == "on battery")
    queue.cancel(analysis)
    await queue.waitUntilIdle()
    #expect(queue.jobs.first?.state == .cancelled)
  }

  @Test
  func `a running job holds at its pause point until it may carry on`() async {
    let paused = Atomic(false)
    let queue = JobQueue(
      pauseCheck: { _ in paused.load(ordering: .relaxed) ? "too hot" : nil },
      checkInterval: .milliseconds(10),
    )
    let carriedOn = Atomic(false)
    queue.enqueue("Cutting out") { _ in
      paused.store(true, ordering: .relaxed)
      await JobQueue.pausePoint()
      carriedOn.store(true, ordering: .relaxed)
    }
    while queue.pauseReason == nil {
      try? await Task.sleep(for: .milliseconds(10)) // why: a cancelled wait just checks again.
    }
    try? await Task.sleep(for: .milliseconds(50)) // why: gives a broken pause time to show.
    let carriedOnWhilePaused = carriedOn.load(ordering: .relaxed)
    #expect(!carriedOnWhilePaused)
    #expect(queue.jobs.first?.state == .running(progress: nil))
    paused.store(false, ordering: .relaxed)
    await queue.waitUntilIdle()
    let carriedOnAfter = carriedOn.load(ordering: .relaxed)
    #expect(carriedOnAfter)
    #expect(queue.pauseReason == nil)
  }

  @Test
  func `a pause point outside a job returns at once`() async {
    await JobQueue.pausePoint()
  }

  @Test
  func `a queued job can be cancelled before it starts`() async {
    let queue = JobQueue()
    queue
      .enqueue("Slow") { _ in
        try? await Task.sleep(for: .milliseconds(50))
      } // why: holds the queue.
    let second = queue.enqueue("Never") { _ in }
    queue.cancel(second)
    await queue.waitUntilIdle()
    #expect(queue.jobs.last?.state == .cancelled)
  }

  @Test
  func `cancelling the running job leaves the queued ones to finish`() async {
    let queue = JobQueue()
    let first = queue.enqueue("Endless") { _ throws(JobError) in
      while !Task.isCancelled {
        try? await Task.sleep(for: .milliseconds(5)) // why: a cancelled wait just checks again.
      }
      throw .cancelled
    }
    queue.enqueue("Second") { _ in }
    queue.enqueue("Third") { _ in }
    while queue.jobs.first?.state == .queued {
      try? await Task.sleep(for: .milliseconds(5)) // why: a cancelled wait just checks again.
    }
    queue.cancel(first)
    await queue.waitUntilIdle()
    #expect(queue.jobs.map(\.state) == [.cancelled, .done, .done])
  }

  @Test
  func `progress reports reach the job`() async {
    let queue = JobQueue()
    let released = Mutex(false)
    let id = queue.enqueue("Counting") { progress in
      progress(0.5)
      while !released.withLock({ $0 }) {
        try? await Task.sleep(for: .milliseconds(5)) // why: a cancelled wait just checks again.
      }
    }
    var reported = false
    for _ in 0 ..< 400 where !reported {
      reported = queue.jobs.first { $0.id == id }?.state == .running(progress: 0.5)
      try? await Task.sleep(for: .milliseconds(5)) // why: a cancelled wait just checks again.
    }
    released.withLock { $0 = true }
    await queue.waitUntilIdle()
    #expect(reported)
  }

  @Test
  func `only the last few finished jobs are kept`() async {
    let queue = JobQueue()
    for number in 0 ..< 8 {
      queue.enqueue("Job \(number)") { _ in }
    }
    await queue.waitUntilIdle()
    #expect(queue.jobs.count == JobQueue.finishedKept)
    #expect(queue.jobs.last?.title == "Job 7")
  }
}
