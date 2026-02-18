// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("PESPacketizer")
struct PESPacketizerTests {

    // MARK: - Video PES

    @Test("Video PES: starts with 0x000001E0")
    func videoPESStartCode() {
        let packetizer = PESPacketizer()
        let pes = packetizer.packetize(
            videoData: Data(repeating: 0xAA, count: 100),
            pts: 90000,
            dts: nil
        )
        #expect(pes[0] == 0x00)
        #expect(pes[1] == 0x00)
        #expect(pes[2] == 0x01)
        #expect(pes[3] == 0xE0)
    }

    @Test("Video PES: PTS correctly encoded (5-byte format)")
    func videoPESPTSEncoded() {
        let packetizer = PESPacketizer()
        let pts: UInt64 = 90000  // 1 second
        let pes = packetizer.packetize(
            videoData: Data(repeating: 0, count: 10),
            pts: pts,
            dts: nil
        )
        // PTS starts at offset 9 (after header)
        let ptsBytes = Data(pes[9..<14])
        let decoded = decodePTSDTS(ptsBytes)
        #expect(decoded == pts)
    }

    @Test("Video PES: PTS + DTS both present when DTS provided")
    func videoPESPTSAndDTS() {
        let packetizer = PESPacketizer()
        let pts: UInt64 = 93000
        let dts: UInt64 = 90000
        let pes = packetizer.packetize(
            videoData: Data(repeating: 0, count: 10),
            pts: pts,
            dts: dts
        )
        // PTS_DTS_flags should be 11 (0xC0)
        #expect(pes[7] & 0xC0 == 0xC0)
        // PES header data length should be 10
        #expect(pes[8] == 10)

        // Decode PTS (offset 9-13) and DTS (offset 14-18)
        let decodedPTS = decodePTSDTS(Data(pes[9..<14]))
        let decodedDTS = decodePTSDTS(Data(pes[14..<19]))
        #expect(decodedPTS == pts)
        #expect(decodedDTS == dts)
    }

    @Test("Video PES: PTS-only when DTS is nil")
    func videoPESPTSOnly() {
        let packetizer = PESPacketizer()
        let pes = packetizer.packetize(
            videoData: Data(repeating: 0, count: 10),
            pts: 90000,
            dts: nil
        )
        // PTS_DTS_flags should be 10 (0x80)
        #expect(pes[7] & 0xC0 == 0x80)
        // PES header data length should be 5
        #expect(pes[8] == 5)
    }

    @Test("Video PES: PTS-only when DTS equals PTS")
    func videoPESDTSEqualsPTS() {
        let packetizer = PESPacketizer()
        let pes = packetizer.packetize(
            videoData: Data(repeating: 0, count: 10),
            pts: 90000,
            dts: 90000
        )
        // Should be PTS-only since DTS == PTS
        #expect(pes[7] & 0xC0 == 0x80)
        #expect(pes[8] == 5)
    }

    // MARK: - Audio PES

    @Test("Audio PES: starts with 0x000001C0")
    func audioPESStartCode() {
        let packetizer = PESPacketizer()
        let pes = packetizer.packetize(
            audioData: Data(repeating: 0xBB, count: 50),
            pts: 90000
        )
        #expect(pes[0] == 0x00)
        #expect(pes[1] == 0x00)
        #expect(pes[2] == 0x01)
        #expect(pes[3] == 0xC0)
    }

    @Test("Audio PES: PTS-only (no DTS for audio)")
    func audioPESPTSOnly() {
        let packetizer = PESPacketizer()
        let pes = packetizer.packetize(
            audioData: Data(repeating: 0, count: 50),
            pts: 90000
        )
        // PTS_DTS_flags should be 10 (0x80)
        #expect(pes[7] & 0xC0 == 0x80)
        #expect(pes[8] == 5)
    }

    @Test("Audio PES: packet length is non-zero")
    func audioPESPacketLength() {
        let audioData = Data(repeating: 0, count: 50)
        let packetizer = PESPacketizer()
        let pes = packetizer.packetize(
            audioData: audioData,
            pts: 90000
        )
        let pesLength = UInt16(pes[4]) << 8 | UInt16(pes[5])
        // 3 (optional header) + 5 (PTS) + 50 (data) = 58
        #expect(pesLength == 58)
    }

    // MARK: - PTS/DTS encoding

    @Test("PTS encoding: known values (verify bit layout)")
    func ptsEncodingKnownValues() {
        let pts: UInt64 = 90000
        let encoded = encodePTSDTS(pts, marker: 0x20)
        #expect(encoded.count == 5)
        let decoded = decodePTSDTS(encoded)
        #expect(decoded == pts)
    }

    @Test("PTS encoding: zero timestamp")
    func ptsEncodingZero() {
        let encoded = encodePTSDTS(0, marker: 0x20)
        #expect(encoded.count == 5)
        let decoded = decodePTSDTS(encoded)
        #expect(decoded == 0)
    }

    @Test("PTS encoding: large timestamp (near 33-bit max)")
    func ptsEncodingLarge() {
        let maxPTS: UInt64 = 0x1_FFFF_FFFF  // 33-bit max
        let encoded = encodePTSDTS(maxPTS, marker: 0x20)
        let decoded = decodePTSDTS(encoded)
        #expect(decoded == maxPTS)
    }

    @Test("PTS encoding: marker bits are correct")
    func ptsEncodingMarkerBits() {
        // PTS-only marker: 0x20 → byte0[7:4] = 0010
        let ptsOnly = encodePTSDTS(12345, marker: 0x20)
        #expect(ptsOnly[0] & 0xF0 == 0x20)

        // PTS in PTS+DTS: 0x30 → byte0[7:4] = 0011
        let ptsPlusDts = encodePTSDTS(12345, marker: 0x30)
        #expect(ptsPlusDts[0] & 0xF0 == 0x30)

        // DTS marker: 0x10 → byte0[7:4] = 0001
        let dtsMarker = encodePTSDTS(12345, marker: 0x10)
        #expect(dtsMarker[0] & 0xF0 == 0x10)
    }

    @Test("PTS encoding: marker bit 1s are present")
    func ptsEncodingMarkerOnes() {
        let encoded = encodePTSDTS(54321, marker: 0x20)
        // byte 0 bit 0 = 1
        #expect(encoded[0] & 0x01 == 0x01)
        // byte 2 bit 0 = 1
        #expect(encoded[2] & 0x01 == 0x01)
        // byte 4 bit 0 = 1
        #expect(encoded[4] & 0x01 == 0x01)
    }
}

// MARK: - Helpers

extension PESPacketizerTests {

    /// Decode a 5-byte PTS/DTS value back to a 33-bit timestamp.
    private func decodePTSDTS(_ data: Data) -> UInt64 {
        let base = data.startIndex
        let b0 = UInt64(data[base])
        let b1 = UInt64(data[base + 1])
        let b2 = UInt64(data[base + 2])
        let b3 = UInt64(data[base + 3])
        let b4 = UInt64(data[base + 4])

        let tsHigh = (b0 >> 1) & 0x07
        let tsMid1 = b1
        let tsMid2 = (b2 >> 1) & 0x7F
        let tsMid3 = b3
        let tsLow = (b4 >> 1) & 0x7F

        return (tsHigh << 30)
            | (tsMid1 << 22)
            | (tsMid2 << 15)
            | (tsMid3 << 7)
            | tsLow
    }
}
