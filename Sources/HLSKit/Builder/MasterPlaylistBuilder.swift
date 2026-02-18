// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// A component that can appear in a master playlist DSL block.
public protocol MasterPlaylistComponent: Sendable {}

extension Variant: MasterPlaylistComponent {}
extension IFrameVariant: MasterPlaylistComponent {}
extension Rendition: MasterPlaylistComponent {}
extension SessionData: MasterPlaylistComponent {}
extension ContentSteering: MasterPlaylistComponent {}

/// A result builder for constructing ``MasterPlaylist`` instances
/// using a declarative DSL.
///
/// ```swift
/// let playlist = MasterPlaylist {
///     Variant(bandwidth: 800_000, resolution: .p480, uri: "480p/playlist.m3u8")
///     Variant(bandwidth: 2_800_000, resolution: .p720, uri: "720p/playlist.m3u8")
///     Variant(bandwidth: 5_000_000, resolution: .p1080, uri: "1080p/playlist.m3u8")
/// }
/// ```
@resultBuilder
public struct MasterPlaylistBuilder {

    /// Builds a master playlist from an array of components.
    public static func buildBlock(_ components: [MasterPlaylistComponent]...) -> [MasterPlaylistComponent] {
        components.flatMap { $0 }
    }

    /// Supports conditional inclusion with `if`.
    public static func buildOptional(_ component: [MasterPlaylistComponent]?) -> [MasterPlaylistComponent] {
        component ?? []
    }

    /// Supports the first branch of `if/else`.
    public static func buildEither(first component: [MasterPlaylistComponent]) -> [MasterPlaylistComponent] {
        component
    }

    /// Supports the second branch of `if/else`.
    public static func buildEither(second component: [MasterPlaylistComponent]) -> [MasterPlaylistComponent] {
        component
    }

    /// Supports `for...in` loops.
    public static func buildArray(_ components: [[MasterPlaylistComponent]]) -> [MasterPlaylistComponent] {
        components.flatMap { $0 }
    }

    /// Converts a single expression to an array.
    public static func buildExpression(_ expression: MasterPlaylistComponent) -> [MasterPlaylistComponent] {
        [expression]
    }
}

// MARK: - MasterPlaylist DSL Initializer

extension MasterPlaylist {

    /// Creates a master playlist using a result builder DSL.
    ///
    /// - Parameter builder: A closure that returns master playlist components.
    public init(@MasterPlaylistBuilder _ builder: () -> [MasterPlaylistComponent]) {
        let components = builder()
        self.init()
        for component in components {
            switch component {
            case let variant as Variant:
                self.variants.append(variant)
            case let iFrame as IFrameVariant:
                self.iFrameVariants.append(iFrame)
            case let rendition as Rendition:
                self.renditions.append(rendition)
            case let data as SessionData:
                self.sessionData.append(data)
            case let steering as ContentSteering:
                self.contentSteering = steering
            default:
                break
            }
        }
    }
}
