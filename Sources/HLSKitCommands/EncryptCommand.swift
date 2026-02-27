// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import ArgumentParser
import Foundation
import HLSKit

/// Encrypt HLS segments.
///
/// ```
/// hlskit encrypt ./hls/ --key-url https://example.com/key.bin
/// hlskit encrypt ./hls/ --method sample-aes --key-url ./key.bin
/// hlskit encrypt ./hls/ --key-url ./key.bin --rotation 10
/// ```
struct EncryptCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "encrypt",
        abstract: "Encrypt HLS segments."
    )

    @Argument(help: "Directory containing HLS segments")
    var input: String

    @Option(
        name: .long,
        help: "Encryption method: aes-128, sample-aes (default: aes-128)"
    )
    var method: String = "aes-128"

    @Option(name: .long, help: "Key URL for EXT-X-KEY tag")
    var keyURL: String

    @Option(
        name: .long,
        help: "Hex-encoded 16-byte key (auto-generated if omitted)"
    )
    var key: String?

    @Option(
        name: .long,
        help: "Hex-encoded 16-byte IV (derived from sequence if omitted)"
    )
    var iv: String?

    @Option(
        name: .long,
        help: "Key rotation interval in segments"
    )
    var rotation: Int?

    @Flag(
        name: .long,
        help: "Write key file to output directory"
    )
    var writeKey: Bool = false

    @Flag(name: .long, help: "Suppress output")
    var quiet: Bool = false

    @Option(
        name: .long,
        help: "Output format: text, json (default: text)"
    )
    var outputFormat: String = "text"

    func run() async throws {
        let dirURL = URL(fileURLWithPath: input)

        guard FileManager.default.fileExists(atPath: input) else {
            printErr("Error: directory not found: \(input)")
            throw ExitCode(ExitCodes.fileNotFound)
        }

        guard let parsedKeyURL = URL(string: keyURL) else {
            printErr("Error: invalid key URL: \(keyURL)")
            throw ExitCode(ExitCodes.generalError)
        }

        let encMethod = parseMethod(method)
        let keyData = key.flatMap { parseHexString($0) }
        let ivData = iv.flatMap { parseHexString($0) }

        let config = EncryptionConfig(
            method: encMethod,
            keyURL: parsedKeyURL,
            key: keyData,
            iv: ivData,
            keyRotationInterval: rotation,
            writeKeyFile: writeKey
        )

        let segmentFiles = try findSegmentFiles(in: dirURL)

        if !quiet {
            print(
                "Encrypting \(segmentFiles.count) segments"
                    + " in \(input)")
            print("Method: \(encMethod.rawValue)")
        }

        let encryptor = SegmentEncryptor()
        let usedKey = try encryptor.encryptDirectory(
            dirURL,
            segmentFilenames: segmentFiles,
            config: config
        )

        try updatePlaylistWithEncryption(
            in: dirURL,
            config: config,
            segmentCount: segmentFiles.count
        )

        if !quiet {
            let keyHex = usedKey.map {
                String(format: "%02x", $0)
            }.joined()
            print(
                ColorOutput.success(
                    "Encrypted \(segmentFiles.count) segments"
                )
            )
            print("  Key: \(keyHex)")
        }
    }
}

// MARK: - Helpers

extension EncryptCommand {

    private func parseMethod(
        _ string: String
    ) -> EncryptionMethod {
        switch string.lowercased() {
        case "sample-aes", "sampleaes":
            return .sampleAES
        case "none":
            return .none
        default:
            return .aes128
        }
    }

    private func parseHexString(_ hex: String) -> Data? {
        let cleaned =
            hex.hasPrefix("0x")
            ? String(hex.dropFirst(2)) : hex
        guard cleaned.count == 32 else { return nil }
        var data = Data()
        var index = cleaned.startIndex
        while index < cleaned.endIndex {
            let next = cleaned.index(index, offsetBy: 2)
            guard next <= cleaned.endIndex else { return nil }
            let byteStr = String(cleaned[index..<next])
            guard let byte = UInt8(byteStr, radix: 16) else {
                return nil
            }
            data.append(byte)
            index = next
        }
        return data
    }

    private func findSegmentFiles(
        in directory: URL
    ) throws -> [String] {
        let contents = try FileManager.default
            .contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            )
        return
            contents
            .filter {
                $0.pathExtension == "ts"
                    || $0.pathExtension == "m4s"
            }
            .map(\.lastPathComponent)
            .sorted()
    }

    private func updatePlaylistWithEncryption(
        in directory: URL,
        config: EncryptionConfig,
        segmentCount: Int
    ) throws {
        let playlistURL = directory.appendingPathComponent(
            "playlist.m3u8"
        )
        guard
            FileManager.default.fileExists(
                atPath: playlistURL.path
            )
        else {
            return
        }

        let content = try String(
            contentsOf: playlistURL, encoding: .utf8
        )
        let builder = EncryptedPlaylistBuilder()
        let updated = builder.addEncryptionTags(
            to: content,
            config: config,
            segmentCount: segmentCount
        )
        try updated.write(
            to: playlistURL, atomically: true, encoding: .utf8
        )
    }

    private func printErr(_ message: String) {
        var stderr = FileHandleOutputStream(
            FileHandle.standardError
        )
        print(message, to: &stderr)
    }
}
