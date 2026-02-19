// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit
@testable import HLSKitCommands

@Suite("OutputFormatter")
struct OutputFormatterTests {

    // MARK: - Initialization

    @Test("Init from 'json' string creates JSON formatter")
    func initJSON() {
        let fmt = OutputFormatter(from: "json")
        #expect(fmt == .json)
    }

    @Test("Init from 'JSON' string creates JSON formatter")
    func initJSONCaseInsensitive() {
        let fmt = OutputFormatter(from: "JSON")
        #expect(fmt == .json)
    }

    @Test("Init from 'text' string creates text formatter")
    func initText() {
        let fmt = OutputFormatter(from: "text")
        #expect(fmt == .text)
    }

    @Test("Init from unknown string defaults to text")
    func initUnknown() {
        let fmt = OutputFormatter(from: "xml")
        #expect(fmt == .text)
    }

    // MARK: - Key-Value Formatting

    @Test("Text format key-values aligns columns")
    func textKeyValues() {
        let pairs: [(String, String)] = [
            ("File:", "test.m3u8"),
            ("Type:", "Media Playlist")
        ]
        let output = OutputFormatter.text.formatKeyValues(pairs)
        #expect(output.contains("File:"))
        #expect(output.contains("test.m3u8"))
        #expect(output.contains("Type:"))
        #expect(output.contains("Media Playlist"))
    }

    @Test("JSON format key-values produces valid JSON structure")
    func jsonKeyValues() {
        let pairs: [(String, String)] = [
            ("File:", "test.m3u8"),
            ("Type:", "Master Playlist")
        ]
        let output = OutputFormatter.json.formatKeyValues(pairs)
        #expect(output.hasPrefix("{"))
        #expect(output.hasSuffix("}"))
        #expect(output.contains("\"File:\""))
        #expect(output.contains("\"test.m3u8\""))
    }

    @Test("Key-values with empty pairs produces output")
    func emptyKeyValues() {
        let pairs: [(String, String)] = []
        let textOutput = OutputFormatter.text.formatKeyValues(pairs)
        let jsonOutput = OutputFormatter.json.formatKeyValues(pairs)
        #expect(textOutput.isEmpty)
        #expect(jsonOutput.contains("{"))
    }

    // MARK: - Validation Report Formatting

    @Test("Text format: valid report shows success")
    func textValidReport() {
        let report = ValidationReport(results: [])
        let output = OutputFormatter.text.formatValidationReport(
            report, filename: "test.m3u8"
        )
        #expect(output.contains("Validating: test.m3u8"))
        #expect(output.contains("Valid HLS manifest"))
    }

    @Test("Text format: report with errors shows error count")
    func textReportWithErrors() {
        let results = [
            ValidationResult(
                severity: .error,
                message: "Missing EXTM3U",
                field: "header"
            ),
            ValidationResult(
                severity: .error,
                message: "No segments",
                field: "segments"
            )
        ]
        let report = ValidationReport(results: results)
        let output = OutputFormatter.text.formatValidationReport(
            report, filename: "bad.m3u8"
        )
        #expect(output.contains("Invalid HLS manifest"))
        #expect(output.contains("Errors: 2"))
        #expect(output.contains("Missing EXTM3U"))
    }

    @Test("Text format: report with warnings shows warning count")
    func textReportWithWarnings() {
        let results = [
            ValidationResult(
                severity: .warning,
                message: "Recommend version 7",
                field: "version"
            )
        ]
        let report = ValidationReport(results: results)
        let output = OutputFormatter.text.formatValidationReport(
            report, filename: "warn.m3u8"
        )
        #expect(output.contains("Valid HLS manifest"))
        #expect(output.contains("Warnings: 1"))
        #expect(output.contains("Recommend version 7"))
    }

    @Test("JSON format: validation report structure")
    func jsonValidationReport() {
        let results = [
            ValidationResult(
                severity: .error,
                message: "Missing tag",
                field: "header"
            )
        ]
        let report = ValidationReport(results: results)
        let output = OutputFormatter.json.formatValidationReport(
            report, filename: "test.m3u8"
        )
        #expect(output.contains("\"valid\""))
        #expect(output.contains("false"))
        #expect(output.contains("\"errorCount\""))
        #expect(output.contains("\"errors\""))
        #expect(output.contains("Missing tag"))
    }

    @Test("JSON format: valid report has valid=true")
    func jsonValidReport() {
        let report = ValidationReport(results: [])
        let output = OutputFormatter.json.formatValidationReport(
            report, filename: "ok.m3u8"
        )
        #expect(output.contains("\"valid\": true"))
    }

    // MARK: - Segmentation Result Formatting

    @Test("Text format: segment result displays count and size")
    func textSegmentResult() {
        let result = makeSegmentResult(count: 3)
        let output = OutputFormatter.text.formatSegmentResult(
            result, outputDirectory: "./out/"
        )
        #expect(output.contains("3 segments"))
        #expect(output.contains("./out/"))
        #expect(output.contains("segment_0"))
        #expect(output.contains("segment_2"))
    }

    @Test("Text format: single segment result")
    func textSingleSegment() {
        let result = makeSegmentResult(count: 1)
        let output = OutputFormatter.text.formatSegmentResult(
            result, outputDirectory: "./out/"
        )
        #expect(output.contains("1 segments"))
        #expect(output.contains("Segment:"))
    }

    @Test("Text format: zero segments")
    func textZeroSegments() {
        let result = makeSegmentResult(count: 0)
        let output = OutputFormatter.text.formatSegmentResult(
            result, outputDirectory: "./out/"
        )
        #expect(output.contains("0 segments"))
    }

    @Test("JSON format: segment result is valid JSON")
    func jsonSegmentResult() {
        let result = makeSegmentResult(count: 2)
        let output = OutputFormatter.json.formatSegmentResult(
            result, outputDirectory: "./out/"
        )
        #expect(output.hasPrefix("{"))
        #expect(output.hasSuffix("}"))
        #expect(output.contains("\"segments\""))
        #expect(output.contains("\"outputDirectory\""))
        #expect(output.contains("\"totalSize\""))
        #expect(output.contains("\"duration\""))
    }

    // MARK: - Byte Formatting

    @Test("Format bytes: small value shows B")
    func formatBytesSmall() {
        #expect(OutputFormatter.formatBytes(500) == "500 B")
    }

    @Test("Format bytes: KB range")
    func formatBytesKB() {
        let result = OutputFormatter.formatBytes(2048)
        #expect(result.contains("KB"))
    }

    @Test("Format bytes: MB range")
    func formatBytesMB() {
        let result = OutputFormatter.formatBytes(2_097_152)
        #expect(result.contains("MB"))
    }

    @Test("Format bytes: zero")
    func formatBytesZero() {
        #expect(OutputFormatter.formatBytes(0) == "0 B")
    }

    @Test("Instance formatBytes delegates to static")
    func instanceFormatBytes() {
        let fmt = OutputFormatter.text
        #expect(fmt.formatBytes(1024) == OutputFormatter.formatBytes(1024))
    }

    // MARK: - Helpers

    private func makeSegmentResult(count: Int) -> SegmentationResult {
        let segments = (0..<count).map { i in
            MediaSegmentOutput(
                index: i,
                data: Data(repeating: 0, count: 1024),
                duration: 6.0,
                filename: "segment_\(i).m4s",
                byteRangeOffset: nil,
                byteRangeLength: nil
            )
        }
        let fileInfo = MP4FileInfo(
            timescale: 90000,
            duration: 0,
            brands: ["isom"],
            tracks: []
        )
        let config = SegmentationConfig()
        return SegmentationResult(
            initSegment: Data(repeating: 0, count: 256),
            mediaSegments: segments,
            playlist: nil,
            fileInfo: fileInfo,
            config: config
        )
    }
}
