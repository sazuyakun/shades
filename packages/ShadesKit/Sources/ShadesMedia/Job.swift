import Foundation

// MARK: - Job

/// One piece of background work (a proxy, a transcript…) and how it's going.
public struct Job: Identifiable, Sendable, Equatable {
  public let id: UUID
  /// What it's doing, e.g. "Transcribing Interview A".
  public let title: String
  public internal(set) var state: JobState
}

// MARK: - JobState

/// Where a job is in its life.
public enum JobState: Sendable, Equatable {
  case queued
  /// Running; `progress` goes from 0 to 1 when the work can tell.
  case running(progress: Double?)
  case done
  case failed(String)
  case cancelled

  /// Whether the job has stopped, for better or worse.
  public var isFinished: Bool {
    switch self {
    case .queued,
         .running: false
    case .done,
         .failed,
         .cancelled: true
    }
  }
}

// MARK: - JobError

/// Why a job stopped. Work wraps its own module's error in `failed` with plain words.
public enum JobError: Error, Equatable {
  case failed(String)
  case cancelled
}

// MARK: LocalizedError

extension JobError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .failed(let message): message
    case .cancelled: "The job was cancelled."
    }
  }
}
