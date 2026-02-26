// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Dolby Vision profile and level configuration.
///
/// Encodes the Dolby Vision profile number and level, and generates
/// the correct `SUPPLEMENTAL-CODECS` string for HLS manifests.
///
/// ```swift
/// let profile = DolbyVisionProfile.profile8_1
/// print(profile.supplementalCodecsString)  // "dvh1.08.01"
/// print(profile.isHEVCBased)               // true
/// ```
public struct DolbyVisionProfile: Sendable, Equatable, Hashable {

    /// Profile number (e.g., 5, 8, 9).
    public let profile: Int

    /// Level number (e.g., 1, 4, 6).
    public let level: Int

    /// Creates a Dolby Vision profile.
    ///
    /// - Parameters:
    ///   - profile: Profile number.
    ///   - level: Level number.
    public init(profile: Int, level: Int) {
        self.profile = profile
        self.level = level
    }

    // MARK: - Computed Properties

    /// HLS SUPPLEMENTAL-CODECS string (e.g., "dvh1.08.01").
    ///
    /// Uses `dvh1` prefix for HEVC-based profiles, `dva1` for AVC-based,
    /// and `dav1` for AV1-based profiles.
    public var supplementalCodecsString: String {
        let prefix: String
        if isAV1Based {
            prefix = "dav1"
        } else if isHEVCBased {
            prefix = "dvh1"
        } else {
            prefix = "dva1"
        }
        return String(format: "%@.%02d.%02d", prefix, profile, level)
    }

    /// Whether this profile uses HEVC base codec.
    public var isHEVCBased: Bool {
        profile >= 5 && profile != 9
    }

    /// Whether this profile uses AV1 base codec.
    public var isAV1Based: Bool {
        profile == 9
    }

    // MARK: - Common Profiles

    /// Profile 5: single-layer HEVC, 10-bit, no base layer compatibility.
    public static let profile5 = DolbyVisionProfile(profile: 5, level: 6)

    /// Profile 8.1: HEVC with HDR10 base layer, 10-bit.
    public static let profile8_1 = DolbyVisionProfile(profile: 8, level: 1)

    /// Profile 8.4: HEVC with HDR10 base layer, 12-bit.
    public static let profile8_4 = DolbyVisionProfile(profile: 8, level: 4)

    /// Profile 9: AV1-based Dolby Vision.
    public static let profile9 = DolbyVisionProfile(profile: 9, level: 1)
}
