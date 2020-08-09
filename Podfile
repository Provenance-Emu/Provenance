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
          lock_pod_sources: lock_pod_sources,
          preserve_pod_file_structure: true

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
  subspecs = %w[
    Atari800
  ]

  options = {
    path: './',
    inhibit_warnings: false,
    project_name: 'ProvenanceCores',
    binary: false,
    subspecs: subspecs
  }

  pod 'ProvenanceCores', options
end

def deps_all
  pvsupport
  pvlibrary
end

def deps_app
  # Rx
  pod 'RxSwift'
  pod 'RxRealm'

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
