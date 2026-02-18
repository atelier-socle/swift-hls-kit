// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// A component that can appear in a media playlist DSL block.
public protocol MediaPlaylistComponent: Sendable {}

extension Segment: MediaPlaylistComponent {}
extension DateRange: MediaPlaylistComponent {}

/// A result builder for constructing ``MediaPlaylist`` instances
/// using a declarative DSL.
///
/// ```swift
/// let playlist = MediaPlaylist(targetDuration: 6) {
///     Segment(duration: 6.006, uri: "segment001.ts")
///     Segment(duration: 5.839, uri: "segment002.ts")
///     Segment(duration: 6.006, uri: "segment003.ts")
/// }
/// ```
@resultBuilder
public struct MediaPlaylistBuilder {

    /// Builds a media playlist from an array of components.
    public static func buildBlock(_ components: [MediaPlaylistComponent]...) -> [MediaPlaylistComponent] {
        components.flatMap { $0 }
    }

    /// Supports conditional inclusion with `if`.
    public static func buildOptional(_ component: [MediaPlaylistComponent]?) -> [MediaPlaylistComponent] {
        component ?? []
    }

    /// Supports the first branch of `if/else`.
    public static func buildEither(first component: [MediaPlaylistComponent]) -> [MediaPlaylistComponent] {
        component
    }

    /// Supports the second branch of `if/else`.
    public static func buildEither(second component: [MediaPlaylistComponent]) -> [MediaPlaylistComponent] {
        component
    }

    /// Supports `for...in` loops.
    public static func buildArray(_ components: [[MediaPlaylistComponent]]) -> [MediaPlaylistComponent] {
        components.flatMap { $0 }
    }

    /// Converts a single expression to an array.
    public static func buildExpression(_ expression: MediaPlaylistComponent) -> [MediaPlaylistComponent] {
        [expression]
    }
}

// MARK: - MediaPlaylist DSL Initializer

extension MediaPlaylist {

    /// Creates a media playlist using a result builder DSL.
    ///
    /// - Parameters:
    ///   - targetDuration: The maximum segment duration.
    ///   - playlistType: The optional playlist type.
    ///   - version: The optional HLS version.
    ///   - builder: A closure that returns media playlist components.
    public init(
        targetDuration: Int,
        playlistType: PlaylistType? = nil,
        version: HLSVersion? = nil,
        @MediaPlaylistBuilder _ builder: () -> [MediaPlaylistComponent]
    ) {
        let components = builder()
        self.init(version: version, targetDuration: targetDuration, playlistType: playlistType)
        for component in components {
            switch component {
            case let segment as Segment:
                self.segments.append(segment)
            case let dateRange as DateRange:
                self.dateRanges.append(dateRange)
            default:
                break
            }
        }
    }
}
