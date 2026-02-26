// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// CENC (Common Encryption) interoperability configuration.
///
/// Enables the same CMAF segments to be played by multiple DRM systems:
/// FairPlay (Apple), Widevine (Google/Android), PlayReady (Microsoft).
///
/// HLSKit handles manifest attributes and PSSH box metadata.
/// Actual license acquisition remains the app's responsibility.
///
/// ```swift
/// let cenc = CENCConfig(
///     systems: [.widevine, .playReady],
///     defaultKeyID: "key-001"
/// )
/// let psshData = cenc.psshBoxData(for: .widevine)
/// ```
public struct CENCConfig: Sendable, Equatable {

    /// DRM systems to support.
    public var systems: [CENCSystem]

    /// Default key ID for all systems.
    public var defaultKeyID: String

    /// License server URL template (per system).
    public var licenseServers: [CENCSystem: String]

    /// Creates a CENC configuration.
    ///
    /// - Parameters:
    ///   - systems: DRM systems to support.
    ///   - defaultKeyID: Default key ID for all systems.
    ///   - licenseServers: License server URL template per system.
    public init(
        systems: [CENCSystem],
        defaultKeyID: String,
        licenseServers: [CENCSystem: String] = [:]
    ) {
        self.systems = systems
        self.defaultKeyID = defaultKeyID
        self.licenseServers = licenseServers
    }

    // MARK: - CENCSystem

    /// Supported CENC DRM systems.
    public enum CENCSystem: String, Sendable, CaseIterable, Equatable, Hashable {

        /// Google Widevine.
        case widevine = "widevine"

        /// Microsoft PlayReady.
        case playReady = "playready"

        /// Apple FairPlay (via CBCS).
        case fairPlay = "fairplay"
    }

    // MARK: - System IDs

    /// Standard system ID UUIDs per DASH-IF.
    ///
    /// - Parameter system: The CENC DRM system.
    /// - Returns: The system ID UUID string.
    public static func systemID(for system: CENCSystem) -> String {
        switch system {
        case .widevine:
            return "edef8ba9-79d6-4ace-a3c8-27dcd51d21ed"
        case .playReady:
            return "9a04f079-9840-4286-ab92-e65be0885f95"
        case .fairPlay:
            return "94ce86fb-07ff-4f43-adb8-93d2fa968ca2"
        }
    }

    // MARK: - PSSH Box

    /// Generate PSSH box metadata for a given system.
    ///
    /// Returns the raw bytes for embedding in fMP4 init segments.
    /// This is a minimal PSSH box containing the system ID and key ID.
    ///
    /// - Parameters:
    ///   - system: The DRM system.
    ///   - keyID: Optional key ID override (defaults to ``defaultKeyID``).
    /// - Returns: PSSH box data.
    public func psshBoxData(
        for system: CENCSystem,
        keyID: String? = nil
    ) -> Data {
        let resolvedKeyID = keyID ?? defaultKeyID
        let systemIDString = Self.systemID(for: system)
        let systemIDBytes = uuidBytes(from: systemIDString)
        let keyIDData = Data(resolvedKeyID.utf8)

        // PSSH box layout: [size(4)][type(4)][version+flags(4)][systemID(16)][dataSize(4)][data]
        var box = Data()
        let psshType = Data([0x70, 0x73, 0x73, 0x68])  // "pssh"
        let versionAndFlags = Data([0x00, 0x00, 0x00, 0x00])

        var dataSize = UInt32(keyIDData.count).bigEndian
        let dataSizeData = Data(bytes: &dataSize, count: 4)

        let totalSize = 4 + 4 + 4 + 16 + 4 + keyIDData.count
        var size = UInt32(totalSize).bigEndian
        let sizeData = Data(bytes: &size, count: 4)

        box.append(sizeData)
        box.append(psshType)
        box.append(versionAndFlags)
        box.append(systemIDBytes)
        box.append(dataSizeData)
        box.append(keyIDData)

        return box
    }

    // MARK: - Key Format

    /// KEYFORMAT string for a CENC system in HLS.
    ///
    /// - Parameter system: The CENC DRM system.
    /// - Returns: The KEYFORMAT attribute value.
    public static func keyFormat(for system: CENCSystem) -> String {
        switch system {
        case .widevine:
            return "urn:uuid:edef8ba9-79d6-4ace-a3c8-27dcd51d21ed"
        case .playReady:
            return "urn:uuid:9a04f079-9840-4286-ab92-e65be0885f95"
        case .fairPlay:
            return "com.apple.streamingkeydelivery"
        }
    }

    // MARK: - Helpers

    /// Convert a UUID string to 16 bytes.
    private func uuidBytes(from uuidString: String) -> Data {
        let hex = uuidString.replacingOccurrences(of: "-", with: "")
        var bytes = Data(capacity: 16)
        var index = hex.startIndex
        for _ in 0..<16 {
            let nextIndex = hex.index(index, offsetBy: 2)
            if let byte = UInt8(hex[index..<nextIndex], radix: 16) {
                bytes.append(byte)
            }
            index = nextIndex
        }
        return bytes
    }
}
