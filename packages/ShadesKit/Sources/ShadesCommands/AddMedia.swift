import ShadesCore

/// Adds an already-loaded media file to the project's media list.
public struct AddMedia: Command {
  public init(media: Media) {
    self.media = media
  }

  public static let title = "Import Media"

  public let media: Media

  public func apply(to project: inout Project) throws(CommandError) {
    guard project.media(withID: media.id) == nil else {
      throw rejected(.mediaAlreadyAdded(media.id))
    }
    project.media.append(media)
  }
}
