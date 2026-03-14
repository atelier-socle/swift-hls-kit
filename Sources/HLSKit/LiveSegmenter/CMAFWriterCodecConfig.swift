// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

// MARK: - mp4a Sample Entry + esds

extension CMAFWriter {

    func buildMp4aSampleEntry(
        config: AudioConfig
    ) -> Data {
        var entry = BinaryWriter()
        // Reserved (6 bytes)
        entry.writeZeros(6)
        // Data reference index
        entry.writeUInt16(1)
        // Version + revision + vendor
        entry.writeZeros(8)
        // Channel count
        entry.writeUInt16(UInt16(config.channels))
        // Sample size (16 bits)
        entry.writeUInt16(16)
        // Compression ID + packet size
        entry.writeZeros(4)
        // Sample rate (16.16 fixed point)
        entry.writeUInt32(UInt32(config.sampleRate) << 16)
        // esds box
        entry.writeData(buildEsds(config: config))
        var box = BinaryWriter()
        box.writeBox(type: "mp4a", payload: entry.data)
        return box.data
    }

    private func buildEsds(config: AudioConfig) -> Data {
        let asc = buildAudioSpecificConfig(config: config)
        // DecoderConfigDescriptor
        var decoderConfig = BinaryWriter()
        decoderConfig.writeUInt8(0x40)  // objectTypeIndication: Audio ISO/IEC 14496-3
        // streamType=5 (audio), upstream=0, reserved=1 → (5 << 2) | 1 = 0x15
        decoderConfig.writeUInt8(0x15)
        // bufferSizeDB (3 bytes)
        decoderConfig.writeUInt8(0)
        decoderConfig.writeUInt16(0)
        // maxBitrate
        decoderConfig.writeUInt32(0)
        // avgBitrate
        decoderConfig.writeUInt32(0)
        // DecoderSpecificInfo descriptor
        decoderConfig.writeUInt8(0x05)  // tag
        decoderConfig.writeUInt8(UInt8(asc.count))
        decoderConfig.writeData(asc)

        // ES_Descriptor
        var esDescriptor = BinaryWriter()
        esDescriptor.writeUInt16(0)  // ES_ID
        esDescriptor.writeUInt8(0)  // streamDependenceFlag, etc.
        // DecoderConfigDescriptor
        esDescriptor.writeUInt8(0x04)  // tag
        esDescriptor.writeUInt8(
            UInt8(decoderConfig.count)
        )
        esDescriptor.writeData(decoderConfig.data)
        // SLConfigDescriptor
        esDescriptor.writeUInt8(0x06)  // tag
        esDescriptor.writeUInt8(1)  // length
        esDescriptor.writeUInt8(0x02)  // predefined = MP4

        // Wrap in esds full box
        var esdsPayload = BinaryWriter()
        esdsPayload.writeUInt8(0x03)  // ES_Descriptor tag
        esdsPayload.writeUInt8(
            UInt8(esDescriptor.count)
        )
        esdsPayload.writeData(esDescriptor.data)
        var box = BinaryWriter()
        box.writeFullBox(
            type: "esds", version: 0, flags: 0,
            payload: esdsPayload.data
        )
        return box.data
    }

    /// Build the 2-byte AudioSpecificConfig for AAC.
    ///
    /// Layout:
    /// ```
    /// objectType (5 bits) | sampleRateIndex (4 bits)
    /// | channelConfig (4 bits) | padding (3 bits)
    /// ```
    func buildAudioSpecificConfig(
        config: AudioConfig
    ) -> Data {
        let objectType = aacObjectType(for: config.profile)
        let srIndex = sampleRateIndex(
            for: config.sampleRate
        )
        let channelConfig = UInt8(min(config.channels, 7))

        let byte0 =
            (objectType << 3) | (srIndex >> 1)
        let byte1 =
            ((srIndex & 0x01) << 7)
            | (channelConfig << 3)

        return Data([byte0, byte1])
    }

    private func aacObjectType(
        for profile: AACProfile
    ) -> UInt8 {
        switch profile {
        case .lc: 2
        case .he: 5
        case .heV2: 29
        case .ld: 23
        case .eld: 39
        }
    }

    func sampleRateIndex(for sampleRate: Double) -> UInt8 {
        let table: [Int: UInt8] = [
            96000: 0, 88200: 1, 64000: 2, 48000: 3,
            44100: 4, 32000: 5, 24000: 6, 22050: 7,
            16000: 8, 12000: 9, 11025: 10, 8000: 11,
            7350: 12
        ]
        return table[Int(sampleRate)] ?? 15
    }
}

// MARK: - avc1 Sample Entry + avcC

extension CMAFWriter {

    func buildAvc1SampleEntry(
        config: VideoConfig
    ) -> Data {
        var entry = BinaryWriter()
        // Reserved (6 bytes)
        entry.writeZeros(6)
        // Data reference index
        entry.writeUInt16(1)
        // Pre-defined + reserved
        entry.writeZeros(16)
        // Width
        entry.writeUInt16(UInt16(config.width))
        // Height
        entry.writeUInt16(UInt16(config.height))
        // Horizontal resolution (72 dpi = 0x00480000)
        entry.writeUInt32(0x0048_0000)
        // Vertical resolution
        entry.writeUInt32(0x0048_0000)
        // Reserved
        entry.writeUInt32(0)
        // Frame count
        entry.writeUInt16(1)
        // Compressor name (32 bytes, null-padded)
        entry.writeZeros(32)
        // Depth (24 bit)
        entry.writeUInt16(0x0018)
        // Pre-defined = -1 (ISO 14496-12 §12.1.3: int(16))
        entry.writeInt16(-1)
        // avcC box
        entry.writeData(buildAvcC(config: config))
        var box = BinaryWriter()
        box.writeBox(type: "avc1", payload: entry.data)
        return box.data
    }

    private func buildAvcC(config: VideoConfig) -> Data {
        var payload = BinaryWriter()
        // configurationVersion
        payload.writeUInt8(1)
        // profile_idc (from SPS[1])
        let profile: UInt8 =
            config.sps.count > 1 ? config.sps[1] : 66
        payload.writeUInt8(profile)
        // profile_compatibility (from SPS[2])
        let compat: UInt8 =
            config.sps.count > 2 ? config.sps[2] : 0
        payload.writeUInt8(compat)
        // level_idc (from SPS[3])
        let level: UInt8 =
            config.sps.count > 3 ? config.sps[3] : 30
        payload.writeUInt8(level)
        // lengthSizeMinusOne = 3 → 0xFF (6 reserved bits + 2 bits)
        payload.writeUInt8(0xFF)
        // numSPS = 1 → 0xE1 (3 reserved bits + 5 bits)
        payload.writeUInt8(0xE1)
        // SPS length + data
        payload.writeUInt16(UInt16(config.sps.count))
        payload.writeData(config.sps)
        // numPPS = 1
        payload.writeUInt8(1)
        // PPS length + data
        payload.writeUInt16(UInt16(config.pps.count))
        payload.writeData(config.pps)
        var box = BinaryWriter()
        box.writeBox(type: "avcC", payload: payload.data)
        return box.data
    }
}

// MARK: - hev1 Sample Entry + hvcC (ISO 14496-15 §8.3)

extension CMAFWriter {

    func buildHev1SampleEntry(
        config: VideoConfig
    ) -> Data {
        var entry = BinaryWriter()
        // VisualSampleEntry (ISO 14496-12 §12.1.3)
        // Same 78-byte header as avc1
        entry.writeZeros(6)       // reserved
        entry.writeUInt16(1)      // data_reference_index
        entry.writeZeros(16)      // pre_defined + reserved
        entry.writeUInt16(UInt16(config.width))
        entry.writeUInt16(UInt16(config.height))
        entry.writeUInt32(0x0048_0000)  // 72 dpi horizontal
        entry.writeUInt32(0x0048_0000)  // 72 dpi vertical
        entry.writeUInt32(0)      // reserved
        entry.writeUInt16(1)      // frame_count
        entry.writeZeros(32)      // compressorname
        entry.writeUInt16(0x0018) // depth (24-bit)
        entry.writeInt16(-1)      // pre_defined
        // hvcC box (ISO 14496-15 §8.3.3.1)
        entry.writeData(buildHvcC(config: config))
        var box = BinaryWriter()
        box.writeBox(type: "hev1", payload: entry.data)
        return box.data
    }

    private func buildHvcC(config: VideoConfig) -> Data {
        let sps = config.sps
        let pps = config.pps
        let vps = config.vps ?? Data()
        // Parse profile/tier/level from SPS RBSP
        // HEVC SPS NALU: byte[0-1] = NAL header,
        // byte[2] = (profile_space<<6)|(tier<<5)|profile_idc
        // byte[3..6] = profile_compatibility_flags
        // byte[7..12] = constraint_indicator_flags
        // byte[13] = level_idc
        let spsInfo = parseHEVCSPSHeader(sps)
        var payload = BinaryWriter()
        // configurationVersion
        payload.writeUInt8(1)
        // general_profile_space(2) + tier_flag(1) + profile_idc(5)
        payload.writeUInt8(spsInfo.profileByte)
        // general_profile_compatibility_flags (4 bytes)
        payload.writeData(spsInfo.profileCompatibility)
        // general_constraint_indicator_flags (6 bytes)
        payload.writeData(spsInfo.constraintIndicator)
        // general_level_idc
        payload.writeUInt8(spsInfo.levelIDC)
        // 0xF000 | min_spatial_segmentation_idc (0)
        payload.writeUInt16(0xF000)
        // 0xFC | parallelismType (0)
        payload.writeUInt8(0xFC)
        // 0xFC | chromaFormat (from SPS, default 1 = 4:2:0)
        payload.writeUInt8(0xFC | spsInfo.chromaFormat)
        // 0xF8 | bitDepthLumaMinus8 (default 0 = 8-bit)
        payload.writeUInt8(0xF8 | spsInfo.bitDepthLuma)
        // 0xF8 | bitDepthChromaMinus8 (default 0 = 8-bit)
        payload.writeUInt8(0xF8 | spsInfo.bitDepthChroma)
        // avgFrameRate (0 = unknown)
        payload.writeUInt16(0)
        // constantFrameRate(2) + numTemporalLayers(3)
        // + temporalIdNested(1) + lengthSizeMinusOne(2)
        // = 0b00_001_1_11 = 0x0F (1 layer, nested, 4-byte lengths)
        payload.writeUInt8(0x0F)
        // numOfArrays: VPS + SPS + PPS
        let hasVPS = !vps.isEmpty
        payload.writeUInt8(hasVPS ? 3 : 2)
        // VPS array (NAL type 32 = 0x20)
        if hasVPS {
            writeNALUArray(
                &payload, nalType: 0x20, data: vps
            )
        }
        // SPS array (NAL type 33 = 0x21)
        writeNALUArray(&payload, nalType: 0x21, data: sps)
        // PPS array (NAL type 34 = 0x22)
        writeNALUArray(&payload, nalType: 0x22, data: pps)
        var box = BinaryWriter()
        box.writeBox(type: "hvcC", payload: payload.data)
        return box.data
    }

    private func writeNALUArray(
        _ writer: inout BinaryWriter,
        nalType: UInt8,
        data: Data
    ) {
        // array_completeness=0(1b) + reserved=0(1b)
        // + NAL_unit_type(6b)
        writer.writeUInt8(nalType & 0x3F)
        // numNalus = 1
        writer.writeUInt16(1)
        // nalUnitLength + data
        writer.writeUInt16(UInt16(data.count))
        writer.writeData(data)
    }
}

// MARK: - HEVC SPS Header Parsing

extension CMAFWriter {

    struct HEVCSPSInfo: Sendable {
        let profileByte: UInt8
        let profileCompatibility: Data
        let constraintIndicator: Data
        let levelIDC: UInt8
        let chromaFormat: UInt8
        let bitDepthLuma: UInt8
        let bitDepthChroma: UInt8
    }

    /// Parse profile/tier/level from HEVC SPS NALU bytes.
    ///
    /// HEVC SPS structure (after 2-byte NAL header):
    /// - byte[0]: sps_video_parameter_set_id(4) + max_sub_layers(3) + temporal_id_nesting(1)
    /// - byte[1]: profile_space(2) + tier_flag(1) + profile_idc(5)
    /// - byte[2..5]: profile_compatibility_flags (32 bits)
    /// - byte[6..11]: constraint_indicator_flags (48 bits)
    /// - byte[12]: general_level_idc
    func parseHEVCSPSHeader(
        _ sps: Data
    ) -> HEVCSPSInfo {
        // Minimum: 2 NAL header + 13 PTL bytes = 15
        guard sps.count >= 15 else {
            return defaultHEVCSPSInfo()
        }
        let base = sps.startIndex + 2  // skip NAL header
        let profileByte = sps[base + 1]
        let profileCompat = sps.subdata(
            in: (base + 2)..<(base + 6)
        )
        let constraintInd = sps.subdata(
            in: (base + 6)..<(base + 12)
        )
        let levelIDC = sps[base + 12]
        return HEVCSPSInfo(
            profileByte: profileByte,
            profileCompatibility: profileCompat,
            constraintIndicator: constraintInd,
            levelIDC: levelIDC,
            chromaFormat: 1,    // 4:2:0 default
            bitDepthLuma: 0,    // 8-bit default
            bitDepthChroma: 0   // 8-bit default
        )
    }

    private func defaultHEVCSPSInfo() -> HEVCSPSInfo {
        HEVCSPSInfo(
            profileByte: 0x01,  // Main profile
            profileCompatibility: Data(
                repeating: 0, count: 4
            ),
            constraintIndicator: Data(
                repeating: 0, count: 6
            ),
            levelIDC: 93,  // Level 3.1
            chromaFormat: 1,
            bitDepthLuma: 0,
            bitDepthChroma: 0
        )
    }
}
