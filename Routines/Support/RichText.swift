//
//  RichText.swift
//  Routines
//

import Foundation
import SwiftUI

/// Archiving for the rich text the app stores in SwiftData.
///
/// `AttributedString`'s own `Codable` conformance only round-trips Foundation's
/// own attributes, so bold, italic and underline applied in a SwiftUI editor
/// would be silently dropped on save. Naming the SwiftUI attribute scope
/// explicitly is what keeps them.
enum RichText {
    private struct Payload: Codable {
        @CodableConfiguration(from: \.swiftUI)
        var text = AttributedString()

        init(_ text: AttributedString) {
            self.text = text
        }
    }

    /// Archives `text`, or returns `nil` when there is nothing worth storing.
    static func encode(_ text: AttributedString) -> Data? {
        guard !text.characters.isEmpty else { return nil }
        return try? JSONEncoder().encode(Payload(text))
    }

    /// Restores archived rich text, or `nil` if the data is absent or unreadable.
    static func decode(_ data: Data?) -> AttributedString? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(Payload.self, from: data).text
    }
}
