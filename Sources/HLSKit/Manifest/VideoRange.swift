// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// HLS VIDEO-RANGE attribute values.
///
/// Indicates the dynamic range of the video content in a variant stream.
/// Per Apple HLS spec, if VIDEO-RANGE is absent, SDR is assumed.
///
/// See RFC 8216bis and Apple HLS Authoring Specification.
public enum VideoRange: String, Sendable, Hashable, Codable, CaseIterable {

    /// Standard Dynamic Range video.
    case sdr = "SDR"

    /// Perceptual Quantizer (SMPTE ST 2084) for HDR10 and Dolby Vision.
    case pq = "PQ"

    /// Hybrid Log-Gamma for broadcast HDR.
    case hlg = "HLG"
}
