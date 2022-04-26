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
        .library(
          name: "VitalCore",
          targets: ["VitalCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CreateAPI/Get", from: "0.7.1"),
        .package(name: "KeychainSwift", url: "https://github.com/evgenyneu/keychain-swift", from: "20.0.0"),
        .package(name: "CombineCoreBluetooth", url: "https://github.com/StarryInternet/CombineCoreBluetooth.git", from: "0.2.1"),
    ],
    targets: [
        .target(
            name: "VitalHealthKit",
            dependencies: ["VitalCore"]),
        .target(
          name: "VitalDevices",
          dependencies: ["CombineCoreBluetooth", "VitalCore"]),
        .target(
          name: "VitalCore",
          dependencies: ["Get", "KeychainSwift"]),
        .testTarget(
            name: "VitalHealthKitTests",
            dependencies: ["VitalHealthKit"]),
    ]
)
