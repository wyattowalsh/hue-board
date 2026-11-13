import XCTest
@testable import HueBoardKit

final class HueBridgeEndpointTests: XCTestCase {
    func testParsesPrivateIPv4WithDefaultAndExplicitPorts() throws {
        XCTAssertEqual(
            try HueBridgeEndpoint(parsing: " 192.168.1.20 "),
            try HueBridgeEndpoint(host: "192.168.1.20", port: 443)
        )
        XCTAssertEqual(
            try HueBridgeEndpoint(parsing: "10.0.0.8:8443"),
            try HueBridgeEndpoint(host: "10.0.0.8", port: 8443)
        )
        XCTAssertEqual(
            try HueBridgeEndpoint(parsing: "172.16.4.5:1"),
            try HueBridgeEndpoint(host: "172.16.4.5", port: 1)
        )
    }

    func testParsesTrustedLocalHostnameAndNormalizesCase() throws {
        let endpoint = try HueBridgeEndpoint(parsing: "Hue-Bridge.LOCAL:9443")
        XCTAssertEqual(endpoint.host, "hue-bridge.local")
        XCTAssertEqual(endpoint.port, 9443)
        XCTAssertEqual(endpoint.displayHost, "hue-bridge.local:9443")
        XCTAssertEqual(try HueBridgeEndpoint(parsing: "hue-bridge.local").displayHost, "hue-bridge.local")
    }

    func testRejectsUntrustedOrAmbiguousAddresses() {
        let invalid = [
            "",
            "https://192.168.1.2",
            "8.8.8.8",
            "127.0.0.1",
            "user@192.168.1.2",
            "192.168.1.2/path",
            "192.168.1.2?x=1",
            "192.168.1.2#fragment",
            "[fd00::1]",
            "fd00::1",
            "bridge.example.com",
        ]
        for value in invalid {
            XCTAssertThrowsError(try HueBridgeEndpoint(parsing: value), value)
        }
    }

    func testRejectsInvalidPorts() {
        for value in [
            "192.168.1.2:",
            ":443",
            "192.168.1.2:0",
            "192.168.1.2:65536",
            "192.168.1.2:-1",
            "192.168.1.2:not-a-port",
            "192.168.1.2:00443",
        ] {
            XCTAssertThrowsError(try HueBridgeEndpoint(parsing: value), value)
        }
    }
}
