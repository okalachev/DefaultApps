// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DefaultApps",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "DefaultApps",
            path: "Sources"
        )
    ]
)
