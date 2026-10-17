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
