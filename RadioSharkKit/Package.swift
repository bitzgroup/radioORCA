// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RadioSharkKit",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "RadioSharkKit", targets: ["RadioSharkKit"]),
        .executable(name: "radioorca-cli", targets: ["radioorca-cli"]),
        .executable(name: "radioaudio-cli", targets: ["radioaudio-cli"]),
    ],
    targets: [
        .target(name: "RadioSharkKit"),
        .executableTarget(
            name: "radioorca-cli",
            dependencies: ["RadioSharkKit"]
        ),
        .executableTarget(
            name: "radioaudio-cli",
            dependencies: ["RadioSharkKit"]
        ),
        .testTarget(
            name: "RadioSharkKitTests",
            dependencies: ["RadioSharkKit"]
        ),
    ]
)
