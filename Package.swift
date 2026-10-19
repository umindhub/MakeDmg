// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "MakeDmg",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "makedmg", targets: ["makedmg"]),
        .library(name: "MakeDmgKit", targets: ["MakeDmgKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    ],
    targets: [
        // CLI layer: argument parsing only
        .executableTarget(
            name: "makedmg",
            dependencies: [
                "MakeDmgKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        // Core logic: config, DS_Store, alias, hdiutil, signing, preview
        .target(name: "MakeDmgKit"),
        .testTarget(name: "MakeDmgKitTests", dependencies: ["MakeDmgKit"]),
    ]
)
