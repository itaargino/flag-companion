import Foundation

/// Where the library lives on disk. Until first-run setup exists (E3), the
/// default is `~/CTFs`, and "Choose Root Folder…" in the File menu changes it.
nonisolated enum RootFolderPreference {
    private static let defaultsKey = "rootFolderPath"

    static var defaultFolder: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "CTFs", directoryHint: .isDirectory)
    }

    static func load(from defaults: UserDefaults = .standard) -> URL {
        guard let path = defaults.string(forKey: defaultsKey) else { return defaultFolder }
        return URL(filePath: path, directoryHint: .isDirectory)
    }

    static func save(_ folder: URL, to defaults: UserDefaults = .standard) {
        defaults.set(folder.path, forKey: defaultsKey)
    }
}
