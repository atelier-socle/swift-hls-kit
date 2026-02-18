// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("MP4InfoParser")
struct MP4InfoParserTests {

    let boxReader = MP4BoxReader()
    let parser = MP4InfoParser()

    // MARK: - ftyp Parsing

    @Test("Parse ftyp — brands extracted")
    func parseBrands() throws {
        let data = MP4TestDataBuilder.minimalMP4()
        let boxes = try boxReader.readBoxes(from: data)
        let info = try parser.parseFileInfo(from: boxes)
        #expect(info.brands.contains("isom"))
        #expect(info.brands.contains("iso2"))
    }

    // MARK: - mvhd Parsing

    @Test("Parse mvhd — timescale and duration (v0)")
    func parseMvhdV0() throws {
        let data = MP4TestDataBuilder.minimalMP4(
            timescale: 600, duration: 6000
        )
        let boxes = try boxReader.readBoxes(from: data)
        let info = try parser.parseFileInfo(from: boxes)
        #expect(info.timescale == 600)
        #expect(info.duration == 6000)
        #expect(info.durationSeconds == 10.0)
    }

    @Test("Parse mvhd — version 1 (64-bit duration)")
    func parseMvhdV1() throws {
        let ftypBox = MP4TestDataBuilder.ftyp()
        let mvhdBox = MP4TestDataBuilder.mvhdV1(
            timescale: 48000, duration: 480000
        )
        let moovBox = MP4TestDataBuilder.containerBox(
            type: "moov", children: [mvhdBox]
        )
        var data = Data()
        data.append(ftypBox)
        data.append(moovBox)
        let boxes = try boxReader.readBoxes(from: data)
        let info = try parser.parseFileInfo(from: boxes)
        #expect(info.timescale == 48000)
        #expect(info.duration == 480000)
        #expect(info.durationSeconds == 10.0)
    }

    // MARK: - Track Parsing

    @Test("Parse video track — full info")
    func parseVideoTrack() throws {
        let data = MP4TestDataBuilder.videoMP4()
        let boxes = try boxReader.readBoxes(from: data)
        let info = try parser.parseFileInfo(from: boxes)
        #expect(info.tracks.count == 1)
        let track = info.tracks[0]
        #expect(track.trackId == 1)
        #expect(track.mediaType == .video)
        #expect(track.timescale == 90000)
        #expect(track.duration == 900000)
        #expect(track.durationSeconds == 10.0)
        #expect(track.codec == "avc1")
        #expect(track.hasSyncSamples)
    }

    @Test("Parse video track — dimensions")
    func parseVideoDimensions() throws {
        let data = MP4TestDataBuilder.videoMP4(
            width: 1920, height: 1080
        )
        let boxes = try boxReader.readBoxes(from: data)
        let info = try parser.parseFileInfo(from: boxes)
        let track = info.tracks[0]
        #expect(track.dimensions != nil)
        #expect(track.dimensions?.width == 1920)
        #expect(track.dimensions?.height == 1080)
    }

    @Test("Parse audio track — full info")
    func parseAudioTrack() throws {
        let ftypBox = MP4TestDataBuilder.ftyp()
        let aTrack = MP4TestDataBuilder.audioTrack(
            trackId: 1, timescale: 44100, duration: 441000
        )
        let moovBox = MP4TestDataBuilder.containerBox(
            type: "moov",
            children: [
                MP4TestDataBuilder.mvhd(
                    timescale: 600, duration: 6000
                ),
                aTrack
            ]
        )
        var data = Data()
        data.append(ftypBox)
        data.append(moovBox)
        let boxes = try boxReader.readBoxes(from: data)
        let info = try parser.parseFileInfo(from: boxes)
        let track = info.tracks[0]
        #expect(track.mediaType == .audio)
        #expect(track.codec == "mp4a")
        #expect(track.timescale == 44100)
        #expect(track.dimensions == nil)
    }

    @Test("Parse multi-track — video + audio")
    func parseMultiTrack() throws {
        let data = MP4TestDataBuilder.avMP4()
        let boxes = try boxReader.readBoxes(from: data)
        let info = try parser.parseFileInfo(from: boxes)
        #expect(info.tracks.count == 2)
        #expect(info.videoTrack != nil)
        #expect(info.audioTrack != nil)
        #expect(info.videoTrack?.mediaType == .video)
        #expect(info.audioTrack?.mediaType == .audio)
    }

    // MARK: - Language Decoding

    @Test("Language — eng decoded correctly")
    func languageEng() {
        let packed = MP4TestDataBuilder.encodeLanguage("eng")
        let result = MP4InfoParser().decodeLanguage(packed)
        #expect(result == "eng")
    }

    @Test("Language — fra decoded correctly")
    func languageFra() {
        let packed = MP4TestDataBuilder.encodeLanguage("fra")
        let result = MP4InfoParser().decodeLanguage(packed)
        #expect(result == "fra")
    }

    @Test("Language — und returns nil")
    func languageUnd() {
        let packed = MP4TestDataBuilder.encodeLanguage("und")
        let result = MP4InfoParser().decodeLanguage(packed)
        #expect(result == nil)
    }

    @Test("Audio track — language from mdhd")
    func audioTrackLanguage() throws {
        let ftypBox = MP4TestDataBuilder.ftyp()
        let aTrack = MP4TestDataBuilder.audioTrack(
            trackId: 1, duration: 44100,
            language: "fra"
        )
        let moovBox = MP4TestDataBuilder.containerBox(
            type: "moov",
            children: [
                MP4TestDataBuilder.mvhd(
                    timescale: 600, duration: 6000
                ),
                aTrack
            ]
        )
        var data = Data()
        data.append(ftypBox)
        data.append(moovBox)
        let boxes = try boxReader.readBoxes(from: data)
        let info = try parser.parseFileInfo(from: boxes)
        #expect(info.tracks[0].language == "fra")
    }

    // MARK: - MP4FileInfo Helpers

    @Test("videoTrack — returns first video track")
    func videoTrackHelper() throws {
        let data = MP4TestDataBuilder.avMP4()
        let boxes = try boxReader.readBoxes(from: data)
        let info = try parser.parseFileInfo(from: boxes)
        #expect(info.videoTrack?.trackId == 1)
    }

    @Test("audioTrack — returns first audio track")
    func audioTrackHelper() throws {
        let data = MP4TestDataBuilder.avMP4()
        let boxes = try boxReader.readBoxes(from: data)
        let info = try parser.parseFileInfo(from: boxes)
        #expect(info.audioTrack?.trackId == 2)
    }

    @Test("TrackInfo — durationSeconds calculation")
    func durationSeconds() throws {
        let data = MP4TestDataBuilder.videoMP4(
            timescale: 90000, duration: 900000
        )
        let boxes = try boxReader.readBoxes(from: data)
        let info = try parser.parseFileInfo(from: boxes)
        #expect(info.tracks[0].durationSeconds == 10.0)
    }

    @Test("MP4FileInfo — durationSeconds with zero timescale")
    func durationZeroTimescale() {
        let info = MP4FileInfo(
            timescale: 0, duration: 1000,
            brands: [], tracks: []
        )
        #expect(info.durationSeconds == 0)
    }

    @Test("TrackInfo — durationSeconds with zero timescale")
    func trackDurationZeroTimescale() {
        let track = TrackInfo(
            trackId: 1, mediaType: .video,
            timescale: 0, duration: 1000,
            codec: "avc1", dimensions: nil,
            language: nil,
            sampleDescriptionData: Data(),
            hasSyncSamples: false
        )
        #expect(track.durationSeconds == 0)
    }

    // MARK: - Error Cases

    @Test("Missing moov — throws")
    func missingMoov() throws {
        let ftypBox = MP4TestDataBuilder.ftyp()
        let boxes = try boxReader.readBoxes(from: ftypBox)
        #expect(throws: MP4Error.self) {
            try parser.parseFileInfo(from: boxes)
        }
    }

    @Test("Missing mvhd — throws")
    func missingMvhd() throws {
        let ftypBox = MP4TestDataBuilder.ftyp()
        let moovBox = MP4TestDataBuilder.containerBox(
            type: "moov", children: []
        )
        var data = Data()
        data.append(ftypBox)
        data.append(moovBox)
        let boxes = try boxReader.readBoxes(from: data)
        #expect(throws: MP4Error.self) {
            try parser.parseFileInfo(from: boxes)
        }
    }

    // MARK: - stsd Parsing

    @Test("Parse stsd — codec extracted")
    func stsdCodec() throws {
        let data = MP4TestDataBuilder.videoMP4(
            width: 1280, height: 720
        )
        let boxes = try boxReader.readBoxes(from: data)
        let info = try parser.parseFileInfo(from: boxes)
        #expect(info.tracks[0].codec == "avc1")
    }

    // MARK: - hasSyncSamples

    @Test("Video track with stss — hasSyncSamples true")
    func hasSyncSamples() throws {
        let data = MP4TestDataBuilder.videoMP4()
        let boxes = try boxReader.readBoxes(from: data)
        let info = try parser.parseFileInfo(from: boxes)
        #expect(info.tracks[0].hasSyncSamples == true)
    }

    @Test("Audio track without stss — hasSyncSamples false")
    func noSyncSamples() throws {
        let ftypBox = MP4TestDataBuilder.ftyp()
        let aTrack = MP4TestDataBuilder.audioTrack(
            trackId: 1, duration: 44100
        )
        let moovBox = MP4TestDataBuilder.containerBox(
            type: "moov",
            children: [
                MP4TestDataBuilder.mvhd(
                    timescale: 600, duration: 6000
                ),
                aTrack
            ]
        )
        var data = Data()
        data.append(ftypBox)
        data.append(moovBox)
        let boxes = try boxReader.readBoxes(from: data)
        let info = try parser.parseFileInfo(from: boxes)
        #expect(info.tracks[0].hasSyncSamples == false)
    }

    // MARK: - MediaTrackType

    @Test("MediaTrackType — raw values")
    func mediaTrackTypeRawValues() {
        #expect(MediaTrackType.video.rawValue == "vide")
        #expect(MediaTrackType.audio.rawValue == "soun")
        #expect(MediaTrackType.subtitle.rawValue == "sbtl")
        #expect(MediaTrackType.text.rawValue == "text")
    }
}
