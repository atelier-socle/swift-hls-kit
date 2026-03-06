// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// A style definition for IMSC1 subtitle rendering.
///
/// Maps to TTML `<style>` elements with styling attributes
/// from the `tts` (TT Styling) namespace. All properties
/// are optional strings matching their TTML serialized form.
///
/// ```swift
/// let style = IMSC1Style(
///     id: "default",
///     fontFamily: "proportionalSansSerif",
///     fontSize: "100%",
///     color: "white"
/// )
/// ```
public struct IMSC1Style: Sendable, Equatable {

    /// Unique identifier for this style.
    public let id: String

    /// Font family name (e.g. "proportionalSansSerif").
    public let fontFamily: String?

    /// Font size (e.g. "100%", "24px").
    public let fontSize: String?

    /// Foreground text color (e.g. "white", "#FFFFFF").
    public let color: String?

    /// Background color behind text (e.g. "black", "#000000FF").
    public let backgroundColor: String?

    /// Text alignment (e.g. "center", "start", "end").
    public let textAlign: String?

    /// Font style (e.g. "normal", "italic").
    public let fontStyle: String?

    /// Font weight (e.g. "normal", "bold").
    public let fontWeight: String?

    /// Text outline specification (e.g. "black 2px").
    public let textOutline: String?

    /// Creates a new IMSC1 style definition.
    ///
    /// - Parameters:
    ///   - id: Unique identifier for this style.
    ///   - fontFamily: Font family name.
    ///   - fontSize: Font size value.
    ///   - color: Foreground text color.
    ///   - backgroundColor: Background color behind text.
    ///   - textAlign: Text alignment.
    ///   - fontStyle: Font style (normal/italic).
    ///   - fontWeight: Font weight (normal/bold).
    ///   - textOutline: Text outline specification.
    public init(
        id: String,
        fontFamily: String? = nil,
        fontSize: String? = nil,
        color: String? = nil,
        backgroundColor: String? = nil,
        textAlign: String? = nil,
        fontStyle: String? = nil,
        fontWeight: String? = nil,
        textOutline: String? = nil
    ) {
        self.id = id
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.color = color
        self.backgroundColor = backgroundColor
        self.textAlign = textAlign
        self.fontStyle = fontStyle
        self.fontWeight = fontWeight
        self.textOutline = textOutline
    }
}
