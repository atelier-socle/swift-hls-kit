// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// H.264/H.265 encoding profile.
///
/// Profiles define the set of coding tools available for encoding.
/// Higher profiles offer better compression but require more
/// processing power.
///
/// ## H.264 Profiles
/// - `.baseline` — Widest device support, lowest complexity
/// - `.main` — Balanced quality and compatibility
/// - `.high` — Best quality/compression ratio
///
/// ## H.265 (HEVC) Profiles
/// - `.mainHEVC` — Standard 8-bit HEVC
/// - `.main10HEVC` — 10-bit HEVC for HDR
public enum VideoProfile: String, Sendable, Hashable, Codable,
    CaseIterable
{
    /// H.264 Baseline profile — widest compatibility.
    case baseline

    /// H.264 Main profile — good balance.
    case main

    /// H.264 High profile — best compression.
    case high

    /// HEVC Main profile — standard 8-bit.
    case mainHEVC = "main-hevc"

    /// HEVC Main 10 profile — 10-bit for HDR.
    case main10HEVC = "main10-hevc"
}
