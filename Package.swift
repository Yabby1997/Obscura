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
    targets: [
        .target(
            name: "Obscura",
            path: "Obscura"
        )
    ]
)
