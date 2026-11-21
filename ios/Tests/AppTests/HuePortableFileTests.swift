import XCTest
import HueBoardKit
@testable import Hue_Board

final class HuePortableFileTests: XCTestCase {
    func testCoordinatedReadEnforcesPortableFileSizeLimit() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("hue-transfer-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let maximum = HuePortableDataCodec.maximumFileSize
        var bytes = Data(repeating: 0x41, count: maximum)
        try bytes.write(to: url)
        XCTAssertEqual(try HuePortableFile.read(from: url), bytes)

        bytes.append(0x42)
        try bytes.write(to: url)
        XCTAssertThrowsError(try HuePortableFile.read(from: url)) { error in
            XCTAssertEqual(error as? HueBoardError, .unsupported("Hue Board files must be 512 KB or smaller."))
        }
    }
}
