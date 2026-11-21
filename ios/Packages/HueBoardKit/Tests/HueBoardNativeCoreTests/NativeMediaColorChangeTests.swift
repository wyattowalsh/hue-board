#if canImport(AVFoundation) && canImport(CoreGraphics)
import Foundation
import HueBoardKit
import XCTest
@testable import HueBoardNativeCore

@MainActor
final class NativeMediaColorChangeTests: XCTestCase {
  func testCurrentPlaybackPositionChangesTintWithNoMicrophoneOrAudioTrack() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
    defer { try? FileManager.default.removeItem(at: url) }
    try XCTUnwrap(Data(base64Encoded: Self.clip, options: .ignoreUnknownCharacters)).write(to: url)
    let sampler = NativeMediaSampler(url: url)
    let metadata = try await sampler.prepare()
    XCTAssertTrue(metadata.hasVideo)
    XCTAssertFalse(metadata.hasAudio)
    XCTAssertEqual(metadata.duration, 4, accuracy: 0.05)
    let early = try await sampler.signal(at: 0.75)
    let late = try await sampler.signal(at: 3.25)
    let red = try XCTUnwrap(early.color)
    let blue = try XCTUnwrap(late.color)
    XCTAssertGreaterThan(red.red, 0.75)
    XCTAssertLessThan(red.blue, 0.2)
    XCTAssertGreaterThan(blue.blue, 0.75)
    XCTAssertLessThan(blue.red, 0.2)
    XCTAssertEqual(early.level, 0)
    XCTAssertEqual(late.level, 0)
  }

  // Two synthetic lavfi colors, 32×32 at 4 fps, each held for 2 seconds.
  // Concatenated with ffmpeg, encoded as libx264 yuv420p with GOP 4 and no audio,
  // metadata or SEI. Buffering stays inside a self-contained test fixture.
  private static let clip = """
  AAAAIGZ0eXBpc29tAAACAGlzb21pc28yYXZjMW1wNDEAAANtbW9vdgAAAGxtdmhkAAAAAAAAAAAAAAAAAAAD6AAAD6AAAQAA
  AQAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  AAAAAgAAAph0cmFrAAAAXHRraGQAAAADAAAAAAAAAAAAAAABAAAAAAAAD6AAAAAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAA
  AAAAAAABAAAAAAAAAAAAAAAAAABAAAAAACAAAAAgAAAAAAAkZWR0cwAAABxlbHN0AAAAAAAAAAEAAA+gAAAAAAABAAAAAAIQ
  bWRpYQAAACBtZGhkAAAAAAAAAAAAAAAAAABAAAABAABVxAAAAAAALWhkbHIAAAAAAAAAAHZpZGUAAAAAAAAAAAAAAABWaWRl
  b0hhbmRsZXIAAAABu21pbmYAAAAUdm1oZAAAAAEAAAAAAAAAAAAAACRkaW5mAAAAHGRyZWYAAAAAAAAAAQAAAAx1cmwgAAAA
  AQAAAXtzdGJsAAAAt3N0c2QAAAAAAAAAAQAAAKdhdmMxAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAAACAAIABIAAAASAAAAAAA
  AAABFUxhdmM2MS4xOS4xMDEgbGlieDI2NAAAAAAAAAAAAAAAGP//AAAALWF2Y0MBQsAK/+EAFmdCwAraJbARAAADAAEAAAMA
  CA8SJqABAARozg/IAAAAEHBhc3AAAAABAAAAAQAAABRidHJ0AAAAAAAAAb4AAAAAAAAAGHN0dHMAAAAAAAAAAQAAABAAABAA
  AAAAIHN0c3MAAAAAAAAABAAAAAEAAAAFAAAACQAAAA0AAAAcc3RzYwAAAAAAAAABAAAAAQAAABAAAAABAAAAVHN0c3oAAAAA
  AAAAAAAAABAAAAAZAAAACgAAAAoAAAAKAAAAGgAAAAoAAAAKAAAACgAAABoAAAAKAAAACgAAAAoAAAAaAAAACgAAAAoAAAAK
  AAAAFHN0Y28AAAAAAAAAAQAAA50AAABhdWR0YQAAAFltZXRhAAAAAAAAACFoZGxyAAAAAAAAAABtZGlyYXBwbAAAAAAAAAAA
  AAAAACxpbHN0AAAAJKl0b28AAAAcZGF0YQAAAAEAAAAATGF2ZjYxLjcuMTAzAAAACGZyZWUAAADnbWRhdAAAABVliIQ6EYoA
  AhjxwABA9jgACHlJ114AAAAGQZogEKLAAAAABkGaQBCiwAAAAAZBmmAQosAAAAAWZYiCA+hGKAAJvscAARUY4AAoUSddeAAA
  AAZBmiAQosAAAAAGQZpAEKLAAAAABkGaYBCiwAAAABZliIQEaEYoAAxIxwABVyjgACGDJ114AAAABkGaIBCiwAAAAAZBmkAQ
  osAAAAAGQZpgEKLAAAAAFmWIggEqEYoAAzExwABYQjgACGzJ114AAAAGQZogEKLAAAAABkGaQBCiwAAAAAZBmmAQosA=
  """
}
#endif
