Pod::Spec.new do |s|
    s.name = 'VitalDevices'
    s.version = '1.4.1'
    s.license = 'AGPL v3.0'
    s.summary = 'The official Swift Library for Vital API, HealthKit and Devices'
    s.homepage = 'https://github.com/tryVital/vital-ios'
    s.authors = { 'Vital' => 'contact@tryVital.io' }
    s.source = { :git => 'https://github.com/tryVital/vital-ios.git', :tag => s.version }
    s.documentation_url = 'https://docs.tryvital.io/wearables/sdks/iOS'
    s.social_media_url = 'https://twitter.com/tryVital'

    s.ios.deployment_target = '14.0'
    s.swift_versions = ['5']
    s.source_files = 'Sources/VitalDevices/**/*.swift'
    s.frameworks = ['CoreNFC', 'AVFoundation', 'CoreBluetooth', 'Combine', 'CryptoKit']
    
    s.dependency 'VitalCore', '~> 1.4.1'
    s.dependency 'CombineCoreBluetooth', '~> 0.3.1'

    s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end

