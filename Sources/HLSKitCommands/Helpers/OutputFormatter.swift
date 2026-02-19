// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import HLSKit

/// Formats command output as text or JSON.
public enum OutputFormatter: String, Sendable {
    case text
    case json

    /// Creates a formatter from a string value.
    public init(from string: String) {
        self = string.lowercased() == "json" ? .json : .text
    }

    // MARK: - Segmentation

    /// Format a segmentation result summary.
    public func formatSegmentResult(
        _ result: SegmentationResult,
        outputDirectory: String
    ) -> String {
        switch self {
        case .text:
            return formatSegmentResultText(
                result, outputDirectory: outputDirectory
            )
        case .json:
            return formatSegmentResultJSON(
                result, outputDirectory: outputDirectory
            )
        }
    }

    // MARK: - Validation

    /// Format a validation report.
    public func formatValidationReport(
        _ report: ValidationReport,
        filename: String
    ) -> String {
        switch self {
        case .text:
            return formatValidationText(
                report, filename: filename
            )
        case .json:
            return formatValidationJSON(report)
        }
    }

    // MARK: - Generic Key-Value

    /// Format a dictionary of key-value pairs.
    public func formatKeyValues(
        _ pairs: [(String, String)]
    ) -> String {
        switch self {
        case .text:
            let maxKey = pairs.map(\.0.count).max() ?? 0
            return pairs.map { key, value in
                let padded = key.padding(
                    toLength: maxKey + 1,
                    withPad: " ",
                    startingAt: 0
                )
                return "  \(padded) \(value)"
            }.joined(separator: "\n")
        case .json:
            return formatDictJSON(pairs)
        }
    }
}

// MARK: - Text Formatters

extension OutputFormatter {

    private func formatSegmentResultText(
        _ result: SegmentationResult,
        outputDirectory: String
    ) -> String {
        var lines: [String] = []
        let count = result.mediaSegments.count
        lines.append(
            ColorOutput.success("Created \(count) segments")
                + " in \(outputDirectory)"
        )
        if !result.initSegment.isEmpty {
            let size = formatBytes(result.initSegment.count)
            lines.append("  Init segment: \(size)")
        }
        if count > 0 {
            let first = result.mediaSegments[0].filename
            let last = result.mediaSegments[count - 1].filename
            if count == 1 {
                lines.append("  Segment:  \(first)")
            } else {
                lines.append("  Segments: \(first) — \(last)")
            }
        }
        let totalSize = result.mediaSegments.reduce(
            result.initSegment.count
        ) { $0 + $1.data.count }
        lines.append("  Total size: \(formatBytes(totalSize))")
        let duration = result.mediaSegments.reduce(0.0) {
            $0 + $1.duration
        }
        lines.append(
            "  Duration: \(String(format: "%.1f", duration))s"
        )
        return lines.joined(separator: "\n")
    }

    private func formatValidationText(
        _ report: ValidationReport,
        filename: String
    ) -> String {
        var lines: [String] = []
        lines.append("Validating: \(filename)")
        lines.append("")

        if report.isValid {
            lines.append(
                ColorOutput.success("Valid HLS manifest")
            )
        } else {
            lines.append(
                ColorOutput.error("Invalid HLS manifest")
            )
        }

        if !report.errors.isEmpty {
            lines.append(
                "  Errors: \(report.errors.count)"
            )
            for err in report.errors {
                lines.append(
                    "    \(ColorOutput.error("*")) \(err.message)"
                )
            }
        }
        if !report.warnings.isEmpty {
            lines.append(
                "  Warnings: \(report.warnings.count)"
            )
            for warn in report.warnings {
                lines.append(
                    "    \(ColorOutput.warning("!")) "
                        + warn.message
                )
            }
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - JSON Formatters

extension OutputFormatter {

    private func formatSegmentResultJSON(
        _ result: SegmentationResult,
        outputDirectory: String
    ) -> String {
        let totalSize = result.mediaSegments.reduce(
            result.initSegment.count
        ) { $0 + $1.data.count }
        let duration = result.mediaSegments.reduce(0.0) {
            $0 + $1.duration
        }
        let dict: [(String, String)] = [
            ("\"segments\"", "\(result.mediaSegments.count)"),
            ("\"outputDirectory\"", "\"\(outputDirectory)\""),
            ("\"totalSize\"", "\(totalSize)"),
            ("\"duration\"", String(format: "%.1f", duration))
        ]
        return formatJSONObject(dict)
    }

    private func formatValidationJSON(
        _ report: ValidationReport
    ) -> String {
        var dict: [(String, String)] = [
            ("\"valid\"", report.isValid ? "true" : "false"),
            ("\"errorCount\"", "\(report.errors.count)"),
            ("\"warningCount\"", "\(report.warnings.count)")
        ]
        if !report.errors.isEmpty {
            let msgs = report.errors.map { "\"\($0.message)\"" }
            dict.append(
                ("\"errors\"", "[\(msgs.joined(separator: ", "))]")
            )
        }
        if !report.warnings.isEmpty {
            let msgs = report.warnings.map {
                "\"\($0.message)\""
            }
            dict.append(
                (
                    "\"warnings\"",
                    "[\(msgs.joined(separator: ", "))]"
                )
            )
        }
        return formatJSONObject(dict)
    }

    private func formatDictJSON(
        _ pairs: [(String, String)]
    ) -> String {
        let entries = pairs.map { key, value in
            "\"\(key)\": \"\(value)\""
        }
        return "{\n  \(entries.joined(separator: ",\n  "))\n}"
    }

    private func formatJSONObject(
        _ pairs: [(String, String)]
    ) -> String {
        let entries = pairs.map { key, value in
            "  \(key): \(value)"
        }
        return "{\n\(entries.joined(separator: ",\n"))\n}"
    }
}

// MARK: - Byte Formatting

extension OutputFormatter {

    /// Format a byte count as human-readable string.
    public static func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1_048_576 {
            return String(
                format: "%.1f KB", Double(bytes) / 1024.0
            )
        } else {
            return String(
                format: "%.1f MB",
                Double(bytes) / 1_048_576.0
            )
        }
    }

    func formatBytes(_ bytes: Int) -> String {
        Self.formatBytes(bytes)
    }
}
