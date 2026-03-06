// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

@Suite("IMSC1Style — Style Definition")
struct IMSC1StyleTests {

    @Test("Init with all parameters")
    func initAllParams() {
        let style = IMSC1Style(
            id: "s1",
            fontFamily: "proportionalSansSerif",
            fontSize: "100%",
            color: "white",
            backgroundColor: "black",
            textAlign: "center",
            fontStyle: "italic",
            fontWeight: "bold",
            textOutline: "black 2px"
        )
        #expect(style.id == "s1")
        #expect(style.fontFamily == "proportionalSansSerif")
        #expect(style.fontSize == "100%")
        #expect(style.color == "white")
        #expect(style.backgroundColor == "black")
        #expect(style.textAlign == "center")
        #expect(style.fontStyle == "italic")
        #expect(style.fontWeight == "bold")
        #expect(style.textOutline == "black 2px")
    }

    @Test("Init with nil optionals")
    func initNilOptionals() {
        let style = IMSC1Style(id: "minimal")
        #expect(style.id == "minimal")
        #expect(style.fontFamily == nil)
        #expect(style.fontSize == nil)
        #expect(style.color == nil)
        #expect(style.backgroundColor == nil)
        #expect(style.textAlign == nil)
        #expect(style.fontStyle == nil)
        #expect(style.fontWeight == nil)
        #expect(style.textOutline == nil)
    }

    @Test("Equatable — equal styles")
    func equatableEqual() {
        let a = IMSC1Style(id: "s1", color: "white")
        let b = IMSC1Style(id: "s1", color: "white")
        #expect(a == b)
    }

    @Test("Equatable — different styles")
    func equatableDifferent() {
        let a = IMSC1Style(id: "s1", color: "white")
        let b = IMSC1Style(id: "s1", color: "yellow")
        #expect(a != b)
    }

    @Test("Sendable conformance")
    func sendable() {
        let style = IMSC1Style(id: "s1")
        let fn: @Sendable () -> String = { style.id }
        #expect(fn() == "s1")
    }
}
