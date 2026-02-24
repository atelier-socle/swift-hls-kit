// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("ADTSParser", .timeLimit(.minutes(1)))
struct ADTSParserTests {

    let parser = ADTSParser()

    // MARK: - Helpers

    /// Builds a valid ADTS header (7 bytes, no CRC).
    ///
    /// - Parameters:
    ///   - profile: AAC profile (0=Main, 1=LC, 2=SSR, 3=LTP).
    ///   - sampleRateIndex: Sample rate frequency index.
    ///   - channelConfig: Channel configuration.
    ///   - payloadSize: Size of the AAC payload following the header.
    /// - Returns: 7-byte ADTS header.
    private func buildADTSHeader(
        profile: UInt8 = 1,
        sampleRateIndex: UInt8 = 4,
        channelConfig: UInt8 = 2,
        payloadSize: Int = 100
    ) -> Data {
        let frameLength = payloadSize + 7
        var header = Data(capacity: 7)

        // Byte 0: sync word high
        header.append(0xFF)
        // Byte 1: sync low (0xF) + ID=0 + layer=00 + protection_absent=1
        header.append(0xF1)
        // Byte 2: profile(2) + freq_index(4) + private(0) + channel_high(1)
        let byte2 =
            ((profile & 0x03) << 6)
            | ((sampleRateIndex & 0x0F) << 2)
            | ((channelConfig >> 2) & 0x01)
        header.append(byte2)
        // Byte 3: channel_low(2) + original(0) + home(0) + copyright(0)
        //        + copyright_start(0) + frame_length_high(2)
        let byte3 =
            ((channelConfig & 0x03) << 6)
            | UInt8((frameLength >> 11) & 0x03)
        header.append(byte3)
        // Byte 4: frame_length mid(8)
        header.append(UInt8((frameLength >> 3) & 0xFF))
        // Byte 5: frame_length low(3) + buffer_fullness high(5)
        let byte5 = UInt8((frameLength & 0x07) << 5) | 0x1F
        header.append(byte5)
        // Byte 6: buffer_fullness low(6) + num_raw_data_blocks(2) = 0
        header.append(0xFC)

        return header
    }

    /// Builds a complete ADTS frame (header + payload).
    private func buildADTSFrame(
        profile: UInt8 = 1,
        sampleRateIndex: UInt8 = 4,
        channelConfig: UInt8 = 2,
        payloadSize: Int = 100
    ) -> Data {
        var frame = buildADTSHeader(
            profile: profile,
            sampleRateIndex: sampleRateIndex,
            channelConfig: channelConfig,
            payloadSize: payloadSize
        )
        frame.append(Data(repeating: 0xAA, count: payloadSize))
        return frame
    }

    /// Builds an ADTS header with CRC (9 bytes).
    private func buildADTSHeaderWithCRC(
        profile: UInt8 = 1,
        sampleRateIndex: UInt8 = 4,
        channelConfig: UInt8 = 2,
        payloadSize: Int = 100
    ) -> Data {
        let frameLength = payloadSize + 9
        var header = Data(capacity: 9)

        header.append(0xFF)
        // protection_absent = 0 (CRC present)
        header.append(0xF0)
        let byte2 =
            ((profile & 0x03) << 6)
            | ((sampleRateIndex & 0x0F) << 2)
            | ((channelConfig >> 2) & 0x01)
        header.append(byte2)
        let byte3 =
            ((channelConfig & 0x03) << 6)
            | UInt8((frameLength >> 11) & 0x03)
        header.append(byte3)
        header.append(UInt8((frameLength >> 3) & 0xFF))
        let byte5 = UInt8((frameLength & 0x07) << 5) | 0x1F
        header.append(byte5)
        header.append(0xFC)
        // 2 bytes CRC
        header.append(0x00)
        header.append(0x00)

        return header
    }

    // MARK: - Valid Parsing

    @Test("Parse single valid ADTS frame")
    func parseSingleFrame() {
        let frame = buildADTSFrame()
        let result = parser.parseFrames(from: frame)

        #expect(result.frames.count == 1)
        #expect(result.bytesConsumed == frame.count)

        let parsed = result.frames[0]
        #expect(parsed.profile == 1)
        #expect(parsed.sampleRateIndex == 4)
        #expect(parsed.sampleRate == 44_100)
        #expect(parsed.channelConfig == 2)
        #expect(parsed.payload.count == 100)
        #expect(parsed.headerSize == 7)
        #expect(parsed.frameLength == 107)
    }

    @Test("Parse multiple consecutive ADTS frames")
    func parseMultipleFrames() {
        var data = Data()
        data.append(buildADTSFrame(payloadSize: 50))
        data.append(buildADTSFrame(payloadSize: 75))
        data.append(buildADTSFrame(payloadSize: 120))

        let result = parser.parseFrames(from: data)

        #expect(result.frames.count == 3)
        #expect(result.frames[0].payload.count == 50)
        #expect(result.frames[1].payload.count == 75)
        #expect(result.frames[2].payload.count == 120)
        #expect(result.bytesConsumed == data.count)
    }

    @Test("Parse frame with CRC present (9-byte header)")
    func parseFrameWithCRC() {
        let payloadSize = 80
        var frame = buildADTSHeaderWithCRC(payloadSize: payloadSize)
        frame.append(Data(repeating: 0xBB, count: payloadSize))

        let result = parser.parseFrames(from: frame)

        #expect(result.frames.count == 1)
        #expect(result.frames[0].headerSize == 9)
        #expect(result.frames[0].payload.count == payloadSize)
    }

    // MARK: - Sample Rates

    @Test("Parse frames with various sample rate indices")
    func parseSampleRateIndices() {
        let expectedRates: [(UInt8, Int)] = [
            (0, 96_000),
            (1, 88_200),
            (2, 64_000),
            (3, 48_000),
            (4, 44_100),
            (5, 32_000),
            (6, 24_000),
            (7, 22_050),
            (8, 16_000),
            (9, 12_000),
            (10, 11_025),
            (11, 8_000),
            (12, 7_350)
        ]

        for (index, expectedRate) in expectedRates {
            let frame = buildADTSFrame(sampleRateIndex: index)
            let result = parser.parseFrames(from: frame)

            #expect(result.frames.count == 1)
            #expect(
                result.frames[0].sampleRate == expectedRate,
                "Index \(index): expected \(expectedRate), got \(result.frames[0].sampleRate)"
            )
            #expect(result.frames[0].sampleRateIndex == index)
        }
    }

    // MARK: - Channel Configurations

    @Test("Parse frames with various channel configs")
    func parseChannelConfigs() {
        let channelConfigs: [UInt8] = [1, 2, 3, 6, 7]

        for config in channelConfigs {
            let frame = buildADTSFrame(channelConfig: config)
            let result = parser.parseFrames(from: frame)

            #expect(result.frames.count == 1)
            #expect(
                result.frames[0].channelConfig == config,
                "Expected channel config \(config), got \(result.frames[0].channelConfig)"
            )
        }
    }

    // MARK: - Profiles

    @Test("Parse frames with various AAC profiles")
    func parseProfiles() {
        let profiles: [UInt8] = [0, 1, 2, 3]

        for profile in profiles {
            let frame = buildADTSFrame(profile: profile)
            let result = parser.parseFrames(from: frame)

            #expect(result.frames.count == 1)
            #expect(
                result.frames[0].profile == profile,
                "Expected profile \(profile), got \(result.frames[0].profile)"
            )
        }
    }

    // MARK: - Incomplete Data

    @Test("Incomplete frame: less than 7 bytes")
    func incompleteHeaderTooShort() {
        let data = Data([0xFF, 0xF1, 0x50])
        let result = parser.parseFrames(from: data)

        #expect(result.frames.isEmpty)
        #expect(result.bytesConsumed == 0)
    }

    @Test("Incomplete frame: header present but payload truncated")
    func incompletePayload() {
        // Header says 107 bytes total, but we only provide 50
        let header = buildADTSHeader(payloadSize: 100)
        var data = header
        data.append(Data(repeating: 0xAA, count: 20))  // Only 27 bytes total

        let result = parser.parseFrames(from: data)

        #expect(result.frames.isEmpty)
        #expect(result.bytesConsumed == 0)
    }

    @Test("Partial frame after complete frames")
    func partialFrameAfterComplete() {
        var data = buildADTSFrame(payloadSize: 50)
        // Add incomplete second frame
        data.append(buildADTSHeader(payloadSize: 200))
        // Don't append the full payload

        let result = parser.parseFrames(from: data)

        #expect(result.frames.count == 1)
        #expect(result.frames[0].payload.count == 50)
        #expect(result.bytesConsumed == 57)  // Only first frame consumed
    }

    // MARK: - Invalid Data

    @Test("Invalid sync word: not 0xFFF")
    func invalidSyncWord() {
        var data = Data(repeating: 0x00, count: 20)
        let result = parser.parseFrames(from: data)

        #expect(result.frames.isEmpty)

        // All bytes should be consumed by sync word scanning
        data = Data([0xFF, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        let result2 = parser.parseFrames(from: data)
        #expect(result2.frames.isEmpty)
    }

    @Test("Empty data returns empty result")
    func emptyData() {
        let result = parser.parseFrames(from: Data())

        #expect(result.frames.isEmpty)
        #expect(result.bytesConsumed == 0)
    }

    // MARK: - Bytes Consumed

    @Test("Bytes consumed matches total frame data")
    func bytesConsumedAccuracy() {
        var data = Data()
        let sizes = [50, 100, 150]
        var expectedTotal = 0

        for size in sizes {
            data.append(buildADTSFrame(payloadSize: size))
            expectedTotal += size + 7
        }

        let result = parser.parseFrames(from: data)

        #expect(result.bytesConsumed == expectedTotal)
        #expect(result.frames.count == 3)
    }

    // MARK: - Sample Rate Table

    @Test("Sample rate table has 16 entries")
    func sampleRateTableSize() {
        #expect(ADTSParser.sampleRateTable.count == 16)
    }

    @Test("Sample rate table reserved indices are zero")
    func sampleRateTableReserved() {
        #expect(ADTSParser.sampleRateTable[13] == 0)
        #expect(ADTSParser.sampleRateTable[14] == 0)
        #expect(ADTSParser.sampleRateTable[15] == 0)
    }
}
