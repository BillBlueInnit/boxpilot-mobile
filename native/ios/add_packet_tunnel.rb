# Adds the PacketTunnel network extension to the Xcode project that
# `npx expo prebuild --platform ios` generated, and links Libbox into it.
# Idempotent; runs on macOS (CI), where the xcodeproj gem ships with CocoaPods:
#
#   ruby native/ios/add_packet_tunnel.rb
#
# The extension's sources stay in native/ios/PacketTunnel and are referenced
# from there, so prebuild can regenerate ios/ at any time.
require 'xcodeproj'

root = File.expand_path('../..', __dir__)
ios = File.join(root, 'ios')
project_path = Dir[File.join(ios, '*.xcodeproj')].first or abort('run `npx expo prebuild --platform ios` first')
project = Xcodeproj::Project.open(project_path)
app = project.targets.find { |t| t.product_type == 'com.apple.product-type.application' } or abort('no app target')
bundle_id = 'io.github.billblueinnit.boxpilot'
deployment = app.build_configurations.first.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] || '16.4'
sources = File.join(root, 'native', 'ios')
# The same folder for build settings, so the project does not hold absolute paths.
settings_dir = '$(SRCROOT)/../native/ios'

unless project.targets.any? { |t| t.name == 'PacketTunnel' }
  tunnel = project.new_target(:app_extension, 'PacketTunnel', :ios, deployment)
  group = project.main_group.new_group('PacketTunnel', File.join(sources, 'PacketTunnel'))
  source = group.new_file('PacketTunnelProvider.swift')
  group.new_file('Info.plist')
  group.new_file('PacketTunnel.entitlements')
  tunnel.source_build_phase.add_file_reference(source)

  # sing-box, built by scripts/build_libbox.sh apple. Only the extension links
  # it; the app reads the core through its Clash API.
  libbox = project.frameworks_group.new_file(File.join(sources, 'Libbox.xcframework'))
  tunnel.frameworks_build_phase.add_file_reference(libbox)
  # libbox uses UIKit (screen state, background tasks) besides NetworkExtension.
  %w[NetworkExtension UIKit].each do |name|
    fw = project.frameworks_group.new_file("System/Library/Frameworks/#{name}.framework", :sdk_root)
    tunnel.frameworks_build_phase.add_file_reference(fw)
  end
  tunnel.frameworks_build_phase.add_file_reference(project.frameworks_group.new_file('usr/lib/libresolv.tbd', :sdk_root))

  app_settings = app.build_configurations.first.build_settings
  tunnel.build_configurations.each do |c|
    s = c.build_settings
    s['PRODUCT_BUNDLE_IDENTIFIER'] = "#{bundle_id}.PacketTunnel"
    s['PRODUCT_NAME'] = '$(TARGET_NAME)'
    s['INFOPLIST_FILE'] = "#{settings_dir}/PacketTunnel/Info.plist"
    s['CODE_SIGN_ENTITLEMENTS'] = "#{settings_dir}/PacketTunnel/PacketTunnel.entitlements"
    s['IPHONEOS_DEPLOYMENT_TARGET'] = deployment
    s['MARKETING_VERSION'] = app_settings['MARKETING_VERSION'] || '1.0'
    s['CURRENT_PROJECT_VERSION'] = app_settings['CURRENT_PROJECT_VERSION'] || '1'
    s['SWIFT_VERSION'] = '5.0'
    s['TARGETED_DEVICE_FAMILY'] = '1,2'
    s['SKIP_INSTALL'] = 'YES'
    s['FRAMEWORK_SEARCH_PATHS'] = ['$(inherited)', settings_dir]
    s['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
    s['ENABLE_BITCODE'] = 'NO'
    s['GENERATE_INFOPLIST_FILE'] = 'NO'
  end

  embed = app.new_copy_files_build_phase('Embed Foundation Extensions')
  embed.symbol_dst_subfolder_spec = :plug_ins
  embed.add_file_reference(tunnel.product_reference).settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
  app.add_dependency(tunnel)

  # Embedding the extension after the script phases (bundling, CocoaPods) can
  # make a build cycle; it goes right after the app's own resources.
  resources = app.build_phases.index(app.resources_build_phase)
  app.build_phases.delete(embed)
  app.build_phases.insert(resources + 1, embed)
end

project.save
puts 'PacketTunnel target ready'
