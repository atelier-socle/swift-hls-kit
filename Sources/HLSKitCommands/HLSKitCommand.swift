// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import ArgumentParser

/// Root command for the hlskit CLI.
///
/// Groups all subcommands under a single entry point:
/// ```
/// hlskit segment input.mp4 --output ./hls/
/// hlskit transcode input.mp4 --preset 720p
/// hlskit validate playlist.m3u8
/// hlskit info input.mp4
/// hlskit encrypt ./hls/ --key-url https://example.com/key.bin
/// hlskit manifest parse playlist.m3u8
/// ```
public struct HLSKitCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "hlskit",
        abstract: "HLS packaging toolkit — segment, transcode, encrypt, and validate HLS streams.",
        version: "0.1.0",
        subcommands: [
            SegmentCommand.self,
            TranscodeCommand.self,
            ValidateCommand.self,
            InfoCommand.self,
            EncryptCommand.self,
            ManifestCommand.self
        ]
    )

    public init() {}
}
