import ShadesCore

/// Adds an already-loaded media file to the project's media list.
public struct AddMedia: Command {
  public init(media: Media) {
    self.media = media
  }

  public let media: Media

  public func apply(to project: inout Project) throws(CommandError) {
    guard project.media(withID: media.id) == nil else {
      logger.error("media.addFailed reason=alreadyAdded id=\(media.id, privacy: .public)")
      throw .mediaAlreadyAdded(media.id)
    }
    project.media.append(media)
  }
}
