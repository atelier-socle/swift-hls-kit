// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// An MPEG Transport Stream packet (188 bytes).
///
/// Each TS packet has a 4-byte header followed by an optional
/// adaptation field and/or payload. The sync byte is always `0x47`.
///
/// - SeeAlso: ISO 13818-1, Section 2.4.3
public struct TSPacket: Sendable, Hashable {

    /// Fixed packet size in bytes.
    public static let packetSize = 188

    /// Sync byte (always 0x47).
    public static let syncByte: UInt8 = 0x47

    /// Packet Identifier (13-bit).
    public let pid: UInt16

    /// Payload unit start indicator.
    public let payloadUnitStart: Bool

    /// Adaptation field control.
    public let adaptationFieldControl: AdaptationFieldControl

    /// Continuity counter (0–15).
    public let continuityCounter: UInt8

    /// Adaptation field (if present).
    public let adaptationField: AdaptationField?

    /// Payload data (if present).
    public let payload: Data?

    /// Creates a TS packet.
    ///
    /// - Parameters:
    ///   - pid: Packet Identifier (13-bit).
    ///   - payloadUnitStart: Whether a PES/PSI starts in this packet.
    ///   - adaptationFieldControl: Adaptation field control value.
    ///   - continuityCounter: Continuity counter (0–15).
    ///   - adaptationField: Optional adaptation field.
    ///   - payload: Optional payload data.
    public init(
        pid: UInt16,
        payloadUnitStart: Bool,
        adaptationFieldControl: AdaptationFieldControl,
        continuityCounter: UInt8,
        adaptationField: AdaptationField? = nil,
        payload: Data? = nil
    ) {
        self.pid = pid & 0x1FFF
        self.payloadUnitStart = payloadUnitStart
        self.adaptationFieldControl = adaptationFieldControl
        self.continuityCounter = continuityCounter & 0x0F
        self.adaptationField = adaptationField
        self.payload = payload
    }

    /// Adaptation field control values.
    public enum AdaptationFieldControl: UInt8, Sendable, Hashable {
        /// Payload only (no adaptation field).
        case payloadOnly = 0b01
        /// Adaptation field only (no payload).
        case adaptationOnly = 0b10
        /// Adaptation field followed by payload.
        case adaptationAndPayload = 0b11
    }

    /// Serialize this packet to exactly 188 bytes.
    ///
    /// - Returns: 188-byte TS packet data.
    public func serialize() -> Data {
        var data = Data(capacity: TSPacket.packetSize)

        // Byte 0: sync byte
        data.append(TSPacket.syncByte)

        // Byte 1: TEI(0) | PUSI | priority(0) | PID high 5 bits
        let pusiFlag: UInt8 = payloadUnitStart ? 0x40 : 0x00
        let pidHigh = UInt8((pid >> 8) & 0x1F)
        data.append(pusiFlag | pidHigh)

        // Byte 2: PID low 8 bits
        data.append(UInt8(pid & 0xFF))

        // Byte 3: scrambling(00) | adaptation_field_control | cc
        let afcBits = adaptationFieldControl.rawValue << 4
        data.append(afcBits | continuityCounter)

        // Adaptation field
        if let af = adaptationField {
            let afData = af.serialize()
            data.append(afData)
        }

        // Payload
        if let payloadData = payload {
            data.append(payloadData)
        }

        // Pad to 188 bytes if needed
        if data.count < TSPacket.packetSize {
            data.append(
                Data(
                    repeating: 0xFF,
                    count: TSPacket.packetSize - data.count
                )
            )
        }

        return data
    }
}

// MARK: - Well-Known PIDs

extension TSPacket {

    /// Standard PID assignments for MPEG-TS.
    public enum PID {
        /// Program Association Table.
        public static let pat: UInt16 = 0x0000
        /// Conditional Access Table.
        public static let cat: UInt16 = 0x0001
        /// Null packet (padding).
        public static let nullPacket: UInt16 = 0x1FFF
        /// Program Map Table (conventional).
        public static let pmt: UInt16 = 0x0100
        /// Video elementary stream (conventional).
        public static let video: UInt16 = 0x0101
        /// Audio elementary stream (conventional).
        public static let audio: UInt16 = 0x0102
    }
}

// MARK: - Adaptation Field

/// Adaptation field within a TS packet.
///
/// Contains timing (PCR) and signaling (random access, discontinuity)
/// information for the transport stream decoder.
///
/// - SeeAlso: ISO 13818-1, Section 2.4.3.4
public struct AdaptationField: Sendable, Hashable {

    /// Random access indicator (keyframe).
    public var randomAccessIndicator: Bool

    /// Discontinuity indicator.
    public var discontinuityIndicator: Bool

    /// PCR value (if present). 27 MHz clock encoded as
    /// `PCR_base * 300 + PCR_extension`.
    public var pcr: UInt64?

    /// Stuffing byte count (0xFF padding).
    public var stuffingCount: Int

    /// Creates an adaptation field.
    ///
    /// - Parameters:
    ///   - randomAccessIndicator: Whether this is a random access point.
    ///   - discontinuityIndicator: Whether there is a discontinuity.
    ///   - pcr: Optional PCR value (27 MHz).
    ///   - stuffingCount: Number of stuffing bytes to append.
    public init(
        randomAccessIndicator: Bool = false,
        discontinuityIndicator: Bool = false,
        pcr: UInt64? = nil,
        stuffingCount: Int = 0
    ) {
        self.randomAccessIndicator = randomAccessIndicator
        self.discontinuityIndicator = discontinuityIndicator
        self.pcr = pcr
        self.stuffingCount = stuffingCount
    }

    /// Total size in bytes (including the length byte).
    public var size: Int {
        // 1 (length byte) + 1 (flags byte) + PCR (6) + stuffing
        var contentSize = 1  // flags byte
        if pcr != nil {
            contentSize += 6
        }
        contentSize += stuffingCount
        return 1 + contentSize  // +1 for length byte itself
    }

    /// Serialize the adaptation field.
    ///
    /// - Returns: Serialized adaptation field data.
    public func serialize() -> Data {
        var contentSize = 1  // flags byte
        if pcr != nil {
            contentSize += 6
        }
        contentSize += stuffingCount

        var data = Data(capacity: 1 + contentSize)

        // Length byte (number of bytes after this byte)
        data.append(UInt8(contentSize))

        // Flags byte
        var flags: UInt8 = 0
        if discontinuityIndicator { flags |= 0x80 }
        if randomAccessIndicator { flags |= 0x40 }
        if pcr != nil { flags |= 0x10 }
        data.append(flags)

        // PCR (6 bytes)
        if let pcrValue = pcr {
            let pcrBase = pcrValue / 300
            let pcrExt = pcrValue % 300
            // PCR_base: 33 bits
            data.append(UInt8((pcrBase >> 25) & 0xFF))
            data.append(UInt8((pcrBase >> 17) & 0xFF))
            data.append(UInt8((pcrBase >> 9) & 0xFF))
            data.append(UInt8((pcrBase >> 1) & 0xFF))
            // 1 bit of PCR_base + 6 reserved + 9 bits PCR_ext
            let lastBaseBit = UInt8((pcrBase & 0x01) << 7)
            let reserved: UInt8 = 0x7E  // 6 reserved bits = 1
            let extHigh = UInt8((pcrExt >> 8) & 0x01)
            data.append(lastBaseBit | reserved | extHigh)
            data.append(UInt8(pcrExt & 0xFF))
        }

        // Stuffing bytes
        if stuffingCount > 0 {
            data.append(
                Data(repeating: 0xFF, count: stuffingCount)
            )
        }

        return data
    }
}
