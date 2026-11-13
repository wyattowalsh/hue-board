import Foundation

public struct HueBridgeEndpoint: Equatable, Sendable {
    public let host: String
    public let port: Int

    public init(host: String, port: Int = 443) throws {
        let normalizedHost = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard HueBridgeHostValidator.isAllowed(normalizedHost) else {
            throw HueBridgeEndpointError.unsupportedHost
        }
        guard (1...65_535).contains(port) else {
            throw HueBridgeEndpointError.invalidPort
        }
        self.host = normalizedHost
        self.port = port
    }

    public init(parsing rawValue: String) throws {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !value.isEmpty else { throw HueBridgeEndpointError.empty }
        guard !value.contains("://") else { throw HueBridgeEndpointError.schemeNotAllowed }
        guard !value.contains("/"), !value.contains("\\"), !value.contains("@"),
              !value.contains("?"), !value.contains("#")
        else {
            throw HueBridgeEndpointError.unsupportedHost
        }
        guard !value.hasPrefix("["), !value.contains("]") else {
            throw HueBridgeEndpointError.ipv6Unsupported
        }

        let separators = value.indices.filter { value[$0] == ":" }
        let host: String
        let port: Int
        switch separators.count {
        case 0:
            host = value
            port = 443
        case 1:
            guard let separator = separators.first else {
                throw HueBridgeEndpointError.invalidPort
            }
            host = String(value[..<separator])
            let portText = String(value[value.index(after: separator)...])
            guard !host.isEmpty, !portText.isEmpty, let parsed = Int(portText),
                  String(parsed) == portText
            else {
                throw HueBridgeEndpointError.invalidPort
            }
            port = parsed
        default:
            throw HueBridgeEndpointError.ipv6Unsupported
        }
        try self.init(host: host, port: port)
    }

    public var displayHost: String {
        port == 443 ? host : "\(host):\(port)"
    }
}

public enum HueBridgeEndpointError: Error, Equatable, LocalizedError, Sendable {
    case empty
    case schemeNotAllowed
    case unsupportedHost
    case ipv6Unsupported
    case invalidPort

    public var errorDescription: String? {
        switch self {
        case .empty:
            return "Enter a private LAN IPv4 address or trusted .local Hue Bridge hostname."
        case .schemeNotAllowed:
            return "Enter only the Bridge host and optional port, without https://."
        case .unsupportedHost:
            return "Use a private LAN IPv4 address or trusted .local Hue Bridge hostname."
        case .ipv6Unsupported:
            return "IPv6 Bridge addresses are not supported yet."
        case .invalidPort:
            return "The Bridge port must be a number from 1 through 65535."
        }
    }
}
