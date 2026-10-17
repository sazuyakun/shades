import ShadesCore

/// The part of a media file marked with I and O in the browser; placing the media uses just
/// this part.
struct SourceMarks: Equatable {
  var start: MediaTime?
  var end: MediaTime?
}
