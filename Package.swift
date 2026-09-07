// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DesktopPup",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "DesktopPup",
            path: "Sources/DesktopPup"
        )
    ]
)
