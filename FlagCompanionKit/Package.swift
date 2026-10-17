// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FlagCompanionKit",
    platforms: [.macOS("27.0")],
    products: [
        .library(name: "SessionKit", targets: ["SessionKit"]),
        .library(name: "LogStore", targets: ["LogStore"]),
        .library(name: "ChallengeLibrary", targets: ["ChallengeLibrary"]),
    ],
    targets: [
        .target(name: "SessionKit"),
        .target(name: "LogStore"),
        .target(name: "ChallengeLibrary"),
        .testTarget(name: "SessionKitTests", dependencies: ["SessionKit"]),
        .testTarget(name: "LogStoreTests", dependencies: ["LogStore"]),
        .testTarget(name: "ChallengeLibraryTests", dependencies: ["ChallengeLibrary"]),
    ]
)
