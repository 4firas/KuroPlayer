import Foundation
import Network

@MainActor
class GoogleOAuthServer {
    private var listener: NWListener?
    private var connection: NWConnection?

    func waitForCallback() async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            do {
                let parameters = NWParameters.tcp
                let port = NWEndpoint.Port(rawValue: 8080)!
                let listener = try NWListener(using: parameters, on: port)
                self.listener = listener

                listener.newConnectionHandler = { [weak self] newConnection in
                    guard let self = self else { return }
                    Task { @MainActor in
                        self.connection = newConnection
                        newConnection.start(queue: .main)

                        self.receive(on: newConnection) { url in
                            Task { @MainActor in
                                self.stop()
                            }
                            continuation.resume(returning: url)
                        }
                    }
                }

                listener.stateUpdateHandler = { [weak self] state in
                    guard let self = self else { return }
                    if case .failed(let error) = state {
                        Task { @MainActor in
                            self.stop()
                        }
                        continuation.resume(throwing: error)
                    }
                }

                listener.start(queue: .main)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func receive(on connection: NWConnection, completion: @escaping @Sendable (URL) -> Void) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, context, isComplete, error in
            if let data = data, let requestString = String(data: data, encoding: .utf8) {
                if let requestLine = requestString.components(separatedBy: "\r\n").first {
                    let parts = requestLine.components(separatedBy: " ")
                    if parts.count >= 2 {
                        let path = parts[1]
                        if let url = URL(string: "http://127.0.0.1:8080\(path)") {
                            let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n<html><body><h2>Authentication successful!</h2><p>You can close this tab and return to KuroPlayer.</p><script>window.close()</script></body></html>"
                            connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
                                completion(url)
                            })
                            return
                        }
                    }
                }
            }
            if !isComplete && error == nil {
                self?.receive(on: connection, completion: completion)
            }
        }
    }

    @MainActor
    func stop() {
        listener?.cancel()
        connection?.cancel()
        listener = nil
        connection = nil
    }
}
