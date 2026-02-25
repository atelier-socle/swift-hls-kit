// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Resolves `{$variable}` references in HLS playlists.
///
/// RFC 8216bis-20 Section 4.4.3.8: Variable substitution replaces
/// occurrences of `{$name}` with the value defined via EXT-X-DEFINE.
///
/// Three definition forms:
/// - NAME/VALUE: `#EXT-X-DEFINE:NAME="base",VALUE="https://cdn.example.com"`
/// - IMPORT: `#EXT-X-DEFINE:IMPORT="base"` (import from multivariant)
/// - QUERYPARAM: `#EXT-X-DEFINE:QUERYPARAM="token"` (from request URL)
///
/// ```swift
/// var resolver = VariableResolver()
/// resolver.define(name: "base", value: "https://cdn.example.com")
/// let resolved = resolver.resolve("{$base}/path")
/// // → "https://cdn.example.com/path"
/// ```
public struct VariableResolver: Sendable, Equatable {

    /// Variable definitions (name → value).
    public private(set) var definitions: [String: String]

    /// Creates an empty resolver.
    public init() {
        self.definitions = [:]
    }

    /// Creates a resolver with initial definitions.
    ///
    /// - Parameter definitions: Initial variable definitions.
    public init(definitions: [String: String]) {
        self.definitions = definitions
    }

    /// Creates a resolver from parsed ``VariableDefinition`` entries.
    ///
    /// - Parameter variableDefinitions: Parsed EXT-X-DEFINE entries.
    public init(from variableDefinitions: [VariableDefinition]) {
        var defs = [String: String]()
        for entry in variableDefinitions {
            defs[entry.name] = entry.value
        }
        self.definitions = defs
    }

    // MARK: - Define

    /// Define a variable (NAME/VALUE form).
    ///
    /// - Parameters:
    ///   - name: Variable name (case-sensitive).
    ///   - value: Variable value.
    public mutating func define(name: String, value: String) {
        definitions[name] = value
    }

    /// Import a variable from a parent (multivariant) resolver.
    ///
    /// - Parameters:
    ///   - name: Variable name to import.
    ///   - parent: The parent resolver to import from.
    /// - Returns: `true` if the variable was found and imported.
    @discardableResult
    public mutating func importVariable(
        name: String, from parent: VariableResolver
    ) -> Bool {
        guard let value = parent.definitions[name] else {
            return false
        }
        definitions[name] = value
        return true
    }

    /// Extract a variable from a URL query parameter.
    ///
    /// - Parameters:
    ///   - name: Variable name (and query parameter name).
    ///   - url: The URL string to extract the parameter from.
    /// - Returns: `true` if the parameter was found and defined.
    @discardableResult
    public mutating func defineFromQueryParam(
        name: String, url: String
    ) -> Bool {
        guard let components = URLComponents(string: url),
            let items = components.queryItems,
            let item = items.first(where: { $0.name == name }),
            let value = item.value
        else {
            return false
        }
        definitions[name] = value
        return true
    }

    // MARK: - Resolve

    /// Resolve all `{$variable}` references in a string.
    ///
    /// Undefined variables are left as-is (lenient mode).
    ///
    /// - Parameter input: The string with potential variable refs.
    /// - Returns: The resolved string.
    public func resolve(_ input: String) -> String {
        guard Self.containsVariableReferences(input) else {
            return input
        }
        var result = input
        for (name, value) in definitions {
            let pattern = "{$\(name)}"
            result = result.replacingOccurrences(of: pattern, with: value)
        }
        return result
    }

    /// Resolve all variable references with strict error checking.
    ///
    /// - Parameter input: The string with potential variable refs.
    /// - Returns: Resolved string and list of undefined variable names.
    public func resolveStrict(
        _ input: String
    ) -> (resolved: String, undefinedVariables: [String]) {
        let resolved = resolve(input)
        let remaining = Self.extractVariableNames(from: resolved)
        return (resolved, remaining)
    }

    // MARK: - Inspection

    /// Check if a string contains any `{$variable}` references.
    ///
    /// - Parameter input: The string to check.
    /// - Returns: `true` if variable references are found.
    public static func containsVariableReferences(
        _ input: String
    ) -> Bool {
        input.contains("{$")
    }

    /// Extract all variable names referenced in a string.
    ///
    /// - Parameter input: The string to extract from.
    /// - Returns: An array of variable names found.
    public static func extractVariableNames(
        from input: String
    ) -> [String] {
        var names = [String]()
        var searchRange = input.startIndex..<input.endIndex

        while let openRange = input.range(
            of: "{$", range: searchRange
        ) {
            let afterOpen = openRange.upperBound
            guard afterOpen < input.endIndex,
                let closeRange = input.range(
                    of: "}", range: afterOpen..<input.endIndex
                )
            else { break }

            let name = String(input[afterOpen..<closeRange.lowerBound])
            if !name.isEmpty {
                names.append(name)
            }
            searchRange = closeRange.upperBound..<input.endIndex
        }
        return names
    }
}
