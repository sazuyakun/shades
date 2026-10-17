import Foundation
import ShadesCaptions
import ShadesCommands
import ShadesCore
import ShadesDocument

/// Whoever holds the open project (the app's workspace), so Claude can list, create and open
/// projects.
@MainActor
public protocol ProjectHost: AnyObject {
  /// The open project's package, if one is open.
  var documentURL: URL? { get }

  /// Transcripts, speech activity and beats worked out so far.
  var analysis: AnalysisLibrary { get }

  /// Saves the open project and opens another.
  func openProject(at url: URL) async throws(DocumentError)
  /// Creates a project in the library and opens it.
  func createProject(named name: String, format: VideoFormat) async throws(DocumentError)
  /// Queues transcripts (default: sound on the timeline not yet transcribed); returns what was
  /// queued.
  func transcribe(_ mediaIDs: [Media.ID]?, model: TranscriptionModel, language: String?) -> [String]
  /// Queues speech and beat detection; returns what was queued.
  func analyzeAudio(_ mediaIDs: [Media.ID]?) -> [String]
  /// Adds captions for what's said (in `range`, or everywhere); returns how many.
  func addCaptions(in range: TimeRange?) throws(CommandError) -> Int
}
