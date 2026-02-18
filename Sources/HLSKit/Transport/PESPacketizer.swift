// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Creates PES (Packetized Elementary Stream) packets.
///
/// Wraps raw codec data (H.264 NAL units, AAC frames) with
/// PES headers containing PTS/DTS timing.
///
/// - SeeAlso: ISO 13818-1, Section 2.4.3.6
public struct PESPacketizer: Sendable {

    /// Creates a new PES packetizer.
    public init() {}

    /// Create a PES packet for a video access unit.
    ///
    /// Video PES uses stream ID `0xE0` and includes both PTS
    /// and optional DTS. The PES packet length is set to 0
    /// (unbounded) for video.
    ///
    /// - Parameters:
    ///   - data: Video access unit data (Annex B format for H.264).
    ///   - pts: Presentation timestamp (90 kHz).
    ///   - dts: Decoding timestamp (90 kHz), nil if same as PTS.
    ///   - streamId: Stream ID (default: 0xE0 for video).
    /// - Returns: Complete PES packet data.
    public func packetize(
        videoData data: Data,
        pts: UInt64,
        dts: UInt64?,
        streamId: UInt8 = 0xE0
    ) -> Data {
        let hasDTS = dts != nil && dts != pts
        let headerDataLength: UInt8 = hasDTS ? 10 : 5
        let ptsDtsFlags: UInt8 = hasDTS ? 0xC0 : 0x80

        var pes = Data()

        // Packet start code prefix: 0x000001
        pes.append(0x00)
        pes.append(0x00)
        pes.append(0x01)

        // Stream ID
        pes.append(streamId)

        // PES packet length: 0 = unbounded (used for video)
        pes.append(0x00)
        pes.append(0x00)

        // Optional PES header
        // Marker bits (10) + scrambling(00) + priority(0)
        // + alignment(0) + copyright(0) + original(0)
        pes.append(0x80)

        // PTS_DTS_flags + other flags (all 0)
        pes.append(ptsDtsFlags)

        // PES header data length
        pes.append(headerDataLength)

        // PTS
        let ptsMarker: UInt8 = hasDTS ? 0x30 : 0x20
        pes.append(contentsOf: encodePTSDTS(pts, marker: ptsMarker))

        // DTS
        if hasDTS, let dtsValue = dts {
            pes.append(
                contentsOf: encodePTSDTS(dtsValue, marker: 0x10)
            )
        }

        // Elementary stream data
        pes.append(data)

        return pes
    }

    /// Create a PES packet for an audio frame.
    ///
    /// Audio PES uses stream ID `0xC0` and includes PTS only
    /// (no DTS for audio).
    ///
    /// - Parameters:
    ///   - data: Audio frame data (ADTS format for AAC).
    ///   - pts: Presentation timestamp (90 kHz).
    ///   - streamId: Stream ID (default: 0xC0 for audio).
    /// - Returns: Complete PES packet data.
    public func packetize(
        audioData data: Data,
        pts: UInt64,
        streamId: UInt8 = 0xC0
    ) -> Data {
        let headerDataLength: UInt8 = 5

        var pes = Data()

        // Packet start code prefix: 0x000001
        pes.append(0x00)
        pes.append(0x00)
        pes.append(0x01)

        // Stream ID
        pes.append(streamId)

        // PES packet length (audio uses actual length)
        // 3 (optional header bytes) + 5 (PTS) + data length
        let pesPayloadLength =
            3 + Int(headerDataLength)
            + data.count
        if pesPayloadLength <= Int(UInt16.max) {
            let len = UInt16(pesPayloadLength)
            pes.append(UInt8((len >> 8) & 0xFF))
            pes.append(UInt8(len & 0xFF))
        } else {
            pes.append(0x00)
            pes.append(0x00)
        }

        // Optional PES header
        pes.append(0x80)

        // PTS only
        pes.append(0x80)

        // PES header data length
        pes.append(headerDataLength)

        // PTS
        pes.append(contentsOf: encodePTSDTS(pts, marker: 0x20))

        // Elementary stream data
        pes.append(data)

        return pes
    }
}

// MARK: - PTS/DTS Encoding

/// Encode a 33-bit timestamp into 5-byte PTS/DTS format.
///
/// The 33-bit value is spread across 5 bytes with marker bits:
/// ```
/// byte 0: [7:4]=marker, [3:1]=TS[32:30], [0]=marker(1)
/// byte 1: [7:0]=TS[29:22]
/// byte 2: [7:1]=TS[21:15], [0]=marker(1)
/// byte 3: [7:0]=TS[14:7]
/// byte 4: [7:1]=TS[6:0], [0]=marker(1)
/// ```
///
/// - Parameters:
///   - timestamp: 33-bit timestamp at 90 kHz.
///   - marker: High nibble marker (0x20 for PTS-only,
///     0x30 for PTS in PTS+DTS, 0x10 for DTS).
/// - Returns: 5 bytes of encoded timestamp.
public func encodePTSDTS(_ timestamp: UInt64, marker: UInt8) -> Data {
    let ts = timestamp & 0x1_FFFF_FFFF  // mask to 33 bits

    var data = Data(capacity: 5)

    // Byte 0: marker[7:4] | TS[32:30] << 1 | 1
    let byte0 =
        marker
        | UInt8((ts >> 29) & 0x0E)
        | 0x01
    data.append(byte0)

    // Byte 1: TS[29:22]
    data.append(UInt8((ts >> 22) & 0xFF))

    // Byte 2: TS[21:15] << 1 | 1
    let byte2 = UInt8((ts >> 14) & 0xFE) | 0x01
    data.append(byte2)

    // Byte 3: TS[14:7]
    data.append(UInt8((ts >> 7) & 0xFF))

    // Byte 4: TS[6:0] << 1 | 1
    let byte4 = UInt8((ts << 1) & 0xFE) | 0x01
    data.append(byte4)

    return data
}
