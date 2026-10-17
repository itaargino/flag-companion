/// The session log format written by this module.
///
/// Every event line carries the current version in its `v` field, so readers
/// can keep supporting older files when the format changes.
///
/// ```swift
/// let version = LogFormat.currentVersion // 1
/// ```
public enum LogFormat {
    public static let currentVersion = 1
}
