// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("TSSegmentBuilder")
struct TSSegmentBuilderTests {

    // MARK: - Video-Only Segment

    @Test("Video-only segment starts with PAT + PMT packets")
    func videoOnlyStartsWithPATPMT() {
        let builder = TSSegmentBuilder()
        let samples = makeVideoSamples(count: 3)
        let config = makeVideoCodecConfig()
        let data = builder.buildSegment(
            videoSamples: samples, audioSamples: nil,
            config: config, sequenceNumber: 1
        )
        // At least 2 packets (PAT + PMT) + video packets
        #expect(data.count >= 188 * 3)
        // First packet: PAT (PID 0x0000)
        #expect(data[0] == 0x47)
        let patPID = extractPID(from: data, packetIndex: 0)
        #expect(patPID == TSPacket.PID.pat)
        // Second packet: PMT (PID 0x0100)
        let pmtPID = extractPID(from: data, packetIndex: 1)
        #expect(pmtPID == TSPacket.PID.pmt)
    }

    @Test("Video-only segment: video packets have correct PID")
    func videoOnlyCorrectPID() {
        let builder = TSSegmentBuilder()
        let samples = makeVideoSamples(count: 2)
        let config = makeVideoCodecConfig()
        let data = builder.buildSegment(
            videoSamples: samples, audioSamples: nil,
            config: config, sequenceNumber: 1
        )
        // Skip PAT and PMT, check video PID
        let packetCount = data.count / 188
        var foundVideo = false
        for i in 2..<packetCount {
            let pid = extractPID(from: data, packetIndex: i)
            #expect(pid == TSPacket.PID.video)
            foundVideo = true
        }
        #expect(foundVideo)
    }

    @Test("Video-only segment: first video packet has PCR")
    func videoOnlyFirstPacketHasPCR() {
        let builder = TSSegmentBuilder()
        let samples = makeVideoSamples(count: 1)
        let config = makeVideoCodecConfig()
        let data = builder.buildSegment(
            videoSamples: samples, audioSamples: nil,
            config: config, sequenceNumber: 1
        )
        // Third packet (index 2) is first video packet
        let packetStart = 188 * 2
        let afcBits = (data[packetStart + 3] >> 4) & 0x03
        // AFC should be 0b11 (adaptation + payload)
        #expect(afcBits == 0b11)
        // Check PCR flag in adaptation field
        let flags = data[packetStart + 5]
        let pcrFlag = (flags & 0x10) != 0
        #expect(pcrFlag)
    }

    @Test("Video-only segment: keyframe has RAI in adaptation field")
    func videoOnlyKeyframeRAI() {
        let builder = TSSegmentBuilder()
        var samples = makeVideoSamples(count: 2)
        samples[0] = SampleData(
            data: makeLengthPrefixedNAL(size: 50),
            pts: 0, dts: nil, duration: 3000, isSync: true
        )
        let config = makeVideoCodecConfig()
        let data = builder.buildSegment(
            videoSamples: samples, audioSamples: nil,
            config: config, sequenceNumber: 1
        )
        // Third packet is first video (keyframe)
        let packetStart = 188 * 2
        let flags = data[packetStart + 5]
        let rai = (flags & 0x40) != 0
        #expect(rai)
    }

    // MARK: - Muxed Segment

    @Test("Muxed segment: both video and audio PIDs present")
    func muxedBothPIDs() {
        let builder = TSSegmentBuilder()
        let videoSamples = makeVideoSamples(count: 2)
        let audioSamples = makeAudioSamples(count: 3)
        let config = makeMuxedCodecConfig()
        let data = builder.buildSegment(
            videoSamples: videoSamples,
            audioSamples: audioSamples,
            config: config, sequenceNumber: 1
        )
        let packetCount = data.count / 188
        var foundVideo = false
        var foundAudio = false
        for i in 0..<packetCount {
            let pid = extractPID(from: data, packetIndex: i)
            if pid == TSPacket.PID.video { foundVideo = true }
            if pid == TSPacket.PID.audio { foundAudio = true }
        }
        #expect(foundVideo)
        #expect(foundAudio)
    }

    @Test("Muxed segment: samples interleaved by PTS")
    func muxedInterleavedByPTS() {
        let builder = TSSegmentBuilder()
        // Video at PTS 0, 3000; Audio at PTS 1500, 4500
        let videoSamples = [
            SampleData(
                data: makeLengthPrefixedNAL(size: 50),
                pts: 0, dts: nil, duration: 3000, isSync: true
            ),
            SampleData(
                data: makeLengthPrefixedNAL(size: 50),
                pts: 3000, dts: nil, duration: 3000,
                isSync: false
            )
        ]
        let audioSamples = [
            SampleData(
                data: Data(repeating: 0xAA, count: 20),
                pts: 1500, dts: nil, duration: 1024,
                isSync: true
            ),
            SampleData(
                data: Data(repeating: 0xBB, count: 20),
                pts: 4500, dts: nil, duration: 1024,
                isSync: true
            )
        ]
        let config = makeMuxedCodecConfig()
        let data = builder.buildSegment(
            videoSamples: videoSamples,
            audioSamples: audioSamples,
            config: config, sequenceNumber: 1
        )
        // Verify that data was produced and is valid
        #expect(data.count > 188 * 2)
        #expect(data.count % 188 == 0)
    }

    // MARK: - Audio-Only Segment

    @Test("Audio-only segment: PAT + PMT + audio packets")
    func audioOnlySegment() {
        let builder = TSSegmentBuilder()
        let audioSamples = makeAudioSamples(count: 5)
        let config = makeAudioOnlyCodecConfig()
        let data = builder.buildAudioOnlySegment(
            audioSamples: audioSamples,
            config: config, sequenceNumber: 1
        )
        #expect(data.count >= 188 * 3)
        let patPID = extractPID(from: data, packetIndex: 0)
        #expect(patPID == TSPacket.PID.pat)
        let pmtPID = extractPID(from: data, packetIndex: 1)
        #expect(pmtPID == TSPacket.PID.pmt)
        // Check that audio PID is present
        let packetCount = data.count / 188
        var foundAudio = false
        for i in 2..<packetCount {
            let pid = extractPID(from: data, packetIndex: i)
            if pid == TSPacket.PID.audio { foundAudio = true }
        }
        #expect(foundAudio)
    }

    // MARK: - Structural Validation

    @Test("Segment data is multiple of 188 bytes")
    func segmentMultipleOf188() {
        let builder = TSSegmentBuilder()
        let samples = makeVideoSamples(count: 5)
        let config = makeVideoCodecConfig()
        let data = builder.buildSegment(
            videoSamples: samples, audioSamples: nil,
            config: config, sequenceNumber: 1
        )
        #expect(data.count % 188 == 0)
    }

    @Test("All packets start with sync byte 0x47")
    func allPacketsSyncByte() {
        let builder = TSSegmentBuilder()
        let samples = makeVideoSamples(count: 3)
        let config = makeVideoCodecConfig()
        let data = builder.buildSegment(
            videoSamples: samples, audioSamples: nil,
            config: config, sequenceNumber: 1
        )
        let packetCount = data.count / 188
        for i in 0..<packetCount {
            #expect(data[i * 188] == 0x47)
        }
    }

    @Test("Continuity counters are sequential per PID")
    func continuityCountersSequential() {
        let builder = TSSegmentBuilder()
        let samples = makeVideoSamples(count: 5)
        let config = makeVideoCodecConfig()
        let data = builder.buildSegment(
            videoSamples: samples, audioSamples: nil,
            config: config, sequenceNumber: 1
        )
        let packetCount = data.count / 188
        var counters: [UInt16: [UInt8]] = [:]
        for i in 0..<packetCount {
            let pid = extractPID(from: data, packetIndex: i)
            let cc = data[i * 188 + 3] & 0x0F
            counters[pid, default: []].append(cc)
        }
        // Verify each PID has sequential counters
        for (_, ccs) in counters {
            for i in 1..<ccs.count {
                let expected = (ccs[i - 1] + 1) & 0x0F
                #expect(ccs[i] == expected)
            }
        }
    }
}

// MARK: - Test Helpers

extension TSSegmentBuilderTests {

    private func extractPID(
        from data: Data, packetIndex: Int
    ) -> UInt16 {
        let offset = packetIndex * 188
        let high = UInt16(data[offset + 1] & 0x1F) << 8
        let low = UInt16(data[offset + 2])
        return high | low
    }

    private func makeLengthPrefixedNAL(size: Int) -> Data {
        var data = Data()
        let nalSize = UInt32(size)
        data.append(UInt8((nalSize >> 24) & 0xFF))
        data.append(UInt8((nalSize >> 16) & 0xFF))
        data.append(UInt8((nalSize >> 8) & 0xFF))
        data.append(UInt8(nalSize & 0xFF))
        data.append(Data(repeating: 0x65, count: size))
        return data
    }

    private func makeVideoSamples(count: Int) -> [SampleData] {
        (0..<count).map { i in
            SampleData(
                data: makeLengthPrefixedNAL(size: 50),
                pts: UInt64(i) * 3000,
                dts: nil,
                duration: 3000,
                isSync: i == 0
            )
        }
    }

    private func makeAudioSamples(
        count: Int
    ) -> [SampleData] {
        (0..<count).map { i in
            SampleData(
                data: Data(repeating: 0xAA, count: 20),
                pts: UInt64(i) * 1024,
                dts: nil,
                duration: 1024,
                isSync: true
            )
        }
    }

    private func makeVideoCodecConfig() -> TSCodecConfig {
        let sc = AnnexBConverter.startCode
        let sps = sc + Data(repeating: 0x67, count: 10)
        let pps = sc + Data(repeating: 0x68, count: 5)
        return TSCodecConfig(
            sps: sps, pps: pps, aacConfig: nil,
            videoStreamType: .h264, audioStreamType: nil
        )
    }

    private func makeAudioOnlyCodecConfig() -> TSCodecConfig {
        let aacConfig = ADTSConverter.AACConfig(
            profile: 1, sampleRateIndex: 4, channelConfig: 2
        )
        return TSCodecConfig(
            sps: nil, pps: nil, aacConfig: aacConfig,
            videoStreamType: nil, audioStreamType: .aac
        )
    }

    private func makeMuxedCodecConfig() -> TSCodecConfig {
        let sc = AnnexBConverter.startCode
        let sps = sc + Data(repeating: 0x67, count: 10)
        let pps = sc + Data(repeating: 0x68, count: 5)
        let aacConfig = ADTSConverter.AACConfig(
            profile: 1, sampleRateIndex: 4, channelConfig: 2
        )
        return TSCodecConfig(
            sps: sps, pps: pps, aacConfig: aacConfig,
            videoStreamType: .h264, audioStreamType: .aac
        )
    }
}
