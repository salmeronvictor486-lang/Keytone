// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Keytone",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "KeytoneCore",
            path: "Sources/KeytoneCore"
        ),
        .executableTarget(
            name: "Keytone",
            dependencies: ["KeytoneCore"],
            path: "Sources/Keytone"
        ),
        .testTarget(
            name: "KeytoneTests",
            dependencies: ["KeytoneCore"],
            path: "Tests/KeytoneTests"
        ),
    ]
)
