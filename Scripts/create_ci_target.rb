#!/usr/bin/env ruby
# Creates a "Provenance-CI" target cloned from "Provenance-Lite (AppStore)"
# with all emulator core dependencies removed, for fast CI builds.

require 'xcodeproj'
require 'fileutils'

PROJECT_PATH = File.expand_path('../Provenance.xcodeproj', __dir__)
WORKSPACE_PATH = File.expand_path('../Provenance.xcworkspace', __dir__)
SOURCE_TARGET_NAME = 'Provenance-Lite (AppStore)'
CI_TARGET_NAME = 'Provenance-CI'

# Core framework patterns to strip
CORE_PATTERNS = [
  /^PVStella/, /^PVPokeMini/, /^PVVirtualJaguar/, /^PVPicoDrive/,
  /^PVAtari800/, /^PVCrabEmu/, /^PVTGBDual/, /^PVFreeDO/,
  /^PVProSystem/, /^PVBliss/, /^PVGambatte/, /^PVVisualBoyAdvance/,
  /^PVCoreMednafen/, /^PVEmuThree/, /^PVPPSSPP/, /^PVMupen64Plus/,
  /^PVBeetlePSX/, /^PVSNES/, /^PVFCEU/, /^PVO2EM/,
  /^PVGenesis/, /^PVGME/, /^PVVecX/, /^PVRSPCXD4/,
  /^PVPotator/, /^PVDesmume/, /^PVCoreBridgeRetro/,
  /^libMoltenVK/, /^MoltenVK/,
  /^snes9x/,  # SNES emulator core framework
]

# macOS-only frameworks to strip for iOS-only CI target
MACOS_ONLY_FRAMEWORKS = [/^OpenGL$/]

def is_core?(name)
  CORE_PATTERNS.any? { |pat| name =~ pat }
end

def is_macos_only?(name)
  MACOS_ONLY_FRAMEWORKS.any? { |pat| name =~ pat }
end

project = Xcodeproj::Project.open(PROJECT_PATH)

# Check if CI target already exists
existing = project.targets.find { |t| t.name == CI_TARGET_NAME }
if existing
  puts "Removing existing #{CI_TARGET_NAME} target..."
  existing.build_phases.each(&:remove_from_project)
  existing.build_configuration_list.build_configurations.each(&:remove_from_project)
  existing.build_configuration_list.remove_from_project
  existing.remove_from_project
end

# Find source target
source = project.targets.find { |t| t.name == SOURCE_TARGET_NAME }
abort "Could not find target '#{SOURCE_TARGET_NAME}'" unless source

puts "Cloning '#{SOURCE_TARGET_NAME}' -> '#{CI_TARGET_NAME}'..."

# Create new target
ci_target = project.new_target(
  :application,
  CI_TARGET_NAME,
  :ios,
  nil, # deployment target inherited from project
  nil, # group
  :swift
)

# Copy build configurations from source
ci_target.build_configuration_list.build_configurations.each(&:remove_from_project)
ci_target.build_configuration_list.remove_from_project

config_list = project.new(Xcodeproj::Project::Object::XCConfigurationList)
config_list.default_configuration_name = source.build_configuration_list.default_configuration_name
config_list.default_configuration_is_visible = source.build_configuration_list.default_configuration_is_visible

source.build_configuration_list.build_configurations.each do |src_config|
  new_config = project.new(Xcodeproj::Project::Object::XCBuildConfiguration)
  new_config.name = src_config.name
  new_config.build_settings = src_config.build_settings.dup
  # Override product name
  new_config.build_settings['PRODUCT_NAME'] = 'Provenance CI'
  new_config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'org.provenance-emu.provenance.ci'
  config_list.build_configurations << new_config
end
ci_target.build_configuration_list = config_list

# Copy build phases (excluding core frameworks)
# 1. Sources phase - use same fileSystemSynchronizedGroups
ci_target.build_phases.clear

sources_phase = ci_target.new_shell_script_build_phase('[CI] Sources')
sources_phase.remove_from_project
sources_phase = project.new(Xcodeproj::Project::Object::PBXSourcesBuildPhase)
ci_target.build_phases << sources_phase

# Copy source files from source target's Sources phase
source.source_build_phase.files.each do |file|
  next unless file.file_ref
  ci_target.source_build_phase.add_file_reference(file.file_ref)
end

# Copy fileSystemSynchronizedGroups (shared reference to the same group)
if source.respond_to?(:file_system_synchronized_groups)
  source.file_system_synchronized_groups.each do |group|
    ci_target.file_system_synchronized_groups << group
  end
end

# 2. Frameworks phase - only non-core frameworks
frameworks_phase = project.new(Xcodeproj::Project::Object::PBXFrameworksBuildPhase)
ci_target.build_phases << frameworks_phase

source_fw_phase = source.frameworks_build_phase
source_fw_phase.files.each do |file|
  next unless file.file_ref
  name = file.file_ref.display_name || file.file_ref.path || ''
  if is_core?(name)
    puts "  Skipping core framework: #{name}"
    next
  end
  if is_macos_only?(name.sub(/\.framework$/, ''))
    puts "  Skipping macOS-only framework: #{name}"
    next
  end
  frameworks_phase.add_file_reference(file.file_ref)
end

# 3. Resources phase — skip tvOS-specific resources (storyboards, assets)
resources_phase = project.new(Xcodeproj::Project::Object::PBXResourcesBuildPhase)
ci_target.build_phases << resources_phase

TVOS_SKIP_PATTERNS = [/ProvenanceTV/, /LaunchScreenTV/, /TVAssets/, /LaunchImageTV/]

if source.resources_build_phase
  source.resources_build_phase.files.each do |file|
    next unless file.file_ref
    path = file.file_ref.real_path.to_s rescue file.file_ref.path.to_s rescue ''
    name = file.file_ref.display_name || file.file_ref.path || ''
    if TVOS_SKIP_PATTERNS.any? { |pat| path =~ pat || name =~ pat }
      puts "  Skipping tvOS resource: #{name}"
      next
    end
    resources_phase.add_file_reference(file.file_ref)
  end
end

# 4. Copy Embed Frameworks phase - only non-core
embed_phase = project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
embed_phase.name = 'Embed Frameworks'
embed_phase.symbol_dst_subfolder_spec = :frameworks
ci_target.build_phases << embed_phase

source.copy_files_build_phases.each do |phase|
  next unless phase.name == 'Embed Frameworks'
  phase.files.each do |file|
    next unless file.file_ref
    name = file.file_ref.display_name || file.file_ref.path || ''
    if is_core?(name)
      puts "  Skipping core embed: #{name}"
      next
    end
    build_file = embed_phase.add_file_reference(file.file_ref)
    build_file.settings = file.settings.dup if file.settings
  end
end

# 5. Copy non-core package dependencies
source.package_product_dependencies.each do |dep|
  name = dep.product_name || ''
  if is_core?(name)
    puts "  Skipping core SPM dep: #{name}"
    next
  end
  # Create new package product dependency
  new_dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  new_dep.product_name = dep.product_name
  new_dep.package = dep.package if dep.respond_to?(:package)
  ci_target.package_product_dependencies << new_dep
end

# Skip the Check Git Submodules dependency (not needed for CI)
puts "  Skipping 'Check Git Submodules' dependency (not needed for CI)"

# Save project
project.save
puts "\nSaved project with new '#{CI_TARGET_NAME}' target."

# Create scheme
scheme_path = File.join(WORKSPACE_PATH, 'xcshareddata', 'xcschemes')
FileUtils.mkdir_p(scheme_path)

scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(ci_target)
scheme.set_launch_target(ci_target)

# Set build configuration to Debug for speed
scheme.launch_action.build_configuration = 'Debug'
scheme.test_action.build_configuration = 'Debug'
scheme.analyze_action.build_configuration = 'Debug'
scheme.archive_action.build_configuration = 'Debug'

scheme.save_as(PROJECT_PATH, CI_TARGET_NAME, true)
puts "Created scheme: #{CI_TARGET_NAME}"
puts "\nDone! Build with:"
puts "  xcodebuild build -workspace Provenance.xcworkspace -scheme '#{CI_TARGET_NAME}' -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO"
