// swift-tools-version: 5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Themes",
    platforms: [.iOS(.v14)],
    products: [
        .library(name: "RunestoneTomorrowTheme", targets: ["RunestoneTomorrowTheme"]),
        .library(name: "RunestoneTomorrowNightTheme", targets: ["RunestoneTomorrowNightTheme"]),
        .library(name: "RunestoneOneDarkTheme", targets: ["RunestoneOneDarkTheme"]),
        .library(name: "RunestonePlainTextTheme", targets: ["RunestonePlainTextTheme"]),
        .library(name: "RunestoneThemeCommon", targets: ["RunestoneThemeCommon"])
    ],
    dependencies: [
        .package(path: "../Runestone")
    ],
    targets: [
        .target(name: "RunestoneTomorrowTheme", dependencies: ["Runestone", "RunestoneThemeCommon"], resources: [.process("Colors.xcassets")]),
        .target(name: "RunestoneTomorrowNightTheme", dependencies: ["Runestone", "RunestoneThemeCommon"], resources: [.process("Colors.xcassets")]),
        .target(name: "RunestoneOneDarkTheme", dependencies: ["Runestone", "RunestoneThemeCommon"], resources: [.process("Colors.xcassets")]),
        .target(name: "RunestonePlainTextTheme", dependencies: ["Runestone", "RunestoneThemeCommon"]),
        .target(name: "RunestoneThemeCommon", dependencies: ["Runestone"])
    ]
)
