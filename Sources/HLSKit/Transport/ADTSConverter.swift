// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Generates ADTS headers for raw AAC frames.
///
/// MP4 stores raw AAC frames without headers. MPEG-TS requires
/// ADTS (Audio Data Transport Stream) headers prepended to each
/// frame.
///
/// - SeeAlso: ISO 14496-3, Section 1.A.2.2
public struct ADTSConverter: Sendable {

    /// AAC audio configuration extracted from MP4's
    /// AudioSpecificConfig.
    public struct AACConfig: Sendable, Hashable {
        /// AAC profile (1 = AAC-LC, 2 = HE-AAC, etc.)
        public let profile: UInt8
        /// Sample rate index (3 = 48kHz, 4 = 44.1kHz, etc.)
        public let sampleRateIndex: UInt8
        /// Channel configuration (1 = mono, 2 = stereo, etc.)
        public let channelConfig: UInt8

        /// Creates an AAC configuration.
        ///
        /// - Parameters:
        ///   - profile: AAC object type / profile.
        ///   - sampleRateIndex: Sample rate frequency index.
        ///   - channelConfig: Channel configuration.
        public init(
            profile: UInt8,
            sampleRateIndex: UInt8,
            channelConfig: UInt8
        ) {
            self.profile = profile
            self.sampleRateIndex = sampleRateIndex
            self.channelConfig = channelConfig
        }
    }

    /// Creates a new ADTS converter.
    public init() {}

    /// Extract AAC configuration from AudioSpecificConfig.
    ///
    /// AudioSpecificConfig is typically 2 bytes:
    /// ```
    /// bits [4:0]  = audioObjectType
    /// bits [8:5]  = samplingFrequencyIndex
    /// bits [12:9] = channelConfiguration
    /// ```
    ///
    /// - Parameter audioSpecificConfig: Raw AudioSpecificConfig
    ///   bytes (typically 2 bytes).
    /// - Returns: Parsed AAC configuration.
    /// - Throws: `TransportError.invalidAudioConfig` if invalid.
    public func extractConfig(
        from audioSpecificConfig: Data
    ) throws -> AACConfig {
        guard audioSpecificConfig.count >= 2 else {
            throw TransportError.invalidAudioConfig(
                "AudioSpecificConfig too short: "
                    + "\(audioSpecificConfig.count) bytes"
            )
        }

        let base = audioSpecificConfig.startIndex
        let byte0 = audioSpecificConfig[base]
        let byte1 = audioSpecificConfig[base + 1]

        // audioObjectType: 5 bits (byte0[7:3])
        let objectType = (byte0 >> 3) & 0x1F

        // samplingFrequencyIndex: 4 bits (byte0[2:0] + byte1[7])
        let freqIndex =
            ((byte0 & 0x07) << 1)
            | ((byte1 >> 7) & 0x01)

        // channelConfiguration: 4 bits (byte1[6:3])
        let channelConfig = (byte1 >> 3) & 0x0F

        // ADTS profile = objectType - 1
        let profile = objectType > 0 ? objectType - 1 : 0

        return AACConfig(
            profile: profile,
            sampleRateIndex: freqIndex,
            channelConfig: channelConfig
        )
    }

    /// Extract AudioSpecificConfig from esds box data.
    ///
    /// Navigates the esds descriptor hierarchy to find the
    /// DecoderSpecificInfo descriptor containing AudioSpecificConfig.
    ///
    /// - Parameter esdsData: Raw esds box payload (after
    ///   version+flags).
    /// - Returns: AudioSpecificConfig bytes.
    /// - Throws: `TransportError.invalidAudioConfig` if invalid.
    public func extractAudioSpecificConfig(
        from esdsData: Data
    ) throws -> Data {
        guard esdsData.count >= 2 else {
            throw TransportError.invalidAudioConfig(
                "esds data too short"
            )
        }

        var offset = esdsData.startIndex

        // Skip ES_Descriptor tag (0x03)
        offset = try skipDescriptorTag(
            esdsData, offset: offset, expectedTag: 0x03
        )

        // Skip ES_ID (2) + stream priority (1)
        guard offset + 3 <= esdsData.endIndex else {
            throw TransportError.invalidAudioConfig(
                "truncated ES_Descriptor"
            )
        }
        offset += 3

        // DecoderConfigDescriptor tag (0x04)
        offset = try skipDescriptorTag(
            esdsData, offset: offset, expectedTag: 0x04
        )

        // Skip objectTypeIndication(1) + streamType(1)
        // + bufferSizeDB(3) + maxBitrate(4) + avgBitrate(4)
        guard offset + 13 <= esdsData.endIndex else {
            throw TransportError.invalidAudioConfig(
                "truncated DecoderConfigDescriptor"
            )
        }
        offset += 13

        // DecoderSpecificInfo tag (0x05)
        offset = try skipDescriptorTag(
            esdsData, offset: offset, expectedTag: 0x05
        )

        // Read the AudioSpecificConfig bytes
        guard offset + 2 <= esdsData.endIndex else {
            throw TransportError.invalidAudioConfig(
                "truncated AudioSpecificConfig"
            )
        }

        // The remaining data (at least 2 bytes) is the config
        let configLength = min(
            esdsData.endIndex - offset,
            esdsData.endIndex - offset
        )
        return Data(esdsData[offset..<(offset + configLength)])
    }

    /// Generate an ADTS header for a raw AAC frame.
    ///
    /// Produces a 7-byte ADTS header (no CRC protection).
    ///
    /// - Parameters:
    ///   - frameSize: Size of the raw AAC frame in bytes.
    ///   - config: AAC configuration.
    /// - Returns: 7-byte ADTS header.
    public func generateADTSHeader(
        frameSize: Int,
        config: AACConfig
    ) -> Data {
        let adtsLength = frameSize + 7
        var header = Data(capacity: 7)

        // Byte 0: sync word high (0xFF)
        header.append(0xFF)

        // Byte 1: sync word low(4) + ID(0=MPEG4) + layer(00)
        //        + protection_absent(1=no CRC)
        header.append(0xF1)

        // Byte 2: profile(2) + freq_index(4) + private(0)
        //        + channel_config high(1)
        let byte2 =
            ((config.profile & 0x03) << 6)
            | ((config.sampleRateIndex & 0x0F) << 2)
            | ((config.channelConfig >> 2) & 0x01)
        header.append(byte2)

        // Byte 3: channel_config low(2) + original(0) + home(0)
        //        + copyright_id(0) + copyright_start(0)
        //        + frame_length high(2)
        let byte3 =
            ((config.channelConfig & 0x03) << 6)
            | UInt8((adtsLength >> 11) & 0x03)
        header.append(byte3)

        // Byte 4: frame_length mid(8)
        header.append(UInt8((adtsLength >> 3) & 0xFF))

        // Byte 5: frame_length low(3) + buffer_fullness high(5)
        // buffer_fullness = 0x7FF (variable bitrate)
        let byte5 = UInt8((adtsLength & 0x07) << 5) | 0x1F
        header.append(byte5)

        // Byte 6: buffer_fullness low(6)
        //        + num_raw_data_blocks(2) = 0
        header.append(0xFC)

        return header
    }

    /// Wrap a raw AAC frame with an ADTS header.
    ///
    /// - Parameters:
    ///   - frame: Raw AAC frame data.
    ///   - config: AAC configuration.
    /// - Returns: ADTS header + raw frame.
    public func wrapWithADTS(
        frame: Data,
        config: AACConfig
    ) -> Data {
        var result = generateADTSHeader(
            frameSize: frame.count, config: config
        )
        result.append(frame)
        return result
    }
}

// MARK: - Private Helpers

extension ADTSConverter {

    private func skipDescriptorTag(
        _ data: Data,
        offset: Int,
        expectedTag: UInt8
    ) throws -> Int {
        guard offset < data.endIndex else {
            throw TransportError.invalidAudioConfig(
                "unexpected end of esds data"
            )
        }

        let tag = data[offset]
        guard tag == expectedTag else {
            throw TransportError.invalidAudioConfig(
                "expected descriptor tag 0x"
                    + String(expectedTag, radix: 16)
                    + " but found 0x"
                    + String(tag, radix: 16)
            )
        }

        var pos = offset + 1

        // Read variable-length size (up to 4 bytes of 0x80+ prefix)
        while pos < data.endIndex, data[pos] & 0x80 != 0 {
            pos += 1
        }
        // Skip the final size byte
        guard pos < data.endIndex else {
            throw TransportError.invalidAudioConfig(
                "truncated descriptor length"
            )
        }
        pos += 1

        return pos
    }
}
