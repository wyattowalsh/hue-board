import Foundation
import HueBoardKit
#if canImport(CryptoKit)
import CryptoKit
#endif

/// Fixture bytes and expected digests are identical across SwiftPM hosts.
func fixtureSHA256(_ data: Data) -> String {
    #if canImport(CryptoKit)
    return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    #else
    return PersistenceChecksum.sha256Hex(data)
    #endif
}
