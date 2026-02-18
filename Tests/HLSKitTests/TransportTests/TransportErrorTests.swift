// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("TransportError")
struct TransportErrorTests {

    @Test("All error cases have non-empty errorDescription")
    func allCasesHaveDescription() {
        let errors: [TransportError] = [
            .invalidAVCConfig("test"),
            .invalidAudioConfig("test"),
            .pesError("test"),
            .packetError("test"),
            .unsupportedCodec("test")
        ]
        for error in errors {
            #expect(error.errorDescription != nil)
            if let desc = error.errorDescription {
                #expect(!desc.isEmpty)
            }
        }
    }

    @Test("Hashable conformance")
    func hashableConformance() {
        let error1 = TransportError.invalidAVCConfig("a")
        let error2 = TransportError.invalidAVCConfig("a")
        let error3 = TransportError.invalidAVCConfig("b")
        #expect(error1 == error2)
        #expect(error1 != error3)

        var set = Set<TransportError>()
        set.insert(error1)
        set.insert(error2)
        #expect(set.count == 1)
    }

    @Test("Error descriptions contain details")
    func errorDescriptionsContainDetails() {
        let error = TransportError.invalidAVCConfig(
            "too short"
        )
        let desc = error.errorDescription ?? ""
        #expect(desc.contains("too short"))
    }
}
