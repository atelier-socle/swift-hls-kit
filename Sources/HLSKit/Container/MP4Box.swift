// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Represents an ISOBMFF box (atom) in an MP4 file.
///
/// An MP4 file is a tree of boxes. Container boxes (moov, trak, etc.)
/// hold child boxes. Leaf boxes hold raw payload data.
///
/// - SeeAlso: ISO 14496-12, Section 4.2
public struct MP4Box: Sendable, Hashable {

    /// The 4-character box type code (e.g., "moov", "trak", "mdat").
    public let type: String

    /// Total size of the box in bytes (including header).
    public let size: UInt64

    /// Offset of the box start in the file.
    public let offset: UInt64

    /// Size of the box header (8 for standard, 16 for extended).
    public let headerSize: Int

    /// The raw payload data (excluding header).
    ///
    /// Nil for container boxes (children are parsed instead)
    /// and for large leaf boxes like mdat.
    public let payload: Data?

    /// Child boxes (for container boxes like moov, trak, mdia, etc.).
    public let children: [MP4Box]

    /// Data offset (start of payload = offset + headerSize).
    public var dataOffset: UInt64 {
        offset + UInt64(headerSize)
    }

    /// Data size (payload size = size - headerSize).
    public var dataSize: UInt64 {
        size - UInt64(headerSize)
    }
}

// MARK: - Box Type Constants

extension MP4Box {

    /// Well-known ISOBMFF box type codes.
    enum BoxType {

        // File level
        static let ftyp = "ftyp"
        static let moov = "moov"
        static let mdat = "mdat"
        static let free = "free"
        static let skip = "skip"

        // Movie
        static let mvhd = "mvhd"
        static let trak = "trak"
        static let mvex = "mvex"
        static let trex = "trex"

        // Track
        static let tkhd = "tkhd"
        static let edts = "edts"
        static let elst = "elst"
        static let mdia = "mdia"

        // Media
        static let mdhd = "mdhd"
        static let hdlr = "hdlr"
        static let minf = "minf"

        // Media information
        static let vmhd = "vmhd"
        static let smhd = "smhd"
        static let dinf = "dinf"
        static let dref = "dref"
        static let stbl = "stbl"

        // Sample table
        static let stsd = "stsd"
        static let stts = "stts"
        static let ctts = "ctts"
        static let stsc = "stsc"
        static let stsz = "stsz"
        static let stco = "stco"
        static let co64 = "co64"
        static let stss = "stss"
        static let sgpd = "sgpd"
        static let sbgp = "sbgp"

        // Fragmented MP4
        static let moof = "moof"
        static let mfhd = "mfhd"
        static let traf = "traf"
        static let tfhd = "tfhd"
        static let tfdt = "tfdt"
        static let trun = "trun"
        static let styp = "styp"

        /// Box types that are containers (have children, not raw payload).
        static let containerTypes: Set<String> = [
            moov, trak, mdia, minf, stbl, dinf, edts,
            mvex, moof, traf
        ]
    }
}

// MARK: - Hierarchy Navigation

extension MP4Box {

    /// Find the first child box with the given type.
    ///
    /// - Parameter type: The 4-character box type to find.
    /// - Returns: The first matching child, or nil.
    public func findChild(_ type: String) -> MP4Box? {
        children.first { $0.type == type }
    }

    /// Find all child boxes with the given type.
    ///
    /// - Parameter type: The 4-character box type to find.
    /// - Returns: All matching children.
    public func findChildren(_ type: String) -> [MP4Box] {
        children.filter { $0.type == type }
    }

    /// Find a box by path (e.g., "moov/trak/mdia/hdlr").
    ///
    /// Traverses the hierarchy using first-child-match at each level.
    ///
    /// - Parameter path: Slash-separated box type path.
    /// - Returns: The box at the end of the path, or nil.
    public func findByPath(_ path: String) -> MP4Box? {
        let components = path.split(separator: "/")
        var current: MP4Box? = self
        for component in components {
            current = current?.findChild(String(component))
        }
        return current
    }

    /// Find all track boxes (direct trak children).
    public var tracks: [MP4Box] {
        findChildren(BoxType.trak)
    }
}
