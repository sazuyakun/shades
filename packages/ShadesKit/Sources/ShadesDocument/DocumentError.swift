import Foundation

// MARK: - DocumentError

/// Why a project couldn't be read, saved or created.
public enum DocumentError: Error, Equatable {
  case unreadable(URL)
  case damaged(URL)
  case unwritable(URL)
  case nameTaken(String)
  case invalidName
}

// MARK: LocalizedError

extension DocumentError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .unreadable(let url):
      "\(url.deletingPathExtension().lastPathComponent) couldn't be opened. Check it still exists."

    case .damaged(let url):
      "\(url.lastPathComponent) is damaged and couldn't be read. Try File › Revert To."

    case .unwritable(let url):
      "Shades couldn't save to \(url.deletingLastPathComponent().path). Check there's free space "
        + "and the folder is writable."

    case .nameTaken(let name):
      "A project named \(name) already exists. Pick another name."

    case .invalidName:
      "Give the project a name without slashes or colons."
    }
  }
}
