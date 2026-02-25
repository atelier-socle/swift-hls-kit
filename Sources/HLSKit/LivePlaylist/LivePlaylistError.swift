// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Errors thrown by ``LivePlaylistManager`` implementations.
public enum LivePlaylistError: Error, Sendable, Equatable {

    /// The stream has already ended (EXT-X-ENDLIST was added).
    case streamEnded

    /// The segment index is invalid or out of order.
    case invalidSegmentIndex(String)

    /// A partial segment references a non-existent parent segment.
    case parentSegmentNotFound(Int)

    /// A configuration error.
    case invalidConfiguration(String)
}
