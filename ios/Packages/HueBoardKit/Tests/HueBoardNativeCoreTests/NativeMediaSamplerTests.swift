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

    func testVideoFileReturnsRedTintWithoutAudio() async throws {
        let video = try XCTUnwrap(Data(base64Encoded: solidRedMP4, options: .ignoreUnknownCharacters))
        let url = try writeFixture(video, fileExtension: "mp4")
        defer { try? FileManager.default.removeItem(at: url) }

        let sampler = NativeMediaSampler(url: url)
        let metadata = try await sampler.prepare()
        XCTAssertEqual(metadata.duration, 1, accuracy: 0.05)
        XCTAssertFalse(metadata.hasAudio)
        XCTAssertTrue(metadata.hasVideo)

        let signal = try await sampler.signal(at: 0.5)
        let tint = try XCTUnwrap(signal.color)
        XCTAssertEqual(signal.level, 0)
        XCTAssertGreaterThan(tint.red, 0.75)
        XCTAssertLessThan(tint.green, 0.2)
        XCTAssertLessThan(tint.blue, 0.2)
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

    // Two 32x32 frames with no audio. Generate with:
    // ffmpeg -f lavfi -i color=c=red:s=32x32:r=2:d=1 -an -c:v libx264 -preset ultrafast
    //   -pix_fmt yuv420p -bsf:v filter_units=remove_types=6 -movflags +faststart -map_metadata -1 red.mp4
    private let solidRedMP4 = """
        AAAAIGZ0eXBpc29tAAACAGlzb21pc28yYXZjMW1wNDEAAAMpbW9vdgAAAGxtdmhkAAAAAAAAAAAA
        AAAAAAAD6AAAA+gAAQAAAQAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAA
        AABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgAAAlR0cmFrAAAAXHRraGQAAAADAAAA
        AAAAAAAAAAABAAAAAAAAA+gAAAAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAABAAAAAAAA
        AAAAAAAAAABAAAAAACAAAAAgAAAAAAAkZWR0cwAAABxlbHN0AAAAAAAAAAEAAAPoAAAAAAABAAAA
        AAHMbWRpYQAAACBtZGhkAAAAAAAAAAAAAAAAAABAAAAAQABVxAAAAAAALWhkbHIAAAAAAAAAAHZp
        ZGUAAAAAAAAAAAAAAABWaWRlb0hhbmRsZXIAAAABd21pbmYAAAAUdm1oZAAAAAEAAAAAAAAAAAAA
        ACRkaW5mAAAAHGRyZWYAAAAAAAAAAQAAAAx1cmwgAAAAAQAAATdzdGJsAAAAt3N0c2QAAAAAAAAA
        AQAAAKdhdmMxAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAAACAAIABIAAAASAAAAAAAAAABFUxhdmM2
        MS4xOS4xMDEgbGlieDI2NAAAAAAAAAAAAAAAGP//AAAALWF2Y0MBQsAK/+EAFmdCwAraJbARAAAD
        AAEAAAMABA8SJqABAARozg/IAAAAEHBhc3AAAAABAAAAAQAAABRidHJ0AAAAAAAAARgAAAAAAAAA
        GHN0dHMAAAAAAAAAAQAAAAIAACAAAAAAFHN0c3MAAAAAAAAAAQAAAAEAAAAcc3RzYwAAAAAAAAAB
        AAAAAQAAAAIAAAABAAAAHHN0c3oAAAAAAAAAAAAAAAIAAAAZAAAACgAAABRzdGNvAAAAAAAAAAEA
        AANZAAAAYXVkdGEAAABZbWV0YQAAAAAAAAAhaGRscgAAAAAAAAAAbWRpcmFwcGwAAAAAAAAAAAAA
        AAAsaWxzdAAAACSpdG9vAAAAHGRhdGEAAAABAAAAAExhdmY2MS43LjEwMwAAAAhmcmVlAAAAK21k
        YXQAAAAVZYiEOhGKAAIY8cAAQPY4AAh5SddeAAAABkGaIBKiwA==
        """
}
#endif
