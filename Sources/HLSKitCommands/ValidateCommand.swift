// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import ArgumentParser
import Foundation
import HLSKit

/// Validate HLS manifests against RFC 8216 and Apple HLS
/// Authoring Spec.
///
/// ```
/// hlskit validate playlist.m3u8
/// hlskit validate master.m3u8 --strict
/// hlskit validate ./hls_output/ --recursive
/// ```
struct ValidateCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "validate",
        abstract: "Validate HLS manifests against RFC 8216 and Apple HLS Authoring Spec."
    )

    @Argument(
        help: "M3U8 file or directory containing HLS files"
    )
    var input: String

    @Flag(
        name: .long,
        help: "Treat warnings as errors"
    )
    var strict: Bool = false

    @Flag(
        name: .long,
        help: "Validate all M3U8 files in directory recursively"
    )
    var recursive: Bool = false

    @Option(
        name: .long,
        help: "Output format: text, json (default: text)"
    )
    var outputFormat: String = "text"

    func run() async throws {
        let formatter = OutputFormatter(from: outputFormat)

        guard FileManager.default.fileExists(atPath: input) else {
            printErr("Error: file not found: \(input)")
            throw ExitCode(ExitCodes.fileNotFound)
        }

        var isDir: ObjCBool = false
        _ = FileManager.default.fileExists(
            atPath: input, isDirectory: &isDir
        )

        if isDir.boolValue {
            try validateDirectory(formatter: formatter)
        } else {
            let hasErrors = try validateFile(
                path: input, formatter: formatter
            )
            if hasErrors {
                throw ExitCode(ExitCodes.validationError)
            }
        }
    }
}

// MARK: - Single File Validation

extension ValidateCommand {

    @discardableResult
    private func validateFile(
        path: String, formatter: OutputFormatter
    ) throws -> Bool {
        let url = URL(fileURLWithPath: path)
        let content = try String(
            contentsOf: url, encoding: .utf8
        )
        let engine = HLSEngine()
        let report = try engine.validateString(content)

        let output = formatter.formatValidationReport(
            report, filename: url.lastPathComponent
        )
        print(output)

        if strict && !report.warnings.isEmpty {
            return true
        }
        return !report.errors.isEmpty
    }
}

// MARK: - Directory Validation

extension ValidateCommand {

    private func validateDirectory(
        formatter: OutputFormatter
    ) throws {
        let url = URL(fileURLWithPath: input)
        let fm = FileManager.default
        var files: [URL] = []

        if recursive {
            if let enumerator = fm.enumerator(
                at: url,
                includingPropertiesForKeys: nil
            ) {
                for case let fileURL as URL in enumerator
                where fileURL.pathExtension == "m3u8" {
                    files.append(fileURL)
                }
            }
        } else {
            let contents = try fm.contentsOfDirectory(
                at: url, includingPropertiesForKeys: nil
            )
            files = contents.filter {
                $0.pathExtension == "m3u8"
            }
        }

        guard !files.isEmpty else {
            print("No M3U8 files found in \(input)")
            return
        }

        var hasErrors = false
        for file in files.sorted(by: { $0.path < $1.path }) {
            let fileHasErrors = try validateFile(
                path: file.path, formatter: formatter
            )
            if fileHasErrors { hasErrors = true }
            print("")
        }

        if hasErrors {
            throw ExitCode(ExitCodes.validationError)
        }
    }
}

// MARK: - Helpers

extension ValidateCommand {

    private func printErr(_ message: String) {
        var stderr = FileHandleOutputStream(
            FileHandle.standardError
        )
        print(message, to: &stderr)
    }
}
