import Foundation

/// A folder-safe name built from a challenge or CTF name: lowercase ASCII
/// letters and digits separated by single hyphens, never starting or ending
/// with a hyphen.
///
/// ```swift
/// let slug = try Slug("picoCTF 2026")
/// print(slug.value) // "picoctf-2026"
/// ```
public struct Slug: Equatable {
    public let value: String

    /// Builds a slug, or throws when the name has no ASCII letters or digits.
    public init(_ name: String) throws {
        let words = name
            .folding(options: .diacriticInsensitive, locale: nil)
            .lowercased()
            .split(whereSeparator: { !Self.isSlugCharacter($0) })

        guard !words.isEmpty else {
            throw SlugError.noLatinLettersOrDigits(
                received: name,
                expected: "at least one ASCII letter or digit"
            )
        }
        value = words.joined(separator: "-")
    }

    // Hyphens are not slug characters, so they only appear between words, never
    // at the start: a folder named "-x" would be read by shells as an option.
    private static func isSlugCharacter(_ character: Character) -> Bool {
        return ("a"..."z").contains(character) || ("0"..."9").contains(character)
    }
}

/// Errors thrown when a name cannot become a slug.
public enum SlugError: Error, Equatable {
    case noLatinLettersOrDigits(received: String, expected: String)
}
