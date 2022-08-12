// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "vital-ios",
    platforms: [
      .iOS(.v14)
    ],
    products: [
        .library(
            name: "VitalHealthKit",
            targets: ["VitalHealthKit"]),
        .library(
          name: "VitalDevices",
          targets: ["VitalDevices"]),
        .library(
          name: "VitalCore",
          targets: ["VitalCore"]),
    ],
    dependencies: [
        .package(name: "CombineCoreBluetooth", url: "https://github.com/StarryInternet/CombineCoreBluetooth.git", from: "0.3.1"),
    ],
    targets: [
        .target(
            name: "VitalHealthKit",
            dependencies: ["VitalCore"]),
        .target(
          name: "VitalDevices",
          dependencies: ["CombineCoreBluetooth", "VitalCore"],
          exclude: [
            "./LICENSE",
          ]
        ),
        .target(
          name: "VitalCore",
          exclude: [
            "./Get/LICENSE",
            "./Get/README.md",
            "./Keychain/LICENSE"
          ]
        ),
        .testTarget(
            name: "VitalHealthKitTests",
            dependencies: ["VitalHealthKit"]),
    ]
)
