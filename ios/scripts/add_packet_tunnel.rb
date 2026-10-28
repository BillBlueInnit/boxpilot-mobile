# Adds the PacketTunnel network extension to Runner.xcodeproj and links Libbox.
# Idempotent; runs on macOS (CI) where the xcodeproj gem ships with CocoaPods:
#
#   ruby ios/scripts/add_packet_tunnel.rb
require 'xcodeproj'

ios = File.expand_path('..', __dir__)
project = Xcodeproj::Project.open(File.join(ios, 'Runner.xcodeproj'))
runner = project.targets.find { |t| t.name == 'Runner' }
bundle_id = 'io.github.billblueinnit.boxpilot'
deployment = '15.0'

libbox_ref = project.frameworks_group.files.find { |f| f.path == 'Libbox.xcframework' } ||
             project.frameworks_group.new_file('Libbox.xcframework', :group)

runner.build_configurations.each do |c|
  c.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
  c.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = deployment
end
# Only the extension links libbox; the app reads the core through its Clash API.
runner.frameworks_build_phase.files.select { |f| f.file_ref == libbox_ref }.each(&:remove_from_project)
host = runner.source_build_phase
runner_group = project.main_group['Runner']
core_host = runner_group.files.find { |f| f.path == 'CoreHost.swift' } || runner_group.new_file('CoreHost.swift')
host.add_file_reference(core_host) unless host.files_references.include?(core_host)

tunnel = project.targets.find { |t| t.name == 'PacketTunnel' }
unless tunnel
  tunnel = project.new_target(:app_extension, 'PacketTunnel', :ios, deployment)
  group = project.main_group['PacketTunnel'] || project.main_group.new_group('PacketTunnel', 'PacketTunnel')
  source = group.files.find { |f| f.path == 'PacketTunnelProvider.swift' } || group.new_file('PacketTunnelProvider.swift')
  group.new_file('Info.plist') unless group.files.any? { |f| f.path == 'Info.plist' }
  group.new_file('PacketTunnel.entitlements') unless group.files.any? { |f| f.path == 'PacketTunnel.entitlements' }
  tunnel.source_build_phase.add_file_reference(source)
  tunnel.frameworks_build_phase.add_file_reference(libbox_ref)
  # libbox uses UIKit (screen state, background tasks) besides NetworkExtension.
  %w[NetworkExtension UIKit].each do |name|
    fw = project.frameworks_group.new_file("System/Library/Frameworks/#{name}.framework", :sdk_root)
    tunnel.frameworks_build_phase.add_file_reference(fw)
  end
  %w[libresolv.tbd].each do |lib|
    tunnel.frameworks_build_phase.add_file_reference(project.frameworks_group.new_file("usr/lib/#{lib}", :sdk_root))
  end

  tunnel.build_configurations.each do |c|
    s = c.build_settings
    s['PRODUCT_BUNDLE_IDENTIFIER'] = "#{bundle_id}.PacketTunnel"
    s['PRODUCT_NAME'] = '$(TARGET_NAME)'
    s['INFOPLIST_FILE'] = 'PacketTunnel/Info.plist'
    s['CODE_SIGN_ENTITLEMENTS'] = 'PacketTunnel/PacketTunnel.entitlements'
    s['IPHONEOS_DEPLOYMENT_TARGET'] = deployment
    s['SWIFT_VERSION'] = '5.0'
    s['TARGETED_DEVICE_FAMILY'] = '1,2'
    s['SKIP_INSTALL'] = 'YES'
    s['FRAMEWORK_SEARCH_PATHS'] = ['$(inherited)', '$(PROJECT_DIR)']
    s['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
    s['FLUTTER_BUILD_NAME'] = '$(FLUTTER_BUILD_NAME)'
    s['ENABLE_BITCODE'] = 'NO'
    s['GENERATE_INFOPLIST_FILE'] = 'NO'
  end
  # The extension reads FLUTTER_BUILD_NAME/NUMBER from the same xcconfig as Runner.
  runner.build_configurations.each do |rc|
    tc = tunnel.build_configurations.find { |c| c.name == rc.name }
    tc.base_configuration_reference = rc.base_configuration_reference if tc
  end

  embed = runner.copy_files_build_phases.find { |p| p.name == 'Embed Foundation Extensions' } ||
          runner.new_copy_files_build_phase('Embed Foundation Extensions')
  embed.symbol_dst_subfolder_spec = :plug_ins
  embed.add_file_reference(tunnel.product_reference).settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
  runner.add_dependency(tunnel)
end

# Embedding the extension after Flutter's "Thin Binary" script makes a build cycle;
# it has to run before the script phases.
embed = runner.copy_files_build_phases.find { |p| p.name == 'Embed Foundation Extensions' }
first_script = runner.build_phases.index { |p| p.is_a?(Xcodeproj::Project::Object::PBXShellScriptBuildPhase) && p.name.to_s.include?('Thin Binary') }
if embed && first_script && runner.build_phases.index(embed) > first_script
  runner.build_phases.delete(embed)
  runner.build_phases.insert(first_script, embed)
end

# Libbox is a static framework inside the xcframework, so the extension links it; nothing is embedded.
project.save
puts 'PacketTunnel target ready'
