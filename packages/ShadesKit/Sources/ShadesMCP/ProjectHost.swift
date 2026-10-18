import Foundation
import ShadesCaptions
import ShadesCommands
import ShadesCore
import ShadesDocument
import ShadesMatting
import ShadesPolish

/// Whoever holds the open project (the app's workspace), so Claude can list, create and open
/// projects.
@MainActor
public protocol ProjectHost: AnyObject {
  /// The open project's package, if one is open.
  var documentURL: URL? { get }

  /// Transcripts, speech activity and beats worked out so far.
  var analysis: AnalysisLibrary { get }

  /// The Polish plan waiting for review, if any.
  var polishPlan: PolishPlan? { get }

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
  /// Proposes Polish for a stretch of a track and keeps the plan for review.
  @discardableResult
  func proposePolish(in range: TimeRange, track: String?, options: PolishOptions) -> PolishPlan
  /// Applies the plan (only `ids` or `kinds` when given) as one undo step; returns what was done.
  func applyPolish(ids: Set<UUID>?, kinds: Set<PolishKind>?) throws(CommandError) -> String
  /// Throws the plan away.
  func discardPolish()
  /// Queues cut-outs (default: video on the timeline without one); returns what was queued.
  func makeCutouts(_ mediaIDs: [Media.ID]?, engine: MatteEngine) -> [String]
  /// Reframes clips (default: the selection) around their subject; returns how many.
  func autoReframe(_ clipIDs: [Clip.ID]?) throws(CommandError) -> Int
}
