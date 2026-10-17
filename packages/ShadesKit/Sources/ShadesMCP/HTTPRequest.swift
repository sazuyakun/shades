import Foundation

// MARK: - HTTPRequest

/// A parsed HTTP/1.1 request. Ported from Nebula.
struct HTTPRequest: Sendable, Hashable {
  /// The method as sent, e.g. `POST`.
  var method: String
  /// The path without its query string.
  var path: String
  /// Header fields keyed by lowercased name; repeated fields are joined with ", ".
  var headers: [String: String]
  var body: Data

  /// A header's value, looked up case-insensitively.
  func header(_ name: String) -> String? {
    headers[name.lowercased()]
  }
}

// MARK: - HTTPRequestParser

/// Reads one HTTP/1.1 request with a `Content-Length` body from the bytes received so far.
enum HTTPRequestParser {

  // MARK: Internal

  /// What the bytes so far amount to.
  enum Outcome: Sendable {
    case incomplete
    case complete(HTTPRequest)
    /// Malformed or too large: send this response and close.
    case rejected(HTTPResponse)
  }

  /// Largest accepted request line plus headers.
  static let maxHeadBytes = 32 * 1024
  /// Largest accepted body.
  static let maxBodyBytes = 4 * 1024 * 1024

  /// Parses the first request in `buffer`.
  static func parse(_ buffer: Data) -> Outcome {
    guard let terminator = buffer.range(of: Data("\r\n\r\n".utf8)) else {
      return buffer.count > maxHeadBytes ? .rejected(tooLarge) : .incomplete
    }
    guard buffer.distance(from: buffer.startIndex, to: terminator.lowerBound) <= maxHeadBytes else {
      return .rejected(tooLarge)
    }
    guard
      let head = String(
        data: buffer[buffer.startIndex ..< terminator.lowerBound],
        encoding: .isoLatin1,
      )
    else {
      return .rejected(.plain(status: 400, "Malformed request head."))
    }
    var lines = head.components(separatedBy: "\r\n")
    let requestLine = lines.removeFirst().split(separator: " ", omittingEmptySubsequences: false)
    guard requestLine.count == 3, !requestLine[0].isEmpty, !requestLine[1].isEmpty else {
      return .rejected(.plain(status: 400, "Malformed request line."))
    }
    guard requestLine[2].hasPrefix("HTTP/1.") else {
      return .rejected(.plain(status: 505, "Only HTTP/1.x is supported."))
    }
    let target = requestLine[1]
    let path = target.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
      .first.map(String.init) ?? String(target)
    guard let headers = parseHeaders(lines) else {
      return .rejected(.plain(status: 400, "Malformed header field."))
    }
    guard headers["transfer-encoding"] == nil else {
      return .rejected(.plain(status: 501, "Send Content-Length instead of Transfer-Encoding."))
    }
    let length = headers["content-length"].map { Int($0) } ?? 0
    guard let length, length >= 0 else {
      return .rejected(.plain(status: 400, "Invalid Content-Length."))
    }
    guard length <= maxBodyBytes else {
      return .rejected(.plain(status: 413, "The request body is over 4 MB."))
    }
    let bodyStart = terminator.upperBound
    guard buffer.distance(from: bodyStart, to: buffer.endIndex) >= length else {
      return .incomplete
    }
    let body = Data(buffer[bodyStart ..< buffer.index(bodyStart, offsetBy: length)])
    return .complete(HTTPRequest(
      method: String(requestLine[0]),
      path: path,
      headers: headers,
      body: body,
    ))
  }

  // MARK: Private

  private static let tooLarge = HTTPResponse.plain(status: 431, "Request header fields too large.")

  /// Header fields by lowercased name, or `nil` if any line is malformed.
  private static func parseHeaders(_ lines: [String]) -> [String: String]? {
    var headers = [String: String]()
    for line in lines {
      guard
        let colon = line.firstIndex(of: ":"), let first = line.first, first != " ",
        first != "\t"
      else {
        return nil
      }
      let name = line[..<colon].lowercased()
      guard !name.isEmpty, !name.contains(where: { $0 == " " || $0 == "\t" }) else {
        return nil
      }
      let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
      headers[name] = headers[name].map { $0 + ", " + value } ?? value
    }
    return headers
  }

}
