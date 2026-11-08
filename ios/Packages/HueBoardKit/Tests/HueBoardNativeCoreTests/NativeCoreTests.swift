import XCTest
import HueBoardKit
@testable import HueBoardNativeCore
final class NativeCoreTests:XCTestCase{
 func testProfile()throws{let p=try BridgeProfile(bridgeID:"AABB",host:"192.168.1.2");XCTAssertEqual(p.bridgeID,"aabb");XCTAssertThrowsError(try BridgeProfile(bridgeID:"bad",host:"8.8.8.8"))}
 func testPersistence()async throws{let suite="HueBoardTests.\(UUID())";defer{UserDefaults.standard.removePersistentDomain(forName:suite)};let p=AppPersistence(suiteName:suite),profile=try BridgeProfile(bridgeID:"AABB",host:"192.168.1.2");try await p.saveProfile(profile);let loaded=try await p.loadProfile();XCTAssertEqual(loaded,profile)}
 func testDescriptorBounds()throws{let p=try BridgeProfile(bridgeID:"AABB",host:"192.168.1.2"),area=HueArea(id:.init(rawValue:"r"),kind:.room,name:"R",lights:[]),d=LiveSessionDescriptor(profile:p,area:area,presetID:"x",brightness:500,duration:2);XCTAssertEqual(d.brightness,100);XCTAssertEqual(d.duration,60)}
}
