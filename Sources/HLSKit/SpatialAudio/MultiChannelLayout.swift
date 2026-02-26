// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Standard audio channel layouts with HLS mapping.
///
/// Provides mapping between channel configurations, CoreAudio layout tags,
/// and HLS `CHANNELS` attribute values per RFC 8216bis.
///
/// ```swift
/// let layout = MultiChannelLayout.surround5_1
/// print(layout.channelCount)          // 6
/// print(layout.hlsChannelsAttribute)  // "6"
///
/// let atmos = MultiChannelLayout.atmos7_1_4
/// print(atmos.hlsChannelsAttribute)   // "16/JOC"
/// ```
public struct MultiChannelLayout: Sendable, Equatable, Hashable {

    /// Layout identifier.
    public let identifier: LayoutIdentifier

    /// Standard layout identifiers.
    public enum LayoutIdentifier: String, Sendable, CaseIterable, Equatable, Hashable {
        /// Mono (C).
        case mono
        /// Stereo (L, R).
        case stereo
        /// 3.0 surround (L, R, C).
        case surround3_0
        /// 4.0 surround (L, R, C, Cs).
        case surround4_0
        /// 5.0 surround (L, R, C, Ls, Rs).
        case surround5_0
        /// 5.1 surround (L, R, C, LFE, Ls, Rs).
        case surround5_1
        /// 6.1 surround (L, R, C, LFE, Ls, Rs, Cs).
        case surround6_1
        /// 7.1 surround (L, R, C, LFE, Ls, Rs, Lrs, Rrs).
        case surround7_1
        /// 7.1.4 Atmos bed (L, R, C, LFE, Ls, Rs, Lrs, Rrs, Ltf, Rtf, Ltb, Rtb).
        case atmos7_1_4
    }

    /// Creates a layout from its identifier.
    ///
    /// - Parameter identifier: The layout identifier.
    public init(identifier: LayoutIdentifier) {
        self.identifier = identifier
    }

    // MARK: - Computed Properties

    /// Number of discrete audio channels.
    public var channelCount: Int {
        switch identifier {
        case .mono: 1
        case .stereo: 2
        case .surround3_0: 3
        case .surround4_0: 4
        case .surround5_0: 5
        case .surround5_1: 6
        case .surround6_1: 7
        case .surround7_1: 8
        case .atmos7_1_4: 12
        }
    }

    /// HLS CHANNELS attribute string.
    ///
    /// Returns `"2"` for stereo, `"6"` for 5.1, `"8"` for 7.1,
    /// `"16/JOC"` for Atmos per RFC 8216bis.
    public var hlsChannelsAttribute: String {
        switch identifier {
        case .atmos7_1_4: "16/JOC"
        default: "\(channelCount)"
        }
    }

    /// Whether this layout requires object-based coding (Atmos).
    public var isObjectBased: Bool {
        identifier == .atmos7_1_4
    }

    /// Whether this layout is surround (more than 2 channels).
    public var isSurround: Bool {
        channelCount > 2
    }

    /// Channel names for each position in this layout.
    public var channelNames: [String] {
        switch identifier {
        case .mono:
            ["C"]
        case .stereo:
            ["L", "R"]
        case .surround3_0:
            ["L", "R", "C"]
        case .surround4_0:
            ["L", "R", "C", "Cs"]
        case .surround5_0:
            ["L", "R", "C", "Ls", "Rs"]
        case .surround5_1:
            ["L", "R", "C", "LFE", "Ls", "Rs"]
        case .surround6_1:
            ["L", "R", "C", "LFE", "Ls", "Rs", "Cs"]
        case .surround7_1:
            ["L", "R", "C", "LFE", "Ls", "Rs", "Lrs", "Rrs"]
        case .atmos7_1_4:
            [
                "L", "R", "C", "LFE", "Ls", "Rs", "Lrs", "Rrs",
                "Ltf", "Rtf", "Ltb", "Rtb"
            ]
        }
    }

    /// Validates whether a source layout can be encoded to a target layout.
    ///
    /// Encoding to a layout with fewer channels is allowed (downmix).
    /// Encoding to a layout with more channels requires the source to have
    /// at least as many channels as the target.
    ///
    /// - Parameter target: The target layout.
    /// - Returns: Whether encoding from this layout to the target is valid.
    public func canEncode(to target: MultiChannelLayout) -> Bool {
        channelCount >= target.channelCount
    }

    // MARK: - Standard Layouts

    /// Mono layout (1 channel).
    public static let mono = MultiChannelLayout(identifier: .mono)
    /// Stereo layout (2 channels).
    public static let stereo = MultiChannelLayout(identifier: .stereo)
    /// 3.0 surround layout (3 channels).
    public static let surround3_0 = MultiChannelLayout(identifier: .surround3_0)
    /// 4.0 surround layout (4 channels).
    public static let surround4_0 = MultiChannelLayout(identifier: .surround4_0)
    /// 5.0 surround layout (5 channels).
    public static let surround5_0 = MultiChannelLayout(identifier: .surround5_0)
    /// 5.1 surround layout (6 channels).
    public static let surround5_1 = MultiChannelLayout(identifier: .surround5_1)
    /// 6.1 surround layout (7 channels).
    public static let surround6_1 = MultiChannelLayout(identifier: .surround6_1)
    /// 7.1 surround layout (8 channels).
    public static let surround7_1 = MultiChannelLayout(identifier: .surround7_1)
    /// 7.1.4 Atmos bed layout (12 channels).
    public static let atmos7_1_4 = MultiChannelLayout(identifier: .atmos7_1_4)
}
