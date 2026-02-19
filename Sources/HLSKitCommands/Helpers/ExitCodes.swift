// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Standard exit codes for CLI commands.
///
/// Based on BSD `sysexits.h` where applicable, with
/// application-specific codes for validation errors.
public enum ExitCodes {
    /// Successful execution.
    public static let success: Int32 = 0
    /// General error.
    public static let generalError: Int32 = 1
    /// Validation failed (errors found in manifest).
    public static let validationError: Int32 = 2
    /// Input file not found (EX_NOINPUT).
    public static let fileNotFound: Int32 = 66
    /// I/O error (EX_IOERR).
    public static let ioError: Int32 = 74
}
