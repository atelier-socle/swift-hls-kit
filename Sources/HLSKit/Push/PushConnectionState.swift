// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Connection state for a segment pusher.
///
/// Tracks the lifecycle of a push connection from initial
/// disconnected state through connection, and handles reconnection
/// and terminal failure scenarios.
public enum PushConnectionState: String, Sendable, Equatable {

    /// Not connected to the push destination.
    case disconnected

    /// Currently establishing a connection.
    case connecting

    /// Connected and ready to push.
    case connected

    /// Lost connection, attempting to reconnect.
    case reconnecting

    /// Connection permanently failed.
    case failed

    /// Whether the pusher is in a state where it can accept
    /// push requests.
    public var isReady: Bool {
        self == .connected
    }

    /// Whether this is a terminal state.
    public var isTerminal: Bool {
        self == .failed
    }
}
