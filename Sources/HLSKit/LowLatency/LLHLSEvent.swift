// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Events emitted by ``LLHLSManager`` during the LL-HLS lifecycle.
///
/// Observe these events via ``LLHLSManager/events`` to react to
/// partial segment additions, segment completions, preload hint
/// updates, and stream termination.
public enum LLHLSEvent: Sendable {

    /// A partial segment was added.
    case partialAdded(LLPartialSegment)

    /// A full segment was completed with its associated partials.
    case segmentCompleted(
        LiveSegment, partials: [LLPartialSegment]
    )

    /// The preload hint was updated.
    case preloadHintUpdated(PreloadHint)

    /// The stream has ended.
    case streamEnded
}
