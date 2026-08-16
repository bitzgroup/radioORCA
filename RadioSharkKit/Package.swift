// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RadioSharkKit",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "RadioSharkKit", targets: ["RadioSharkKit"]),
        .executable(name: "radiosh-cli", targets: ["radiosh-cli"]),
        .executable(name: "radioaudio-cli", targets: ["radioaudio-cli"]),
    ],
    targets: [
        .target(name: "RadioSharkKit"),
        .executableTarget(
            name: "radiosh-cli",
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
