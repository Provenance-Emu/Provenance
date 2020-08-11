# frozen_string_literal true

is_ci = false
clean = false
lock_pod_sources = !is_ci

source 'https://cdn.cocoapods.org/'

plugin 'cocoapods-binary'
plugin 'cocoapods-githooks'

use_frameworks!
inhibit_all_warnings!
# all_binary!
# ensure_bundler! '> 2.0'

workspace 'Provenance.xcworkspace'
project 'Provenance.xcodeproj'

# plugin 'cocoapods-check'
install!  'cocoapods',
          generate_multiple_pod_projects: true,
          clean: clean,
          deduplicate_targets: true,
          incremental_installation: true,
          share_schemes_for_development_pods: true,
          deterministic_uuids: true,
          lock_pod_sources: lock_pod_sources

def pvlibrary
  pod 'LzmaSDK-ObjC',
      git: 'https://github.com/Provenance-Emu/LzmaSDKObjC.git',
      branch: 'master'

  options = {
    path: './',
    inhibit_warnings: false,
    binary: false,
    project_name: 'PVLibrary',
    # appspecs: appspecs,
    # subspecs: subspecs,
    testspecs: ['PVLibraryTests']
  }

  pod 'PVLibrary', options
end

def pvsupport
  options = {
    path: './',
    inhibit_warnings: false,
    binary: false,
    project_name: 'PVSupport',
    testspecs: ['PVSupportTests']
  }

  pod 'PVSupport', options
end

def cores
  cores = %w[
    Atari800
    PokeMini
  ]

  cores.each { |core|
    options = {
      path: './Cores/' + core,
      inhibit_warnings: false,
      project_name: 'Cores',
      binary: false
    }

    pod core, options
  }
end

def deps_all
  pvsupport
  pvlibrary
end

def deps_app

  # Rx
  pod 'RxSwift'
  pod 'RxRealm'

  pod 'QuickTableViewController'
  pod 'RxDataSources'
  pod 'RxReachability', git: 'https://github.com/RxSwiftCommunity/RxReachability.git', tag: '1.1.0'
  pod 'SteamController'

  cores
end

deps_all

abstract_target 'ProvenanceApps' do
  deps_app

  # iOS
  target 'Provenance' do
    platform :ios, '10.0'

    # https://docs.microsoft.com/en-us/appcenter/sdk/getting-started/ios#31-integration-via-cocoapods
    pod 'AppCenter/Analytics'
    pod 'AppCenter/Distribute'
    pod 'AppCenter/Crashes'

    pod 'RxGesture'

    pod 'XLActionController',
        git: 'https://github.com/Puasonych/XLActionController.git',
        branch: 'update-for-xcode-11'

    target 'Provenance Tests' do
      inherit! :search_paths
      # RxTest and RxBlocking make the most sense in the context of unit/integration tests
      # pod 'RxBlocking', '~> 5'
      # pod 'RxTest', '~> 5'
    end
  end

  # tvOS
  target 'ProvenanceTV' do
    platform :tvos, '10.0'
  end
end

target 'Spotlight' do
  platform :ios, '10.0'
end

target 'TopShelf' do
  platform :tvos, '10.0'
  pod 'CocoaLumberjack/Swift'
end

#post_install do |installer|
#  installer.generated_aggregate_targets.each do |project|
#    puts "Setting preprocessor macro for #{project}..."
#    project.targets.each do |target|
#      puts "Setting preprocessor macro for #{target.name}..."
#      if target.name.include?('SSZipArchive')
#        puts "Setting preprocessor macro for #{target.name}..."
#        target.build_configurations.each do |config|
#          puts "#{config} configuration..."
#          puts "before: #{config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'].inspect}"
#          config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)']
#          config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] << 'LZMASDKOBJC=1'
#          config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] << 'LZMASDKOBJC_OMIT_UNUSED_CODE=1'
#          puts "after: #{config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'].inspect}"
#          puts '---'
#        end
#      end
#    end
#  end
#end

post_install do |installer|
  installer.generated_projects.each do |project|
    project.targets.each do |target|
      target.build_configurations.each do |config|
        config.build_settings['CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES'] = 'YES'
        config.build_settings['ENABLE_BITCODE'] = 'NO'
        config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'NO'
        config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)']
        config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] << 'LZMASDKOBJC=1'
        config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] << 'LZMASDKOBJC_OMIT_UNUSED_CODE=1'
      end
    end
  end
end
