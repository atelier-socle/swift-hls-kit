// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Manages the lifecycle of partial segments within a live LL-HLS stream.
///
/// Tracks partial segments for the current (in-progress) segment and
/// retains partials for recently completed segments so they can be
/// included in the playlist rendering window.
///
/// ## Lifecycle
/// 1. Call ``addPartial(duration:uri:isIndependent:isGap:byteRange:)``
///    for each sub-segment chunk.
/// 2. Call ``completeSegment()`` when the full segment is finalized.
/// 3. Repeat for subsequent segments.
///
/// ## Eviction
/// When the number of retained segment histories exceeds
/// ``maxRetainedSegments``, the oldest segment's partials are evicted.
///
/// ## Thread safety
/// This is an actor — all methods are safe to call concurrently.
public actor PartialSegmentManager {

    /// Target partial duration from configuration.
    public let partTargetDuration: TimeInterval

    /// Maximum partials allowed per segment.
    public let maxPartialsPerSegment: Int

    /// How many completed segments' partials to retain.
    public let maxRetainedSegments: Int

    /// URI template for auto-generated URIs.
    public let uriTemplate: String

    /// File extension for URI template resolution.
    public let fileExtension: String

    // MARK: - State

    private var currentSegmentIndex: Int
    private var currentPartials: [LLPartialSegment] = []
    private var recentPartials: [Int: [LLPartialSegment]] = [:]
    private var retainedOrder: [Int] = []
    private var hasEnded = false

    /// Creates a partial segment manager.
    ///
    /// - Parameters:
    ///   - partTargetDuration: Target partial duration in seconds.
    ///   - maxPartialsPerSegment: Max partials per segment.
    ///   - maxRetainedSegments: Completed segments to retain.
    ///   - startSegmentIndex: Initial segment index. Default `0`.
    ///   - uriTemplate: URI template. Default `"seg{segment}.{part}.{ext}"`.
    ///   - fileExtension: File extension for template. Default `"mp4"`.
    public init(
        partTargetDuration: TimeInterval = 0.33334,
        maxPartialsPerSegment: Int = 6,
        maxRetainedSegments: Int = 3,
        startSegmentIndex: Int = 0,
        uriTemplate: String = "seg{segment}.{part}.{ext}",
        fileExtension: String = "mp4"
    ) {
        self.partTargetDuration = partTargetDuration
        self.maxPartialsPerSegment = maxPartialsPerSegment
        self.maxRetainedSegments = maxRetainedSegments
        self.currentSegmentIndex = startSegmentIndex
        self.uriTemplate = uriTemplate
        self.fileExtension = fileExtension
    }

    // MARK: - API

    /// Add a partial segment to the current in-progress segment.
    ///
    /// The first partial of each segment must have `isIndependent = true`.
    ///
    /// - Parameters:
    ///   - duration: Duration in seconds.
    ///   - uri: URI for the partial. Auto-generated from template if `nil`.
    ///   - isIndependent: Whether it starts with an IDR frame.
    ///   - isGap: Whether this is a GAP partial.
    ///   - byteRange: Optional byte range.
    /// - Returns: The created partial segment.
    /// - Throws: ``LLHLSError/firstPartialMustBeIndependent``
    ///   if the first partial is not independent.
    @discardableResult
    public func addPartial(
        duration: TimeInterval,
        uri: String? = nil,
        isIndependent: Bool,
        isGap: Bool = false,
        byteRange: ByteRange? = nil
    ) throws -> LLPartialSegment {
        guard !hasEnded else {
            throw LLHLSError.streamAlreadyEnded
        }

        let partialIndex = currentPartials.count

        if partialIndex == 0 && !isIndependent {
            throw LLHLSError.firstPartialMustBeIndependent
        }

        let resolvedURI =
            uri
            ?? resolveURI(
                segmentIndex: currentSegmentIndex,
                partialIndex: partialIndex
            )

        let partial = LLPartialSegment(
            duration: duration,
            uri: resolvedURI,
            isIndependent: isIndependent,
            isGap: isGap,
            byteRange: byteRange,
            segmentIndex: currentSegmentIndex,
            partialIndex: partialIndex
        )

        currentPartials.append(partial)
        return partial
    }

    /// Complete the current segment.
    ///
    /// Moves current partials to the retained history, advances
    /// the segment index, and evicts the oldest retained segment
    /// if at capacity.
    ///
    /// - Returns: The partials belonging to the completed segment.
    @discardableResult
    public func completeSegment() -> [LLPartialSegment] {
        let completed = currentPartials

        if !completed.isEmpty {
            recentPartials[currentSegmentIndex] = completed
            retainedOrder.append(currentSegmentIndex)
            evictIfNeeded()
        }

        currentPartials = []
        currentSegmentIndex += 1
        return completed
    }

    /// Get all partials that should appear in the current playlist.
    ///
    /// Returns retained segment partials plus the current in-progress
    /// segment's partials, ordered by segment index.
    ///
    /// - Returns: Tuples of (segmentIndex, partials) in ascending order.
    public func partialsForRendering()
        -> [(segmentIndex: Int, partials: [LLPartialSegment])]
    {
        var result: [(segmentIndex: Int, partials: [LLPartialSegment])] =
            []

        for idx in retainedOrder {
            if let partials = recentPartials[idx] {
                result.append((segmentIndex: idx, partials: partials))
            }
        }

        if !currentPartials.isEmpty {
            result.append(
                (
                    segmentIndex: currentSegmentIndex,
                    partials: currentPartials
                ))
        }

        return result
    }

    /// Generate the current preload hint for the next expected partial.
    ///
    /// Points to the next partial in the current segment, or
    /// the first partial of the next segment if the current segment
    /// has reached max partials.
    ///
    /// - Returns: A preload hint, or `nil` if the stream has ended.
    public func currentPreloadHint() -> PreloadHint? {
        guard !hasEnded else { return nil }

        let nextPartialIndex = currentPartials.count
        let segIdx: Int
        let partIdx: Int

        if nextPartialIndex >= maxPartialsPerSegment {
            segIdx = currentSegmentIndex + 1
            partIdx = 0
        } else {
            segIdx = currentSegmentIndex
            partIdx = nextPartialIndex
        }

        let uri = resolveURI(
            segmentIndex: segIdx, partialIndex: partIdx
        )

        return PreloadHint(type: .part, uri: uri)
    }

    /// Mark the stream as ended.
    public func end() {
        hasEnded = true
    }

    // MARK: - Accessors

    /// Total number of partials across retained + current.
    public var totalPartialCount: Int {
        let retainedCount = recentPartials.values.reduce(0) {
            $0 + $1.count
        }
        return retainedCount + currentPartials.count
    }

    /// Number of partials in the current in-progress segment.
    public var currentPartialCount: Int {
        currentPartials.count
    }

    /// Current segment index being built.
    public var activeSegmentIndex: Int {
        currentSegmentIndex
    }

    /// Whether the stream has ended.
    public var isEnded: Bool {
        hasEnded
    }

    // MARK: - Private

    private func evictIfNeeded() {
        while retainedOrder.count > maxRetainedSegments {
            let oldest = retainedOrder.removeFirst()
            recentPartials.removeValue(forKey: oldest)
        }
    }

    private func resolveURI(
        segmentIndex: Int, partialIndex: Int
    ) -> String {
        uriTemplate
            .replacingOccurrences(
                of: "{segment}", with: "\(segmentIndex)"
            )
            .replacingOccurrences(
                of: "{part}", with: "\(partialIndex)"
            )
            .replacingOccurrences(
                of: "{ext}", with: fileExtension
            )
    }
}
