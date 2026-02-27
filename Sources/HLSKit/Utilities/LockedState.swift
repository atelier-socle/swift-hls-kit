// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Thread-safe mutable state wrapper.
///
/// Uses `OSAllocatedUnfairLock` on Apple platforms and
/// `NSLock` on Linux for cross-platform compatibility.
///
/// ```swift
/// let counter = LockedState(initialState: 0)
/// let value = counter.withLock { state -> Int in
///     state += 1
///     return state
/// }
/// ```
#if canImport(os)
    import os

    struct LockedState<State: Sendable>: Sendable {

        private let lock: OSAllocatedUnfairLock<State>

        /// Creates a locked state with the given initial value.
        ///
        /// - Parameter initialState: The initial value.
        init(initialState: State) {
            self.lock = OSAllocatedUnfairLock(initialState: initialState)
        }

        /// Perform a mutation on the state while holding the lock.
        ///
        /// - Parameter body: Closure that receives an `inout` reference
        ///   to the state.
        /// - Returns: The value returned by `body`.
        func withLock<T: Sendable>(
            _ body: @Sendable (inout State) throws -> T
        ) rethrows -> T {
            try lock.withLock(body)
        }
    }

#else

    struct LockedState<State: Sendable>: @unchecked Sendable {

        private let lock = NSLock()
        private let storage: MutableBox<State>

        /// Creates a locked state with the given initial value.
        ///
        /// - Parameter initialState: The initial value.
        init(initialState: State) {
            self.storage = MutableBox(initialState)
        }

        /// Perform a mutation on the state while holding the lock.
        ///
        /// - Parameter body: Closure that receives an `inout` reference
        ///   to the state.
        /// - Returns: The value returned by `body`.
        func withLock<T: Sendable>(
            _ body: @Sendable (inout State) throws -> T
        ) rethrows -> T {
            lock.lock()
            defer { lock.unlock() }
            return try body(&storage.value)
        }
    }

    private final class MutableBox<Value>: @unchecked Sendable {
        var value: Value
        init(_ value: Value) { self.value = value }
    }

#endif
