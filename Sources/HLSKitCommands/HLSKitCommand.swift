// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import ArgumentParser

/// Root command for the hlskit-cli CLI.
///
/// Groups all subcommands under a single entry point:
/// ```
/// hlskit-cli segment input.mp4 --output ./hls/
/// hlskit-cli transcode input.mp4 --preset 720p
/// hlskit-cli validate playlist.m3u8
/// hlskit-cli info input.mp4
/// hlskit-cli encrypt ./hls/ --key-url https://example.com/key.bin
/// hlskit-cli manifest parse playlist.m3u8
/// ```
@available(macOS 14, iOS 17, tvOS 17, watchOS 10, macCatalyst 17, visionOS 1, *)
public struct HLSKitCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "hlskit-cli",
        abstract: "HLS packaging toolkit — segment, transcode, encrypt, and validate HLS streams.",
        version: "0.2.0",
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
