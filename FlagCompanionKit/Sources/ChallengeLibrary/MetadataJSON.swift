import Foundation

/// The JSON settings shared by `ctf.json` and `challenge.json`, so every reader
/// and writer agrees on the file format from the spec.
///
/// ```swift
/// let challenge = try MetadataJSON.decoder().decode(Challenge.self, from: data)
/// let data = try MetadataJSON.encoder().encode(challenge)
/// ```
public enum MetadataJSON {
    // The spec stores dates as ISO 8601 with offset; JSONDecoder's default expects seconds since 2001.
    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    public static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
