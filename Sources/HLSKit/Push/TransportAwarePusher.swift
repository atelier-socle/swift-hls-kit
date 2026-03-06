// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Wraps a ``SegmentPusher`` and exposes transport health signals
/// to ``LivePipeline``.
///
/// Works with any pusher whose transport conforms to
/// ``QualityAwareTransport`` and/or ``AdaptiveBitrateTransport``.
/// This actor delegates all ``SegmentPusher`` methods to the
/// inner pusher and enriches the API with quality, events, and
/// ABR recommendation accessors.
///
/// Existentials (`any SegmentPusher`, `any QualityAwareTransport`,
/// `any AdaptiveBitrateTransport`) are justified here — this actor
/// is a type-erasing wrapper that must accept heterogeneous
/// pusher/transport types at runtime.
public actor TransportAwarePusher: SegmentPusher {

    /// The wrapped segment pusher.
    private let inner: any SegmentPusher

    /// Quality-aware transport reference (nil if transport
    /// doesn't support quality).
    private let qualityTransport: (any QualityAwareTransport)?

    /// ABR transport reference (nil if transport doesn't
    /// support ABR).
    private let abrTransport: (any AdaptiveBitrateTransport)?

    /// Stream of transport events from the quality-aware transport.
    ///
    /// Returns an active stream if a ``QualityAwareTransport``
    /// was provided, otherwise an empty completed stream.
    public nonisolated let transportEvents: AsyncStream<TransportEvent>

    /// Creates a transport-aware pusher wrapping an existing pusher.
    ///
    /// - Parameters:
    ///   - pusher: The segment pusher to wrap.
    ///   - qualityTransport: Quality-aware transport for health
    ///     signals. Pass `nil` if the transport doesn't support
    ///     quality reporting.
    ///   - abrTransport: Adaptive bitrate transport for bitrate
    ///     recommendations. Pass `nil` if the transport doesn't
    ///     support ABR.
    public init(
        pusher: any SegmentPusher,
        qualityTransport: (any QualityAwareTransport)? = nil,
        abrTransport: (any AdaptiveBitrateTransport)? = nil
    ) {
        self.inner = pusher
        self.qualityTransport = qualityTransport
        self.abrTransport = abrTransport

        if let qt = qualityTransport {
            self.transportEvents = qt.transportEvents
        } else {
            self.transportEvents = AsyncStream { $0.finish() }
        }
    }

    // MARK: - SegmentPusher Conformance

    /// Push a completed live segment. Delegates to the inner pusher.
    public func push(
        segment: LiveSegment, as filename: String
    ) async throws {
        try await inner.push(segment: segment, as: filename)
    }

    /// Push a partial segment (LL-HLS). Delegates to the inner
    /// pusher.
    public func push(
        partial: LLPartialSegment, as filename: String
    ) async throws {
        try await inner.push(partial: partial, as: filename)
    }

    /// Push an updated playlist. Delegates to the inner pusher.
    public func pushPlaylist(
        _ m3u8: String, as filename: String
    ) async throws {
        try await inner.pushPlaylist(m3u8, as: filename)
    }

    /// Push an init segment. Delegates to the inner pusher.
    public func pushInitSegment(
        _ data: Data, as filename: String
    ) async throws {
        try await inner.pushInitSegment(data, as: filename)
    }

    /// Current connection state from the inner pusher.
    public var connectionState: PushConnectionState {
        get async {
            await inner.connectionState
        }
    }

    /// Current push statistics from the inner pusher.
    public var stats: PushStats {
        get async {
            await inner.stats
        }
    }

    /// Connect to the push destination. Delegates to the inner
    /// pusher.
    public func connect() async throws {
        try await inner.connect()
    }

    /// Disconnect from the push destination. Delegates to the
    /// inner pusher.
    public func disconnect() async {
        await inner.disconnect()
    }

    // MARK: - Transport-Aware Additions

    /// Current transport quality, if available.
    ///
    /// Returns `nil` when no ``QualityAwareTransport`` was provided.
    public var transportQuality: TransportQuality? {
        get async {
            guard let qt = qualityTransport else { return nil }
            return await qt.connectionQuality
        }
    }

    /// Latest bitrate recommendation from the ABR transport.
    ///
    /// Returns `nil` if no ``AdaptiveBitrateTransport`` was
    /// provided. When available, collects the most recent
    /// recommendation from the ABR stream.
    public var latestBitrateRecommendation: TransportBitrateRecommendation? {
        get async {
            guard let abr = abrTransport else { return nil }
            var latest: TransportBitrateRecommendation?
            for await recommendation in abr.bitrateRecommendations {
                latest = recommendation
                break
            }
            return latest
        }
    }
}
