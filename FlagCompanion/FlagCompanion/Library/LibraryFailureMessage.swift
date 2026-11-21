import ChallengeLibrary
import Foundation

/// Turns an error from a library action into a sentence for an alert.
nonisolated func libraryFailureMessage(for error: Error) -> String {
    switch error {
    case SlugError.noLatinLettersOrDigits:
        return "The name needs at least one letter or digit (A–Z, 0–9) to become a folder name."
    case LibraryError.itemAlreadyExists(let url, _):
        return "A folder named “\(url.lastPathComponent)” already exists here."
    default:
        return error.localizedDescription
    }
}
