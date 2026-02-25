// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("CMAFWriter", .timeLimit(.minutes(1)))
struct CMAFWriterTests {

    let writer = CMAFWriter()

    // MARK: - Helpers

    private func readBoxes(
        from data: Data
    ) throws -> [MP4Box] {
        try MP4BoxReader().readBoxes(from: data)
    }

    private func findBox(
        _ type: String, in boxes: [MP4Box]
    ) -> MP4Box? {
        boxes.first { $0.type == type }
    }

    /// Check if a FourCC string appears in binary data.
    private func containsFourCC(
        _ fourCC: String, in data: Data
    ) -> Bool {
        let pattern = Data(fourCC.utf8)
        guard pattern.count == 4, data.count >= 4 else {
            return false
        }
        let searchRange = data.startIndex...(data.endIndex - 4)
        return searchRange.contains(where: { data[$0..<($0 + 4)] == pattern })
    }

    // MARK: - Audio Init Segment

    @Test("Audio init segment contains ftyp and moov")
    func audioInitSegmentStructure() throws {
        let config = CMAFWriter.AudioConfig(
            sampleRate: 48000, channels: 2
        )
        let data = writer.generateAudioInitSegment(
            config: config
        )
        let boxes = try readBoxes(from: data)

        #expect(findBox("ftyp", in: boxes) != nil)
        #expect(findBox("moov", in: boxes) != nil)
    }

    @Test("Audio init segment ftyp has cmfc brand")
    func audioInitFtypBrand() throws {
        let config = CMAFWriter.AudioConfig(
            sampleRate: 48000, channels: 2
        )
        let data = writer.generateAudioInitSegment(
            config: config
        )
        let boxes = try readBoxes(from: data)
        let ftyp = try #require(findBox("ftyp", in: boxes))
        let payload = try #require(ftyp.payload)

        // Major brand is first 4 bytes
        let brand = String(
            data: payload.prefix(4),
            encoding: .ascii
        )
        #expect(brand == "cmfc")
    }

    @Test("Audio init segment moov has trak and mvex")
    func audioInitMoovChildren() throws {
        let config = CMAFWriter.AudioConfig(
            sampleRate: 48000, channels: 2
        )
        let data = writer.generateAudioInitSegment(
            config: config
        )
        let boxes = try readBoxes(from: data)
        let moov = try #require(findBox("moov", in: boxes))

        #expect(moov.findChild("mvhd") != nil)
        #expect(moov.findChild("trak") != nil)
        #expect(moov.findChild("mvex") != nil)
    }

    @Test("Audio init segment trak has stsd with mp4a")
    func audioInitTrakStsd() throws {
        let config = CMAFWriter.AudioConfig(
            sampleRate: 48000, channels: 2
        )
        let data = writer.generateAudioInitSegment(
            config: config
        )
        let boxes = try readBoxes(from: data)
        let moov = try #require(findBox("moov", in: boxes))
        let trak = try #require(moov.findChild("trak"))
        let mdia = try #require(trak.findChild("mdia"))
        let minf = try #require(mdia.findChild("minf"))
        let stbl = try #require(minf.findChild("stbl"))
        let stsd = try #require(stbl.findChild("stsd"))

        // stsd payload should contain mp4a box type
        let payload = try #require(stsd.payload)
        #expect(containsFourCC("mp4a", in: payload))
    }

    @Test("Audio init segment has esds inside mp4a")
    func audioInitEsds() throws {
        let config = CMAFWriter.AudioConfig(
            sampleRate: 48000, channels: 2, profile: .lc
        )
        let data = writer.generateAudioInitSegment(
            config: config
        )
        let boxes = try readBoxes(from: data)
        let moov = try #require(findBox("moov", in: boxes))
        let stsd = try #require(
            moov.findByPath("trak/mdia/minf/stbl/stsd")
        )
        let payload = try #require(stsd.payload)
        #expect(containsFourCC("esds", in: payload))
    }

    @Test("Audio init segment has empty sample tables")
    func audioInitEmptySampleTables() throws {
        let config = CMAFWriter.AudioConfig(
            sampleRate: 48000, channels: 2
        )
        let data = writer.generateAudioInitSegment(
            config: config
        )
        let boxes = try readBoxes(from: data)
        let moov = try #require(findBox("moov", in: boxes))
        let stbl = try #require(
            moov.findByPath("trak/mdia/minf/stbl")
        )

        #expect(stbl.findChild("stts") != nil)
        #expect(stbl.findChild("stsc") != nil)
        #expect(stbl.findChild("stsz") != nil)
        #expect(stbl.findChild("stco") != nil)
    }

    @Test("Audio init segment mvex contains trex")
    func audioInitMvex() throws {
        let config = CMAFWriter.AudioConfig(
            sampleRate: 48000, channels: 2
        )
        let data = writer.generateAudioInitSegment(
            config: config
        )
        let boxes = try readBoxes(from: data)
        let moov = try #require(findBox("moov", in: boxes))
        let mvex = try #require(moov.findChild("mvex"))

        #expect(mvex.findChild("trex") != nil)
    }

    @Test("AudioSpecificConfig for LC 48kHz stereo")
    func audioSpecificConfigLC48k() {
        let config = CMAFWriter.AudioConfig(
            sampleRate: 48000, channels: 2, profile: .lc
        )
        let asc = writer.buildAudioSpecificConfig(
            config: config
        )
        #expect(asc.count == 2)
        // objectType=2, srIndex=3(48k), channels=2
        // byte0 = (2 << 3) | (3 >> 1) = 16 | 1 = 0x11
        // byte1 = ((3 & 1) << 7) | (2 << 3) = 128 | 16 = 0x90
        #expect(asc[0] == 0x11)
        #expect(asc[1] == 0x90)
    }

    @Test("AudioSpecificConfig for LC 44100Hz stereo")
    func audioSpecificConfigLC44100() {
        let config = CMAFWriter.AudioConfig(
            sampleRate: 44100, channels: 2, profile: .lc
        )
        let asc = writer.buildAudioSpecificConfig(
            config: config
        )
        #expect(asc.count == 2)
        // objectType=2, srIndex=4(44100), channels=2
        // byte0 = (2 << 3) | (4 >> 1) = 16 | 2 = 0x12
        // byte1 = ((4 & 1) << 7) | (2 << 3) = 0 | 16 = 0x10
        #expect(asc[0] == 0x12)
        #expect(asc[1] == 0x10)
    }

    @Test("AudioSpecificConfig for HE 48kHz stereo")
    func audioSpecificConfigHE48k() {
        let config = CMAFWriter.AudioConfig(
            sampleRate: 48000, channels: 2, profile: .he
        )
        let asc = writer.buildAudioSpecificConfig(
            config: config
        )
        #expect(asc.count == 2)
        // objectType=5, srIndex=3(48k), channels=2
        // byte0 = (5 << 3) | (3 >> 1) = 40 | 1 = 0x29
        // byte1 = ((3 & 1) << 7) | (2 << 3) = 128 | 16 = 0x90
        #expect(asc[0] == 0x29)
        #expect(asc[1] == 0x90)
    }

    @Test("AudioSpecificConfig for LC 48kHz mono")
    func audioSpecificConfigMono() {
        let config = CMAFWriter.AudioConfig(
            sampleRate: 48000, channels: 1, profile: .lc
        )
        let asc = writer.buildAudioSpecificConfig(
            config: config
        )
        // objectType=2, srIndex=3, channels=1
        // byte0 = (2 << 3) | (3 >> 1) = 0x11
        // byte1 = ((3 & 1) << 7) | (1 << 3) = 128 | 8 = 0x88
        #expect(asc[0] == 0x11)
        #expect(asc[1] == 0x88)
    }

    @Test("Sample rate index mapping")
    func sampleRateIndexMapping() {
        #expect(writer.sampleRateIndex(for: 96000) == 0)
        #expect(writer.sampleRateIndex(for: 88200) == 1)
        #expect(writer.sampleRateIndex(for: 64000) == 2)
        #expect(writer.sampleRateIndex(for: 48000) == 3)
        #expect(writer.sampleRateIndex(for: 44100) == 4)
        #expect(writer.sampleRateIndex(for: 32000) == 5)
        #expect(writer.sampleRateIndex(for: 24000) == 6)
        #expect(writer.sampleRateIndex(for: 22050) == 7)
        #expect(writer.sampleRateIndex(for: 16000) == 8)
        #expect(writer.sampleRateIndex(for: 12000) == 9)
        #expect(writer.sampleRateIndex(for: 11025) == 10)
        #expect(writer.sampleRateIndex(for: 8000) == 11)
        #expect(writer.sampleRateIndex(for: 7350) == 12)
        #expect(writer.sampleRateIndex(for: 99999) == 15)
    }

    // MARK: - AudioConfig

    @Test("AudioConfig timescale from sample rate")
    func audioConfigTimescale() {
        let config = CMAFWriter.AudioConfig(
            sampleRate: 44100, channels: 2
        )
        #expect(config.timescale == 44100)
    }

    @Test("AudioConfig default profile is LC")
    func audioConfigDefaultProfile() {
        let config = CMAFWriter.AudioConfig(
            sampleRate: 48000, channels: 2
        )
        #expect(config.profile == .lc)
    }

    @Test("AudioConfig equatable")
    func audioConfigEquatable() {
        let config1 = CMAFWriter.AudioConfig(
            sampleRate: 48000, channels: 2, profile: .lc
        )
        let config2 = CMAFWriter.AudioConfig(
            sampleRate: 48000, channels: 2, profile: .lc
        )
        #expect(config1 == config2)
    }

    // MARK: - Round-Trip Validation

    @Test("Audio init segment round-trips through MP4BoxReader")
    func audioInitRoundTrip() throws {
        let config = CMAFWriter.AudioConfig(
            sampleRate: 48000, channels: 2, profile: .lc
        )
        let data = writer.generateAudioInitSegment(
            config: config
        )
        let boxes = try readBoxes(from: data)

        #expect(boxes.count == 2)
        #expect(boxes[0].type == "ftyp")
        #expect(boxes[1].type == "moov")
    }

    // MARK: - Test Helpers

    private func makeAudioFrames(
        count: Int
    ) -> [EncodedFrame] {
        let frameDuration = 1024.0 / 48000.0
        return (0..<count).map { i in
            EncodedFrame(
                data: Data(repeating: 0xAA, count: 256),
                timestamp: MediaTimestamp(
                    seconds: Double(i) * frameDuration
                ),
                duration: MediaTimestamp(
                    seconds: frameDuration
                ),
                isKeyframe: true,
                codec: .aac
            )
        }
    }
}
