// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MapViewModule",
    platforms: [.iOS(SupportedPlatform.IOSVersion.v14)],
    products: [
        .library(
            name: "MapViewModule",
            targets: ["MapViewModule"]
        )
    ],
    targets: [
        .target(name: "MapViewModule"),
        .testTarget(
            name: "MapViewModuleTests",
            dependencies: ["MapViewModule"]
        )
    ]
)
