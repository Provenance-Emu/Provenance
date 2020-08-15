# :frozen_string_literal => true

# Be sure to run `pod lib lint ProvenanceCores.podspec' to ensure this is a
# valid spec before submitting.

Pod::Spec.new do |s|
  s.name             = 'PVGambatte'
  s.version          = '1.5'
  s.summary          = 'Gambatte Provenance Emulator Cores'

  s.description      = <<-DESC
  Gambatte is the iOS framework for the Provenance Gambatte emulator core.
  Upsream core https://github.com/sinamas/gambatte
  DESC

  s.homepage = 'https://provenance-emu.com'
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

  s.ios.deployment_target = '10.0'
  s.tvos.deployment_target = '10.0'

  s.module_name = 'PVGambatte'
  s.header_dir = 'PVGambatte'

  s.frameworks = 'Foundation', 'OpenGLES'
  s.libraries = 'c++'

  s.dependency 'PVSupport', '~> 1.5'

  ## Our code
  core_headers_public = %w[
    PVGambatteEmulatorCore/*.h
  ].map { |file| "Sources/#{file}" }

  core_headers_private = %w[
    PVGambatte/gbcpalettes.h
  ].map { |file| "Sources/#{file}" }

  core_sources = %w[
    PVGambatte/gbcpalettes.h
    PVGambatteEmulatorCore/*.{h,m,mm,swift}
  ].map { |file| "Sources/#{file}" }

  ## Upstream project
  upstream_sources = %w[
    common/resample/src/**/*.{h,cpp}
    libgambatte/src/*.{cpp}
    libgambatte/src/file/file.{h,cpp}
    libgambatte/src/mem/*.{h,cpp}
    libgambatte/src/sound/*.{h,cpp}
    libgambatte/src/video/*.{h,cpp}
  ].map { |file| "Sources/upstream/#{file}" }

  libgambatte_headers_private = %w[
    common/resample/src/**/*.h
    common/*.h
    libgambatte/include/gambatte.h
    libgambatte/include/gbint.h
    libgambatte/include/inputgetter.h
    libgambatte/include/loadres.h
    libgambatte/include/pakinfo.h
    libgambatte/src/*.h
    libgambatte/src/file/file.h
    libgambatte/src/mem/*.h
    libgambatte/src/sound/*.h
    libgambatte/src/video/*.h
  ].map { |file| "Sources/upstream/#{file}" }

  s.public_header_files = core_headers_public
  s.private_header_files = core_headers_private + libgambatte_headers_private
  s.source_files = upstream_sources + core_sources + core_headers_public + libgambatte_headers_private
  # s.header_mappings_dir = 'Sources/upstream/libgambatte/src/'
  s.preserve_paths = %w[
    Sources/upstream/libgambatte/src/file/
    Sources/upstream/libgambatte/include/
  ]

  ## Resources
  s.resources = [
    'Resources/**/*.*'
  ]

  ## Settings
  s.compiler_flags = '-DCORE_GAMBATTE_SUBSPEC_INCLUDED', '-DHAVE_STDINT_H'

  s.pod_target_xcconfig = {
    'PRODUCT_BUNDLE_IDENTIFIER': 'com.provenance-emu.PVGambatte',
    'CORE_GAMBATTE_SUBSPEC_INCLUDED' => '-D\'CORE_GAMBATTE_SUBSPEC_INCLUDED\'',
    'OTHER_SWIFT_FLAGS' => '$(CORE_GAMBATTE_SUBSPEC_INCLUDED)',
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'gnu++11',
    'CLANG_CXX_LIBRARY' => 'libc++'
  }

  s.test_spec 'GambatteTests' do |test_spec|
    test_spec.requires_app_host = false
    # test_spec.test_type = :ui
    test_spec.resources = [
      'Resources/**/*.*'
    ]

    test_spec.source_files = 'Tests/**/*.swift'
  end
end
