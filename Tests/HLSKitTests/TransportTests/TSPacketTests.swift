// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("TSPacket")
struct TSPacketTests {

    // MARK: - Serialization basics

    @Test("Serialize packet: exactly 188 bytes")
    func serializeExactly188Bytes() {
        let packet = TSPacket(
            pid: 0x0101,
            payloadUnitStart: false,
            adaptationFieldControl: .payloadOnly,
            continuityCounter: 0,
            payload: Data(repeating: 0xAA, count: 184)
        )
        let data = packet.serialize()
        #expect(data.count == 188)
    }

    @Test("Serialize: sync byte is 0x47")
    func serializeSyncByte() {
        let packet = TSPacket(
            pid: 0x0000,
            payloadUnitStart: false,
            adaptationFieldControl: .payloadOnly,
            continuityCounter: 0,
            payload: Data(repeating: 0, count: 184)
        )
        let data = packet.serialize()
        #expect(data[0] == 0x47)
    }

    @Test("Serialize: PID correctly encoded in 13 bits")
    func serializePIDEncoding() {
        let pid: UInt16 = 0x1FFF  // max 13-bit value
        let packet = TSPacket(
            pid: pid,
            payloadUnitStart: false,
            adaptationFieldControl: .payloadOnly,
            continuityCounter: 0,
            payload: Data(repeating: 0, count: 184)
        )
        let data = packet.serialize()
        let encodedPID =
            UInt16(data[1] & 0x1F) << 8
            | UInt16(data[2])
        #expect(encodedPID == pid)
    }

    @Test("Serialize: PUSI flag at correct bit position")
    func serializePUSI() {
        let packetWithPUSI = TSPacket(
            pid: 0x0100,
            payloadUnitStart: true,
            adaptationFieldControl: .payloadOnly,
            continuityCounter: 0,
            payload: Data(repeating: 0, count: 184)
        )
        let data = packetWithPUSI.serialize()
        #expect(data[1] & 0x40 != 0)

        let packetWithoutPUSI = TSPacket(
            pid: 0x0100,
            payloadUnitStart: false,
            adaptationFieldControl: .payloadOnly,
            continuityCounter: 0,
            payload: Data(repeating: 0, count: 184)
        )
        let data2 = packetWithoutPUSI.serialize()
        #expect(data2[1] & 0x40 == 0)
    }

    @Test("Serialize: continuity counter in low 4 bits of byte 3")
    func serializeContinuityCounter() {
        for cc: UInt8 in 0...15 {
            let packet = TSPacket(
                pid: 0x0101,
                payloadUnitStart: false,
                adaptationFieldControl: .payloadOnly,
                continuityCounter: cc,
                payload: Data(repeating: 0, count: 184)
            )
            let data = packet.serialize()
            #expect(data[3] & 0x0F == cc)
        }
    }

    @Test("Serialize: adaptation field control bits")
    func serializeAFCBits() {
        let payloadOnly = TSPacket(
            pid: 0x0101,
            payloadUnitStart: false,
            adaptationFieldControl: .payloadOnly,
            continuityCounter: 0,
            payload: Data(repeating: 0, count: 184)
        )
        let d1 = payloadOnly.serialize()
        #expect((d1[3] >> 4) & 0x03 == 0b01)

        let afOnly = TSPacket(
            pid: 0x0101,
            payloadUnitStart: false,
            adaptationFieldControl: .adaptationOnly,
            continuityCounter: 0,
            adaptationField: AdaptationField(stuffingCount: 182)
        )
        let d2 = afOnly.serialize()
        #expect((d2[3] >> 4) & 0x03 == 0b10)

        let both = TSPacket(
            pid: 0x0101,
            payloadUnitStart: false,
            adaptationFieldControl: .adaptationAndPayload,
            continuityCounter: 0,
            adaptationField: AdaptationField(),
            payload: Data(repeating: 0, count: 182)
        )
        let d3 = both.serialize()
        #expect((d3[3] >> 4) & 0x03 == 0b11)
    }

    @Test("Serialize: payload only (no adaptation field)")
    func serializePayloadOnly() {
        let payload = Data(repeating: 0xBB, count: 184)
        let packet = TSPacket(
            pid: 0x0101,
            payloadUnitStart: false,
            adaptationFieldControl: .payloadOnly,
            continuityCounter: 5,
            payload: payload
        )
        let data = packet.serialize()
        #expect(Data(data[4..<188]) == payload)
    }

    @Test("Serialize: adaptation field + payload")
    func serializeAFAndPayload() {
        let af = AdaptationField(randomAccessIndicator: true)
        let payload = Data(repeating: 0xCC, count: 182)
        let packet = TSPacket(
            pid: 0x0101,
            payloadUnitStart: true,
            adaptationFieldControl: .adaptationAndPayload,
            continuityCounter: 0,
            adaptationField: af,
            payload: payload
        )
        let data = packet.serialize()
        #expect(data.count == 188)
        // AF length byte at index 4
        let afLength = data[4]
        #expect(afLength == 1)  // flags byte only
    }

    @Test("Serialize: adaptation field only (stuffing)")
    func serializeAFOnly() {
        let af = AdaptationField(stuffingCount: 182)
        let packet = TSPacket(
            pid: 0x1FFF,
            payloadUnitStart: false,
            adaptationFieldControl: .adaptationOnly,
            continuityCounter: 0,
            adaptationField: af
        )
        let data = packet.serialize()
        #expect(data.count == 188)
    }

    // MARK: - Adaptation field details

    @Test("Adaptation field: random access indicator")
    func adaptationFieldRAI() {
        let af = AdaptationField(randomAccessIndicator: true)
        let afData = af.serialize()
        // Byte 0: length, Byte 1: flags
        #expect(afData[1] & 0x40 != 0)

        let afNoRAI = AdaptationField(
            randomAccessIndicator: false
        )
        let afNoRAIData = afNoRAI.serialize()
        #expect(afNoRAIData[1] & 0x40 == 0)
    }

    @Test("Adaptation field: PCR encoding")
    func adaptationFieldPCR() {
        // PCR = base * 300 + ext
        // base = 90000 (1 second at 90kHz)
        // ext = 150
        let pcrValue: UInt64 = 90000 * 300 + 150
        let af = AdaptationField(pcr: pcrValue)
        let afData = af.serialize()

        // Verify PCR flag is set
        #expect(afData[1] & 0x10 != 0)

        // Verify PCR size: length(1) + flags(1) + pcr(6) = 8
        #expect(afData[0] == 7)  // length byte = 7 (after it)
    }

    @Test("Adaptation field: stuffing bytes are 0xFF")
    func adaptationFieldStuffing() {
        let af = AdaptationField(stuffingCount: 10)
        let afData = af.serialize()
        // length(1) + flags(1) + 10 stuffing = 12 bytes total
        #expect(afData.count == 12)
        for i in 2..<12 {
            #expect(afData[i] == 0xFF)
        }
    }

    @Test("Adaptation field: discontinuity indicator")
    func adaptationFieldDiscontinuity() {
        let af = AdaptationField(discontinuityIndicator: true)
        let afData = af.serialize()
        #expect(afData[1] & 0x80 != 0)
    }

    // MARK: - PID constants

    @Test("PID constants: PAT, PMT, video, audio, null")
    func pidConstants() {
        #expect(TSPacket.PID.pat == 0x0000)
        #expect(TSPacket.PID.cat == 0x0001)
        #expect(TSPacket.PID.nullPacket == 0x1FFF)
        #expect(TSPacket.PID.pmt == 0x0100)
        #expect(TSPacket.PID.video == 0x0101)
        #expect(TSPacket.PID.audio == 0x0102)
    }

    @Test("Serialize: short payload is padded to 188 bytes")
    func serializeShortPayloadPadded() {
        // Packet with payload shorter than 184 bytes
        // and no adaptation field → should pad with 0xFF
        let packet = TSPacket(
            pid: 0x0101,
            payloadUnitStart: false,
            adaptationFieldControl: .payloadOnly,
            continuityCounter: 0,
            payload: Data(repeating: 0xAA, count: 50)
        )
        let data = packet.serialize()
        #expect(data.count == 188)
        // Trailing bytes should be 0xFF padding
        #expect(data[187] == 0xFF)
    }

    // MARK: - AdaptationField size

    @Test("Adaptation field: size calculation")
    func adaptationFieldSize() {
        let afMinimal = AdaptationField()
        #expect(afMinimal.size == 2)  // length(1) + flags(1)

        let afWithPCR = AdaptationField(
            pcr: 27_000_000
        )
        #expect(afWithPCR.size == 8)  // 1 + 1 + 6

        let afWithStuffing = AdaptationField(stuffingCount: 5)
        #expect(afWithStuffing.size == 7)  // 1 + 1 + 5
    }
}
