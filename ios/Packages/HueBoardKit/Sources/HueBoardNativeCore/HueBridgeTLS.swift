import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(CryptoKit)
import CryptoKit
#endif
#if canImport(Security)
import Security
#endif
import HueBoardKit

public struct HueBridgeCertificateObservation: Equatable, Sendable {
    public let bridgeID: String
    public let sha256: String

    public init(bridgeID: String, sha256: String) {
        self.bridgeID = bridgeID
        self.sha256 = sha256
    }
}

public enum HueBridgeTLSIdentity {
    public static func normalizeBridgeID(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let compact = raw.lowercased().filter { character in
            !character.isWhitespace && character != ":" && character != "-"
        }
        guard compact.count == 16, compact.allSatisfy(\.isHexDigit) else { return nil }
        return compact
    }

    public static func normalizeSHA256(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let compact = raw.lowercased().filter { character in
            !character.isWhitespace && character != ":"
        }
        guard compact.count == 64, compact.allSatisfy(\.isHexDigit) else { return nil }
        return compact
    }

    public static func validate(
        subjectBridgeID: String,
        sha256: String,
        expectedBridgeID: String?,
        pinnedSHA256: String?
    ) throws -> HueBridgeCertificateObservation {
        guard let subject = normalizeBridgeID(subjectBridgeID) else {
            throw HueBoardError.authorization(
                "The Bridge certificate does not contain a valid 16-character Hue Bridge ID."
            )
        }
        if let expectedBridgeID {
            guard let expected = normalizeBridgeID(expectedBridgeID), expected == subject else {
                throw HueBoardError.authorization(
                    "The Bridge certificate identity does not match the discovered Bridge ID."
                )
            }
        }
        guard let fingerprint = normalizeSHA256(sha256) else {
            throw HueBoardError.authorization("The Bridge certificate fingerprint is invalid.")
        }
        if let pinnedSHA256 {
            guard let pin = normalizeSHA256(pinnedSHA256), pin == fingerprint else {
                throw HueBoardError.authorization(
                    "The Bridge certificate changed. Verify the Bridge identity before pairing again."
                )
            }
        }
        return .init(bridgeID: subject, sha256: fingerprint)
    }

    public static func displaySHA256(_ value: String?) -> String? {
        guard let normalized = normalizeSHA256(value) else { return nil }
        return stride(from: 0, to: normalized.count, by: 4).map { offset in
            let start = normalized.index(normalized.startIndex, offsetBy: offset)
            let end = normalized.index(start, offsetBy: 4)
            return normalized[start..<end].uppercased()
        }.joined(separator: " ")
    }
}

#if canImport(Security) && canImport(CryptoKit)
final class HueBridgeTrustDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate,
    @unchecked Sendable
{
    private let expectedHost: String
    private let expectedBridgeID: String?
    private let pinnedSHA256: String?
    private let lock = NSLock()
    private var storedObservation: HueBridgeCertificateObservation?
    private var storedFailure: String?

    init(expectedHost: String, expectedBridgeID: String?, pinnedSHA256: String?) {
        self.expectedHost = expectedHost.lowercased()
        self.expectedBridgeID = expectedBridgeID
        self.pinnedSHA256 = pinnedSHA256
    }

    var observation: HueBridgeCertificateObservation? {
        lock.withLock { storedObservation }
    }

    var failureMessage: String? {
        lock.withLock { storedFailure }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              challenge.protectionSpace.host.lowercased() == expectedHost,
              let trust = challenge.protectionSpace.serverTrust,
              let leaf = SecTrustGetCertificateAtIndex(trust, 0)
        else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        do {
            var commonName: CFString?
            guard SecCertificateCopyCommonName(leaf, &commonName) == errSecSuccess,
                  let subject = commonName as String?
            else {
                throw HueBoardError.authorization(
                    "The Bridge certificate has no readable Bridge identity."
                )
            }
            let digest = SHA256.hash(data: SecCertificateCopyData(leaf) as Data)
                .map { String(format: "%02x", $0) }
                .joined()
            let observation = try HueBridgeTLSIdentity.validate(
                subjectBridgeID: subject,
                sha256: digest,
                expectedBridgeID: expectedBridgeID,
                pinnedSHA256: pinnedSHA256
            )

            let policy = SecPolicyCreateSSL(true, observation.bridgeID as CFString)
            guard SecTrustSetPolicies(trust, policy) == errSecSuccess,
                  SecTrustSetAnchorCertificates(trust, [leaf] as CFArray) == errSecSuccess,
                  SecTrustSetAnchorCertificatesOnly(trust, true) == errSecSuccess
            else {
                throw HueBoardError.authorization("The Bridge certificate policy could not be configured.")
            }
            var trustError: CFError?
            guard SecTrustEvaluateWithError(trust, &trustError) else {
                throw HueBoardError.authorization(
                    "The Bridge certificate is expired or invalid: "
                        + (trustError?.localizedDescription ?? "trust evaluation failed")
                )
            }
            lock.withLock {
                storedObservation = observation
                storedFailure = nil
            }
            completionHandler(.useCredential, URLCredential(trust: trust))
        } catch {
            lock.withLock { storedFailure = error.localizedDescription }
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}
#else
final class HueBridgeTrustDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    let observation: HueBridgeCertificateObservation? = nil
    let failureMessage: String? =
        "Pinned Hue Bridge TLS requires Apple Security and CryptoKit frameworks."

    init(expectedHost: String, expectedBridgeID: String?, pinnedSHA256: String?) {}

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
#endif
