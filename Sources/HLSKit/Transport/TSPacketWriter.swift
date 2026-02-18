// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Writes data into 188-byte MPEG-TS packets.
///
/// Handles splitting PES payloads across multiple packets,
/// managing continuity counters, and inserting adaptation fields.
///
/// - SeeAlso: ISO 13818-1, Section 2.4.3
public struct TSPacketWriter: Sendable {

    /// Track continuity counters per PID.
    private var continuityCounters: [UInt16: UInt8]

    /// Creates a new TS packet writer.
    public init() {
        continuityCounters = [:]
    }

    // MARK: - PES Writing

    /// Write a PES packet as one or more TS packets.
    ///
    /// The first packet has PUSI=1. If `isKeyframe` or `pcr` is
    /// provided, the first packet includes an adaptation field.
    /// Subsequent packets carry continuation payload. The last
    /// packet uses adaptation field stuffing if needed.
    ///
    /// - Parameters:
    ///   - pesData: The complete PES packet data.
    ///   - pid: The PID for these packets.
    ///   - isKeyframe: Whether this is a random access point.
    ///   - pcr: Optional PCR value for the first packet.
    /// - Returns: Array of serialized 188-byte TS packets.
    public mutating func writePES(
        _ pesData: Data,
        pid: UInt16,
        isKeyframe: Bool = false,
        pcr: UInt64? = nil
    ) -> [TSPacket] {
        var packets: [TSPacket] = []
        var offset = 0
        let totalBytes = pesData.count

        // First packet
        let firstPacket = buildFirstPESPacket(
            pesData: pesData,
            pid: pid,
            isKeyframe: isKeyframe,
            pcr: pcr,
            offset: &offset
        )
        packets.append(firstPacket)

        // Continuation packets
        while offset < totalBytes {
            let packet = buildContinuationPacket(
                pesData: pesData,
                pid: pid,
                offset: &offset,
                totalBytes: totalBytes
            )
            packets.append(packet)
        }

        return packets
    }

    // MARK: - PSI Writing

    /// Write a PSI section (PAT or PMT) as TS packet(s).
    ///
    /// PSI packets have a pointer field (0x00) before the section
    /// data. The section is padded with 0xFF to fill the packet.
    ///
    /// - Parameters:
    ///   - sectionData: The PSI section data (including CRC-32).
    ///   - pid: The PID (0x0000 for PAT, PMT PID for PMT).
    /// - Returns: TS packet(s).
    public mutating func writePSI(
        _ sectionData: Data,
        pid: UInt16
    ) -> [TSPacket] {
        // PSI payload = pointer_field(1) + section data
        var psiPayload = Data(capacity: 1 + sectionData.count)
        psiPayload.append(0x00)  // pointer field
        psiPayload.append(sectionData)

        let maxPayload = TSPacket.packetSize - 4  // 184 bytes
        let cc = nextContinuityCounter(for: pid)

        if psiPayload.count <= maxPayload {
            // Fits in one packet — pad with 0xFF
            var payload = psiPayload
            let padding = maxPayload - payload.count
            if padding > 0 {
                payload.append(
                    Data(repeating: 0xFF, count: padding)
                )
            }
            let packet = TSPacket(
                pid: pid,
                payloadUnitStart: true,
                adaptationFieldControl: .payloadOnly,
                continuityCounter: cc,
                payload: payload
            )
            return [packet]
        }

        // Multi-packet PSI (rare for HLS)
        var packets: [TSPacket] = []
        var offset = 0
        var isFirst = true
        var currentCC = cc

        while offset < psiPayload.count {
            let remaining = psiPayload.count - offset
            let chunkSize = min(remaining, maxPayload)
            let chunk = psiPayload.subdata(
                in: offset..<(offset + chunkSize)
            )
            var payload = chunk
            if chunkSize < maxPayload {
                payload.append(
                    Data(
                        repeating: 0xFF,
                        count: maxPayload - chunkSize
                    )
                )
            }
            let packet = TSPacket(
                pid: pid,
                payloadUnitStart: isFirst,
                adaptationFieldControl: .payloadOnly,
                continuityCounter: currentCC,
                payload: payload
            )
            packets.append(packet)
            offset += chunkSize
            isFirst = false
            if offset < psiPayload.count {
                currentCC = nextContinuityCounter(for: pid)
            }
        }
        return packets
    }

    // MARK: - Continuity Counter

    /// Get the next continuity counter for a PID (increments 0–15).
    ///
    /// - Parameter pid: The PID to get/increment the counter for.
    /// - Returns: The next continuity counter value.
    public mutating func nextContinuityCounter(
        for pid: UInt16
    ) -> UInt8 {
        let current = continuityCounters[pid] ?? 0
        continuityCounters[pid] = (current + 1) & 0x0F
        return current
    }
}

// MARK: - Private Helpers

extension TSPacketWriter {

    private mutating func buildFirstPESPacket(
        pesData: Data,
        pid: UInt16,
        isKeyframe: Bool,
        pcr: UInt64?,
        offset: inout Int
    ) -> TSPacket {
        let cc = nextContinuityCounter(for: pid)
        let needsAF = isKeyframe || pcr != nil
        let headerSize = 4  // TS header

        if needsAF {
            var af = AdaptationField(
                randomAccessIndicator: isKeyframe,
                pcr: pcr
            )
            let afSize = af.size
            let availablePayload =
                TSPacket.packetSize - headerSize - afSize
            let chunkSize = min(pesData.count - offset, availablePayload)

            if chunkSize < availablePayload {
                // Need stuffing in adaptation field
                af.stuffingCount += availablePayload - chunkSize
            }

            let payload = pesData.subdata(
                in: offset..<(offset + chunkSize)
            )
            offset += chunkSize

            return TSPacket(
                pid: pid,
                payloadUnitStart: true,
                adaptationFieldControl: .adaptationAndPayload,
                continuityCounter: cc,
                adaptationField: af,
                payload: payload
            )
        }

        return buildFirstPESPacketNoAF(
            pesData: pesData,
            pid: pid,
            headerSize: headerSize,
            cc: cc,
            offset: &offset
        )
    }

    private mutating func buildFirstPESPacketNoAF(
        pesData: Data,
        pid: UInt16,
        headerSize: Int,
        cc: UInt8,
        offset: inout Int
    ) -> TSPacket {
        let maxPayload = TSPacket.packetSize - headerSize  // 184
        let available = pesData.count - offset
        let chunkSize = min(available, maxPayload)

        if chunkSize < maxPayload {
            // Need stuffing AF: min AF size is 2 bytes
            let afMinSize = 2
            let payloadSize = min(chunkSize, maxPayload - afMinSize)
            let stuffingCount = maxPayload - afMinSize - payloadSize
            let af = AdaptationField(
                stuffingCount: max(0, stuffingCount)
            )
            let payload = pesData.subdata(
                in: offset..<(offset + payloadSize)
            )
            offset += payloadSize
            return TSPacket(
                pid: pid,
                payloadUnitStart: true,
                adaptationFieldControl: .adaptationAndPayload,
                continuityCounter: cc,
                adaptationField: af,
                payload: payload
            )
        }

        let payload = pesData.subdata(
            in: offset..<(offset + chunkSize)
        )
        offset += chunkSize
        return TSPacket(
            pid: pid,
            payloadUnitStart: true,
            adaptationFieldControl: .payloadOnly,
            continuityCounter: cc,
            payload: payload
        )
    }

    private mutating func buildContinuationPacket(
        pesData: Data,
        pid: UInt16,
        offset: inout Int,
        totalBytes: Int
    ) -> TSPacket {
        let cc = nextContinuityCounter(for: pid)
        let maxPayload = TSPacket.packetSize - 4  // 184
        let remaining = totalBytes - offset
        let chunkSize = min(remaining, maxPayload)

        if chunkSize < maxPayload {
            // Last packet — need stuffing AF (min 2 bytes)
            let afMinSize = 2
            let payloadSize = min(chunkSize, maxPayload - afMinSize)
            let stuffingCount = maxPayload - afMinSize - payloadSize
            let af = AdaptationField(
                stuffingCount: max(0, stuffingCount)
            )
            let payload = pesData.subdata(
                in: offset..<(offset + payloadSize)
            )
            offset += payloadSize
            return TSPacket(
                pid: pid,
                payloadUnitStart: false,
                adaptationFieldControl: .adaptationAndPayload,
                continuityCounter: cc,
                adaptationField: af,
                payload: payload
            )
        }

        let payload = pesData.subdata(
            in: offset..<(offset + chunkSize)
        )
        offset += chunkSize
        return TSPacket(
            pid: pid,
            payloadUnitStart: false,
            adaptationFieldControl: .payloadOnly,
            continuityCounter: cc,
            payload: payload
        )
    }
}
