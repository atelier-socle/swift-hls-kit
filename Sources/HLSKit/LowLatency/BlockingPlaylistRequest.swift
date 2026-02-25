// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Represents an LL-HLS blocking playlist reload request.
///
/// Parsed from query parameters: `_HLS_msn=47&_HLS_part=3`.
///
/// Per RFC 8216bis §6.2.5.2: if the client provides `_HLS_msn`
/// (and optionally `_HLS_part`), the server must not respond
/// until the playlist contains that segment/partial, or until
/// a server-defined timeout.
///
/// ## Usage
/// ```swift
/// let request = BlockingPlaylistRequest(
///     mediaSequenceNumber: 47,
///     partIndex: 3
/// )
/// let playlist = try await handler.awaitPlaylist(for: request)
/// ```
public struct BlockingPlaylistRequest: Sendable, Hashable {

    /// Media Sequence Number requested (`_HLS_msn`).
    public let mediaSequenceNumber: Int

    /// Partial index requested (`_HLS_part`).
    ///
    /// If present, the client wants a playlist that contains this
    /// specific partial of the segment identified by `_HLS_msn`.
    public let partIndex: Int?

    /// Whether this also requests a delta update (`_HLS_skip`).
    public let skipRequest: HLSSkipRequest?

    /// Creates a blocking playlist request.
    ///
    /// - Parameters:
    ///   - mediaSequenceNumber: The `_HLS_msn` value.
    ///   - partIndex: The `_HLS_part` value. Default `nil`.
    ///   - skipRequest: The `_HLS_skip` value. Default `nil`.
    public init(
        mediaSequenceNumber: Int,
        partIndex: Int? = nil,
        skipRequest: HLSSkipRequest? = nil
    ) {
        self.mediaSequenceNumber = mediaSequenceNumber
        self.partIndex = partIndex
        self.skipRequest = skipRequest
    }

    /// Create from URL query parameters.
    ///
    /// Expects `_HLS_msn` (required), `_HLS_part` (optional),
    /// and `_HLS_skip` (optional).
    ///
    /// - Parameter params: Dictionary of query parameter key-values.
    /// - Returns: A request, or `nil` if `_HLS_msn` is absent or
    ///   not a valid integer.
    public static func fromQueryParameters(
        _ params: [String: String]
    ) -> BlockingPlaylistRequest? {
        guard let msnStr = params["_HLS_msn"],
            let msn = Int(msnStr)
        else { return nil }

        let partIndex = params["_HLS_part"].flatMap(Int.init)
        let skip = params["_HLS_skip"].flatMap(HLSSkipRequest.init)

        return BlockingPlaylistRequest(
            mediaSequenceNumber: msn,
            partIndex: partIndex,
            skipRequest: skip
        )
    }
}
