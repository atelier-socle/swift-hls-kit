// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

@Suite("VideoProjection")
struct VideoProjectionTests {

    @Test("Raw values for all projection types")
    func rawValues() {
        #expect(VideoProjection.rectilinear.rawValue == "PROJ-RECT")
        #expect(VideoProjection.equirectangular.rawValue == "PROJ-EQUI")
        #expect(VideoProjection.halfEquirectangular.rawValue == "PROJ-HEQU")
        #expect(VideoProjection.primary.rawValue == "PROJ-PRIM")
        #expect(VideoProjection.appleImmersiveVideo.rawValue == "PROJ-AIV")
    }

    @Test("CaseIterable includes all 5 cases")
    func caseIterable() {
        let allCases = VideoProjection.allCases
        #expect(allCases.count == 5)
    }

    @Test("Equatable conformance")
    func equatable() {
        #expect(VideoProjection.equirectangular == .equirectangular)
        #expect(VideoProjection.rectilinear != .appleImmersiveVideo)
    }

    @Test("Init from raw value")
    func initFromRawValue() {
        #expect(VideoProjection(rawValue: "PROJ-EQUI") == .equirectangular)
        #expect(VideoProjection(rawValue: "PROJ-AIV") == .appleImmersiveVideo)
        #expect(VideoProjection(rawValue: "UNKNOWN") == nil)
    }

    @Test("Sendable conformance")
    func sendable() {
        let projection: any Sendable = VideoProjection.halfEquirectangular
        #expect(projection is VideoProjection)
    }
}
