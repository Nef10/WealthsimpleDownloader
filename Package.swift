// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "WealthsimpleDownloader",
    products: [
        .library(
            name: "Wealthsimple",
            targets: ["Wealthsimple"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "Wealthsimple",
            dependencies: []),
        .testTarget(
            name: "WealthsimpleTests",
            dependencies: ["Wealthsimple"]),
    ]
)
