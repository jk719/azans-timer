// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ADHDTimerApp",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "ADHDTimerApp",
            targets: ["ADHDTimerApp"])
    ],
    targets: [
        .target(
            name: "ADHDTimerApp",
            path: "ADHDTimerApp",
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals")
            ])
    ]
)
