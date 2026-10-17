/// Stores the limit for each output file from command terminal, the limit is 64 KB
///
/// ```swift
/// let limit = CommandOutputLimit.maxBytesPerCommand // 65536
/// ```
public enum CommandOutputLimit {
    public static let maxBytesPerCommand = 64 * 1024
}
