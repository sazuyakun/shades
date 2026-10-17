import Darwin
import Foundation

/// Measures speed and memory for the performance gates.
public enum Benchmark {

  /// The median time `work` takes over `runs` runs, after one warm-up run.
  public static func median(
    runs: Int = 5,
    _ work: () async throws -> Void,
  ) async rethrows -> Duration {
    let clock = ContinuousClock()
    try await work()
    var durations = [Duration]()
    for _ in 0 ..< runs {
      durations.append(try await clock.measure(work))
    }
    return durations.sorted()[runs / 2]
  }

  /// This process's memory footprint in bytes, as Activity Monitor's "Memory" column shows it.
  public static func memoryFootprint() -> Int {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(
      MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size
    )
    let result = withUnsafeMutablePointer(to: &info) { pointer in
      pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { raw in
        task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), raw, &count)
      }
    }
    return result == KERN_SUCCESS ? Int(info.phys_footprint) : 0
  }

}
