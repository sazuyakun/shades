import Foundation
import ShadesCaptions
import ShadesCommands
import ShadesCore
import ShadesDocument
import ShadesExport
import ShadesMatting
import ShadesPlugins
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

  /// The loaded plugins: styles, templates, stickers, sounds and fonts.
  var plugins: PluginLibrary { get }
  /// The folders plugins load from.
  var pluginFolders: PluginFolders { get }

  /// Saves the open project and opens another.
  func openProject(at url: URL) async throws(DocumentError)
  /// Creates a project in the library and opens it.
  func createProject(named name: String, format: VideoFormat) async throws(DocumentError)
  /// Queues transcripts (default: sound on the timeline not yet transcribed); returns what was
  /// queued.
  func transcribe(_ mediaIDs: [Media.ID]?, model: TranscriptionModel, language: String?) -> [String]
  /// Queues speech and beat detection; returns what was queued.
  func analyzeAudio(_ mediaIDs: [Media.ID]?) -> [String]
  /// Adds captions for what's said (in `range`, or everywhere), revealed and styled as asked;
  /// returns how many.
  func addCaptions(
    in range: TimeRange?,
    reveal: TextReveal,
    style: TextStyle?,
  ) throws(CommandError) -> Int
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
  /// Places a plugin's template at `time` with its fields filled; returns what was added.
  func applyTemplate(
    named name: String,
    at time: MediaTime,
    fields: [String: String],
  ) async throws(ToolError) -> String
  /// Sets the master level so the mix plays at `target` LUFS; returns what was measured.
  func normalizeLoudness(target: Double) async throws(ToolError) -> String
  /// Sets clips to play noise-reduced sound (strength 0 restores the original); returns what
  /// was done.
  func reduceNoise(_ clipIDs: [Clip.ID], strength: Double) throws(CommandError) -> String
  /// Queues `request`'s files for export; returns their names.
  func export(_ request: ExportRequest) throws(CommandError) -> [String]
  /// Queues separating clips' voice from their music, laid under each clip when done; returns
  /// what was queued.
  func separateStems(_ clipIDs: [Clip.ID]) throws(CommandError) -> String
  /// Ducks a music track under the speech on the timeline; returns what was done.
  func duckMusic(track: String?, level: Double) throws(CommandError) -> String
  /// Queues following what's inside `box` (fractions of the picture) of a video clip from `time`
  /// to the clip's end, saved as a path called `name`; returns the job's title.
  func trackMotion(
    clipID: Clip.ID,
    at time: MediaTime,
    box: CGRect,
    name: String,
  ) throws(CommandError) -> String
  /// Makes a layer follow a path through a video clip: a tracked path's `name`, or the
  /// cut-out's subject when `nil`.
  func follow(clipID: Clip.ID, targetID: Clip.ID, path name: String?) throws(CommandError)
}
