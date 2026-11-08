import Foundation
import HueBoardKit
import HueBoardNativeCore
import Network

final class HueLocalDiscovery: @unchecked Sendable {
  func discover(timeout: TimeInterval = 3) async -> [HueBridgeCandidate] {
    await withCheckedContinuation { continuation in
      let session = Session(timeout: timeout, continuation: continuation)
      session.start()
    }
  }

  private final class Session: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.wyattowalsh.HueBoard.bonjour")
    private let browser: NWBrowser
    private let timeout: TimeInterval
    private let continuation: CheckedContinuation<[HueBridgeCandidate], Never>
    private var connections: [String: NWConnection] = [:]
    private var candidates: [String: HueBridgeCandidate] = [:]
    private var seenEndpoints = Set<String>()
    private var keepAlive: Session?
    private var finished = false

    init(
      timeout: TimeInterval,
      continuation: CheckedContinuation<[HueBridgeCandidate], Never>
    ) {
      self.timeout = min(max(timeout, 1), 8)
      self.continuation = continuation
      let parameters = NWParameters.tcp
      parameters.includePeerToPeer = false
      browser = NWBrowser(
        for: .bonjour(type: "_hue._tcp", domain: "local."),
        using: parameters
      )
    }

    func start() {
      keepAlive = self
      browser.stateUpdateHandler = { [weak self] state in
        guard let self else { return }
        switch state {
        case .failed(_), .cancelled:
          self.finish()
        default:
          break
        }
      }
      browser.browseResultsChangedHandler = { [weak self] results, _ in
        guard let self else { return }
        for result in results { self.resolve(result.endpoint) }
      }
      browser.start(queue: queue)
      queue.asyncAfter(deadline: .now() + timeout) { [weak self] in
        self?.finish()
      }
    }

    private func resolve(_ endpoint: NWEndpoint) {
      let key = String(describing: endpoint)
      guard seenEndpoints.insert(key).inserted else { return }

      switch endpoint {
      case .hostPort(let host, let port):
        add(host: host, port: port, serviceName: nil)
      case .service(let name, _, _, _):
        let connection = NWConnection(to: endpoint, using: .tcp)
        connections[key] = connection
        connection.stateUpdateHandler = { [weak self, weak connection] state in
          guard let self, let connection else { return }
          switch state {
          case .ready:
            if let remoteEndpoint = connection.currentPath?.remoteEndpoint,
               case .hostPort(let host, let port) = remoteEndpoint
            {
              self.add(host: host, port: port, serviceName: name)
            }
            self.finishConnection(key: key, connection: connection)
          case .failed(_), .cancelled:
            self.finishConnection(key: key, connection: connection)
          default:
            break
          }
        }
        connection.start(queue: queue)
      default:
        break
      }
    }

    private func add(
      host: NWEndpoint.Host,
      port: NWEndpoint.Port,
      serviceName: String?
    ) {
      let value = String(describing: host)
        .split(separator: "%", maxSplits: 1, omittingEmptySubsequences: true)
        .first
        .map(String.init)?
        .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        .lowercased()
      guard let value, HueBridgeHostValidator.isAllowed(value) else { return }

      let advertisedID = serviceName.flatMap(HueBridgeTLSIdentity.normalizeBridgeID)
      let candidate = HueBridgeCandidate(
        id: advertisedID ?? serviceName ?? value,
        host: value,
        port: Int(port.rawValue)
      )
      let identity = advertisedID ?? "\(value):\(port.rawValue)"
      candidates[identity] = candidate
    }

    private func finishConnection(key: String, connection: NWConnection) {
      connection.stateUpdateHandler = nil
      connection.cancel()
      connections.removeValue(forKey: key)
    }

    private func finish() {
      guard !finished else { return }
      finished = true
      browser.stateUpdateHandler = nil
      browser.browseResultsChangedHandler = nil
      browser.cancel()
      for connection in connections.values {
        connection.stateUpdateHandler = nil
        connection.cancel()
      }
      connections.removeAll()
      let result = candidates.values.sorted {
        if $0.host == $1.host { return $0.port < $1.port }
        return $0.host.localizedStandardCompare($1.host) == .orderedAscending
      }
      continuation.resume(returning: result)
      keepAlive = nil
    }
  }
}
