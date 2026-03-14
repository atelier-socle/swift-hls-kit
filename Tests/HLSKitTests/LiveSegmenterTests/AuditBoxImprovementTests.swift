// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - O4: writeFullBox for stsd

@Suite(
    "O4 — stsd uses writeFullBox",
    .timeLimit(.minutes(1))
)
struct StsdFullBoxTests {

    let writer = CMAFWriter()

    private func readBoxes(
        from data: Data
    ) throws -> [MP4Box] {
        try MP4BoxReader().readBoxes(from: data)
    }

    @Test("Audio init segment stsd is valid fullbox")
    func audioStsdFullBox() throws {
        let config = CMAFWriter.AudioConfig(
            sampleRate: 48000, channels: 2
        )
        let data = writer.generateAudioInitSegment(
            config: config
        )
        let boxes = try readBoxes(from: data)
        let moov = try #require(
            boxes.first { $0.type == "moov" }
        )
        let trak = try #require(moov.findChild("trak"))
        let mdia = try #require(trak.findChild("mdia"))
        let minf = try #require(mdia.findChild("minf"))
        let stbl = try #require(minf.findChild("stbl"))
        let stsd = try #require(stbl.findChild("stsd"))
        let payload = try #require(stsd.payload)
        let version = payload[payload.startIndex]
        #expect(version == 0)
        let flagsHigh = payload[payload.startIndex + 1]
        let flagsMid = payload[payload.startIndex + 2]
        let flagsLow = payload[payload.startIndex + 3]
        #expect(flagsHigh == 0)
        #expect(flagsMid == 0)
        #expect(flagsLow == 0)
    }

    @Test("Video init segment stsd is valid fullbox")
    func videoStsdFullBox() throws {
        let sps = Data([
            0x67, 0x42, 0xC0, 0x1E, 0xD9, 0x00, 0xA0,
            0x47, 0xFE, 0xC8
        ])
        let pps = Data([0x68, 0xCE, 0x38, 0x80])
        let config = CMAFWriter.VideoConfig(
            codec: .h264,
            width: 1920, height: 1080,
            sps: sps, pps: pps
        )
        let data = writer.generateVideoInitSegment(
            config: config
        )
        let boxes = try readBoxes(from: data)
        let moov = try #require(
            boxes.first { $0.type == "moov" }
        )
        let trak = try #require(moov.findChild("trak"))
        let mdia = try #require(trak.findChild("mdia"))
        let minf = try #require(mdia.findChild("minf"))
        let stbl = try #require(minf.findChild("stbl"))
        let stsd = try #require(stbl.findChild("stsd"))
        let payload = try #require(stsd.payload)
        let version = payload[payload.startIndex]
        #expect(version == 0)
    }
}

// MARK: - O5: default_sample_flags in tfhd for Audio

@Suite(
    "O5 — tfhd default_sample_flags for audio",
    .timeLimit(.minutes(1))
)
struct TfhdDefaultSampleFlagsTests {

    let writer = CMAFWriter()

    private func readBoxes(
        from data: Data
    ) throws -> [MP4Box] {
        try MP4BoxReader().readBoxes(from: data)
    }

    @Test("Audio media segment tfhd has default-sample-flags")
    func audioTfhdHasDefaultSampleFlags() throws {
        let frames = (0..<3).map { i in
            EncodedFrame(
                data: Data(repeating: 0xAA, count: 256),
                timestamp: MediaTimestamp(
                    seconds: Double(i) * 1024.0 / 48000.0
                ),
                duration: MediaTimestamp(
                    seconds: 1024.0 / 48000.0
                ),
                isKeyframe: true,
                codec: .aac
            )
        }
        let data = writer.generateMediaSegment(
            frames: frames,
            sequenceNumber: 1,
            timescale: 48000
        )
        let boxes = try readBoxes(from: data)
        let moof = try #require(
            boxes.first { $0.type == "moof" }
        )
        let traf = try #require(moof.findChild("traf"))
        let tfhd = try #require(traf.findChild("tfhd"))
        let payload = try #require(tfhd.payload)
        let flags = readFlags(from: payload)
        #expect(flags & 0x020000 != 0)
        #expect(flags & 0x000020 != 0)
    }

    @Test("Audio tfhd default flags equal sync sample")
    func audioTfhdSyncSampleValue() throws {
        let frames = [
            EncodedFrame(
                data: Data(repeating: 0xAA, count: 256),
                timestamp: MediaTimestamp(seconds: 0),
                duration: MediaTimestamp(
                    seconds: 1024.0 / 48000.0
                ),
                isKeyframe: true,
                codec: .aac
            )
        ]
        let data = writer.generateMediaSegment(
            frames: frames,
            sequenceNumber: 1,
            timescale: 48000
        )
        let boxes = try readBoxes(from: data)
        let moof = try #require(
            boxes.first { $0.type == "moof" }
        )
        let traf = try #require(moof.findChild("traf"))
        let tfhd = try #require(traf.findChild("tfhd"))
        let payload = try #require(tfhd.payload)
        let start = payload.startIndex + 8
        #expect(payload.count >= 12)
        let defaultFlags =
            UInt32(payload[start]) << 24
            | UInt32(payload[start + 1]) << 16
            | UInt32(payload[start + 2]) << 8
            | UInt32(payload[start + 3])
        #expect(defaultFlags == 0x0200_0000)
    }

    @Test("Video tfhd does NOT have default-sample-flags")
    func videoTfhdNoDefaultSampleFlags() throws {
        let frames = [
            EncodedFrame(
                data: Data(repeating: 0xBB, count: 100),
                timestamp: MediaTimestamp(seconds: 0),
                duration: MediaTimestamp(seconds: 1.0 / 30),
                isKeyframe: true,
                codec: .h264
            )
        ]
        let data = writer.generateMediaSegment(
            frames: frames,
            sequenceNumber: 1,
            timescale: 90000
        )
        let boxes = try readBoxes(from: data)
        let moof = try #require(
            boxes.first { $0.type == "moof" }
        )
        let traf = try #require(moof.findChild("traf"))
        let tfhd = try #require(traf.findChild("tfhd"))
        let payload = try #require(tfhd.payload)
        let flags = readFlags(from: payload)
        #expect(flags & 0x000020 == 0)
    }

    @Test("Audio trun omits per-sample flags")
    func audioTrunOmitsPerSampleFlags() throws {
        let frames = (0..<3).map { i in
            EncodedFrame(
                data: Data(repeating: 0xAA, count: 256),
                timestamp: MediaTimestamp(
                    seconds: Double(i) * 1024.0 / 48000.0
                ),
                duration: MediaTimestamp(
                    seconds: 1024.0 / 48000.0
                ),
                isKeyframe: true,
                codec: .aac
            )
        }
        let data = writer.generateMediaSegment(
            frames: frames,
            sequenceNumber: 1,
            timescale: 48000
        )
        let boxes = try readBoxes(from: data)
        let moof = try #require(
            boxes.first { $0.type == "moof" }
        )
        let traf = try #require(moof.findChild("traf"))
        let trun = try #require(traf.findChild("trun"))
        let payload = try #require(trun.payload)
        let trunFlags = readFlags(from: payload)
        #expect(trunFlags & 0x0400 == 0)
    }

    private func readFlags(from payload: Data) -> UInt32 {
        let start = payload.startIndex
        return UInt32(payload[start + 1]) << 16
            | UInt32(payload[start + 2]) << 8
            | UInt32(payload[start + 3])
    }
}
