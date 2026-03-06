// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// A strongly typed wrapper for `SUPPLEMENTAL-CODECS` values.
///
/// Provides common presets for Dolby Vision profiles used with MV-HEVC.
///
/// ```swift
/// let codecs = SupplementalCodecs.dolbyVisionProfile20
/// print(codecs)  // "dvh1.20.09/db4h"
/// ```
public struct SupplementalCodecs: Sendable, Equatable, CustomStringConvertible {

    /// The raw supplemental codecs string value.
    public let value: String

    /// Creates a supplemental codecs wrapper.
    ///
    /// - Parameter value: The raw codecs string.
    public init(_ value: String) {
        self.value = value
    }

    /// A textual representation matching the raw value.
    public var description: String { value }

    /// Dolby Vision Profile 20 (MV-HEVC stereo).
    public static var dolbyVisionProfile20: Self {
        Self("dvh1.20.09/db4h")
    }

    /// Dolby Vision Profile 8 (single-layer HDR).
    public static var dolbyVisionProfile8: Self {
        Self("dvh1.08.09/db4h")
    }
}
