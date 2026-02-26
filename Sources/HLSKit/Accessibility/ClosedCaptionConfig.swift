// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Configuration for closed captions in HLS streams.
///
/// Supports both CEA-608 (analog, CC1-CC4) and CEA-708 (digital, SERVICE1-SERVICE63)
/// caption standards. Generates the correct `EXT-X-MEDIA` entries with
/// `TYPE=CLOSED-CAPTIONS` and appropriate `INSTREAM-ID` values.
///
/// ```swift
/// let config = ClosedCaptionConfig(
///     standard: .cea708,
///     services: [
///         .init(serviceID: 1, language: "en", name: "English"),
///         .init(serviceID: 2, language: "es", name: "Spanish")
///     ]
/// )
/// ```
public struct ClosedCaptionConfig: Sendable, Equatable {

    /// Caption standard.
    public var standard: CaptionStandard

    /// Caption services/channels.
    public var services: [CaptionService]

    /// GROUP-ID for linking to variants.
    public var groupID: String

    /// Creates a closed caption configuration.
    ///
    /// - Parameters:
    ///   - standard: The caption standard to use.
    ///   - services: The caption services/channels.
    ///   - groupID: The GROUP-ID for variant linking.
    public init(
        standard: CaptionStandard = .cea708,
        services: [CaptionService] = [],
        groupID: String = "cc"
    ) {
        self.standard = standard
        self.services = services
        self.groupID = groupID
    }

    // MARK: - CaptionStandard

    /// Caption standards.
    public enum CaptionStandard: String, Sendable, CaseIterable, Equatable {
        /// CEA-608: analog line 21, CC1-CC4, limited character set.
        case cea608 = "cea-608"
        /// CEA-708: digital, SERVICE1-SERVICE63, full Unicode, styled text.
        case cea708 = "cea-708"
    }

    // MARK: - CaptionService

    /// A single caption service/channel.
    public struct CaptionService: Sendable, Equatable {
        /// Service number (1-4 for CEA-608 as CC1-CC4, 1-63 for CEA-708).
        public let serviceID: Int
        /// ISO 639-1 language code.
        public let language: String
        /// Human-readable name (e.g., "English", "Spanish CC").
        public let name: String
        /// Whether this is the default caption track.
        public let isDefault: Bool

        /// Creates a caption service.
        ///
        /// - Parameters:
        ///   - serviceID: The service number.
        ///   - language: The ISO 639-1 language code.
        ///   - name: A human-readable name.
        ///   - isDefault: Whether this is the default caption track.
        public init(
            serviceID: Int,
            language: String,
            name: String,
            isDefault: Bool = false
        ) {
            self.serviceID = serviceID
            self.language = language
            self.name = name
            self.isDefault = isDefault
        }

        /// INSTREAM-ID value for this service.
        ///
        /// CEA-608: "CC1" through "CC4".
        /// CEA-708: "SERVICE1" through "SERVICE63".
        ///
        /// - Parameter standard: The caption standard.
        /// - Returns: The INSTREAM-ID string.
        public func instreamID(standard: CaptionStandard) -> String {
            switch standard {
            case .cea608:
                return "CC\(serviceID)"
            case .cea708:
                return "SERVICE\(serviceID)"
            }
        }
    }

    // MARK: - Properties

    /// Maximum services per standard.
    public var maxServices: Int {
        switch standard {
        case .cea608: return 4
        case .cea708: return 63
        }
    }

    // MARK: - Validation

    /// Validate the configuration.
    ///
    /// - Returns: An array of validation error messages. Empty if valid.
    public func validate() -> [String] {
        var errors: [String] = []

        if services.isEmpty {
            errors.append("No caption services configured")
        }

        let maxID = maxServices
        for service in services {
            if service.serviceID < 1 || service.serviceID > maxID {
                errors.append(
                    "Service ID \(service.serviceID) out of range 1-\(maxID) for \(standard.rawValue)"
                )
            }
        }

        let ids = services.map(\.serviceID)
        if Set(ids).count != ids.count {
            errors.append("Duplicate service IDs found")
        }

        return errors
    }

    // MARK: - Presets

    /// English-only CEA-608 CC1.
    public static let englishOnly608 = ClosedCaptionConfig(
        standard: .cea608,
        services: [
            CaptionService(serviceID: 1, language: "en", name: "English", isDefault: true)
        ]
    )

    /// English + Spanish CEA-708.
    public static let englishSpanish708 = ClosedCaptionConfig(
        standard: .cea708,
        services: [
            CaptionService(serviceID: 1, language: "en", name: "English", isDefault: true),
            CaptionService(serviceID: 2, language: "es", name: "Spanish")
        ]
    )

    /// Full broadcast: English + Spanish + French CEA-708.
    public static let broadcast708 = ClosedCaptionConfig(
        standard: .cea708,
        services: [
            CaptionService(serviceID: 1, language: "en", name: "English", isDefault: true),
            CaptionService(serviceID: 2, language: "es", name: "Spanish"),
            CaptionService(serviceID: 3, language: "fr", name: "French")
        ]
    )
}
