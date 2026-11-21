import Foundation
// AppModel+Setup uses CryptoKit's SHA-256 byte API. Expose that single API using
// the package's own unchanged SHA-256 implementation (symlinked into this module).
public enum SHA256 {
    public static func hash(data: Data) -> [UInt8] {
        let hex = PersistenceChecksum.sha256Hex(data)
        var bytes: [UInt8] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            bytes.append(UInt8(hex[index..<next], radix: 16)!)
            index = next
        }
        return bytes
    }
}
