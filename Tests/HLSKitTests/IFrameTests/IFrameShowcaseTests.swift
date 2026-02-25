// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("IFrame Showcase", .timeLimit(.minutes(1)))
struct IFrameShowcaseTests {

    // MARK: - Sports Scrubbing

    @Test("Sports event: fast scrubbing with I-Frame playlist")
    func sportsScrubbing() {
        var gen = IFramePlaylistGenerator()
        // 90 minutes of sport, 6s segments = 900 keyframes
        for i in 0..<900 {
            gen.addKeyframe(
                segmentURI: "sport_seg\(i).ts",
                byteOffset: 0,
                byteLength: 15000 + (i % 5) * 1000,
                duration: 6.006
            )
        }
        let playlist = gen.generate()
        #expect(playlist.contains("#EXT-X-I-FRAMES-ONLY"))
        #expect(gen.keyframeCount == 900)
        #expect(gen.calculateTargetDuration() == 7)
    }

    // MARK: - VOD Trick Play

    @Test("VOD trick play with byte ranges")
    func vodTrickPlay() throws {
        var gen = IFramePlaylistGenerator()
        gen.addKeyframe(
            segmentURI: "movie_part1.ts", byteOffset: 0,
            byteLength: 20000, duration: 6.0
        )
        gen.addKeyframe(
            segmentURI: "movie_part1.ts", byteOffset: 188000,
            byteLength: 18000, duration: 6.0
        )
        gen.addKeyframe(
            segmentURI: "movie_part2.ts", byteOffset: 0,
            byteLength: 22000, duration: 6.0
        )
        let playlist = gen.generate()
        #expect(playlist.contains("#EXT-X-BYTERANGE:20000@0"))
        #expect(playlist.contains("#EXT-X-BYTERANGE:18000@188000"))
        let manifest = try ManifestParser().parse(playlist)
        if case .media(let mp) = manifest {
            #expect(mp.segments.count == 3)
            #expect(mp.iFramesOnly)
        } else {
            Issue.record("Expected media playlist")
        }
    }

    // MARK: - Live DVR Thumbnails

    @Test("Live DVR: thumbnail timeline preview")
    func liveDVRThumbnails() async throws {
        let extractor = ThumbnailExtractor(
            imageProvider: MockImageProvider(),
            configuration: .init(
                size: .medium,
                tileColumns: 10, tileRows: 5
            )
        )
        // 30 minutes DVR window, 6s segments
        let segments = (0..<300).map { i in
            SimultaneousRecorder.RecordedSegment(
                filename: "dvr_\(i).ts", duration: 6.0,
                isDiscontinuity: false, programDateTime: nil, byteSize: 80000
            )
        }
        let thumbnails = try await extractor.extractFromSegments(segments) { _ in
            Data(repeating: 0x00, count: 800)
        }
        let sheets = extractor.calculateTileLayout(
            thumbnailCount: thumbnails.count,
            segmentDurations: segments.map(\.duration)
        )
        #expect(thumbnails.count == 300)
        #expect(sheets.count == 6)
        let vtt = extractor.generateWebVTT(tileSheets: sheets, baseURL: "dvr/")
        #expect(vtt.contains("dvr/tile0.jpg"))
        #expect(vtt.contains("dvr/tile5.jpg"))
    }

    // MARK: - Podcast Preview

    @Test("Podcast: simple thumbnails without tiling")
    func podcastPreview() {
        let extractor = ThumbnailExtractor(
            imageProvider: MockImageProvider(),
            configuration: .standard
        )
        let thumbnails = (0..<5).map { i in
            ThumbnailExtractor.Thumbnail(
                time: Double(i) * 600.0, duration: 600.0,
                imageData: Data(repeating: 0x00, count: 500), segmentIndex: i
            )
        }
        let vtt = extractor.generateSimpleWebVTT(
            thumbnails: thumbnails, baseURL: "podcast/"
        )
        #expect(vtt.contains("podcast/thumb0.jpg"))
        #expect(vtt.contains("podcast/thumb4.jpg"))
        #expect(vtt.contains("00:10:00.000"))
    }

    // MARK: - Multi-Bitrate

    @Test("Multi-bitrate I-Frame stream info for ABR")
    func multiBitrateIFrame() {
        let infos = [
            IFrameStreamInfo(
                bandwidth: 86000, uri: "iframe-360p.m3u8",
                codecs: "avc1.640028",
                resolution: .init(width: 640, height: 360)
            ),
            IFrameStreamInfo(
                bandwidth: 150000, uri: "iframe-720p.m3u8",
                codecs: "avc1.640028",
                resolution: .init(width: 1280, height: 720)
            ),
            IFrameStreamInfo(
                bandwidth: 300000, uri: "iframe-1080p.m3u8",
                codecs: "avc1.640028",
                resolution: .init(width: 1920, height: 1080)
            )
        ]
        let tags = infos.map { $0.render() }
        #expect(tags.count == 3)
        for tag in tags {
            #expect(tag.hasPrefix("#EXT-X-I-FRAME-STREAM-INF:"))
        }
        #expect(tags[0].contains("RESOLUTION=640x360"))
        #expect(tags[2].contains("BANDWIDTH=300000"))
    }

    // MARK: - Timeline Preview

    @Test("Timeline preview: WebVTT cue timing accuracy")
    func timelinePreview() {
        let extractor = ThumbnailExtractor(
            imageProvider: MockImageProvider(),
            configuration: .init(
                size: .small, tileColumns: 4, tileRows: 4
            )
        )
        let sheets = extractor.calculateTileLayout(
            thumbnailCount: 8,
            segmentDurations: [6.0, 6.0, 6.0, 6.0, 6.0, 6.0, 6.0, 6.0]
        )
        let vtt = extractor.generateWebVTT(tileSheets: sheets, baseURL: "")
        // Verify sequential timing
        #expect(vtt.contains("00:00:00.000 --> 00:00:06.000"))
        #expect(vtt.contains("00:00:06.000 --> 00:00:12.000"))
        #expect(vtt.contains("00:00:42.000 --> 00:00:48.000"))
    }

    // MARK: - Archive

    @Test("Archive: fMP4 I-Frame playlist for long-form content")
    func archiveIFrame() {
        var gen = IFramePlaylistGenerator(configuration: .fmp4)
        // 2-hour archive, 6s segments = 1200 keyframes
        for i in 0..<1200 {
            gen.addKeyframe(
                segmentURI: "archive_\(i).m4s", byteOffset: 0,
                byteLength: 12000, duration: 6.0
            )
        }
        let playlist = gen.generate()
        #expect(playlist.contains("#EXT-X-MAP:URI=\"init.mp4\""))
        #expect(playlist.contains("#EXT-X-I-FRAMES-ONLY"))
        #expect(gen.keyframeCount == 1200)
        #expect(gen.totalByteSize == 1200 * 12000)
    }

    // MARK: - Conference

    @Test("Conference: discontinuities between presentations")
    func conferenceDiscontinuities() throws {
        var gen = IFramePlaylistGenerator()
        // Presentation 1
        for i in 0..<10 {
            gen.addKeyframe(
                segmentURI: "pres1_\(i).ts", byteOffset: 0,
                byteLength: 10000, duration: 6.0,
                isDiscontinuity: i == 0
            )
        }
        // Presentation 2 (discontinuity)
        for i in 0..<10 {
            gen.addKeyframe(
                segmentURI: "pres2_\(i).ts", byteOffset: 0,
                byteLength: 10000, duration: 6.0,
                isDiscontinuity: i == 0
            )
        }
        let playlist = gen.generate()
        #expect(gen.keyframeCount == 20)
        // At least 2 discontinuity tags
        let discCount = playlist.components(separatedBy: "#EXT-X-DISCONTINUITY").count - 1
        #expect(discCount == 2)
    }
}
