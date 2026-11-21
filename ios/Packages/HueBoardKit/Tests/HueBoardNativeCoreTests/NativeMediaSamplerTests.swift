#if canImport(AVFoundation) && canImport(CoreGraphics)
import Foundation
import XCTest
import HueBoardNativeCore

@MainActor
final class NativeMediaSamplerTests: XCTestCase {
    func testPCMFileReportsQuietAndLoudSectionsWithoutVideo() async throws {
        let url = try writeFixture(quietThenLoudWAV(), fileExtension: "wav")
        defer { try? FileManager.default.removeItem(at: url) }

        let sampler = NativeMediaSampler(url: url)
        let metadata = try await sampler.prepare()
        XCTAssertEqual(metadata.duration, 2, accuracy: 0.05)
        XCTAssertTrue(metadata.hasAudio)
        XCTAssertFalse(metadata.hasVideo)

        let quiet = try await sampler.signal(at: 0.5)
        let loud = try await sampler.signal(at: 1.5)
        XCTAssertTrue((0...1).contains(quiet.level))
        XCTAssertTrue((0...1).contains(loud.level))
        XCTAssertLessThan(quiet.level, 0.05)
        XCTAssertGreaterThan(loud.level - quiet.level, 0.2)
        XCTAssertNil(quiet.color)
        XCTAssertNil(loud.color)
    }

    func testMalformedFileCannotPrepare() async throws {
        let invalidWAV = Data("RIFF truncated".utf8)
        let url = try writeFixture(invalidWAV, fileExtension: "wav")
        defer { try? FileManager.default.removeItem(at: url) }

        let sampler = NativeMediaSampler(url: url)
        do {
            _ = try await sampler.prepare()
            XCTFail("A truncated WAV cannot supply an audio or video signal.")
        } catch {
            // AVFoundation rejects the malformed file before sampling.
        }
    }

    private func writeFixture(_ data: Data, fileExtension: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("hue-board-test-\(UUID().uuidString)")
            .appendingPathExtension(fileExtension)
        try data.write(to: url, options: .atomic)
        return url
    }

    private func quietThenLoudWAV() -> Data {
        let sampleRate = 16_000
        let sampleCount = sampleRate * 2
        let sampleBytes = UInt32(sampleCount * MemoryLayout<Int16>.size)
        var wav = Data()
        func append<T: FixedWidthInteger>(_ value: T) {
            withUnsafeBytes(of: value.littleEndian) { wav.append(contentsOf: $0) }
        }

        wav.append(contentsOf: "RIFF".utf8)
        append(36 + sampleBytes)
        wav.append(contentsOf: "WAVEfmt ".utf8)
        append(UInt32(16)) // PCM format chunk length
        append(UInt16(1)) // PCM
        append(UInt16(1)) // one channel
        append(UInt32(sampleRate))
        append(UInt32(sampleRate * MemoryLayout<Int16>.size))
        append(UInt16(MemoryLayout<Int16>.size))
        append(UInt16(Int16.bitWidth))
        wav.append(contentsOf: "data".utf8)
        append(sampleBytes)

        for index in 0..<sampleCount {
            let amplitude = index < sampleRate ? 0 : 0.9
            let phase = 2 * Double.pi * 440 * Double(index) / Double(sampleRate)
            append(Int16((Double(Int16.max) * amplitude * sin(phase)).rounded()))
        }
        return wav
    }
}
#endif
