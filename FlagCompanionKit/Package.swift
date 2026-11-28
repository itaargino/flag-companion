// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FlagCompanionKit",
    platforms: [.macOS("27.0")],
    products: [
        .library(name: "SessionKit", targets: ["SessionKit"]),
        .library(name: "LogStore", targets: ["LogStore"]),
        .library(name: "ChallengeLibrary", targets: ["ChallengeLibrary"]),
        .library(name: "TerminalKit", targets: ["TerminalKit"]),
    ],
    dependencies: [
        // 1.99.x is the author's preview of 2.0; stay on the stable 1.20 line.
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", .upToNextMinor(from: "1.20.0"))
    ],
    targets: [
        .target(name: "SessionKit"),
        .target(name: "LogStore"),
        .target(name: "ChallengeLibrary"),
        .target(name: "TerminalKit", dependencies: ["SwiftTerm"]),
        .testTarget(
            name: "SessionKitTests", dependencies: ["SessionKit"],
            // Real zsh sessions, recorded by scripts/record-session-fixtures.py.
            resources: [.copy("Fixtures")]),
        .testTarget(name: "LogStoreTests", dependencies: ["LogStore"]),
        .testTarget(name: "ChallengeLibraryTests", dependencies: ["ChallengeLibrary"]),
        .testTarget(name: "TerminalKitTests", dependencies: ["TerminalKit"]),
    ]
)
