// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("LLHLSRenditionReport", .timeLimit(.minutes(1)))
struct LLHLSRenditionReportTests {

    // MARK: - LLHLSPlaylistRenderer

    @Test("Render empty rendition reports returns empty string")
    func renderEmpty() {
        let result = LLHLSPlaylistRenderer.renderRenditionReports([])
        #expect(result.isEmpty)
    }

    @Test("Render single rendition report")
    func renderSingle() {
        let report = RenditionReport(
            uri: "audio_128k.m3u8",
            lastMediaSequence: 42,
            lastPartIndex: 3
        )
        let result = LLHLSPlaylistRenderer.renderRenditionReports(
            [report]
        )
        #expect(result.contains("#EXT-X-RENDITION-REPORT:"))
        #expect(result.contains("URI=\"audio_128k.m3u8\""))
        #expect(result.contains("LAST-MSN=42"))
        #expect(result.contains("LAST-PART=3"))
    }

    @Test("Render multiple rendition reports")
    func renderMultiple() {
        let reports = [
            RenditionReport(
                uri: "audio_128k.m3u8",
                lastMediaSequence: 42, lastPartIndex: 3
            ),
            RenditionReport(
                uri: "audio_256k.m3u8",
                lastMediaSequence: 42, lastPartIndex: 2
            )
        ]
        let result = LLHLSPlaylistRenderer.renderRenditionReports(
            reports
        )
        let lines = result.split(separator: "\n")
        #expect(lines.count == 2)
        #expect(lines[0].contains("audio_128k.m3u8"))
        #expect(lines[1].contains("audio_256k.m3u8"))
    }

    @Test("RenditionReport with lastMediaSequence only")
    func msnOnly() {
        let report = RenditionReport(
            uri: "video.m3u8",
            lastMediaSequence: 10, lastPartIndex: nil
        )
        let result = LLHLSPlaylistRenderer.renderRenditionReports(
            [report]
        )
        #expect(result.contains("LAST-MSN=10"))
        #expect(!result.contains("LAST-PART"))
    }

    @Test("RenditionReport with lastPartIndex only")
    func partOnly() {
        let report = RenditionReport(
            uri: "video.m3u8",
            lastMediaSequence: nil, lastPartIndex: 5
        )
        let result = LLHLSPlaylistRenderer.renderRenditionReports(
            [report]
        )
        #expect(!result.contains("LAST-MSN"))
        #expect(result.contains("LAST-PART=5"))
    }

    @Test("RenditionReport with both MSN and part")
    func msnAndPart() {
        let report = RenditionReport(
            uri: "alt.m3u8",
            lastMediaSequence: 99, lastPartIndex: 7
        )
        let result = LLHLSPlaylistRenderer.renderRenditionReports(
            [report]
        )
        #expect(result.contains("LAST-MSN=99"))
        #expect(result.contains("LAST-PART=7"))
    }

    // MARK: - LLHLSManager Integration

    @Test("LLHLSManager: setRenditionReports stores reports")
    func managerStoresReports() async {
        let manager = LLHLSManager()
        let reports = [
            RenditionReport(
                uri: "audio.m3u8",
                lastMediaSequence: 5, lastPartIndex: 1
            )
        ]
        await manager.setRenditionReports(reports)

        let stored = await manager.renditionReports
        #expect(stored.count == 1)
        #expect(stored[0].uri == "audio.m3u8")
    }

    @Test("LLHLSManager: renderPlaylist includes rendition reports")
    func managerPlaylistIncludesReports() async throws {
        let manager = LLHLSManager()

        // Add a segment so playlist has content
        try await manager.addPartial(
            duration: 0.5, isIndependent: true
        )
        _ = await manager.completeSegment(
            duration: 2.0, uri: "seg0.ts"
        )

        let reports = [
            RenditionReport(
                uri: "audio.m3u8",
                lastMediaSequence: 0, lastPartIndex: 0
            )
        ]
        await manager.setRenditionReports(reports)

        let playlist = await manager.renderPlaylist()
        #expect(playlist.contains("#EXT-X-RENDITION-REPORT:"))
        #expect(playlist.contains("URI=\"audio.m3u8\""))
    }

    @Test("LLHLSManager: reports update on each render")
    func managerReportsUpdate() async throws {
        let manager = LLHLSManager()

        // First render with reports
        await manager.setRenditionReports([
            RenditionReport(
                uri: "v1.m3u8",
                lastMediaSequence: 1, lastPartIndex: nil
            )
        ])
        let playlist1 = await manager.renderPlaylist()
        #expect(playlist1.contains("v1.m3u8"))

        // Update reports
        await manager.setRenditionReports([
            RenditionReport(
                uri: "v2.m3u8",
                lastMediaSequence: 2, lastPartIndex: nil
            )
        ])
        let playlist2 = await manager.renderPlaylist()
        #expect(playlist2.contains("v2.m3u8"))
        #expect(!playlist2.contains("v1.m3u8"))
    }

    @Test("LLHLSManager: reports cleared returns empty")
    func managerReportsCleared() async {
        let manager = LLHLSManager()
        await manager.setRenditionReports([
            RenditionReport(
                uri: "audio.m3u8",
                lastMediaSequence: 1, lastPartIndex: nil
            )
        ])
        await manager.setRenditionReports([])

        let playlist = await manager.renderPlaylist()
        #expect(!playlist.contains("#EXT-X-RENDITION-REPORT:"))
    }

    @Test("Integration: partials + segments + rendition reports")
    func fullPlaylistIntegration() async throws {
        let manager = LLHLSManager()

        // Build some content
        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )
        try await manager.addPartial(
            duration: 0.33, isIndependent: false
        )
        _ = await manager.completeSegment(
            duration: 1.0, uri: "seg0.ts"
        )
        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )

        await manager.setRenditionReports([
            RenditionReport(
                uri: "audio_lo.m3u8",
                lastMediaSequence: 0, lastPartIndex: 0
            ),
            RenditionReport(
                uri: "audio_hi.m3u8",
                lastMediaSequence: 0, lastPartIndex: 0
            )
        ])

        let playlist = await manager.renderPlaylist()

        // Verify structure
        #expect(playlist.contains("#EXTM3U"))
        #expect(playlist.contains("#EXT-X-PART-INF:"))
        #expect(playlist.contains("#EXT-X-PART:"))
        #expect(playlist.contains("audio_lo.m3u8"))
        #expect(playlist.contains("audio_hi.m3u8"))

        // Rendition reports should come after content
        let reportRange = playlist.range(
            of: "#EXT-X-RENDITION-REPORT:"
        )
        let partInfRange = playlist.range(of: "#EXT-X-PART-INF:")
        #expect(reportRange != nil)
        #expect(partInfRange != nil)
        if let rr = reportRange, let pi = partInfRange {
            #expect(rr.lowerBound > pi.lowerBound)
        }
    }

    // MARK: - Round-Trip

    @Test("Round-trip: render then parse reports match")
    func roundTrip() throws {
        let reports = [
            RenditionReport(
                uri: "audio.m3u8",
                lastMediaSequence: 42, lastPartIndex: 3
            )
        ]
        let rendered = LLHLSPlaylistRenderer.renderRenditionReports(
            reports
        )
        // Parse with TagParser.parseRenditionReport
        let parser = TagParser()
        let line = rendered.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let prefix = "#EXT-X-RENDITION-REPORT:"
        let attrStr = String(line.dropFirst(prefix.count))
        let parsed = try parser.parseRenditionReport(attrStr)

        #expect(parsed.uri == "audio.m3u8")
        #expect(parsed.lastMediaSequence == 42)
        #expect(parsed.lastPartIndex == 3)
    }
}
