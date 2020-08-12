# :frozen_string_literal => true

# Be sure to run `pod lib lint PVLibrary.podspec' to ensure this is a
# valid spec before submitting.

Pod::Spec.new do |s|
  s.name             = 'PVLibrary'
  s.version          = '1.5.0'
  s.summary          = 'Provenance ROM library framework'

  s.description      = <<-DESC
  PVLibrary is a iOS/tvOS library for the Provenance library platform.
  DESC

  s.homepage = 'https://github.com/Provenance/Provenance'
  s.license = { type: 'Provenance License', file: 'LICENSE.md' }
  s.author  = {
    'James Addyman' => 'james@provenance-emu.com',
    'Joseph Mattiello' => 'joe@provenance-emu.com'
  }
  s.source = {
    git: 'https://github.com/Provenance/Provenance.git',
    tag: s.version.to_s
  }

  s.cocoapods_version = '>= 1.8.0'

  s.swift_versions = ['5.0', '5.1']
  s.platform = :ios, '10.3'

  s.ios.deployment_target = '10.0'
  s.tvos.deployment_target = '10.0'
  s.osx.deployment_target = '10.15'

  s.frameworks = 'CoreGraphics', 'CoreServices', 'Foundation'

  s.module_name = 'PVLibrary'
  s.header_dir = 'PVLibrary'

  s.dependency 'PVSupport'
  s.dependency 'LzmaSDK-ObjC'
  s.dependency 'RealmSwift'
  s.dependency 'RxCocoa'
  s.dependency 'RxRealm'
  s.dependency 'RxSwift'
  s.dependency 'SQLite.swift'
  s.dependency 'SSZipArchive'
  s.dependency 'SWCompression'

  @sources_root = 'PVLibrary/Sources'
  @tests_root = 'PVLibrary/Tests'

  s.public_header_files = "#{@sources_root}/**/*.{h}"
  # s.private_header_files = "#{@sources_root}/**/*.{h}"

  @sources_common = "#{@sources_root}/**/*.{swift,h,m,mm,c}"

  s.source_files = [
    @sources_common
  ]

  s.resources = [
    "#{@sources_root}/Resources/*.*"
  ]

  s.pod_target_xcconfig = { 
    'OTHER_LDFLAGS' => '-lObjC',
    'OTHER_SWIFT_FLAGS[config=Debug]' => '-DDEBUG',
    'PRODUCT_BUNDLE_IDENTIFIER': 'com.provenance-emu.PVLibrary'
  }

  s.test_spec 'PVLibraryTests' do |test_spec|
    test_spec.requires_app_host = false
    # test_spec.test_type = :ui
    test_spec.source_files = 'PVLibrary/Tests/**/*.swift'
  end
end
