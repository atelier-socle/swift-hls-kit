// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// A video resolution expressed as width by height in pixels.
///
/// Used in the `RESOLUTION` attribute of `EXT-X-STREAM-INF` and
/// `EXT-X-I-FRAME-STREAM-INF` tags (RFC 8216 Section 4.3.4.2).
public struct Resolution: Sendable, Hashable, Codable {

    /// The horizontal pixel count.
    public let width: Int

    /// The vertical pixel count.
    public let height: Int

    /// Creates a resolution with the given dimensions.
    ///
    /// - Parameters:
    ///   - width: The horizontal pixel count.
    ///   - height: The vertical pixel count.
    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

// MARK: - Presets

extension Resolution {

    /// 854 x 480 — standard definition.
    public static let p480 = Resolution(width: 854, height: 480)

    /// 1280 x 720 — HD.
    public static let p720 = Resolution(width: 1280, height: 720)

    /// 1920 x 1080 — Full HD.
    public static let p1080 = Resolution(width: 1920, height: 1080)

    /// 2560 x 1440 — QHD / 2K.
    public static let p1440 = Resolution(width: 2560, height: 1440)

    /// 3840 x 2160 — UHD / 4K.
    public static let p2160 = Resolution(width: 3840, height: 2160)
}

// MARK: - CustomStringConvertible

extension Resolution: CustomStringConvertible {

    public var description: String {
        "\(width)x\(height)"
    }
}
