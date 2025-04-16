// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Obscura",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "Obscura",
            targets: ["Obscura"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/Yabby1997/LightMeter", from: "0.2.0")
    ],
    targets: [
        .target(
            name: "Obscura",
            dependencies: [
                .product(name: "LightMeter", package: "LightMeter")
            ],
            path: "Obscura"
        )
    ]
)
