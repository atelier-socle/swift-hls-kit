// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Injects `EXT-X-KEY` tags into HLS media playlists.
///
/// Takes an existing playlist string and adds encryption metadata
/// at the appropriate positions, supporting key rotation.
///
/// ```swift
/// let builder = EncryptedPlaylistBuilder()
/// let encrypted = builder.addEncryptionTags(
///     to: playlist,
///     config: encryptionConfig,
///     segmentCount: 10
/// )
/// ```
///
/// - SeeAlso: ``SegmentEncryptor``, ``EncryptionConfig``
public struct EncryptedPlaylistBuilder: Sendable {

    /// Creates an encrypted playlist builder.
    public init() {}

    // MARK: - Playlist Injection

    /// Add `EXT-X-KEY` tags to a media playlist.
    ///
    /// Inserts encryption key tags before the first `EXTINF` tag,
    /// and at rotation boundaries if key rotation is configured.
    ///
    /// - Parameters:
    ///   - playlist: Original playlist M3U8 string.
    ///   - config: Encryption configuration.
    ///   - segmentCount: Total number of segments.
    /// - Returns: Updated playlist with `EXT-X-KEY` tags.
    public func addEncryptionTags(
        to playlist: String,
        config: EncryptionConfig,
        segmentCount: Int
    ) -> String {
        let lines = playlist.components(separatedBy: "\n")
        var output: [String] = []
        var segmentIndex = 0
        var keyTagInserted = false

        for line in lines {
            if line.hasPrefix("#EXTINF:") {
                let needsKeyTag = shouldInsertKeyTag(
                    segmentIndex: segmentIndex,
                    config: config,
                    alreadyInserted: keyTagInserted
                )
                if needsKeyTag {
                    let keyTag = buildKeyTag(
                        config: config,
                        segmentIndex: segmentIndex
                    )
                    output.append(keyTag)
                    keyTagInserted = true
                }
                output.append(line)
                segmentIndex += 1
            } else {
                output.append(line)
            }
        }

        return output.joined(separator: "\n")
    }

    /// Build an `EXT-X-KEY` tag string.
    ///
    /// - Parameters:
    ///   - config: Encryption configuration.
    ///   - iv: Explicit IV data, or `nil` to omit.
    /// - Returns: Complete `EXT-X-KEY` tag line.
    public func buildKeyTag(
        config: EncryptionConfig,
        iv: Data?
    ) -> String {
        var parts: [String] = []
        parts.append("METHOD=\(config.method.rawValue)")
        parts.append("URI=\"\(config.keyURL.absoluteString)\"")

        if let iv {
            parts.append("IV=\(formatIV(iv))")
        }

        if let keyFormat = config.keyFormat {
            parts.append("KEYFORMAT=\"\(keyFormat)\"")
        }

        if let versions = config.keyFormatVersions {
            parts.append("KEYFORMATVERSIONS=\"\(versions)\"")
        }

        return "#EXT-X-KEY:\(parts.joined(separator: ","))"
    }

    // MARK: - Private

    private func buildKeyTag(
        config: EncryptionConfig,
        segmentIndex: Int
    ) -> String {
        let iv: Data?
        if let explicitIV = config.iv {
            iv = explicitIV
        } else {
            iv = nil
        }
        return buildKeyTag(config: config, iv: iv)
    }

    private func shouldInsertKeyTag(
        segmentIndex: Int,
        config: EncryptionConfig,
        alreadyInserted: Bool
    ) -> Bool {
        if !alreadyInserted {
            return true
        }
        guard let interval = config.keyRotationInterval else {
            return false
        }
        return interval > 0 && segmentIndex % interval == 0
    }

    /// Format IV data as a hex string with `0x` prefix.
    private func formatIV(_ iv: Data) -> String {
        "0x" + iv.map { String(format: "%02x", $0) }.joined()
    }
}
