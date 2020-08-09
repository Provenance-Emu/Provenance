# :frozen_string_literal => true

# Be sure to run `pod lib lint PVSupport.podspec' to ensure this is a
# valid spec before submitting.

Pod::Spec.new do |s|
  s.name             = 'PVSupport'
  s.version          = '1.5.0'
  s.summary          = 'Provenance support framework'

  s.description      = <<-DESC
  PVSupport is a iOS/tvOS library for the Provenance platform.
  DESC

  s.homepage = 'https://github.com/Provenance/Provenance'
  s.license = { :type => 'Provenance License', :file => 'LICENSE.md' }
  s.author  = {
    'James Addyman' => 'james@provenance-emu.com',
    'Joseph Mattiello' => 'joe@provenance-emu.com'
  }
  s.source = {
    :git => 'https://github.com/Provenance/Provenance.git',
    :tag => s.version.to_s
  }

  s.cocoapods_version = '>= 1.8.0'

  s.swift_versions = ['5.0', '5.1']
  s.platform = :ios, '10.3'
  s.requires_arc = true

  s.ios.deployment_target = '10.0'
  s.tvos.deployment_target = '10.0'

  s.frameworks = 'GameController'
  s.frameworks = 'Foundation'

  s.module_name = 'PVSupport'
  s.header_dir = 'PVSupport'

  # s.dependency 'CocoaLumberjack'
  s.dependency 'CocoaLumberjack/Swift'
  s.dependency 'NSLogger'
  # s.dependency 'PVLibrary'

  s.libraries = 'z', 'stdc++', 'xml2'

  s.pod_target_xcconfig = {
    'CLANG_CXX_LANGUAGE_STANDARD' => 'compiler-default',
    'CLANG_CXX_LIBRARY' => 'libc++',
    'OTHER_LDFLAGS' => '$(inherited) -ObjC',
    'HEADER_SEARCH_PATHS' => '$(inherited) "${DT_TOOLCHAIN_DIR}/usr/include" /usr/include/libxml2'
  }

  s.xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -ObjC',
    'HEADER_SEARCH_PATHS' => '$(inherited) "${DT_TOOLCHAIN_DIR}/usr/include" /usr/include/libxml2'
  }

  @sources_root = 'PVSupport/Sources'
  @sources_common = "#{@sources_root}/**/*.{swift,h,m}"
  @headers_common = "#{@sources_root}/**/*.{h}"

  s.public_header_files = [
    @headers_common
  ]

  s.private_header_files = [

  ]


  s.source_files = [
    @sources_common
  ]
end
