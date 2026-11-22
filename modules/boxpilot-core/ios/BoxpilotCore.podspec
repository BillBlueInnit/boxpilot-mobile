Pod::Spec.new do |s|
  s.name           = 'BoxpilotCore'
  s.version        = '1.0.0'
  s.summary        = "BoxPilot's engine and VPN control"
  s.description    = 'The Rust engine (boxpilot-core) behind one JSON entry point, and the packet tunnel manager.'
  s.license        = 'MIT'
  s.author         = 'BoxPilot contributors'
  s.homepage       = 'https://github.com/BillBlueInnit/boxpilot-mobile'
  s.platforms      = { :ios => '16.4' }
  s.swift_version  = '5.9'
  s.source         = { git: 'https://github.com/BillBlueInnit/boxpilot-mobile.git' }
  s.static_framework = true

  s.dependency 'ExpoModulesCore'

  s.source_files = '*.{h,swift}'
  s.public_header_files = 'BoxpilotBridge.h'
  # The Rust bridge, built by scripts/build_rust.sh ios.
  s.vendored_frameworks = 'BoxpilotBridge.xcframework'
  s.frameworks = 'NetworkExtension', 'Security', 'SystemConfiguration'
  s.libraries = 'resolv'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'SWIFT_COMPILATION_MODE' => 'wholemodule'
  }
end
