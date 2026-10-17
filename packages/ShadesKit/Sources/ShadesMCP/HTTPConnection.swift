import Foundation
import Network

/// Serves exactly one request on one accepted connection, then closes it. Ported from Nebula.
///
/// The actor owns the read buffer; only one receive is outstanding at a time, so bytes arrive in
/// order. The response is produced while the actor is suspended, so a slow tool call never
/// blocks other connections.
actor HTTPConnection {

  // MARK: Lifecycle

  init(
    connection: NWConnection,
    queue: DispatchQueue,
    respond: @escaping @Sendable (HTTPRequest) async -> HTTPResponse,
  ) {
    self.connection = connection
    self.queue = queue
    self.respond = respond
  }

  // MARK: Internal

  /// How long a client may take to send a whole request.
  static let readTimeout = Duration.seconds(30)

  func start() {
    // why: the network callbacks hold the actor strongly (nothing else does) until `close()`
    // clears them, so it lives exactly as long as its connection.
    connection.stateUpdateHandler = { state in
      switch state {
      case .failed,
           .cancelled:
        Task { await self.close() }
      default:
        break
      }
    }
    connection.start(queue: queue)
    receiveNext()
    Task { [weak self] in
      try? await Task.sleep(for: Self.readTimeout) // why: cancellation just ends the timer early.
      await self?.readTimedOut()
    }
  }

  // MARK: Private

  private static let readChunk = 64 * 1024

  private let connection: NWConnection
  private let queue: DispatchQueue
  private let respond: @Sendable (HTTPRequest) async -> HTTPResponse
  private var buffer = Data()
  private var hasRequest = false
  private var isClosed = false

  private func receiveNext() {
    connection.receive(minimumIncompleteLength: 1, maximumLength: Self.readChunk) {
      data, _, isComplete, error in
      Task { await self.didReceive(data, isComplete: isComplete || error != nil) }
    }
  }

  private func didReceive(_ data: Data?, isComplete: Bool) async {
    guard !isClosed, !hasRequest else {
      return
    }
    buffer.append(data ?? Data())
    switch HTTPRequestParser.parse(buffer) {
    case .complete(let request):
      hasRequest = true
      buffer = Data()
      send(await respond(request))

    case .rejected(let response):
      hasRequest = true
      send(response)

    case .incomplete:
      if isComplete {
        close()
      } else {
        receiveNext()
      }
    }
  }

  private func readTimedOut() {
    guard !isClosed, !hasRequest else {
      return
    }
    hasRequest = true
    send(.plain(status: 408, "Request timed out."))
  }

  private func send(_ response: HTTPResponse) {
    guard !isClosed else {
      return
    }
    let connection = connection
    connection.send(content: response.serialized, completion: .contentProcessed { _ in
      connection.cancel()
    })
  }

  private func close() {
    guard !isClosed else {
      return
    }
    isClosed = true
    connection.stateUpdateHandler = nil
    connection.cancel()
  }

}
