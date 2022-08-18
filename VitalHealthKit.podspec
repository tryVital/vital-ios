Pod::Spec.new do |s|
    s.name = 'VitalHealthKit'
    s.version = '0.5.5'
    s.license = 'GPL v3.0'
    s.summary = 'The official Swift Library for Vital API, HealthKit and Devices'
    s.homepage = 'https://github.com/tryVital/vital-ios'
    s.authors = { 'Vital' => 'contact@tryVital.io' }
    s.source = { :git => 'https://github.com/tryVital/vital-ios.git', :tag => s.version }
    s.documentation_url = 'https://docs.tryvital.io/wearables/sdks/iOS'
  
    s.ios.deployment_target = '14.0'
    s.swift_versions = ['5']
    s.source_files = 'Sources/VitalHealthKit/**/*.swift'
    s.social_media_url = 'https://twitter.com/tryVital'

    s.dependency 'VitalCore'
end

