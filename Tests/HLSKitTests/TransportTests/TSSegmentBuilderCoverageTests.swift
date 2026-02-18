// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("TSSegmentBuilder Coverage")
struct TSSegmentBuilderCoverageTests {

    // MARK: - Audio-only path

    @Test("Audio-only segment with multiple samples")
    func audioOnlyMultiple() {
        let builder = TSSegmentBuilder()
        let samples = (0..<10).map { i in
            SampleData(
                data: Data(repeating: 0xAA, count: 20),
                pts: UInt64(i) * 1024,
                dts: nil,
                duration: 1024,
                isSync: true
            )
        }
        let config = makeAudioOnlyConfig()
        let data = builder.buildAudioOnlySegment(
            audioSamples: samples,
            config: config, sequenceNumber: 1
        )
        #expect(data.count % 188 == 0)
        #expect(data.count >= 188 * 3)
    }

    @Test("Audio-only segment: PCR in first audio packet")
    func audioOnlyPCR() {
        let builder = TSSegmentBuilder()
        let samples = [
            SampleData(
                data: Data(repeating: 0xAA, count: 20),
                pts: 0, dts: nil, duration: 1024,
                isSync: true
            )
        ]
        let config = makeAudioOnlyConfig()
        let data = builder.buildAudioOnlySegment(
            audioSamples: samples,
            config: config, sequenceNumber: 1
        )
        // Third packet (index 2) should be audio with PCR
        let offset = 188 * 2
        let afc = (data[offset + 3] >> 4) & 0x03
        #expect(afc == 0b11)
        let flags = data[offset + 5]
        let pcrFlag = (flags & 0x10) != 0
        #expect(pcrFlag)
    }

    // MARK: - Video with no audio config

    @Test("Muxed segment with nil aacConfig → no audio")
    func muxedNoAACConfig() {
        let builder = TSSegmentBuilder()
        let videoSamples = [
            SampleData(
                data: makeLengthPrefixedNAL(size: 50),
                pts: 0, dts: nil, duration: 3000,
                isSync: true
            )
        ]
        let audioSamples = [
            SampleData(
                data: Data(repeating: 0xAA, count: 20),
                pts: 0, dts: nil, duration: 1024,
                isSync: true
            )
        ]
        // Config has video but no audio (nil aacConfig)
        let config = TSCodecConfig(
            sps: AnnexBConverter.startCode
                + Data(repeating: 0x67, count: 10),
            pps: AnnexBConverter.startCode
                + Data(repeating: 0x68, count: 5),
            aacConfig: nil,
            videoStreamType: .h264,
            audioStreamType: nil
        )
        let data = builder.buildSegment(
            videoSamples: videoSamples,
            audioSamples: audioSamples,
            config: config, sequenceNumber: 1
        )
        #expect(data.count % 188 == 0)
        // Should have no audio PID
        let packetCount = data.count / 188
        for p in 0..<packetCount {
            let pid = extractPID(
                from: data, packetIndex: p
            )
            #expect(pid != TSPacket.PID.audio)
        }
    }

    // MARK: - Large sample count

    @Test("Video-only with many samples")
    func manyVideoSamples() {
        let builder = TSSegmentBuilder()
        let samples = (0..<100).map { i in
            SampleData(
                data: makeLengthPrefixedNAL(size: 50),
                pts: UInt64(i) * 3000,
                dts: nil,
                duration: 3000,
                isSync: i == 0
            )
        }
        let config = makeVideoOnlyConfig()
        let data = builder.buildSegment(
            videoSamples: samples, audioSamples: nil,
            config: config, sequenceNumber: 1
        )
        #expect(data.count % 188 == 0)
        let packetCount = data.count / 188
        #expect(packetCount > 100)
    }

    // MARK: - PTS ordering in merge

    @Test("Muxed: audio PTS before first video PTS")
    func audioBeforeVideo() {
        let builder = TSSegmentBuilder()
        let videoSamples = [
            SampleData(
                data: makeLengthPrefixedNAL(size: 50),
                pts: 5000, dts: nil, duration: 3000,
                isSync: true
            )
        ]
        let audioSamples = [
            SampleData(
                data: Data(repeating: 0xAA, count: 20),
                pts: 0, dts: nil, duration: 1024,
                isSync: true
            ),
            SampleData(
                data: Data(repeating: 0xBB, count: 20),
                pts: 1024, dts: nil, duration: 1024,
                isSync: true
            )
        ]
        let config = makeMuxedConfig()
        let data = builder.buildSegment(
            videoSamples: videoSamples,
            audioSamples: audioSamples,
            config: config, sequenceNumber: 1
        )
        #expect(data.count % 188 == 0)
        var foundAudio = false
        var foundVideo = false
        let packetCount = data.count / 188
        for p in 2..<packetCount {
            let pid = extractPID(
                from: data, packetIndex: p
            )
            if pid == TSPacket.PID.audio {
                foundAudio = true
            }
            if pid == TSPacket.PID.video {
                foundVideo = true
            }
        }
        #expect(foundAudio)
        #expect(foundVideo)
    }

    // MARK: - Helpers

    private func extractPID(
        from data: Data, packetIndex: Int
    ) -> UInt16 {
        let offset = packetIndex * 188
        let high = UInt16(data[offset + 1] & 0x1F) << 8
        let low = UInt16(data[offset + 2])
        return high | low
    }

    private func makeLengthPrefixedNAL(
        size: Int
    ) -> Data {
        var data = Data()
        let nalSize = UInt32(size)
        data.append(UInt8((nalSize >> 24) & 0xFF))
        data.append(UInt8((nalSize >> 16) & 0xFF))
        data.append(UInt8((nalSize >> 8) & 0xFF))
        data.append(UInt8(nalSize & 0xFF))
        data.append(Data(repeating: 0x65, count: size))
        return data
    }

    private func makeVideoOnlyConfig() -> TSCodecConfig {
        let sc = AnnexBConverter.startCode
        return TSCodecConfig(
            sps: sc + Data(repeating: 0x67, count: 10),
            pps: sc + Data(repeating: 0x68, count: 5),
            aacConfig: nil,
            videoStreamType: .h264,
            audioStreamType: nil
        )
    }

    private func makeAudioOnlyConfig() -> TSCodecConfig {
        let aacConfig = ADTSConverter.AACConfig(
            profile: 1, sampleRateIndex: 4,
            channelConfig: 2
        )
        return TSCodecConfig(
            sps: nil, pps: nil, aacConfig: aacConfig,
            videoStreamType: nil, audioStreamType: .aac
        )
    }

    private func makeMuxedConfig() -> TSCodecConfig {
        let sc = AnnexBConverter.startCode
        let aacConfig = ADTSConverter.AACConfig(
            profile: 1, sampleRateIndex: 4,
            channelConfig: 2
        )
        return TSCodecConfig(
            sps: sc + Data(repeating: 0x67, count: 10),
            pps: sc + Data(repeating: 0x68, count: 5),
            aacConfig: aacConfig,
            videoStreamType: .h264,
            audioStreamType: .aac
        )
    }
}
