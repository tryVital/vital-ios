# vital-ios

The official Swift Library for Vital API, HealthKit and Devices

## Install

We support Swift Package Manager and CocoaPods.

### Swift Package Manager

Add the vital-ios package to your Package.swift.

```swift
.package(url: "https://github.com/tryvital/vital-ios", from: "1.1.2"),
```

Then add the Vital iOS library products you need to your app and/or library targets:

```swift
.target(name: "AppTarget", dependencies: [
    .product(name: "VitalCore", package: "vital-ios"),
    .product(name: "VitalDevices", package: "vital-ios"),
    .product(name: "VitalHealthKit", package: "vital-ios"),
]),
```

### CocoaPods

Add the Vital iOS library products you need to your Podfile:

```
pod "VitalCore", "~> 1.1.2"
pod "VitalDevices", "~> 1.1.2"
pod "VitalHealthKit", "~> 1.1.2"
```

## Documentation

Please refer to the [official Vital](https://docs.tryvital.io/wearables/sdks/iOS) docs provide a full reference on using this library.

## License

vital-ios is available under the AGPLv3 license. See the LICENSE file for more info. VitalDevices is under the `Adept Labs Enterprise Edition (EE) license (the “EE License”)`. Please refer to its license inside its folder.
