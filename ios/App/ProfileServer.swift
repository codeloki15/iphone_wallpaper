import Foundation
import Network

/// A tiny HTTP server on this iPhone that hands one file to Safari.
///
/// iOS only installs a configuration profile that Safari has downloaded, and
/// an app can't pass Safari a file directly. So the app serves the profile
/// on the loopback address and opens Safari there. The server is bound to
/// 127.0.0.1, so nothing outside this device can reach it, and it stops by
/// itself.
final class ProfileServer: @unchecked Sendable {
    static let shared = ProfileServer()
    static let preferredPort: UInt16 = 8437

    // All state below is touched only on `queue`.
    private let queue = DispatchQueue(label: "pocketwalls.profile-server")
    private var listener: NWListener?
    private var body = Data()
    private var announced = false
    private var stopWork: DispatchWorkItem?

    /// Serves `data` at http://127.0.0.1:<port>/<fileName> for `lifetime`
    /// seconds. Calls back on the main queue with that URL, or nil if no
    /// port could be opened.
    func serve(_ data: Data, fileName: String, lifetime: TimeInterval = 120, completion: @escaping @Sendable (URL?) -> Void) {
        queue.async {
            self.stopOnQueue()
            self.body = data
            self.start(port: Self.preferredPort, fileName: fileName, lifetime: lifetime, completion: completion)
        }
    }

    func stop() {
        queue.async { self.stopOnQueue() }
    }

    private func stopOnQueue() {
        stopWork?.cancel()
        stopWork = nil
        listener?.cancel()
        listener = nil
    }

    /// `port` 0 asks the system for any free port; it is the fallback when
    /// the preferred one is taken.
    private func start(port: UInt16, fileName: String, lifetime: TimeInterval, completion: @escaping @Sendable (URL?) -> Void) {
        let endpointPort: NWEndpoint.Port = port == 0 ? .any : (NWEndpoint.Port(rawValue: port) ?? .any)
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        // Bind to loopback only. (`acceptLocalOnly` is not the way to do
        // this: inside an iOS app it rejects loopback connections too.)
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: endpointPort)

        func giveUpOrRetry() {
            if port != 0 {
                start(port: 0, fileName: fileName, lifetime: lifetime, completion: completion)
            } else {
                DispatchQueue.main.async { completion(nil) }
            }
        }

        guard let listener = try? NWListener(using: parameters) else {
            giveUpOrRetry()
            return
        }
        self.listener = listener
        announced = false
        listener.newConnectionHandler = { [weak self] connection in
            self?.respond(to: connection)
        }
        listener.stateUpdateHandler = { [weak self] state in
            guard let self, self.listener === listener else { return }
            switch state {
            case .ready:
                guard !self.announced, let bound = listener.port?.rawValue else { return }
                self.announced = true
                let url = URL(string: "http://127.0.0.1:\(bound)/\(fileName)")
                DispatchQueue.main.async { completion(url) }
            case .failed:
                guard !self.announced else { return }
                listener.cancel()
                self.listener = nil
                giveUpOrRetry()
            default:
                break
            }
        }
        listener.start(queue: queue)

        let work = DispatchWorkItem { [weak self] in self?.stopOnQueue() }
        stopWork = work
        queue.asyncAfter(deadline: .now() + lifetime, execute: work)
    }

    private func respond(to connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) { [weak self] data, _, _, _ in
            guard let self else {
                connection.cancel()
                return
            }
            let request = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            // "GET /PocketWallsIcons.mobileconfig HTTP/1.1"
            let parts = request.prefix { !$0.isNewline }.split(separator: " ")
            let method = parts.first.map(String.init) ?? ""
            let path = parts.count > 1 ? String(parts[1].prefix { $0 != "?" }) : ""
            var response = Data()
            if (method == "GET" || method == "HEAD") && path.hasSuffix(".mobileconfig") {
                let head = "HTTP/1.1 200 OK\r\n"
                    + "Content-Type: application/x-apple-aspen-config\r\n"
                    + "Content-Length: \(self.body.count)\r\n"
                    + "Cache-Control: no-store\r\n"
                    + "Connection: close\r\n\r\n"
                response.append(Data(head.utf8))
                if method == "GET" { response.append(self.body) }
            } else {
                response.append(Data("HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".utf8))
            }
            connection.send(content: response, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }
}
