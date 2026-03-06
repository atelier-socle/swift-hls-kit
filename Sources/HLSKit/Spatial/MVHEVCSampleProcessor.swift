// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Processes MV-HEVC NAL units for fMP4 packaging.
///
/// Extracts parameter sets (VPS, SPS, PPS) from Annex B byte streams,
/// converts between Annex B and length-prefixed formats, and parses
/// SPS profile information for hvcC box construction.
///
/// ```swift
/// let processor = MVHEVCSampleProcessor()
/// let nalus = processor.extractNALUs(from: annexBData)
/// let params = processor.extractParameterSets(from: nalus)
/// ```
public struct MVHEVCSampleProcessor: Sendable {

    /// Creates a new MV-HEVC sample processor.
    public init() {}

    /// Extracts individual NAL units from an Annex B byte stream.
    ///
    /// Splits on both 4-byte (`0x00000001`) and 3-byte (`0x000001`)
    /// start codes.
    ///
    /// - Parameter data: Annex B formatted byte stream.
    /// - Returns: Array of NAL unit data (without start codes).
    public func extractNALUs(from data: Data) -> [Data] {
        guard !data.isEmpty else { return [] }
        var nalus: [Data] = []
        var offset = data.startIndex
        let end = data.endIndex

        while offset < end {
            guard
                let startCodeRange = findStartCode(
                    in: data, from: offset
                )
            else {
                break
            }
            let naluStart = startCodeRange.upperBound
            let nextStart =
                findStartCode(
                    in: data, from: naluStart
                )?.lowerBound ?? end
            if naluStart < nextStart {
                nalus.append(data[naluStart..<nextStart])
            }
            offset = naluStart
        }
        return nalus
    }

    /// Converts Annex B NAL units to length-prefixed format.
    ///
    /// Each NAL unit is preceded by a 4-byte big-endian length field.
    ///
    /// - Parameter annexBData: Annex B formatted byte stream.
    /// - Returns: Length-prefixed data suitable for fMP4 mdat.
    public func annexBToLengthPrefixed(_ annexBData: Data) -> Data {
        let nalus = extractNALUs(from: annexBData)
        var result = Data()
        for nalu in nalus {
            var lengthBytes = Data(count: 4)
            let length = UInt32(nalu.count)
            lengthBytes[0] = UInt8((length >> 24) & 0xFF)
            lengthBytes[1] = UInt8((length >> 16) & 0xFF)
            lengthBytes[2] = UInt8((length >> 8) & 0xFF)
            lengthBytes[3] = UInt8(length & 0xFF)
            result.append(lengthBytes)
            result.append(nalu)
        }
        return result
    }

    /// Identifies the HEVC NAL unit type from the first byte.
    ///
    /// HEVC NAL unit type is bits 1-6 of the first byte:
    /// `(byte[0] >> 1) & 0x3F`.
    ///
    /// - Parameter nalu: A single NAL unit (without start code).
    /// - Returns: The identified NAL unit type, or nil if invalid.
    public func naluType(_ nalu: Data) -> HEVCNALUType? {
        guard let firstByte = nalu.first else { return nil }
        let typeValue = (firstByte >> 1) & 0x3F
        return HEVCNALUType(rawValue: typeValue)
    }

    /// Extracts VPS, SPS, and PPS parameter sets from NAL units.
    ///
    /// Scans the array for the first VPS (32), SPS (33), and PPS (34)
    /// NAL units and returns them as a structured set.
    ///
    /// - Parameter nalus: Array of NAL units to scan.
    /// - Returns: Parameter sets, or nil if any are missing.
    public func extractParameterSets(
        from nalus: [Data]
    ) -> HEVCParameterSets? {
        var vps: Data?
        var sps: Data?
        var pps: Data?
        for nalu in nalus {
            guard let type = naluType(nalu) else { continue }
            switch type {
            case .vps where vps == nil:
                vps = nalu
            case .sps where sps == nil:
                sps = nalu
            case .pps where pps == nil:
                pps = nalu
            default:
                break
            }
        }
        guard let foundVPS = vps,
            let foundSPS = sps,
            let foundPPS = pps
        else {
            return nil
        }
        return HEVCParameterSets(
            vps: foundVPS,
            sps: foundSPS,
            pps: foundPPS
        )
    }

    /// Parses SPS profile/tier/level information from an SPS NAL unit.
    ///
    /// Reads the profile_tier_level syntax from the SPS RBSP
    /// after the NAL unit header (2 bytes) and sps_video_parameter_set_id
    /// and max_sub_layers fields.
    ///
    /// - Parameter sps: Raw SPS NAL unit data.
    /// - Returns: Parsed profile info, or nil if the SPS is too short.
    public func parseSPSProfile(_ sps: Data) -> SPSProfileInfo? {
        // SPS layout after NAL header (2 bytes):
        // - 4 bits: sps_video_parameter_set_id
        // - 3 bits: sps_max_sub_layers_minus1
        // - 1 bit: sps_temporal_id_nesting_flag
        // Then profile_tier_level:
        // - 2 bits: general_profile_space
        // - 1 bit: general_tier_flag
        // - 5 bits: general_profile_idc
        // - 32 bits: general_profile_compatibility_flags
        // - 48 bits: general_constraint_indicator_flags
        // - 8 bits: general_level_idc
        // Minimum: 2 (NAL header) + 1 (vps_id/sublayers) + 11 (PTL) = 14
        guard sps.count >= 14 else { return nil }
        let bytes = Array(sps)

        // Byte 2: profile_tier_level starts at byte index 2 + 1 = 3
        // Actually: byte 2 has vps_id(4b) + max_sub_layers(3b) + nesting(1b)
        // Byte 3: profile_space(2b) + tier_flag(1b) + profile_idc(5b)
        let ptlByte = bytes[3]
        let profileSpace = UInt8((ptlByte >> 6) & 0x03)
        let tierFlag = ((ptlByte >> 5) & 0x01) != 0
        let profileIDC = UInt8(ptlByte & 0x1F)

        // Bytes 4-7: profile_compatibility_flags (32 bits)
        let compatFlags: UInt32 =
            (UInt32(bytes[4]) << 24)
            | (UInt32(bytes[5]) << 16)
            | (UInt32(bytes[6]) << 8)
            | UInt32(bytes[7])

        // Bytes 8-13: constraint_indicator_flags (48 bits)
        var constraintFlags = Data(count: 6)
        for i in 0..<6 {
            constraintFlags[i] = bytes[8 + i]
        }

        // Byte 14: general_level_idc
        guard sps.count >= 15 else {
            return SPSProfileInfo(
                profileSpace: profileSpace,
                tierFlag: tierFlag,
                profileIDC: profileIDC,
                profileCompatibilityFlags: compatFlags,
                constraintIndicatorFlags: constraintFlags,
                levelIDC: 0,
                chromaFormatIDC: 1,
                bitDepthLuma: 8,
                bitDepthChroma: 8
            )
        }
        let levelIDC = bytes[14]

        // Chroma and bit depth require deeper parsing of exp-golomb
        // coded fields. For packaging purposes, use defaults for
        // Main/Main10 profiles.
        let isMain10 = profileIDC == 2
        let bitDepth: UInt8 = isMain10 ? 10 : 8

        return SPSProfileInfo(
            profileSpace: profileSpace,
            tierFlag: tierFlag,
            profileIDC: profileIDC,
            profileCompatibilityFlags: compatFlags,
            constraintIndicatorFlags: constraintFlags,
            levelIDC: levelIDC,
            chromaFormatIDC: 1,
            bitDepthLuma: bitDepth,
            bitDepthChroma: bitDepth
        )
    }
}

// MARK: - Start Code Detection

extension MVHEVCSampleProcessor {

    private func findStartCode(
        in data: Data, from offset: Data.Index
    ) -> Range<Data.Index>? {
        let end = data.endIndex
        var i = offset
        while i < end - 2 {
            if data[i] == 0x00, data[i + 1] == 0x00 {
                // 4-byte start code
                if i + 3 < end,
                    data[i + 2] == 0x00,
                    data[i + 3] == 0x01
                {
                    return i..<(i + 4)
                }
                // 3-byte start code
                if data[i + 2] == 0x01 {
                    return i..<(i + 3)
                }
            }
            i += 1
        }
        return nil
    }
}

// MARK: - HEVCNALUType

/// HEVC NAL unit types relevant to MV-HEVC packaging.
public enum HEVCNALUType: UInt8, Sendable, Equatable {
    /// Trailing picture, non-reference.
    case trailN = 0
    /// Trailing picture, reference.
    case trailR = 1
    /// IDR picture with RADL.
    case idrWRadl = 19
    /// IDR picture, no leading pictures.
    case idrNLP = 20
    /// Video Parameter Set.
    case vps = 32
    /// Sequence Parameter Set.
    case sps = 33
    /// Picture Parameter Set.
    case pps = 34
    /// Prefix Supplemental Enhancement Information.
    case prefixSEI = 39
    /// Suffix Supplemental Enhancement Information.
    case suffixSEI = 40
}

// MARK: - HEVCParameterSets

/// HEVC parameter sets extracted from a bitstream.
///
/// Contains the VPS, SPS, and PPS NAL units needed to construct
/// an hvcC box in the fMP4 init segment.
public struct HEVCParameterSets: Sendable, Equatable {
    /// Video Parameter Set NAL unit.
    public let vps: Data
    /// Sequence Parameter Set NAL unit.
    public let sps: Data
    /// Picture Parameter Set NAL unit.
    public let pps: Data

    /// Creates HEVC parameter sets.
    ///
    /// - Parameters:
    ///   - vps: Video Parameter Set NAL unit data.
    ///   - sps: Sequence Parameter Set NAL unit data.
    ///   - pps: Picture Parameter Set NAL unit data.
    public init(vps: Data, sps: Data, pps: Data) {
        self.vps = vps
        self.sps = sps
        self.pps = pps
    }
}

// MARK: - SPSProfileInfo

/// Parsed profile/tier/level information from an HEVC SPS.
public struct SPSProfileInfo: Sendable, Equatable {
    /// General profile space (0-3).
    public let profileSpace: UInt8
    /// General tier flag (main=false, high=true).
    public let tierFlag: Bool
    /// General profile IDC (1=Main, 2=Main10, etc.).
    public let profileIDC: UInt8
    /// 32-bit profile compatibility flags.
    public let profileCompatibilityFlags: UInt32
    /// 6-byte general constraint indicator flags.
    public let constraintIndicatorFlags: Data
    /// General level IDC (e.g. 123 = Level 4.1).
    public let levelIDC: UInt8
    /// Chroma format IDC (1 = 4:2:0).
    public let chromaFormatIDC: UInt8
    /// Luma bit depth (8 or 10).
    public let bitDepthLuma: UInt8
    /// Chroma bit depth (8 or 10).
    public let bitDepthChroma: UInt8
}
