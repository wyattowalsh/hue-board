#if canImport(AVFoundation) && canImport(CoreGraphics)
@preconcurrency import AVFoundation
import CoreGraphics
import Foundation
import HueBoardKit

public struct NativeMediaMetadata: Sendable {
    public let duration: TimeInterval
    public let hasAudio: Bool
    public let hasVideo: Bool
}

/// Reads a small window from a user-selected local clip at the Live transition rate.
/// The sampler never plays audio, records input, or opens a network URL.
public actor NativeMediaSampler {
    private let url: URL
    private var asset: AVURLAsset?
    private var audioTrack: AVAssetTrack?
    private var imageGenerator: AVAssetImageGenerator?
    private var metadata: NativeMediaMetadata?

    public init(url: URL) {
        self.url = url
    }

    public func prepare() async throws -> NativeMediaMetadata {
        guard url.isFileURL else {
            throw HueBoardError.unsupported("Choose a local audio or video file.")
        }
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        let audio = try await asset.loadTracks(withMediaType: .audio).first
        let video = try await asset.loadTracks(withMediaType: .video).first
        guard duration.isFinite, duration > 0, audio != nil || video != nil,
              try await asset.load(.isPlayable) else {
            throw HueBoardError.unsupported("This file has no playable audio or video.")
        }

        let metadata = NativeMediaMetadata(duration: duration, hasAudio: audio != nil, hasVideo: video != nil)
        self.asset = asset
        audioTrack = audio
        self.metadata = metadata
        if video != nil {
            let generator = AVAssetImageGenerator(asset: asset)
            generator.maximumSize = CGSize(width: 64, height: 64)
            generator.appliesPreferredTrackTransform = true
            generator.requestedTimeToleranceBefore = CMTime(seconds: 0.3, preferredTimescale: 600)
            generator.requestedTimeToleranceAfter = generator.requestedTimeToleranceBefore
            imageGenerator = generator
        }
        return metadata
    }

    public func signal(at seconds: TimeInterval) async throws -> HueLiveSignal {
        guard let asset, let metadata, seconds.isFinite, (0...metadata.duration).contains(seconds) else {
            throw HueBoardError.unsupported("The media position is outside the selected clip.")
        }
        try Task.checkCancellation()
        let level: Double
        if let audioTrack {
            level = (try? Self.audioLevel(asset: asset, track: audioTrack, at: seconds, duration: metadata.duration)) ?? 0
        } else {
            level = 0
        }
        let color: RGB?
        if let imageGenerator {
            let position = min(seconds, max(0, metadata.duration - 0.02))
            let time = CMTime(seconds: position, preferredTimescale: 600)
            let frame = try? await imageGenerator.image(at: time)
            color = frame.flatMap { Self.averageColor($0.image) }
        } else {
            color = nil
        }
        try Task.checkCancellation()
        return HueLiveSignal(level: level, color: color)
    }

    private static func audioLevel(
        asset: AVAsset,
        track: AVAssetTrack,
        at seconds: TimeInterval,
        duration: TimeInterval
    ) throws -> Double {
        let window = min(0.4, duration)
        let start = min(seconds, duration - window)
        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = CMTimeRange(
            start: CMTime(seconds: start, preferredTimescale: 48_000),
            duration: CMTime(seconds: window, preferredTimescale: 48_000)
        )
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 8_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ])
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { return 0 }
        reader.add(output)
        guard reader.startReading() else { return 0 }
        defer { reader.cancelReading() }

        let sampleLimit = 3_200 // 0.4 seconds at the requested 8 kHz.
        var count = 0
        var energy = 0.0
        while count < sampleLimit, let sample = output.copyNextSampleBuffer() {
            try Task.checkCancellation()
            guard let buffer = CMSampleBufferGetDataBuffer(sample) else { continue }
            let sampleCount = min(sampleLimit - count, CMBlockBufferGetDataLength(buffer) / 2)
            guard sampleCount > 0 else { continue }
            var pcm = [Int16](repeating: 0, count: sampleCount)
            let result = pcm.withUnsafeMutableBytes { bytes -> OSStatus? in
                guard let destination = bytes.baseAddress else { return nil }
                return CMBlockBufferCopyDataBytes(buffer, atOffset: 0, dataLength: bytes.count, destination: destination)
            }
            guard result == kCMBlockBufferNoErr else { continue }
            for value in pcm {
                let amplitude = Double(Int16(littleEndian: value)) / 32_768
                energy += amplitude * amplitude
            }
            count += sampleCount
        }
        guard count > 0, energy > 0 else { return 0 }
        let dBFS = 20 * log10(sqrt(energy / Double(count)))
        return min(max((dBFS + 50) / 45, 0), 1)
    }

    private static func averageColor(_ image: CGImage) -> RGB? {
        let side = 16
        let pixelCount = side * side
        var bytes = [UInt8](repeating: 0, count: pixelCount * 4)
        let rendered = bytes.withUnsafeMutableBytes { pixels -> Bool in
            guard let context = CGContext(
                data: pixels.baseAddress,
                width: side,
                height: side,
                bitsPerComponent: 8,
                bytesPerRow: side * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
            ) else { return false }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard rendered else { return nil }
        var rgb = (red: 0, green: 0, blue: 0)
        for index in stride(from: 0, to: bytes.count, by: 4) {
            rgb.red += Int(bytes[index])
            rgb.green += Int(bytes[index + 1])
            rgb.blue += Int(bytes[index + 2])
        }
        let scale = Double(pixelCount * 255)
        return RGB(red: Double(rgb.red) / scale, green: Double(rgb.green) / scale, blue: Double(rgb.blue) / scale)
    }
}
#endif
