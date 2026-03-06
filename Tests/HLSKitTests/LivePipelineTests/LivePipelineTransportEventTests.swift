// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite(
    "LivePipeline — Transport Events",
    .timeLimit(.minutes(1))
)
struct LivePipelineTransportEventTests {

    // MARK: - New Event Construction & Pattern Matching

    @Test("transportQualityDegraded event construction")
    func qualityDegradedEvent() {
        let quality = TransportQuality(
            score: 0.25,
            grade: .critical,
            recommendation: "reduce bitrate",
            timestamp: Date()
        )
        let event = LivePipelineEvent.transportQualityDegraded(
            destination: "Twitch", quality: quality
        )
        if case let .transportQualityDegraded(dest, q) = event {
            #expect(dest == "Twitch")
            #expect(q.grade == .critical)
            #expect(q.score == 0.25)
        } else {
            Issue.record("Expected transportQualityDegraded")
        }
    }

    @Test("transportBitrateAdjusted event construction")
    func bitrateAdjustedEvent() {
        let event = LivePipelineEvent.transportBitrateAdjusted(
            oldBitrate: 256_000,
            newBitrate: 128_000,
            reason: "congestion detected"
        )
        if case let .transportBitrateAdjusted(old, new, reason) =
            event
        {
            #expect(old == 256_000)
            #expect(new == 128_000)
            #expect(reason == "congestion detected")
        } else {
            Issue.record("Expected transportBitrateAdjusted")
        }
    }

    @Test("transportDestinationFailed event construction")
    func destinationFailedEvent() {
        let event = LivePipelineEvent.transportDestinationFailed(
            destination: "YouTube",
            error: "Connection refused"
        )
        if case let .transportDestinationFailed(dest, err) = event {
            #expect(dest == "YouTube")
            #expect(err == "Connection refused")
        } else {
            Issue.record("Expected transportDestinationFailed")
        }
    }

    @Test("transportHealthUpdate event construction")
    func healthUpdateEvent() {
        let dashboard = TransportHealthDashboard(destinations: [])
        let event = LivePipelineEvent.transportHealthUpdate(
            dashboard
        )
        if case let .transportHealthUpdate(d) = event {
            #expect(d.overallGrade == .critical)
            #expect(d.destinations.isEmpty)
        } else {
            Issue.record("Expected transportHealthUpdate")
        }
    }

    // MARK: - Existing Events Regression

    @Test("Existing 16 event cases still work")
    func existingEventCasesRegression() {
        let events: [LivePipelineEvent] = [
            .stateChanged(.idle),
            .segmentProduced(
                index: 0, duration: 6.0, byteSize: 1024
            ),
            .pushCompleted(
                destination: "CDN", segmentIndex: 0,
                latency: 0.5
            ),
            .pushFailed(
                destination: "CDN", error: "timeout"
            ),
            .pushSucceeded(
                destination: "CDN", bytesSent: 2048
            ),
            .metadataInserted(type: "ID3"),
            .metadataInjected,
            .interstitialScheduled("ad-break-1"),
            .scte35Inserted,
            .discontinuityInserted,
            .recordingSegmentSaved(filename: "rec_001.ts"),
            .recordingFinalized,
            .silenceDetected(duration: 5.0),
            .loudnessUpdate(lufs: -23.0),
            .warning("low bandwidth"),
            .componentWarning("missing encoder")
        ]
        #expect(events.count == 16)
    }

    // MARK: - LivePipelineConfiguration + Transport Policy

    @Test("LivePipelineConfiguration with transportPolicy set")
    func configWithTransportPolicy() {
        var config = LivePipelineConfiguration()
        config.transportPolicy = .default
        #expect(config.transportPolicy != nil)
        #expect(config.transportPolicy?.autoAdjustBitrate == true)
    }

    @Test("LivePipelineConfiguration backward compat — default nil")
    func configBackwardCompat() {
        let config = LivePipelineConfiguration()
        #expect(config.transportPolicy == nil)
    }

    @Test("LivePipelineConfiguration Equatable with transportPolicy")
    func configEquatableWithPolicy() {
        var a = LivePipelineConfiguration()
        a.transportPolicy = .default
        var b = LivePipelineConfiguration()
        b.transportPolicy = .default
        #expect(a == b)

        var c = LivePipelineConfiguration()
        c.transportPolicy = .disabled
        #expect(a != c)
    }

    @Test("LivePipelineConfiguration validate still works with transportPolicy")
    func configValidateWithPolicy() {
        var config = LivePipelineConfiguration()
        config.transportPolicy = .default
        #expect(config.validate() == nil)
    }
}
