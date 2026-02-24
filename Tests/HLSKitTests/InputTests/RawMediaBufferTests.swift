// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("RawMediaBuffer")
struct RawMediaBufferTests {

    // MARK: - MediaTimestamp

    @Test("MediaTimestamp: initialization from seconds")
    func mediaTimestampSecondsInit() {
        let ts = MediaTimestamp(seconds: 1.0, timescale: 90000)
        #expect(ts.seconds == 1.0)
        #expect(ts.timescale == 90000)
    }

    @Test("MediaTimestamp: initialization from value and timescale")
    func mediaTimestampValueInit() {
        let ts = MediaTimestamp(value: 90000, timescale: 90000)
        #expect(ts.seconds == 1.0)
        #expect(ts.value == 90000)
    }

    @Test("MediaTimestamp: value computed property")
    func mediaTimestampValue() {
        let ts = MediaTimestamp(seconds: 0.5, timescale: 90000)
        #expect(ts.value == 45000)
    }

    @Test("MediaTimestamp: zero timestamp")
    func mediaTimestampZero() {
        #expect(MediaTimestamp.zero.seconds == 0.0)
    }

    @Test("MediaTimestamp: Comparable conformance")
    func mediaTimestampComparable() {
        let ts1 = MediaTimestamp(seconds: 1.0)
        let ts2 = MediaTimestamp(seconds: 2.0)
        #expect(ts1 < ts2)
        #expect(!(ts2 < ts1))
    }

    @Test("MediaTimestamp: Equatable conformance")
    func mediaTimestampEquatable() {
        let ts1 = MediaTimestamp(seconds: 1.0, timescale: 90000)
        let ts2 = MediaTimestamp(seconds: 1.0, timescale: 90000)
        let ts3 = MediaTimestamp(seconds: 2.0, timescale: 90000)
        #expect(ts1 == ts2)
        #expect(ts1 != ts3)
    }

    @Test("MediaTimestamp: Sendable conformance")
    func mediaTimestampSendable() async {
        let ts = MediaTimestamp(seconds: 1.0)
        await Task {
            #expect(ts.seconds == 1.0)
        }.value
    }

    // MARK: - MediaFormatInfo

    @Test("MediaFormatInfo.video: initialization")
    func mediaFormatInfoVideo() {
        let info = MediaFormatInfo.video(codec: .h264, width: 1920, height: 1080)
        if case .video(let codec, let width, let height) = info {
            #expect(codec == .h264)
            #expect(width == 1920)
            #expect(height == 1080)
        } else {
            Issue.record("Expected video format")
        }
    }

    @Test("MediaFormatInfo.audio: initialization")
    func mediaFormatInfoAudio() {
        let info = MediaFormatInfo.audio(
            sampleRate: 48000,
            channels: 2,
            bitsPerSample: 16,
            isFloat: false
        )
        if case .audio(let rate, let ch, let bits, let isFloat) = info {
            #expect(rate == 48000)
            #expect(ch == 2)
            #expect(bits == 16)
            #expect(!isFloat)
        } else {
            Issue.record("Expected audio format")
        }
    }

    @Test("MediaFormatInfo: Equatable conformance")
    func mediaFormatInfoEquatable() {
        let info1 = MediaFormatInfo.video(codec: .h264, width: 1920, height: 1080)
        let info2 = MediaFormatInfo.video(codec: .h264, width: 1920, height: 1080)
        let info3 = MediaFormatInfo.video(codec: .h265, width: 1920, height: 1080)
        #expect(info1 == info2)
        #expect(info1 != info3)
    }

    // MARK: - RawMediaBuffer

    @Test("RawMediaBuffer: initialization with video data")
    func rawMediaBufferVideoInit() {
        let data = Data([0x00, 0x00, 0x00, 0x01, 0x67])
        let timestamp = MediaTimestamp(seconds: 0.0)
        let duration = MediaTimestamp(seconds: 0.033)
        let formatInfo = MediaFormatInfo.video(codec: .h264, width: 1920, height: 1080)

        let buffer = RawMediaBuffer(
            data: data,
            timestamp: timestamp,
            duration: duration,
            isKeyframe: true,
            mediaType: .video,
            formatInfo: formatInfo
        )

        #expect(buffer.data == data)
        #expect(buffer.timestamp == timestamp)
        #expect(buffer.duration == duration)
        #expect(buffer.isKeyframe)
        #expect(buffer.mediaType == .video)
    }

    @Test("RawMediaBuffer: initialization with audio data")
    func rawMediaBufferAudioInit() {
        let data = Data(repeating: 0x00, count: 1024)
        let timestamp = MediaTimestamp(seconds: 0.0)
        let duration = MediaTimestamp(seconds: 0.021)
        let formatInfo = MediaFormatInfo.audio(
            sampleRate: 48000,
            channels: 2,
            bitsPerSample: 16,
            isFloat: false
        )

        let buffer = RawMediaBuffer(
            data: data,
            timestamp: timestamp,
            duration: duration,
            isKeyframe: true,
            mediaType: .audio,
            formatInfo: formatInfo
        )

        #expect(buffer.data.count == 1024)
        #expect(buffer.mediaType == .audio)
        #expect(buffer.isKeyframe)
    }

    @Test("RawMediaBuffer: Sendable conformance")
    func rawMediaBufferSendable() async {
        let buffer = RawMediaBuffer(
            data: Data([0x01, 0x02, 0x03]),
            timestamp: MediaTimestamp(seconds: 0.0),
            duration: MediaTimestamp(seconds: 0.1),
            isKeyframe: true,
            mediaType: .video,
            formatInfo: .video(codec: .h264, width: 640, height: 480)
        )

        await Task {
            #expect(buffer.data.count == 3)
        }.value
    }

    // MARK: - AudioChannelLayout

    @Test("AudioChannelLayout.Layout: all cases")
    func audioChannelLayoutCases() {
        let cases = AudioChannelLayout.Layout.allCases
        #expect(cases.contains(.mono))
        #expect(cases.contains(.stereo))
        #expect(cases.contains(.surround51))
        #expect(cases.contains(.surround71))
    }

    @Test("AudioChannelLayout: channelCount property")
    func audioChannelLayoutChannelCount() {
        #expect(AudioChannelLayout(layout: .mono).channelCount == 1)
        #expect(AudioChannelLayout(layout: .stereo).channelCount == 2)
        #expect(AudioChannelLayout(layout: .surround51).channelCount == 6)
        #expect(AudioChannelLayout(layout: .surround71).channelCount == 8)
    }
}
