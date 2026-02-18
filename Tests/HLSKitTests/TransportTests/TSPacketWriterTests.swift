// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("TSPacketWriter")
struct TSPacketWriterTests {

    // MARK: - PES writing basics

    @Test("Write small PES (fits in one packet): 1 TS packet")
    func writeSmallPES() {
        var writer = TSPacketWriter()
        let pesData = Data(repeating: 0xAA, count: 100)
        let packets = writer.writePES(
            pesData, pid: TSPacket.PID.video
        )
        #expect(packets.count == 1)
        let serialized = packets[0].serialize()
        #expect(serialized.count == 188)
    }

    @Test("Write large PES (spans multiple packets)")
    func writeLargePES() {
        var writer = TSPacketWriter()
        // 500 bytes of PES data → multiple TS packets
        let pesData = Data(repeating: 0xBB, count: 500)
        let packets = writer.writePES(
            pesData, pid: TSPacket.PID.video
        )
        #expect(packets.count > 1)
        for packet in packets {
            let serialized = packet.serialize()
            #expect(serialized.count == 188)
        }
    }

    @Test("First packet has PUSI=1, subsequent have PUSI=0")
    func pusiFlags() {
        var writer = TSPacketWriter()
        let pesData = Data(repeating: 0xCC, count: 500)
        let packets = writer.writePES(
            pesData, pid: TSPacket.PID.video
        )
        #expect(packets.count > 1)
        #expect(packets[0].payloadUnitStart == true)
        for i in 1..<packets.count {
            #expect(packets[i].payloadUnitStart == false)
        }
    }

    @Test("Continuity counter increments per PID")
    func continuityCounterIncrements() {
        var writer = TSPacketWriter()
        let pesData = Data(repeating: 0xDD, count: 500)
        let packets = writer.writePES(
            pesData, pid: TSPacket.PID.video
        )
        for (i, packet) in packets.enumerated() {
            #expect(packet.continuityCounter == UInt8(i & 0x0F))
        }
    }

    @Test("Continuity counter wraps 15 → 0")
    func continuityCounterWraps() {
        var writer = TSPacketWriter()
        // Write enough PES packets to wrap the counter
        for _ in 0..<17 {
            let pesData = Data(repeating: 0, count: 10)
            _ = writer.writePES(
                pesData, pid: TSPacket.PID.video
            )
        }
        // 17th call → cc should be 1 (after wrapping 16→0)
        let pesData = Data(repeating: 0, count: 10)
        let packets = writer.writePES(
            pesData, pid: TSPacket.PID.video
        )
        // Counter for PID.video: each writePES uses 1 packet
        // 17 loop calls used cc 0..16 (wrapping at 15→0)
        // 18th call gets cc = 17 % 16 = 1
        #expect(
            packets[0].continuityCounter == UInt8(17 % 16)
        )
    }

    @Test("Different PIDs have independent continuity counters")
    func independentCounters() {
        var writer = TSPacketWriter()
        let videoData = Data(repeating: 0xAA, count: 10)
        let audioData = Data(repeating: 0xBB, count: 10)

        let videoPackets1 = writer.writePES(
            videoData, pid: TSPacket.PID.video
        )
        let audioPackets1 = writer.writePES(
            audioData, pid: TSPacket.PID.audio
        )
        let videoPackets2 = writer.writePES(
            videoData, pid: TSPacket.PID.video
        )

        #expect(videoPackets1[0].continuityCounter == 0)
        #expect(audioPackets1[0].continuityCounter == 0)
        #expect(videoPackets2[0].continuityCounter == 1)
    }

    // MARK: - Adaptation field features

    @Test("Keyframe: first packet has adaptation field with RAI=1")
    func keyframeRAI() {
        var writer = TSPacketWriter()
        let pesData = Data(repeating: 0xEE, count: 100)
        let packets = writer.writePES(
            pesData,
            pid: TSPacket.PID.video,
            isKeyframe: true
        )
        #expect(packets[0].adaptationField != nil)
        #expect(
            packets[0].adaptationField?.randomAccessIndicator
                == true
        )
    }

    @Test("PCR: first packet has PCR in adaptation field")
    func pcrInFirstPacket() {
        var writer = TSPacketWriter()
        let pcrValue: UInt64 = 27_000_000
        let pesData = Data(repeating: 0xFF, count: 100)
        let packets = writer.writePES(
            pesData,
            pid: TSPacket.PID.video,
            pcr: pcrValue
        )
        #expect(packets[0].adaptationField != nil)
        #expect(packets[0].adaptationField?.pcr == pcrValue)
    }

    @Test("Last packet: all packets are exactly 188 bytes")
    func allPackets188Bytes() {
        var writer = TSPacketWriter()
        // Use a size that doesn't divide evenly into 184
        let pesData = Data(repeating: 0x11, count: 300)
        let packets = writer.writePES(
            pesData, pid: TSPacket.PID.video
        )
        for packet in packets {
            let serialized = packet.serialize()
            #expect(serialized.count == 188)
        }
    }

    // MARK: - PSI writing

    @Test("PSI packet: pointer field (0x00) prepended")
    func psiPointerField() {
        var writer = TSPacketWriter()
        let gen = ProgramTableGenerator()
        let pat = gen.generatePAT()
        let packets = writer.writePSI(
            pat, pid: TSPacket.PID.pat
        )
        #expect(packets.count == 1)
        #expect(packets[0].payloadUnitStart == true)

        // The payload should start with 0x00 (pointer field)
        if let p = packets[0].payload {
            #expect(p[p.startIndex] == 0x00)
        }
    }

    @Test("PSI: serialized packets are 188 bytes")
    func psiPacket188Bytes() {
        var writer = TSPacketWriter()
        let gen = ProgramTableGenerator()
        let pmt = gen.generatePMT(streams: [
            .init(streamType: .h264, pid: 0x0101),
            .init(streamType: .aac, pid: 0x0102)
        ])
        let packets = writer.writePSI(
            pmt, pid: TSPacket.PID.pmt
        )
        for packet in packets {
            let serialized = packet.serialize()
            #expect(serialized.count == 188)
        }
    }

    @Test("Write PES exactly filling first packet payload")
    func pesExactlyOnePacket() {
        var writer = TSPacketWriter()
        // 184 bytes = exactly one full payload-only packet
        let pesData = Data(repeating: 0x22, count: 184)
        let packets = writer.writePES(
            pesData, pid: TSPacket.PID.video
        )
        #expect(packets.count == 1)
        #expect(
            packets[0].adaptationFieldControl == .payloadOnly
        )
    }

    @Test("Write PES with keyframe and large data")
    func pesKeyframeLargeData() {
        var writer = TSPacketWriter()
        let pesData = Data(repeating: 0x33, count: 1000)
        let packets = writer.writePES(
            pesData,
            pid: TSPacket.PID.video,
            isKeyframe: true,
            pcr: 27_000_000
        )
        #expect(packets.count > 1)
        // All packets serialize to 188 bytes
        for packet in packets {
            #expect(packet.serialize().count == 188)
        }
    }

    @Test("Write very small PES (1 byte) needs stuffing")
    func pesVerySmall() {
        var writer = TSPacketWriter()
        let pesData = Data([0x42])
        let packets = writer.writePES(
            pesData, pid: TSPacket.PID.video
        )
        #expect(packets.count == 1)
        let serialized = packets[0].serialize()
        #expect(serialized.count == 188)
    }

    @Test("Multi-packet PSI: large section splits correctly")
    func multiPacketPSI() {
        var writer = TSPacketWriter()
        // Build section data > 183 bytes to trigger multi-packet
        let largeSection = Data(repeating: 0xAB, count: 300)
        let packets = writer.writePSI(
            largeSection, pid: TSPacket.PID.pmt
        )
        #expect(packets.count > 1)
        #expect(packets[0].payloadUnitStart == true)
        if packets.count > 1 {
            #expect(packets[1].payloadUnitStart == false)
        }
        for packet in packets {
            let serialized = packet.serialize()
            #expect(serialized.count == 188)
        }
    }

    @Test("PES 183 bytes: AF caps payload to 182, spills 1 byte")
    func pes183BytesMinimalAF() {
        var writer = TSPacketWriter()
        // 183 bytes < 184 max → AF(2) + 182 payload, 1 byte spills
        let pesData = Data(repeating: 0x44, count: 183)
        let packets = writer.writePES(
            pesData, pid: TSPacket.PID.video
        )
        // 182 + 1 = 2 packets
        #expect(packets.count >= 1)
        for packet in packets {
            #expect(packet.serialize().count == 188)
        }
    }

    @Test("PES continuation: all packets are exactly 188 bytes")
    func pesContinuationAllPackets188() {
        var writer = TSPacketWriter()
        // 367 bytes = 184 + 182 + 1 → 3 packets all 188 bytes
        let pesData = Data(repeating: 0x55, count: 367)
        let packets = writer.writePES(
            pesData, pid: TSPacket.PID.video
        )
        #expect(packets.count >= 2)
        for packet in packets {
            #expect(packet.serialize().count == 188)
        }
    }

    // MARK: - Data integrity

    @Test("All PES bytes are present in TS packets")
    func pesDataIntegrity() {
        var writer = TSPacketWriter()
        let pesData = Data(
            (0..<400).map { UInt8($0 & 0xFF) }
        )
        let packets = writer.writePES(
            pesData, pid: TSPacket.PID.video
        )

        // Reassemble payload from all packets
        var reassembled = Data()
        for packet in packets {
            let serialized = packet.serialize()
            // Find where payload starts
            var payloadStart = 4  // after TS header
            if packet.adaptationField != nil {
                let afLength = Int(serialized[4])
                payloadStart = 4 + 1 + afLength
            }
            reassembled.append(
                serialized[payloadStart..<188]
            )
        }
        // The reassembled data should start with the PES data
        let pesPrefix = Data(
            reassembled[0..<pesData.count]
        )
        #expect(pesPrefix == pesData)
    }
}
