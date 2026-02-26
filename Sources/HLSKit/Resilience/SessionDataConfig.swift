// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Configuration for EXT-X-SESSION-DATA in master playlists.
///
/// Session data provides metadata about the stream that clients can
/// access without downloading media playlists.
///
/// ```swift
/// let sessionData = SessionDataConfig(entries: [
///     .init(dataID: "com.example.title", value: "Live Concert"),
///     .init(dataID: "com.example.language", value: "en", language: "en")
/// ])
/// ```
public struct SessionDataConfig: Sendable, Equatable {

    /// Session data entries.
    public var entries: [SessionDataEntry]

    /// Creates a session data configuration.
    ///
    /// - Parameter entries: The session data entries.
    public init(entries: [SessionDataEntry] = []) {
        self.entries = entries
    }

    // MARK: - SessionDataEntry

    /// A single session data entry.
    public struct SessionDataEntry: Sendable, Equatable {
        /// DATA-ID: reverse-DNS identifier.
        public let dataID: String
        /// VALUE: string value (mutually exclusive with uri).
        public let value: String?
        /// URI: pointer to a JSON resource (mutually exclusive with value).
        public let uri: String?
        /// LANGUAGE: ISO 639 language tag.
        public let language: String?

        /// Creates a session data entry.
        ///
        /// - Parameters:
        ///   - dataID: The reverse-DNS data identifier.
        ///   - value: An optional string value.
        ///   - uri: An optional URI to a JSON resource.
        ///   - language: An optional ISO 639 language tag.
        public init(
            dataID: String,
            value: String? = nil,
            uri: String? = nil,
            language: String? = nil
        ) {
            self.dataID = dataID
            self.value = value
            self.uri = uri
            self.language = language
        }
    }

    // MARK: - Tag Generation

    /// Generate EXT-X-SESSION-DATA tags.
    ///
    /// - Returns: An array of formatted EXT-X-SESSION-DATA tag strings.
    public func generateTags() -> [String] {
        entries.map { entry in
            var attrs: [String] = ["DATA-ID=\"\(entry.dataID)\""]
            if let value = entry.value {
                attrs.append("VALUE=\"\(value)\"")
            }
            if let uri = entry.uri {
                attrs.append("URI=\"\(uri)\"")
            }
            if let language = entry.language {
                attrs.append("LANGUAGE=\"\(language)\"")
            }
            return "#EXT-X-SESSION-DATA:" + attrs.joined(separator: ",")
        }
    }

    // MARK: - Validation

    /// Validate entries (dataID required, value OR uri but not both).
    ///
    /// - Returns: An array of validation error messages. Empty if valid.
    public func validate() -> [String] {
        var errors: [String] = []

        for (index, entry) in entries.enumerated() {
            if entry.dataID.isEmpty {
                errors.append("Entry \(index): DATA-ID is empty")
            }
            if entry.value != nil && entry.uri != nil {
                errors.append(
                    "Entry \(index): VALUE and URI are mutually exclusive"
                )
            }
            if entry.value == nil && entry.uri == nil {
                errors.append(
                    "Entry \(index): either VALUE or URI must be provided"
                )
            }
        }

        return errors
    }

    // MARK: - Mutation

    /// Add an entry.
    ///
    /// - Parameter entry: The session data entry to add.
    public mutating func addEntry(_ entry: SessionDataEntry) {
        entries.append(entry)
    }
}
