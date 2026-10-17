import ShadesCore

/// The media tile under the pointer and the time the pointer is over, for I and O.
struct MediaHover: Equatable {
  let mediaID: Media.ID
  let time: MediaTime
}
