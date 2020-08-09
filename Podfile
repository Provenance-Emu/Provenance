# frozen_string_literal: true

isCI = false

source 'https://cdn.cocoapods.org/'

use_frameworks!
inhibit_all_warnings!

workspace 'Provenance.xcworkspace'
project 'Provenance.xcodeproj'

plugin 'cocoapods-githooks'
plugin 'cocoapods-check'

install!  'cocoapods',
          :generate_multiple_pod_projects => true,
          :clean => !isCI,
          :deduplicate_targets => true,
          :incremental_installation => true,
          :share_schemes_for_development_pods => true,
          :deterministic_uuids => true,
          :lock_pod_sources => !isCI,
          :preserve_pod_file_structure => true


def pvlibrary
  options = {
    :path => './',
    :inhibit_warnings => false,
    :project_name => 'PVLibrary'
    # :appspecs => appspecs,
    # :subspecs => subspecs,
    # :testspecs => testspecs
  }

  pod 'PVLibrary', options
end

def pvsupport
  options = {
    :path => './',
    :inhibit_warnings => false,
    :project_name => 'PVSupport'
    # :appspecs => appspecs,
    # :subspecs => subspecs,
    # :testspecs => testspecs
  }

  pod 'PVSupport', options
end

def cores
  subspecs = %w[
    Atari800
  ]

  options = {
    :path => './',
    :inhibit_warnings => false,
    :project_name => 'ProvenanceCores',
    :subspecs => subspecs
  }

  pod 'ProvenanceCores', options
end

def deps_app
  pvsupport
  pvlibrary

  # Rx
  pod 'RxSwift'
  pod 'RxRealm'

  cores
end

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
        :git => 'https://github.com/Puasonych/XLActionController.git',
        :branch => 'update-for-xcode-11'
  end

  # tvOS
  target 'ProvenanceTV' do
    platform :tvos, '10.0'
  end
end

target 'Spotlight' do
  platform :ios, '10.0'

  pvsupport
  pvlibrary
end

target 'TopShelf' do
  platform :tvos, '10.0'

  pvsupport
  pvlibrary

  pod 'CocoaLumberjack/Swift'
end
