// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "vital-ios",
    platforms: [
      .iOS(.v14),
    ],
    products: [
        .library(
            name: "VitalHealthKit",
            targets: ["VitalHealthKit"]),
        .library(
          name: "VitalDevices",
          targets: ["VitalDevices"]),
    ],
    dependencies: [
        .package(url: "https://github.com/kean/Get", from: "0.5.0"),
        .package(name: "KeychainSwift", url: "https://github.com/evgenyneu/keychain-swift", from: "20.0.0"),
        .package(name: "CombineCoreBluetooth", url: "https://github.com/StarryInternet/CombineCoreBluetooth.git", from: "0.2.1"),
    ],
    targets: [
        .target(
            name: "VitalHealthKit",
            dependencies: ["Get", "KeychainSwift"]),
        .target(
          name: "VitalDevices",
          dependencies: ["CombineCoreBluetooth"]),
        .testTarget(
            name: "VitalHealthKitTests",
            dependencies: ["VitalHealthKit"]),
    ]
)
