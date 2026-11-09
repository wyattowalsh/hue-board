import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import HueBoardKit

private final class RedirectRejectingDelegate: NSObject, URLSessionTaskDelegate,
    @unchecked Sendable
{
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

private actor HueRequestPacer {
    private let clock = ContinuousClock()
    private let minimum: Duration
    private var next: ContinuousClock.Instant

    init(minimum: Duration = .milliseconds(175)) {
        self.minimum = minimum
        next = clock.now
    }

    func wait() async throws {
        let now = clock.now
        if now < next {
            try await Task.sleep(until: next, clock: clock)
        }
        next = max(clock.now, next) + minimum
    }
}

public actor HueBridgeClient {
    private struct LocalConnection {
        let session: URLSession
        let delegate: HueBridgeTrustDelegate
    }

    private struct LocalResponse {
        let data: Data
        let certificate: HueBridgeCertificateObservation
    }

    private let discoverySession: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let pacer = HueRequestPacer()
    private var localConnections: [String: LocalConnection] = [:]

    public init() {
        let configuration = Self.configuration()
        discoverySession = URLSession(
            configuration: configuration,
            delegate: RedirectRejectingDelegate(),
            delegateQueue: nil
        )
    }

    public func discover() async throws -> [HueBridgeCandidate] {
        guard let url = URL(string: "https://discovery.meethue.com/") else {
            throw HueBoardError.network("Hue discovery URL is invalid.")
        }
        do {
            let (data, response) = try await discoverySession.data(from: url)
            try validate(response, data: data)
            return try decoder.decode([HueDiscoveryRecord].self, from: data)
                .map(\.candidate)
                .filter {
                    HueBridgeHostValidator.isAllowed($0.host)
                        && HueBridgeTLSIdentity.normalizeBridgeID($0.id) != nil
                }
        } catch let error as HueBoardError {
            throw error
        } catch is CancellationError {
            throw HueBoardError.cancelled
        } catch {
            throw HueBoardError.network(
                "Cannot reach Hue discovery over HTTPS: \(error.localizedDescription)"
            )
        }
    }

    public func probe(candidate: HueBridgeCandidate) async throws -> BridgeProfile {
        guard HueBridgeHostValidator.isAllowed(candidate.host) else {
            throw HueBoardError.network("Bridge host is outside the private LAN allowlist.")
        }
        let response = try await uncachedRequest(
            host: candidate.host,
            port: candidate.port,
            expectedBridgeID: HueBridgeTLSIdentity.normalizeBridgeID(candidate.id),
            pinnedSHA256: nil,
            method: "GET",
            path: "/api/config",
            credential: nil,
            body: nil
        )
        let configuration = try decoder.decode(HueBridgeConfiguration.self, from: response.data)
        guard let bridgeID = HueBridgeTLSIdentity.normalizeBridgeID(configuration.bridgeID),
              bridgeID == response.certificate.bridgeID
        else {
            throw HueBoardError.authorization(
                "The Bridge API identity does not match its TLS certificate."
            )
        }
        return try BridgeProfile(
            bridgeID: bridgeID,
            host: candidate.host,
            port: candidate.port,
            modelID: configuration.modelID,
            apiVersion: configuration.apiVersion,
            certificateSHA256: response.certificate.sha256
        )
    }

    public func verify(profile: BridgeProfile) async throws -> BridgeProfile {
        let response = try await requestData(
            profile: profile,
            method: "GET",
            path: "/api/config",
            credential: nil,
            body: nil,
            allowUnpinned: true
        )
        let configuration = try decoder.decode(HueBridgeConfiguration.self, from: response.data)
        guard let bridgeID = HueBridgeTLSIdentity.normalizeBridgeID(configuration.bridgeID),
              bridgeID == profile.bridgeID,
              bridgeID == response.certificate.bridgeID
        else {
            throw HueBoardError.authorization(
                "The saved Bridge identity no longer matches its API and certificate."
            )
        }
        return try BridgeProfile(
            bridgeID: bridgeID,
            host: profile.host,
            port: profile.port,
            modelID: configuration.modelID ?? profile.modelID,
            apiVersion: configuration.apiVersion ?? profile.apiVersion,
            certificateSHA256: response.certificate.sha256
        )
    }

    public func pair(profile: BridgeProfile) async throws -> HueBridgeCredential {
        try requirePinned(profile)
        struct Request: Encodable {
            let devicetype: String
            let generateclientkey: Bool
        }
        let response = try await requestData(
            profile: profile,
            method: "POST",
            path: "/api",
            credential: nil,
            body: try encoder.encode(
                Request(devicetype: "hue_board#iphone", generateclientkey: true)
            )
        )
        let rows = try decoder.decode([HuePairingEntry].self, from: response.data)
        if let success = rows.compactMap(\.success).first {
            return .init(
                bridgeID: profile.bridgeID,
                applicationKey: success.username,
                clientKey: success.clientKey
            )
        }
        throw HueBoardError.authorization(
            rows.compactMap(\.error?.description).first
                ?? "Press the Bridge button and try again."
        )
    }

    public func inventory(
        profile: BridgeProfile,
        credential: HueBridgeCredential,
        outputLimits: [HueResourceID: Double] = [:]
    ) async throws -> [HueArea] {
        try requirePinned(profile)
        async let roomResources: [HueAreaResource] = resources(
            "room", profile: profile, credential: credential)
        async let zoneResources: [HueAreaResource] = resources(
            "zone", profile: profile, credential: credential)
        async let lightResources: [HueLightResource] = resources(
            "light", profile: profile, credential: credential)
        async let deviceResources: [HueDeviceResource] = resources(
            "device", profile: profile, credential: credential)
        let (rooms, zones, lights, devices) = try await (
            roomResources, zoneResources, lightResources, deviceResources
        )
        return HueInventoryBuilder.build(
            rooms: rooms,
            zones: zones,
            lights: lights,
            devices: devices,
            outputLimits: outputLimits
        )
    }

    public func scene(
        id: HueResourceID,
        profile: BridgeProfile,
        credential: HueBridgeCredential
    ) async throws -> HueSceneResource? {
        let rows: [HueSceneResource] = try await resources(
            "scene/\(id.rawValue)", profile: profile, credential: credential)
        return rows.first { $0.id == id }
    }

    public func createScene(
        _ scene: HueSceneCreateRequest,
        profile: BridgeProfile,
        credential: HueBridgeCredential
    ) async throws -> HueResourceID {
        let response: HueAPIResponse<HueResourceAcknowledgement> = try await v2(
            profile: profile,
            method: "POST",
            resource: "scene",
            credential: credential,
            body: scene
        )
        guard let id = response.data.first(where: { $0.resourceType == "scene" })?.resourceID
            ?? response.data.first?.resourceID
        else {
            throw HueBoardError.invalidResponse("Bridge returned no scene identifier.")
        }
        return id
    }

    public func updateScene(
        id: HueResourceID,
        scene: HueSceneUpdateRequest,
        profile: BridgeProfile,
        credential: HueBridgeCredential
    ) async throws {
        let response: HueAPIResponse<HueResourceAcknowledgement> = try await v2(
            profile: profile,
            method: "PUT",
            resource: "scene/\(id.rawValue)",
            credential: credential,
            body: scene
        )
        try acknowledge(response.data, id: id)
    }

    public func recallScene(
        id: HueResourceID,
        profile: BridgeProfile,
        credential: HueBridgeCredential
    ) async throws {
        let response: HueAPIResponse<HueResourceAcknowledgement> = try await v2(
            profile: profile,
            method: "PUT",
            resource: "scene/\(id.rawValue)",
            credential: credential,
            body: HueSceneRecallRequest()
        )
        try acknowledge(response.data, id: id)
    }

    public func updateLight(
        id: HueResourceID,
        action: HueLightAction,
        profile: BridgeProfile,
        credential: HueBridgeCredential
    ) async throws {
        try await pacer.wait()
        let response: HueAPIResponse<HueResourceAcknowledgement> = try await v2(
            profile: profile,
            method: "PUT",
            resource: "light/\(id.rawValue)",
            credential: credential,
            body: action
        )
        try acknowledge(response.data, id: id)
    }

    private struct Empty: Encodable {}

    private func resources<Value: Codable & Sendable>(
        _ resource: String,
        profile: BridgeProfile,
        credential: HueBridgeCredential
    ) async throws -> [Value] {
        let response: HueAPIResponse<Value> = try await v2(
            profile: profile,
            method: "GET",
            resource: resource,
            credential: credential,
            body: Optional<Empty>.none
        )
        return response.data
    }

    private func v2<Response: Codable & Sendable, Body: Encodable>(
        profile: BridgeProfile,
        method: String,
        resource: String,
        credential: HueBridgeCredential,
        body: Body?
    ) async throws -> HueAPIResponse<Response> {
        try requirePinned(profile)
        let response = try await requestData(
            profile: profile,
            method: method,
            path: "/clip/v2/resource/\(resource)",
            credential: credential,
            body: try body.map { try encoder.encode($0) }
        )
        let decoded = try decoder.decode(HueAPIResponse<Response>.self, from: response.data)
        if let error = decoded.errors.first {
            throw HueBoardError.invalidResponse(error.description)
        }
        return decoded
    }

    private func requestData(
        profile: BridgeProfile,
        method: String,
        path: String,
        credential: HueBridgeCredential?,
        body: Data?,
        allowUnpinned: Bool = false
    ) async throws -> LocalResponse {
        if !allowUnpinned { try requirePinned(profile) }
        let connection = localConnection(profile: profile)
        return try await perform(
            connection: connection,
            host: profile.host,
            port: profile.port,
            method: method,
            path: path,
            credential: credential,
            body: body
        )
    }

    private func uncachedRequest(
        host: String,
        port: Int,
        expectedBridgeID: String?,
        pinnedSHA256: String?,
        method: String,
        path: String,
        credential: HueBridgeCredential?,
        body: Data?
    ) async throws -> LocalResponse {
        let delegate = HueBridgeTrustDelegate(
            expectedHost: host,
            expectedBridgeID: expectedBridgeID,
            pinnedSHA256: pinnedSHA256
        )
        let session = URLSession(
            configuration: Self.configuration(),
            delegate: delegate,
            delegateQueue: nil
        )
        defer { session.finishTasksAndInvalidate() }
        return try await perform(
            connection: .init(session: session, delegate: delegate),
            host: host,
            port: port,
            method: method,
            path: path,
            credential: credential,
            body: body
        )
    }

    private func perform(
        connection: LocalConnection,
        host: String,
        port: Int,
        method: String,
        path: String,
        credential: HueBridgeCredential?,
        body: Data?
    ) async throws -> LocalResponse {
        let displayHost = port == 443 ? host : "\(host):\(port)"
        guard HueBridgeHostValidator.isAllowed(host),
              let url = URL(string: "https://\(displayHost)\(path)")
        else {
            throw HueBoardError.network("Invalid Bridge URL.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 8
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let credential {
            request.setValue(credential.applicationKey, forHTTPHeaderField: "hue-application-key")
        }
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        do {
            let (data, response) = try await connection.session.data(for: request)
            try validate(response, data: data)
            guard let certificate = connection.delegate.observation else {
                throw HueBoardError.authorization(
                    "Hue Board could not verify the Bridge TLS certificate."
                )
            }
            return .init(data: data, certificate: certificate)
        } catch let error as HueBoardError {
            throw error
        } catch is CancellationError {
            throw HueBoardError.cancelled
        } catch {
            if let message = connection.delegate.failureMessage {
                throw HueBoardError.authorization(message)
            }
            throw HueBoardError.network(
                "Cannot reach Hue Bridge over verified HTTPS: \(error.localizedDescription)"
            )
        }
    }

    private func localConnection(profile: BridgeProfile) -> LocalConnection {
        let key = [
            profile.displayHost,
            profile.bridgeID,
            profile.certificateSHA256 ?? "unpinned",
        ].joined(separator: "|")
        if let cached = localConnections[key] { return cached }
        let delegate = HueBridgeTrustDelegate(
            expectedHost: profile.host,
            expectedBridgeID: profile.bridgeID,
            pinnedSHA256: profile.certificateSHA256
        )
        let connection = LocalConnection(
            session: URLSession(
                configuration: Self.configuration(),
                delegate: delegate,
                delegateQueue: nil
            ),
            delegate: delegate
        )
        localConnections[key] = connection
        return connection
    }

    private func requirePinned(_ profile: BridgeProfile) throws {
        guard profile.certificateSHA256 != nil else {
            throw HueBoardError.authorization(
                "Verify this Bridge certificate before sending credentials or light commands."
            )
        }
    }

    private static func configuration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 15
#if !canImport(FoundationNetworking)
        configuration.waitsForConnectivity = false
#endif
        configuration.httpAdditionalHeaders = ["Accept": "application/json"]
        return configuration
    }

    private func validate(_ response: URLResponse, data: Data) throws {
        guard let response = response as? HTTPURLResponse else {
            throw HueBoardError.invalidResponse("No HTTP response.")
        }
        switch response.statusCode {
        case 200..<300:
            return
        case 401, 403:
            throw HueBoardError.authorization(
                "Bridge rejected the application key (HTTP \(response.statusCode))."
            )
        case 429:
            throw HueBoardError.network("Bridge asked Hue Board to slow down.")
        default:
            let detail = String(data: data, encoding: .utf8)?.prefix(160) ?? ""
            throw HueBoardError.invalidResponse(
                "Bridge request failed (HTTP \(response.statusCode)). \(detail)"
            )
        }
    }

    private func acknowledge(_ rows: [HueResourceAcknowledgement], id: HueResourceID) throws {
        guard rows.contains(where: { $0.resourceID == id }) else {
            throw HueBoardError.invalidResponse(
                "Bridge did not acknowledge the expected resource. Treat the outcome as uncertain."
            )
        }
    }
}
