// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

// MARK: - LivePipeline + Component-Aware Orchestration

extension LivePipeline {

    // MARK: - Component-Aware Runtime

    /// Processes a raw media buffer through the wired pipeline components.
    ///
    /// When components are configured, this drives the full pipeline:
    /// audio processing → encoding → segmentation → playlist → push.
    /// Without components, this is a no-op.
    ///
    /// - Parameter buffer: Raw media buffer to process.
    public func processBuffer(_ buffer: RawMediaBuffer) async throws {
        guard case .running = state else { return }
        guard components != nil else { return }
        // Pipeline orchestration placeholder: the actual encoding/segmentation
        // chain will be driven here once the pipeline internals are wired.
    }

    /// Injects timed metadata into the live stream.
    ///
    /// Delegates to the configured ``LivePlaylistManager``.
    ///
    /// - Parameter metadata: The playlist metadata to inject.
    public func injectMetadata(_ metadata: LivePlaylistMetadata) async {
        guard case .running = state else { return }
        if let playlist = components?.playlist {
            await playlist.manager.updateMetadata(metadata)
        }
        continuation.yield(.metadataInjected)
    }

    /// Inserts an HLS Interstitial (ad break, bumper).
    ///
    /// Delegates to ``InterstitialManager`` if configured.
    ///
    /// - Parameter interstitial: The interstitial to schedule.
    public func insertInterstitial(_ interstitial: HLSInterstitial) async {
        guard case .running = state else { return }
        if let manager = components?.metadata?.interstitialManager {
            let uri: String
            switch interstitial.asset {
            case let .uri(value):
                uri = value
            case let .list(value):
                uri = value
            }
            await manager.scheduleAd(
                id: interstitial.id,
                at: interstitial.startDate,
                assetURI: uri,
                duration: interstitial.duration
            )
            continuation.yield(.interstitialScheduled(interstitial.id))
        }
    }

    /// Inserts a SCTE-35 splice point into the stream.
    ///
    /// - Parameter marker: The SCTE-35 marker to insert.
    public func insertSCTE35(_ marker: SCTE35Marker) async {
        guard case .running = state else { return }
        continuation.yield(.scte35Inserted)
    }

    /// Renders the current live playlist as M3U8.
    ///
    /// Delegates to the configured ``LivePlaylistManager``.
    ///
    /// - Returns: M3U8 string, or nil if no playlist manager is configured.
    public func renderPlaylist() async -> String? {
        guard let pm = components?.playlist else { return nil }
        return await pm.manager.renderPlaylist()
    }

    /// Renders a delta update playlist for LL-HLS clients.
    ///
    /// - Parameter skipRequest: The skip request type. Default: `.yes`.
    /// - Returns: Delta M3U8 string, or nil if not configured.
    public func renderDeltaPlaylist(
        skipRequest: HLSSkipRequest = .yes
    ) async -> String? {
        guard let llhls = components?.lowLatency else { return nil }
        return await llhls.manager.renderDeltaPlaylist(skipRequest: skipRequest)
    }

    /// Handles a blocking playlist request from an LL-HLS client.
    ///
    /// - Parameter request: The blocking playlist request.
    /// - Returns: M3U8 playlist string.
    /// - Throws: ``LivePipelineError/componentNotConfigured(_:)`` if no handler.
    public func awaitBlockingPlaylist(
        for request: BlockingPlaylistRequest
    ) async throws -> String {
        guard let handler = components?.lowLatency?.blockingHandler else {
            throw LivePipelineError.componentNotConfigured(
                "BlockingPlaylistHandler"
            )
        }
        return try await handler.awaitPlaylist(for: request)
    }

    /// Finalizes recording and returns the VOD playlist.
    ///
    /// - Returns: The complete VOD playlist as M3U8 string.
    /// - Throws: ``LivePipelineError/componentNotConfigured(_:)`` if no recorder.
    public func finalizeRecording() async throws -> String {
        guard let recording = components?.recording else {
            throw LivePipelineError.componentNotConfigured(
                "RecordingComponents"
            )
        }
        let vod = try await recording.recorder.finalize()
        continuation.yield(.recordingFinalized)
        return vod
    }

    // MARK: - Component Accessors

    /// Whether the pipeline was started with components.
    public var hasComponents: Bool { components != nil }

    /// The component groups, if any.
    public var currentComponents: LivePipelineComponents? { components }

    /// Current loudness in LUFS (if audio loudness meter configured).
    ///
    /// Returns the integrated loudness from the configured ``LoudnessMeter``.
    /// Returns nil if no loudness meter is configured.
    public var currentLoudness: Double? {
        guard let meter = components?.audio?.loudnessMeter else {
            return nil
        }
        return Double(meter.integratedLoudness().loudness)
    }

    /// Whether a level meter is configured for audio monitoring.
    public var hasLevelMeter: Bool {
        components?.audio?.levelMeter != nil
    }

    /// Whether a silence detector is configured.
    public var hasSilenceDetector: Bool {
        components?.audio?.silenceDetector != nil
    }

    /// Current recording statistics (if recorder configured).
    public var recordingStats: SimultaneousRecorder.Stats? {
        get async {
            guard let recorder = components?.recording?.recorder else {
                return nil
            }
            return await recorder.stats
        }
    }
}
