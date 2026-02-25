// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("IFrame Integration", .timeLimit(.minutes(1)))
struct IFrameIntegrationTests {

    // MARK: - Helpers

    private func makeSegments(count: Int, duration: TimeInterval = 6.0) -> [SimultaneousRecorder.RecordedSegment] {
        (0..<count).map { i in
            SimultaneousRecorder.RecordedSegment(
                filename: "seg\(i).ts", duration: duration,
                isDiscontinuity: false, programDateTime: nil,
                byteSize: 50000 + i * 1000
            )
        }
    }

    // MARK: - Record → I-Frame Playlist

    @Test("Recorded segments produce valid I-Frame playlist")
    func recordedToIFrame() throws {
        var gen = IFramePlaylistGenerator()
        let segments = makeSegments(count: 5)
        gen.addFromRecordedSegments(segments)
        let playlist = gen.generate()
        let parser = ManifestParser()
        let manifest = try parser.parse(playlist)
        if case .media(let mp) = manifest {
            #expect(mp.iFramesOnly)
            #expect(mp.segments.count == 5)
            #expect(mp.hasEndList)
        } else {
            Issue.record("Expected media playlist")
        }
    }

    // MARK: - Thumbnails → WebVTT

    @Test("Thumbnail extraction and WebVTT generation pipeline")
    func thumbnailsToWebVTT() async throws {
        let provider = MockImageProvider()
        let extractor = ThumbnailExtractor(
            imageProvider: provider,
            configuration: .init(
                size: .init(width: 160, height: 90),
                tileColumns: 5, tileRows: 5
            )
        )
        let segments = makeSegments(count: 3, duration: 6.0)
        let thumbnails = try await extractor.extractFromSegments(segments) { _ in
            Data(repeating: 0xAB, count: 5000)
        }
        let sheets = extractor.calculateTileLayout(
            thumbnailCount: thumbnails.count,
            segmentDurations: segments.map(\.duration)
        )
        let vtt = extractor.generateWebVTT(tileSheets: sheets, baseURL: "tiles/")
        #expect(vtt.hasPrefix("WEBVTT"))
        #expect(vtt.contains("tiles/tile0.jpg"))
        #expect(vtt.contains("#xywh="))
    }

    // MARK: - Master Playlist with I-Frame Streams

    @Test("Master playlist includes EXT-X-I-FRAME-STREAM-INF tags")
    func masterPlaylistIFrameStreams() {
        let streams = [
            IFrameStreamInfo(
                bandwidth: 86000, uri: "iframe-low.m3u8",
                codecs: "avc1.42e01e",
                resolution: .init(width: 640, height: 360)
            ),
            IFrameStreamInfo(
                bandwidth: 300000, uri: "iframe-high.m3u8",
                codecs: "avc1.640028",
                resolution: .init(width: 1920, height: 1080)
            )
        ]
        let tags = streams.map { $0.render() }
        #expect(tags.count == 2)
        #expect(tags[0].contains("iframe-low.m3u8"))
        #expect(tags[1].contains("iframe-high.m3u8"))
        #expect(tags[0].contains("RESOLUTION=640x360"))
        #expect(tags[1].contains("RESOLUTION=1920x1080"))
    }

    // MARK: - Full Pipeline

    @Test("Full pipeline: record → I-Frame + thumbnails + master")
    func fullPipeline() async throws {
        let segments = makeSegments(count: 10)

        // I-Frame playlist
        var gen = IFramePlaylistGenerator()
        gen.addFromRecordedSegments(segments)
        let iframePlaylist = gen.generate()
        #expect(iframePlaylist.contains("#EXT-X-I-FRAMES-ONLY"))
        #expect(gen.keyframeCount == 10)

        // Thumbnails
        let extractor = ThumbnailExtractor(
            imageProvider: MockImageProvider(),
            configuration: .init(tileColumns: 5, tileRows: 2)
        )
        let thumbnails = try await extractor.extractFromSegments(segments) { _ in
            Data(repeating: 0x00, count: 1000)
        }
        #expect(thumbnails.count == 10)

        // Tile sheets
        let sheets = extractor.calculateTileLayout(
            thumbnailCount: 10,
            segmentDurations: segments.map(\.duration)
        )
        #expect(sheets.count == 1)
        #expect(sheets[0].entries.count == 10)

        // I-Frame stream info
        let streamInfo = IFrameStreamInfo(
            bandwidth: gen.totalByteSize * 8 / Int(segments.map(\.duration).reduce(0, +)),
            uri: "iframe.m3u8",
            codecs: "avc1.640028",
            resolution: .init(width: 1280, height: 720)
        )
        #expect(streamInfo.render().contains("iframe.m3u8"))
    }

    // MARK: - Tile Layout Scaling

    @Test("Large tile layout with 100 thumbnails")
    func largeTileLayout() {
        let extractor = ThumbnailExtractor(
            imageProvider: MockImageProvider(),
            configuration: .init(tileColumns: 10, tileRows: 10)
        )
        let sheets = extractor.calculateTileLayout(
            thumbnailCount: 100,
            segmentDurations: Array(repeating: 6.0, count: 100)
        )
        #expect(sheets.count == 1)
        #expect(sheets[0].entries.count == 100)
    }

    @Test("Tile layout with 150 thumbnails spans 2 sheets")
    func largeTileLayoutMultipleSheets() {
        let extractor = ThumbnailExtractor(
            imageProvider: MockImageProvider(),
            configuration: .init(tileColumns: 10, tileRows: 10)
        )
        let sheets = extractor.calculateTileLayout(
            thumbnailCount: 150,
            segmentDurations: Array(repeating: 6.0, count: 150)
        )
        #expect(sheets.count == 2)
        #expect(sheets[0].entries.count == 100)
        #expect(sheets[1].entries.count == 50)
    }

    // MARK: - fMP4 I-Frame

    @Test("fMP4 I-Frame playlist includes EXT-X-MAP")
    func fmp4IFrame() throws {
        var gen = IFramePlaylistGenerator(configuration: .fmp4)
        let segments = makeSegments(count: 3)
        gen.addFromRecordedSegments(segments)
        let playlist = gen.generate()
        #expect(playlist.contains("#EXT-X-MAP:URI=\"init.mp4\""))
        let manifest = try ManifestParser().parse(playlist)
        if case .media(let mp) = manifest {
            #expect(mp.iFramesOnly)
        } else {
            Issue.record("Expected media playlist")
        }
    }
}
