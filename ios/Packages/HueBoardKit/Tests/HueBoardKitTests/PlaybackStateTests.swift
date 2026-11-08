import XCTest
@testable import HueBoardKit
final class PlaybackStateTests:XCTestCase{
 func testNoPrematureBridgeSuccess(){var m=HuePlaybackMachine();m.beginBridge(presetID:"ion-eclipse");m.markBridgeRequestPending(sceneID:.init(rawValue:"s"));XCTAssertEqual(m.snapshot.phase,.requestPending);XCTAssertNil(m.snapshot.startedAt);m.markUncertain("uncertain");XCTAssertEqual(m.snapshot.phase,.uncertain)}
 func testLiveProgressBounds(){var m=HuePlaybackMachine();_ = m.beginLive(presetID:"x",duration:600,continued:true);m.updateLiveProgress(2);XCTAssertEqual(m.snapshot.progress,1);m.finishLive();XCTAssertEqual(m.snapshot.phase,.stopped)}
}
