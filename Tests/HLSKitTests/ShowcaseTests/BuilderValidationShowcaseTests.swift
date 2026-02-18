// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

// MARK: - ValidationReport Tests

@Suite("ValidationReport Model")
struct ValidationReportTests {

    @Test("Empty report is valid")
    func emptyReport() {
        let report = ValidationReport()
        #expect(report.isValid == true)
        #expect(report.results.isEmpty)
        #expect(report.errors.isEmpty)
        #expect(report.warnings.isEmpty)
        #expect(report.infos.isEmpty)
    }

    @Test("Report with only warnings is still valid")
    func warningsOnly() {
        let report = ValidationReport(results: [
            ValidationResult(
                severity: .warning,
                message: "Missing CODECS attribute",
                field: "variants[0].codecs"
            )
        ])
        #expect(report.isValid == true)
        #expect(report.warnings.count == 1)
    }

    @Test("Report with errors is invalid")
    func withErrors() {
        let report = ValidationReport(results: [
            ValidationResult(
                severity: .error,
                message: "Missing variant streams",
                field: "variants"
            ),
            ValidationResult(
                severity: .warning,
                message: "Missing CODECS",
                field: "variants[0].codecs"
            )
        ])
        #expect(report.isValid == false)
        #expect(report.errors.count == 1)
        #expect(report.warnings.count == 1)
    }

    @Test("Results are sorted by severity descending")
    func sortedBySeverity() {
        let report = ValidationReport(results: [
            ValidationResult(severity: .info, message: "Info", field: "a"),
            ValidationResult(severity: .error, message: "Error", field: "b"),
            ValidationResult(severity: .warning, message: "Warning", field: "c")
        ])
        #expect(report.results[0].severity == .error)
        #expect(report.results[1].severity == .warning)
        #expect(report.results[2].severity == .info)
    }
}

// MARK: - ValidationSeverity Tests

@Suite("ValidationSeverity Enum")
struct ValidationSeverityTests {

    @Test("Severity ordering")
    func ordering() {
        #expect(ValidationSeverity.info < .warning)
        #expect(ValidationSeverity.warning < .error)
        #expect(ValidationSeverity.info < .error)
    }

    @Test("ValidationSeverity has 3 cases")
    func allCases() {
        #expect(ValidationSeverity.allCases.count == 3)
    }
}

// MARK: - Builder Tests

@Suite("MasterPlaylist Builder DSL")
struct MasterPlaylistBuilderTests {

    @Test("Build master playlist with variants")
    func buildWithVariants() {
        let playlist = MasterPlaylist {
            Variant(bandwidth: 800_000, resolution: .p480, uri: "480p/playlist.m3u8")
            Variant(bandwidth: 2_800_000, resolution: .p720, uri: "720p/playlist.m3u8")
            Variant(bandwidth: 5_000_000, resolution: .p1080, uri: "1080p/playlist.m3u8")
        }

        #expect(playlist.variants.count == 3)
        #expect(playlist.variants[0].bandwidth == 800_000)
        #expect(playlist.variants[1].resolution == .p720)
        #expect(playlist.variants[2].uri == "1080p/playlist.m3u8")
    }

    @Test("Build master playlist with renditions")
    func buildWithRenditions() {
        let playlist = MasterPlaylist {
            Variant(bandwidth: 2_800_000, uri: "video.m3u8")
            Rendition(type: .audio, groupId: "audio-en", name: "English", uri: "audio/en.m3u8")
        }

        #expect(playlist.variants.count == 1)
        #expect(playlist.renditions.count == 1)
    }
}

@Suite("MediaPlaylist Builder DSL")
struct MediaPlaylistBuilderTests {

    @Test("Build media playlist with segments")
    func buildWithSegments() {
        let playlist = MediaPlaylist(targetDuration: 6) {
            Segment(duration: 6.006, uri: "segment001.ts")
            Segment(duration: 5.839, uri: "segment002.ts")
            Segment(duration: 6.006, uri: "segment003.ts")
        }

        #expect(playlist.targetDuration == 6)
        #expect(playlist.segments.count == 3)
        #expect(playlist.segments[0].duration == 6.006)
        #expect(playlist.segments[1].uri == "segment002.ts")
    }

    @Test("Build media playlist with playlist type")
    func buildWithType() {
        let playlist = MediaPlaylist(targetDuration: 10, playlistType: .vod) {
            Segment(duration: 9.009, uri: "seg001.ts")
        }

        #expect(playlist.playlistType == .vod)
        #expect(playlist.segments.count == 1)
    }
}

// MARK: - Low-Latency HLS Model Tests

@Suite("Low-Latency HLS Models")
struct LowLatencyHLSTests {

    @Test("ServerControl with all fields")
    func serverControl() {
        let control = ServerControl(
            canBlockReload: true,
            canSkipUntil: 36.0,
            canSkipDateRanges: true,
            holdBack: 12.0,
            partHoldBack: 3.0
        )

        #expect(control.canBlockReload == true)
        #expect(control.canSkipUntil == 36.0)
        #expect(control.partHoldBack == 3.0)
    }

    @Test("PartialSegment creation")
    func partialSegment() {
        let part = PartialSegment(
            uri: "part001.mp4",
            duration: 1.0,
            independent: true
        )

        #expect(part.uri == "part001.mp4")
        #expect(part.duration == 1.0)
        #expect(part.independent == true)
    }

    @Test("PreloadHint creation")
    func preloadHint() {
        let hint = PreloadHint(type: .part, uri: "next-part.mp4")
        #expect(hint.type == .part)
        #expect(hint.uri == "next-part.mp4")
    }

    @Test("RenditionReport creation")
    func renditionReport() {
        let report = RenditionReport(
            uri: "audio/en/playlist.m3u8",
            lastMediaSequence: 100,
            lastPartIndex: 3
        )

        #expect(report.uri == "audio/en/playlist.m3u8")
        #expect(report.lastMediaSequence == 100)
        #expect(report.lastPartIndex == 3)
    }

    @Test("SkipInfo creation")
    func skipInfo() {
        let skip = SkipInfo(skippedSegments: 10)
        #expect(skip.skippedSegments == 10)
        #expect(skip.recentlyRemovedDateRanges.isEmpty)
    }
}

// MARK: - Supporting Types Tests

@Suite("Supporting Types")
struct SupportingTypesTests {

    @Test("ByteRange with offset")
    func byteRangeWithOffset() {
        let range = ByteRange(length: 1024, offset: 512)
        #expect(range.length == 1024)
        #expect(range.offset == 512)
    }

    @Test("ByteRange without offset")
    func byteRangeWithoutOffset() {
        let range = ByteRange(length: 2048)
        #expect(range.length == 2048)
        #expect(range.offset == nil)
    }

    @Test("EncryptionKey creation")
    func encryptionKey() {
        let key = EncryptionKey(
            method: .aes128,
            uri: "https://example.com/key",
            iv: "0x12345678",
            keyFormat: "identity"
        )

        #expect(key.method == .aes128)
        #expect(key.uri == "https://example.com/key")
        #expect(key.iv == "0x12345678")
        #expect(key.keyFormat == "identity")
    }

    @Test("MapTag creation")
    func mapTag() {
        let map = MapTag(
            uri: "init.mp4",
            byteRange: ByteRange(length: 720, offset: 0)
        )

        #expect(map.uri == "init.mp4")
        #expect(map.byteRange?.length == 720)
    }

    @Test("StartOffset creation")
    func startOffset() {
        let offset = StartOffset(timeOffset: 25.0, precise: true)
        #expect(offset.timeOffset == 25.0)
        #expect(offset.precise == true)
    }

    @Test("VariableDefinition creation")
    func variableDefinition() {
        let definition = VariableDefinition(name: "base-url", value: "https://cdn.example.com")
        #expect(definition.name == "base-url")
        #expect(definition.value == "https://cdn.example.com")
    }

    @Test("IFrameVariant creation")
    func iFrameVariant() {
        let variant = IFrameVariant(
            bandwidth: 200_000,
            uri: "iframe/playlist.m3u8",
            codecs: "avc1.4d401e",
            resolution: .p480
        )

        #expect(variant.bandwidth == 200_000)
        #expect(variant.uri == "iframe/playlist.m3u8")
        #expect(variant.resolution == .p480)
    }

    @Test("ValidationRuleSet cases")
    func validationRuleSets() {
        #expect(ValidationRuleSet.allCases.count == 2)
        #expect(ValidationRuleSet.rfc8216.rawValue == "rfc8216")
        #expect(ValidationRuleSet.appleHLS.rawValue == "appleHLS")
    }

    @Test("PreloadHintType cases")
    func preloadHintTypes() {
        #expect(PreloadHintType.allCases.count == 2)
        #expect(PreloadHintType.part.rawValue == "PART")
        #expect(PreloadHintType.map.rawValue == "MAP")
    }
}
