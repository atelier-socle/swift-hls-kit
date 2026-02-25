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
        // Pre-defined
        entry.writeInt32(-1)
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
