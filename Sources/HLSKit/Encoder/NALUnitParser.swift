// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Parses H.264/HEVC NAL units from an Annex B byte stream.
///
/// Identifies frame boundaries by detecting start codes
/// (`0x00000001` or `0x000001`) and NAL unit types. Used by
/// ``FFmpegVideoEncoder`` to extract individual compressed
/// frames from ffmpeg's Annex B output.
///
/// ## H.264 NAL Types
/// - IDR slice: type 5 (keyframe)
/// - Non-IDR slice: type 1 (P/B-frame)
/// - SPS: type 7, PPS: type 8
///
/// ## HEVC NAL Types
/// - IDR_W_RADL: 19, IDR_N_LP: 20, CRA: 21
/// - VPS: 32, SPS: 33, PPS: 34
struct NALUnitParser: Sendable {

    /// Parse access units from an Annex B byte stream.
    ///
    /// Groups NAL units into access units (frames) based on
    /// start codes and NAL unit type boundaries.
    ///
    /// - Parameters:
    ///   - data: Annex B byte stream data.
    ///   - codec: Video codec for NAL type interpretation.
    /// - Returns: Parsed access units and total bytes consumed.
    static func parseAccessUnits(
        from data: Data, codec: VideoCodec
    ) -> ParseResult {
        let positions = findStartCodes(in: data)
        guard positions.count >= 2 else {
            return ParseResult(accessUnits: [], bytesConsumed: 0)
        }

        let nalUnits = extractNALUnits(
            from: data, positions: positions, codec: codec
        )
        return groupAccessUnits(nalUnits: nalUnits, codec: codec)
    }
}

// MARK: - Types

extension NALUnitParser {

    /// Result of parsing an Annex B byte stream.
    struct ParseResult: Sendable {
        /// Complete access units found in the data.
        let accessUnits: [AccessUnit]
        /// Number of bytes consumed from the input.
        let bytesConsumed: Int
    }
}

/// A complete video access unit (one frame's worth of NAL units).
struct AccessUnit: Sendable {
    /// Raw data including start codes.
    let data: Data
    /// Whether this is a keyframe (IDR for H.264, IDR/CRA for HEVC).
    let isKeyframe: Bool
    /// NAL unit types found in this access unit.
    let nalTypes: [UInt8]
}

// MARK: - Start Code Detection

extension NALUnitParser {

    /// Find positions of Annex B start codes in the data.
    ///
    /// Detects both 3-byte (`0x000001`) and 4-byte
    /// (`0x00000001`) start codes.
    static func findStartCodes(in data: Data) -> [Int] {
        var positions: [Int] = []
        guard data.count >= 3 else { return positions }

        data.withUnsafeBytes { ptr in
            let bytes = ptr.bindMemory(to: UInt8.self)
            var i = 0
            while i + 2 < bytes.count {
                if bytes[i] == 0 && bytes[i + 1] == 0 {
                    if bytes[i + 2] == 1 {
                        positions.append(i)
                        i += 3
                    } else if i + 3 < bytes.count
                        && bytes[i + 2] == 0 && bytes[i + 3] == 1
                    {
                        positions.append(i)
                        i += 4
                    } else {
                        i += 1
                    }
                } else {
                    i += 1
                }
            }
        }
        return positions
    }

    /// Size of the start code at the given position.
    static func startCodeSize(
        in data: Data, at position: Int
    ) -> Int {
        guard position + 3 < data.count else { return 3 }
        return data.withUnsafeBytes { ptr in
            let bytes = ptr.bindMemory(to: UInt8.self)
            if bytes[position + 2] == 0
                && bytes[position + 3] == 1
            {
                return 4
            }
            return 3
        }
    }
}

// MARK: - NAL Unit Extraction

extension NALUnitParser {

    private struct NALUnit {
        let data: Data
        let type: UInt8
        let endOffset: Int
    }

    /// Extract complete NAL units between consecutive start codes.
    private static func extractNALUnits(
        from data: Data,
        positions: [Int],
        codec: VideoCodec
    ) -> [NALUnit] {
        var units: [NALUnit] = []
        for i in 0..<(positions.count - 1) {
            let scSize = startCodeSize(
                in: data, at: positions[i]
            )
            let headerByte = data[positions[i] + scSize]
            let nalType = Self.nalType(
                byte: headerByte, codec: codec
            )
            let nalData = Data(
                data[positions[i]..<positions[i + 1]]
            )
            units.append(
                NALUnit(
                    data: nalData,
                    type: nalType,
                    endOffset: positions[i + 1]
                ))
        }
        return units
    }
}

// MARK: - Access Unit Grouping

extension NALUnitParser {

    /// Group NAL units into access units.
    ///
    /// Each access unit contains optional non-VCL NALs (SPS, PPS)
    /// followed by exactly one VCL NAL (slice).
    private static func groupAccessUnits(
        nalUnits: [NALUnit], codec: VideoCodec
    ) -> ParseResult {
        var accessUnits: [AccessUnit] = []
        var currentNals: [NALUnit] = []
        var bytesConsumed = 0

        for nal in nalUnits {
            let isVCL = Self.isVCL(type: nal.type, codec: codec)

            if isVCL {
                currentNals.append(nal)
                let auData = currentNals.reduce(into: Data()) {
                    $0.append($1.data)
                }
                let types = currentNals.map(\.type)
                let keyframe = types.contains {
                    Self.isKeyframe(type: $0, codec: codec)
                }
                accessUnits.append(
                    AccessUnit(
                        data: auData,
                        isKeyframe: keyframe,
                        nalTypes: types
                    ))
                bytesConsumed = nal.endOffset
                currentNals = []
            } else {
                currentNals.append(nal)
            }
        }

        return ParseResult(
            accessUnits: accessUnits,
            bytesConsumed: bytesConsumed
        )
    }
}

// MARK: - NAL Type Helpers

extension NALUnitParser {

    /// Extract NAL unit type from the first byte after start code.
    static func nalType(byte: UInt8, codec: VideoCodec) -> UInt8 {
        switch codec {
        case .h264:
            return byte & 0x1F
        case .h265:
            return (byte >> 1) & 0x3F
        case .av1, .vp9:
            return byte
        }
    }

    /// Whether the NAL type is a VCL (Video Coding Layer) NAL.
    static func isVCL(type: UInt8, codec: VideoCodec) -> Bool {
        switch codec {
        case .h264:
            return type >= 1 && type <= 5
        case .h265:
            return type <= 31
        case .av1, .vp9:
            return false
        }
    }

    /// Whether the NAL type indicates a keyframe.
    static func isKeyframe(
        type: UInt8, codec: VideoCodec
    ) -> Bool {
        switch codec {
        case .h264:
            return type == 5
        case .h265:
            return type == 19 || type == 20 || type == 21
        case .av1, .vp9:
            return false
        }
    }
}
