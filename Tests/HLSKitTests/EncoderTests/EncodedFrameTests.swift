// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("EncodedFrame & EncodedCodec", .timeLimit(.minutes(1)))
struct EncodedFrameTests {

    // MARK: - EncodedFrame Creation

    @Test("EncodedFrame: audio frame creation")
    func audioFrameCreation() {
        let data = Data([0x01, 0x02, 0x03])
        let frame = EncodedFrame(
            data: data,
            timestamp: MediaTimestamp(seconds: 1.0),
            duration: MediaTimestamp(seconds: 0.023),
            isKeyframe: true,
            codec: .aac
        )

        #expect(frame.data == data)
        #expect(frame.timestamp.seconds == 1.0)
        #expect(frame.duration.seconds == 0.023)
        #expect(frame.isKeyframe)
        #expect(frame.codec == .aac)
        #expect(frame.bitrateHint == nil)
        #expect(frame.hdrMetadata == nil)
        #expect(frame.channelLayout == nil)
    }

    @Test("EncodedFrame: video frame creation with all fields")
    func videoFrameCreation() {
        let data = Data(repeating: 0xAA, count: 1024)
        let hdr = HDRMetadata(type: .hdr10, maxContentLightLevel: 1000)
        let frame = EncodedFrame(
            data: data,
            timestamp: MediaTimestamp(seconds: 0.0),
            duration: MediaTimestamp(seconds: 1.0 / 30.0),
            isKeyframe: false,
            codec: .h265,
            bitrateHint: 5_000_000,
            hdrMetadata: hdr
        )

        #expect(frame.data.count == 1024)
        #expect(!frame.isKeyframe)
        #expect(frame.codec == .h265)
        #expect(frame.bitrateHint == 5_000_000)
        #expect(frame.hdrMetadata?.type == .hdr10)
        #expect(frame.channelLayout == nil)
    }

    @Test("EncodedFrame: audio frame with channel layout")
    func audioFrameWithChannelLayout() {
        let layout = AudioChannelLayout(layout: .surround51)
        let frame = EncodedFrame(
            data: Data([0x00]),
            timestamp: .zero,
            duration: MediaTimestamp(seconds: 0.023),
            isKeyframe: true,
            codec: .eac3,
            channelLayout: layout
        )

        #expect(frame.channelLayout?.layout == .surround51)
        #expect(frame.channelLayout?.channelCount == 6)
    }

    @Test("EncodedFrame: Sendable across tasks")
    func frameSendable() async {
        let frame = EncodedFrame(
            data: Data([0x01]),
            timestamp: .zero,
            duration: MediaTimestamp(seconds: 0.023),
            isKeyframe: true,
            codec: .aac
        )

        await Task {
            #expect(frame.codec == .aac)
        }.value
    }

    // MARK: - EncodedCodec

    @Test("EncodedCodec: allCases count")
    func codecAllCases() {
        #expect(EncodedCodec.allCases.count == 9)
    }

    @Test("EncodedCodec: audio codecs")
    func codecAudioCases() {
        let audioCodecs: [EncodedCodec] = [
            .aac, .ac3, .eac3, .alac, .flac, .opus
        ]
        for codec in audioCodecs {
            #expect(codec.isAudio, "Expected \(codec.rawValue) to be audio")
            #expect(!codec.isVideo, "Expected \(codec.rawValue) to not be video")
        }
    }

    @Test("EncodedCodec: video codecs")
    func codecVideoCases() {
        let videoCodecs: [EncodedCodec] = [.h264, .h265, .av1]
        for codec in videoCodecs {
            #expect(codec.isVideo, "Expected \(codec.rawValue) to be video")
            #expect(!codec.isAudio, "Expected \(codec.rawValue) to not be audio")
        }
    }

    @Test("EncodedCodec: raw values")
    func codecRawValues() {
        #expect(EncodedCodec.aac.rawValue == "aac")
        #expect(EncodedCodec.ac3.rawValue == "ac3")
        #expect(EncodedCodec.eac3.rawValue == "eac3")
        #expect(EncodedCodec.alac.rawValue == "alac")
        #expect(EncodedCodec.flac.rawValue == "flac")
        #expect(EncodedCodec.opus.rawValue == "opus")
        #expect(EncodedCodec.h264.rawValue == "h264")
        #expect(EncodedCodec.h265.rawValue == "h265")
        #expect(EncodedCodec.av1.rawValue == "av1")
    }

    @Test("EncodedCodec: Codable round-trip")
    func codecCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for codec in EncodedCodec.allCases {
            let encoded = try encoder.encode(codec)
            let decoded = try decoder.decode(
                EncodedCodec.self, from: encoded
            )
            #expect(decoded == codec)
        }
    }

    @Test("EncodedCodec: Hashable in set")
    func codecHashable() {
        var set = Set<EncodedCodec>()
        set.insert(.aac)
        set.insert(.aac)
        set.insert(.h264)
        #expect(set.count == 2)
    }
}
