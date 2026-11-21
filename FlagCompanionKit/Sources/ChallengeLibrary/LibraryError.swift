import Foundation

/// Errors thrown while creating folders and files in the library.
public enum LibraryError: Error, Equatable {
    case itemAlreadyExists(received: URL, expected: String)
}

/// A metadata file that exists but could not be read, reported by a library
/// scan instead of stopping it, so one broken file never hides the rest.
///
/// ```swift
/// for problem in scan.problems {
///     print("\(problem.file.path): \(problem.reason)")
/// }
/// ```
public struct LibraryProblem: Equatable, Sendable {
    public let file: URL
    public let reason: String

    public init(file: URL, reason: String) {
        self.file = file
        self.reason = reason
    }
}
