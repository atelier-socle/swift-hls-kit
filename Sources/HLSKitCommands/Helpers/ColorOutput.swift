// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if canImport(Glibc)
    import Glibc
#elseif canImport(Darwin)
    import Darwin
#elseif canImport(Musl)
    import Musl
#endif

/// ANSI color output for terminal.
///
/// Automatically detects whether stdout is a TTY and disables
/// color codes when piping or redirecting output.
public enum ColorOutput: Sendable {

    /// Whether color output is enabled (stdout is a TTY).
    public static var isEnabled: Bool {
        isatty(STDOUT_FILENO) != 0
    }

    /// Format text as green (success).
    public static func success(_ text: String) -> String {
        wrap(text, code: "32")
    }

    /// Format text as red (error).
    public static func error(_ text: String) -> String {
        wrap(text, code: "31")
    }

    /// Format text as yellow (warning).
    public static func warning(_ text: String) -> String {
        wrap(text, code: "33")
    }

    /// Format text as bold.
    public static func bold(_ text: String) -> String {
        wrap(text, code: "1")
    }

    /// Format text as dim.
    public static func dim(_ text: String) -> String {
        wrap(text, code: "2")
    }

    private static func wrap(
        _ text: String, code: String
    ) -> String {
        guard isEnabled else { return text }
        return "\u{1B}[\(code)m\(text)\u{1B}[0m"
    }
}
