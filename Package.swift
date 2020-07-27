// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "WealthsimpleDownloader",
    products: [
        .library(
            name: "WealthsimpleDownloaderLibrary",
            targets: ["WealthsimpleDownloaderLibrary"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "WealthsimpleDownloaderLibrary",
            dependencies: []),
        .testTarget(
            name: "WealthsimpleDownloaderTests",
            dependencies: ["WealthsimpleDownloaderLibrary"]),
    ]
)
