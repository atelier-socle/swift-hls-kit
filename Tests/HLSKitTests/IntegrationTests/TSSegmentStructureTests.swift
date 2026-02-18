// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("TS Segment Structure Verification")
struct TSSegmentStructureTests {

    private func muxedSegmentData()
        throws -> SegmentationResult
    {
        let data = TSTestDataBuilder.avMP4WithAvcCAndEsds()
        let config = SegmentationConfig(
            containerFormat: .mpegTS
        )
        return try TSSegmenter().segment(
            data: data, config: config
        )
    }

    private func extractPID(
        from data: Data, packetIndex: Int
    ) -> UInt16 {
        let offset = packetIndex * 188
        let high = UInt16(data[offset + 1] & 0x1F) << 8
        let low = UInt16(data[offset + 2])
        return high | low
    }

    // MARK: - Packet Structure

    @Test("Every segment is multiple of 188 bytes")
    func multipleOf188() throws {
        let result = try muxedSegmentData()
        for seg in result.mediaSegments {
            #expect(seg.data.count % 188 == 0)
        }
    }

    @Test("Every packet starts with 0x47 sync byte")
    func syncByte() throws {
        let result = try muxedSegmentData()
        for seg in result.mediaSegments {
            let packetCount = seg.data.count / 188
            for p in 0..<packetCount {
                #expect(seg.data[p * 188] == 0x47)
            }
        }
    }

    @Test("First two packets are PAT and PMT")
    func patPmtFirst() throws {
        let result = try muxedSegmentData()
        for seg in result.mediaSegments {
            let patPID = extractPID(
                from: seg.data, packetIndex: 0
            )
            #expect(patPID == TSPacket.PID.pat)
            let pmtPID = extractPID(
                from: seg.data, packetIndex: 1
            )
            #expect(pmtPID == TSPacket.PID.pmt)
        }
    }

    @Test("PAT contains program entry pointing to PMT PID")
    func patPointsToPMT() throws {
        let result = try muxedSegmentData()
        let seg = try #require(result.mediaSegments.first)
        // PAT: header(4) + pointer(1) + table_id(1) + len(2)
        // + tsid(2) + ver(1) + sn(1) + lsn(1) = 13 bytes
        // Then program entry: pnum(2) + reserved+pid(2)
        let progStart = 4 + 1 + 8
        let pidHigh =
            UInt16(seg.data[progStart + 2] & 0x1F) << 8
        let pidLow = UInt16(seg.data[progStart + 3])
        #expect((pidHigh | pidLow) == TSPacket.PID.pmt)
    }

    @Test("PMT contains video and audio stream entries")
    func pmtContainsStreams() throws {
        let result = try muxedSegmentData()
        let seg = try #require(result.mediaSegments.first)
        // PMT at packet 1: header(4) + pointer(1) +
        // table_id(1) + len(2) + pnum(2) + ver(1) +
        // sn(1) + lsn(1) + pcr_pid(2) + info_len(2)
        let pmtBase = 188
        let streamStart = pmtBase + 4 + 1 + 12
        // Video entry: type(1) + pid(2) + info_len(2)
        let videoType = seg.data[streamStart]
        let videoPid =
            UInt16(seg.data[streamStart + 1] & 0x1F) << 8
            | UInt16(seg.data[streamStart + 2])
        #expect(videoType == 0x1B)
        #expect(videoPid == TSPacket.PID.video)
        // Audio entry
        let audioStart = streamStart + 5
        let audioType = seg.data[audioStart]
        let audioPid =
            UInt16(seg.data[audioStart + 1] & 0x1F) << 8
            | UInt16(seg.data[audioStart + 2])
        #expect(audioType == 0x0F)
        #expect(audioPid == TSPacket.PID.audio)
    }

    @Test("Video packets use expected PID (0x101)")
    func videoPID() throws {
        let result = try muxedSegmentData()
        let seg = try #require(result.mediaSegments.first)
        let packetCount = seg.data.count / 188
        var found = false
        for p in 2..<packetCount {
            let pid = extractPID(
                from: seg.data, packetIndex: p
            )
            if pid == TSPacket.PID.video { found = true }
        }
        #expect(found)
    }

    @Test("Audio packets use expected PID (0x102)")
    func audioPID() throws {
        let result = try muxedSegmentData()
        let seg = try #require(result.mediaSegments.first)
        let packetCount = seg.data.count / 188
        var found = false
        for p in 2..<packetCount {
            let pid = extractPID(
                from: seg.data, packetIndex: p
            )
            if pid == TSPacket.PID.audio { found = true }
        }
        #expect(found)
    }

    @Test("First video packet has PUSI = 1")
    func firstVideoPUSI() throws {
        let result = try muxedSegmentData()
        let seg = try #require(result.mediaSegments.first)
        let packetCount = seg.data.count / 188
        for p in 2..<packetCount {
            let pid = extractPID(
                from: seg.data, packetIndex: p
            )
            if pid == TSPacket.PID.video {
                let pusi =
                    (seg.data[p * 188 + 1] & 0x40) != 0
                #expect(pusi)
                break
            }
        }
    }

    @Test("First video packet of keyframe has RAI")
    func keyframeRAI() throws {
        let result = try muxedSegmentData()
        let seg = try #require(result.mediaSegments.first)
        let packetCount = seg.data.count / 188
        for p in 2..<packetCount {
            let pid = extractPID(
                from: seg.data, packetIndex: p
            )
            if pid == TSPacket.PID.video {
                let afc =
                    (seg.data[p * 188 + 3] >> 4) & 0x03
                #expect(afc >= 0b10)
                let flags = seg.data[p * 188 + 5]
                let rai = (flags & 0x40) != 0
                #expect(rai)
                break
            }
        }
    }

    @Test("PCR present in at least one packet per segment")
    func pcrPresent() throws {
        let result = try muxedSegmentData()
        for seg in result.mediaSegments {
            let packetCount = seg.data.count / 188
            var foundPCR = false
            for p in 0..<packetCount {
                let offset = p * 188
                let afc =
                    (seg.data[offset + 3] >> 4) & 0x03
                if afc >= 0b10 {
                    let afLength = seg.data[offset + 4]
                    if afLength > 0 {
                        let flags = seg.data[offset + 5]
                        if (flags & 0x10) != 0 {
                            foundPCR = true
                            break
                        }
                    }
                }
            }
            #expect(foundPCR)
        }
    }

    @Test("Continuity counters are sequential per PID")
    func continuityCounters() throws {
        let result = try muxedSegmentData()
        let seg = try #require(result.mediaSegments.first)
        let packetCount = seg.data.count / 188
        var counters: [UInt16: [UInt8]] = [:]
        for p in 0..<packetCount {
            let pid = extractPID(
                from: seg.data, packetIndex: p
            )
            let cc = seg.data[p * 188 + 3] & 0x0F
            counters[pid, default: []].append(cc)
        }
        for (_, ccs) in counters {
            for i in 1..<ccs.count {
                let expected = (ccs[i - 1] + 1) & 0x0F
                #expect(ccs[i] == expected)
            }
        }
    }

    @Test("PES start codes present after PUSI packets")
    func pesStartCodes() throws {
        let result = try muxedSegmentData()
        let seg = try #require(result.mediaSegments.first)
        let packetCount = seg.data.count / 188
        for p in 2..<packetCount {
            let offset = p * 188
            let pusi = (seg.data[offset + 1] & 0x40) != 0
            guard pusi else { continue }
            let pid = extractPID(
                from: seg.data, packetIndex: p
            )
            guard
                pid == TSPacket.PID.video
                    || pid == TSPacket.PID.audio
            else { continue }
            let afc = (seg.data[offset + 3] >> 4) & 0x03
            var payloadStart = offset + 4
            if afc >= 0b10 {
                let afLen = Int(seg.data[offset + 4])
                payloadStart = offset + 5 + afLen
            }
            guard payloadStart + 3 <= offset + 188 else {
                continue
            }
            #expect(seg.data[payloadStart] == 0x00)
            #expect(seg.data[payloadStart + 1] == 0x00)
            #expect(seg.data[payloadStart + 2] == 0x01)
        }
    }
}
