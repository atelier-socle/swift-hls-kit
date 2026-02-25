// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("ServerControlRenderer", .timeLimit(.minutes(1)))
struct ServerControlRendererTests {

    @Test("Full render with all attributes")
    func fullRender() {
        let config = ServerControlConfig(
            canBlockReload: true,
            holdBack: 6.0,
            partHoldBack: 1.0,
            canSkipUntil: 36.0,
            canSkipDateRanges: true
        )
        let result = ServerControlRenderer.render(
            config: config,
            targetDuration: 2.0,
            partTargetDuration: 0.33
        )
        #expect(result.contains("CAN-BLOCK-RELOAD=YES"))
        #expect(result.contains("HOLD-BACK=6.0"))
        #expect(result.contains("PART-HOLD-BACK=1.0"))
        #expect(result.contains("CAN-SKIP-UNTIL=36.0"))
        #expect(result.contains("CAN-SKIP-DATERANGES=YES"))
    }

    @Test("canBlockReload=false omits CAN-BLOCK-RELOAD")
    func noBlockReload() {
        let config = ServerControlConfig(
            canBlockReload: false,
            holdBack: 6.0,
            partHoldBack: 1.0
        )
        let result = ServerControlRenderer.render(
            config: config,
            targetDuration: 2.0,
            partTargetDuration: 0.33
        )
        #expect(!result.contains("CAN-BLOCK-RELOAD"))
        #expect(result.contains("HOLD-BACK=6.0"))
    }

    @Test("Render with canSkipUntil set")
    func withSkipUntil() {
        let config = ServerControlConfig(
            holdBack: 6.0,
            partHoldBack: 1.0,
            canSkipUntil: 12.0
        )
        let result = ServerControlRenderer.render(
            config: config,
            targetDuration: 2.0,
            partTargetDuration: 0.33
        )
        #expect(result.contains("CAN-SKIP-UNTIL=12.0"))
        #expect(!result.contains("CAN-SKIP-DATERANGES"))
    }

    @Test("canSkipDateRanges without canSkipUntil is omitted")
    func dateRangesWithoutSkip() {
        let config = ServerControlConfig(
            holdBack: 6.0,
            partHoldBack: 1.0,
            canSkipDateRanges: true
        )
        let result = ServerControlRenderer.render(
            config: config,
            targetDuration: 2.0,
            partTargetDuration: 0.33
        )
        #expect(!result.contains("CAN-SKIP-DATERANGES"))
        #expect(!result.contains("CAN-SKIP-UNTIL"))
    }

    @Test("Attribute order matches spec")
    func attributeOrder() {
        let config = ServerControlConfig(
            canBlockReload: true,
            holdBack: 6.0,
            partHoldBack: 1.0,
            canSkipUntil: 36.0,
            canSkipDateRanges: true
        )
        let result = ServerControlRenderer.render(
            config: config,
            targetDuration: 2.0,
            partTargetDuration: 0.33
        )
        let blockIdx = result.range(of: "CAN-BLOCK-RELOAD")
        let holdIdx = result.range(of: "HOLD-BACK=")
        let partIdx = result.range(of: "PART-HOLD-BACK=")
        let skipIdx = result.range(of: "CAN-SKIP-UNTIL=")
        let dateIdx = result.range(of: "CAN-SKIP-DATERANGES=")

        if let b = blockIdx, let h = holdIdx {
            #expect(b.lowerBound < h.lowerBound)
        }
        if let h = holdIdx, let p = partIdx {
            #expect(h.lowerBound < p.lowerBound)
        }
        if let p = partIdx, let s = skipIdx {
            #expect(p.lowerBound < s.lowerBound)
        }
        if let s = skipIdx, let d = dateIdx {
            #expect(s.lowerBound < d.lowerBound)
        }
    }

    @Test("Decimal formatting: no trailing zeros")
    func decimalFormatting() {
        let config = ServerControlConfig(
            holdBack: 6.0,
            partHoldBack: 1.0
        )
        let result = ServerControlRenderer.render(
            config: config,
            targetDuration: 2.0,
            partTargetDuration: 0.33
        )
        #expect(result.contains("HOLD-BACK=6.0"))
        #expect(result.contains("PART-HOLD-BACK=1.0"))
    }

    @Test("Default holdbacks computed from target durations")
    func defaultHoldbacks() {
        let config = ServerControlConfig()
        let result = ServerControlRenderer.render(
            config: config,
            targetDuration: 4.0,
            partTargetDuration: 0.5
        )
        #expect(result.contains("HOLD-BACK=12.0"))
        #expect(result.contains("PART-HOLD-BACK=1.5"))
    }

    @Test("Explicit holdbacks override defaults")
    func explicitHoldbacks() {
        let config = ServerControlConfig(
            holdBack: 9.0,
            partHoldBack: 2.0
        )
        let result = ServerControlRenderer.render(
            config: config,
            targetDuration: 2.0,
            partTargetDuration: 0.33
        )
        #expect(result.contains("HOLD-BACK=9.0"))
        #expect(result.contains("PART-HOLD-BACK=2.0"))
    }

    @Test("Minimal render: defaults only, no skip")
    func minimalRender() {
        let config = ServerControlConfig()
        let result = ServerControlRenderer.render(
            config: config,
            targetDuration: 2.0,
            partTargetDuration: 0.33
        )
        #expect(result.hasPrefix("#EXT-X-SERVER-CONTROL:"))
        #expect(result.contains("CAN-BLOCK-RELOAD=YES"))
        #expect(!result.contains("CAN-SKIP-UNTIL"))
    }

    @Test("Delegates through LLHLSPlaylistRenderer")
    func playlistRendererDelegation() {
        let config = ServerControlConfig(holdBack: 6.0)
        let direct = ServerControlRenderer.render(
            config: config,
            targetDuration: 2.0,
            partTargetDuration: 0.33
        )
        let delegated = LLHLSPlaylistRenderer.renderServerControl(
            config: config,
            targetDuration: 2.0,
            partTargetDuration: 0.33
        )
        #expect(direct == delegated)
    }
}
