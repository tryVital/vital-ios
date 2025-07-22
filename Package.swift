// swift-tools-version:6.1
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
  traits: [
    "WriteAPI",
    .default(enabledTraits: ["WriteAPI"])
  ],
  dependencies: [
    .package(url: "https://github.com/StarryInternet/CombineCoreBluetooth.git", from: "0.3.0"),
    .package(url: "https://github.com/WeTransfer/Mocker.git", .upToNextMajor(from: "2.6.0")),
  ],
  targets: [
    .target(
      name: "VitalHealthKit",
      dependencies: ["VitalCore"],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .target(
      name: "VitalDevices",
      dependencies: ["CombineCoreBluetooth", "VitalCore"],
      exclude: [
        "./LICENSE",
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .target(
      name: "VitalCore",
      dependencies: ["VitalLogging"],
      exclude: [
        "./Get/LICENSE",
        "./DataCompression/LICENSE",
        "./Keychain/LICENSE"
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .target(
      name: "VitalLogging",
      exclude: ["./LICENSE.txt", "./README.txt"],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .testTarget(
      name: "VitalHealthKitTests",
      dependencies: ["VitalHealthKit"],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .testTarget(
      name: "VitalCoreTests",
      dependencies: ["VitalCore", "Mocker"],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .testTarget(
      name: "VitalDevicesTests",
      dependencies: ["VitalDevices"],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
  ]
)
