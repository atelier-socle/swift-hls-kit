// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Converts H.264/AVC data between MP4 and MPEG-TS formats.
///
/// MP4 stores NAL units with length prefixes.
/// MPEG-TS uses Annex B format with start codes (`0x00000001`).
///
/// - SeeAlso: ITU-T H.264, Annex B
public struct AnnexBConverter: Sendable {

    /// 4-byte Annex B start code.
    static let startCode = Data([0x00, 0x00, 0x00, 0x01])

    /// Creates a new Annex B converter.
    public init() {}

    /// Convert length-prefixed NAL units to Annex B format.
    ///
    /// Replaces 4-byte length prefixes with 4-byte start codes.
    ///
    /// - Parameter data: MP4-format NAL unit data (length-prefixed).
    /// - Returns: Annex B format data (start code-prefixed).
    public func convertToAnnexB(_ data: Data) -> Data {
        var result = Data()
        var offset = data.startIndex

        while offset + 4 <= data.endIndex {
            let length = readUInt32(data, at: offset)
            offset += 4

            let nalEnd = offset + Int(length)
            guard nalEnd <= data.endIndex else { break }

            result.append(Self.startCode)
            result.append(data[offset..<nalEnd])
            offset = nalEnd
        }

        return result
    }

    /// Extract SPS and PPS from avcC box data.
    ///
    /// The avcC box (inside stsd -> avc1) contains the parameter
    /// sets that must be prepended to keyframe access units.
    ///
    /// - Parameter avcCData: Raw avcC box payload.
    /// - Returns: Tuple of (SPS, PPS) in Annex B format.
    /// - Throws: `TransportError.invalidAVCConfig` if data is invalid.
    public func extractParameterSets(
        from avcCData: Data
    ) throws -> (sps: Data, pps: Data) {
        guard avcCData.count >= 7 else {
            throw TransportError.invalidAVCConfig(
                "avcC data too short: \(avcCData.count) bytes"
            )
        }

        let base = avcCData.startIndex

        // configurationVersion should be 1
        guard avcCData[base] == 1 else {
            throw TransportError.invalidAVCConfig(
                "unsupported configuration version: "
                    + "\(avcCData[base])"
            )
        }

        var spsData = Data()
        var ppsData = Data()
        var offset = base + 5

        // Number of SPS (low 5 bits)
        guard offset < avcCData.endIndex else {
            throw TransportError.invalidAVCConfig(
                "truncated avcC: missing SPS count"
            )
        }
        let numSPS = Int(avcCData[offset] & 0x1F)
        offset += 1

        try parseSPSData(
            from: avcCData, count: numSPS,
            into: &spsData, offset: &offset
        )

        // Number of PPS
        guard offset < avcCData.endIndex else {
            throw TransportError.invalidAVCConfig(
                "truncated avcC: missing PPS count"
            )
        }
        let numPPS = Int(avcCData[offset])
        offset += 1

        try parsePPSData(
            from: avcCData, count: numPPS,
            into: &ppsData, offset: &offset
        )

        return (sps: spsData, pps: ppsData)
    }

    /// Build a complete keyframe access unit for MPEG-TS.
    ///
    /// Prepends SPS + PPS (in Annex B format) to the converted
    /// NAL units.
    ///
    /// - Parameters:
    ///   - sampleData: MP4-format sample data (length-prefixed).
    ///   - sps: SPS in Annex B format.
    ///   - pps: PPS in Annex B format.
    /// - Returns: Complete Annex B access unit with parameter sets.
    public func buildKeyframeAccessUnit(
        sampleData: Data,
        sps: Data,
        pps: Data
    ) -> Data {
        var result = Data()
        result.append(sps)
        result.append(pps)
        result.append(convertToAnnexB(sampleData))
        return result
    }
}

// MARK: - Private Helpers

extension AnnexBConverter {

    private func parseSPSData(
        from avcCData: Data,
        count numSPS: Int,
        into spsData: inout Data,
        offset: inout Int
    ) throws {
        for _ in 0..<numSPS {
            guard offset + 2 <= avcCData.endIndex else {
                throw TransportError.invalidAVCConfig(
                    "truncated avcC: missing SPS length"
                )
            }
            let spsLength = Int(readUInt16(avcCData, at: offset))
            offset += 2
            guard offset + spsLength <= avcCData.endIndex else {
                throw TransportError.invalidAVCConfig(
                    "truncated avcC: incomplete SPS data"
                )
            }
            spsData.append(Self.startCode)
            spsData.append(avcCData[offset..<(offset + spsLength)])
            offset += spsLength
        }
    }

    private func parsePPSData(
        from avcCData: Data,
        count numPPS: Int,
        into ppsData: inout Data,
        offset: inout Int
    ) throws {
        for _ in 0..<numPPS {
            guard offset + 2 <= avcCData.endIndex else {
                throw TransportError.invalidAVCConfig(
                    "truncated avcC: missing PPS length"
                )
            }
            let ppsLength = Int(readUInt16(avcCData, at: offset))
            offset += 2
            guard offset + ppsLength <= avcCData.endIndex else {
                throw TransportError.invalidAVCConfig(
                    "truncated avcC: incomplete PPS data"
                )
            }
            ppsData.append(Self.startCode)
            ppsData.append(avcCData[offset..<(offset + ppsLength)])
            offset += ppsLength
        }
    }

    private func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
        let b0 = UInt32(data[offset])
        let b1 = UInt32(data[offset + 1])
        let b2 = UInt32(data[offset + 2])
        let b3 = UInt32(data[offset + 3])
        return (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
    }

    private func readUInt16(_ data: Data, at offset: Int) -> UInt16 {
        let b0 = UInt16(data[offset])
        let b1 = UInt16(data[offset + 1])
        return (b0 << 8) | b1
    }
}
