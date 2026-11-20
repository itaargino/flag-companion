import Foundation

/// Turns a metadata read error into one short sentence a user can act on,
/// naming the JSON key when the decoder knows it.
func describe(_ error: Error) -> String {
    guard let decodingError = error as? DecodingError else {
        return error.localizedDescription
    }
    switch decodingError {
    case .keyNotFound(let key, _):
        return "Missing key \"\(key.stringValue)\"."
    case .typeMismatch(_, let context), .valueNotFound(_, let context):
        return "Wrong value for \"\(keyPath(of: context))\"."
    case .dataCorrupted(let context) where context.codingPath.isEmpty:
        return "The file is not valid JSON."
    case .dataCorrupted(let context):
        return "Invalid value for \"\(keyPath(of: context))\"."
    @unknown default:
        return "The file could not be read."
    }
}

private func keyPath(of context: DecodingError.Context) -> String {
    context.codingPath.map(\.stringValue).joined(separator: ".")
}
