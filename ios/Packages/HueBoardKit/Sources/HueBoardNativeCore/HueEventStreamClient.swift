import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import HueBoardKit

public actor HueEventStreamClient {
    public init() {}

    public func stream(
        profile: BridgeProfile,
        credential: HueBridgeCredential
    ) -> AsyncThrowingStream<HueEventStreamMessage, Error> {
        AsyncThrowingStream { continuation in
            let task = Task { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }
                do {
                    try await self.consume(
                        profile: profile,
                        credential: credential,
                        continuation: continuation
                    )
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { @Sendable _ in task.cancel() }
        }
    }

#if canImport(Security) && canImport(CryptoKit) && !canImport(FoundationNetworking)
    private func consume(
        profile: BridgeProfile,
        credential: HueBridgeCredential,
        continuation: AsyncThrowingStream<HueEventStreamMessage, Error>.Continuation
    ) async throws {
        guard profile.certificateSHA256 != nil else {
            throw HueBoardError.authorization(
                "Verify this Bridge certificate before opening its event stream."
            )
        }
        guard HueBridgeHostValidator.isAllowed(profile.host),
              let url = URL(string: "https://\(profile.displayHost)/eventstream/clip/v2")
        else {
            throw HueBoardError.network("Invalid Bridge event-stream URL.")
        }

        let delegate = HueBridgeTrustDelegate(
            expectedHost: profile.host,
            expectedBridgeID: profile.bridgeID,
            pinnedSHA256: profile.certificateSHA256
        )
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 7 * 24 * 60 * 60
        configuration.httpAdditionalHeaders = ["Accept": "text/event-stream"]
        let session = URLSession(
            configuration: configuration,
            delegate: delegate,
            delegateQueue: nil
        )
        defer { session.invalidateAndCancel() }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue(credential.applicationKey, forHTTPHeaderField: "hue-application-key")

        do {
            let (bytes, response) = try await session.bytes(for: request)
            guard let response = response as? HTTPURLResponse else {
                throw HueBoardError.invalidResponse("No HTTP response for the Hue event stream.")
            }
            guard (200..<300).contains(response.statusCode) else {
                if response.statusCode == 401 || response.statusCode == 403 {
                    throw HueBoardError.authorization(
                        "Bridge rejected the event-stream application key (HTTP \(response.statusCode))."
                    )
                }
                throw HueBoardError.invalidResponse(
                    "Hue event stream failed (HTTP \(response.statusCode))."
                )
            }
            guard delegate.observation != nil else {
                throw HueBoardError.authorization(
                    "Hue Board could not verify the event-stream TLS certificate."
                )
            }
            if let contentType = response.value(forHTTPHeaderField: "Content-Type"),
               !contentType.lowercased().contains("text/event-stream")
            {
                throw HueBoardError.invalidResponse(
                    "Bridge returned an unexpected event-stream content type."
                )
            }

            continuation.yield(.connected)
            var parser = HueEventStreamParser()
            for try await line in bytes.lines {
                try Task.checkCancellation()
                if let batch = try parser.ingest(line) {
                    continuation.yield(.batch(batch))
                }
            }
            if let batch = try parser.finish() {
                continuation.yield(.batch(batch))
            }
            try Task.checkCancellation()
            throw HueBoardError.network("The Hue event stream ended unexpectedly.")
        } catch let error as HueBoardError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if let message = delegate.failureMessage {
                throw HueBoardError.authorization(message)
            }
            throw HueBoardError.network(
                "Hue event stream disconnected: \(error.localizedDescription)"
            )
        }
    }
#else
    private func consume(
        profile: BridgeProfile,
        credential: HueBridgeCredential,
        continuation: AsyncThrowingStream<HueEventStreamMessage, Error>.Continuation
    ) async throws {
        throw HueBoardError.unsupported(
            "Hue event streaming requires Apple URLSession, Security, and CryptoKit support."
        )
    }
#endif
}
