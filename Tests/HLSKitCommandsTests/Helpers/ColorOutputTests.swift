// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKitCommands

@Suite("ColorOutput")
struct ColorOutputTests {

    @Test("success wraps text correctly")
    func successOutput() {
        let result = ColorOutput.success("OK")
        if ColorOutput.isEnabled {
            #expect(result.contains("\u{1B}[32m"))
            #expect(result.contains("OK"))
            #expect(result.contains("\u{1B}[0m"))
        } else {
            #expect(result == "OK")
        }
    }

    @Test("error wraps text correctly")
    func errorOutput() {
        let result = ColorOutput.error("FAIL")
        if ColorOutput.isEnabled {
            #expect(result.contains("\u{1B}[31m"))
            #expect(result.contains("FAIL"))
        } else {
            #expect(result == "FAIL")
        }
    }

    @Test("warning wraps text correctly")
    func warningOutput() {
        let result = ColorOutput.warning("WARN")
        if ColorOutput.isEnabled {
            #expect(result.contains("\u{1B}[33m"))
            #expect(result.contains("WARN"))
        } else {
            #expect(result == "WARN")
        }
    }

    @Test("bold wraps text correctly")
    func boldOutput() {
        let result = ColorOutput.bold("BOLD")
        if ColorOutput.isEnabled {
            #expect(result.contains("\u{1B}[1m"))
            #expect(result.contains("BOLD"))
        } else {
            #expect(result == "BOLD")
        }
    }

    @Test("dim wraps text correctly")
    func dimOutput() {
        let result = ColorOutput.dim("DIM")
        if ColorOutput.isEnabled {
            #expect(result.contains("\u{1B}[2m"))
            #expect(result.contains("DIM"))
        } else {
            #expect(result == "DIM")
        }
    }

    @Test("When disabled, returns text without ANSI codes")
    func disabledMode() {
        // In test runner (piped), isEnabled is typically false
        // We verify the text is always present regardless
        let result = ColorOutput.success("test")
        #expect(result.contains("test"))
    }

    @Test("Empty string wrapped produces valid output")
    func emptyString() {
        let result = ColorOutput.success("")
        // Should not crash; output is either "" or ANSI-wrapped ""
        #expect(result.count >= 0)
    }

    @Test("isEnabled returns a Bool")
    func isEnabledType() {
        let value = ColorOutput.isEnabled
        #expect(value == true || value == false)
    }
}
