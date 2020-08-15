# :frozen_string_literal => true

# Be sure to run `pod lib lint ProvenanceCores.podspec' to ensure this is a
# valid spec before submitting.

Pod::Spec.new do |s|
  s.name             = 'FCEU'
  s.version          = '1.5'
  s.summary          = 'FCEU Provenance Emulator Cores'

  s.description      = <<-DESC
  FCEU is the iOS framework for the Provenance FCEU emulator core.
  Upsream core https://github.com/TASVideos/fceux/
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

  s.requires_arc = true
  s.cocoapods_version = '>= 1.8.0'

  s.swift_versions = ['5.0', '5.1']
  s.platform = :ios, '10.3'

  s.ios.deployment_target = '10.0'
  s.tvos.deployment_target = '10.0'

  s.module_name = 'PVFCEU'
  s.header_dir = 'PVFCEU'

  s.frameworks = 'Foundation', 'OpenGLES'
  s.libraries = 'z'

  s.dependency 'PVSupport', '~> 1.5'
  s.dependency 'PVLibrary', '~> 1.5'

  upstream_sources = %w[
    asm
    cart
    cheat
    conddebug
    config
    driver
    debug
    drawing
    emufile
    fceu
    fds
    file
    filter
    ines
    input
    lua-engines
    movie
    netplay
    nsf
    oldmovie
    palette
    ppu
    sound
    state
    types
    unif
    video
    vsuni
    wave
    x6502
    drivers/common/*
    boards/*
    input/*
    utils/*
  ].map { |file| "Sources/upstream/#{file}.{h,hpp,cpp,c}" }

  core_sources = %w[
    PVFCEU/**/*.{m,mm,swift}
    PVFCEU/PVFCEU.h
    PVFCEU/PVFCEUEmulatorCore/PVFCEUEmulatorCore.h
  ].map { |file| "Sources/#{file}" }

  s.source_files = upstream_sources + core_sources

  # s.preserve_path = 'Sources/upstream/'
  # s.header_mappings_dir = 'Sources/upstream/'

  s.public_header_files = %w[
    PVFCEU.h
    PVFCEUEmulatorCore/PVFCEUEmulatorCore.h
  ].map { |file| "Sources/PVFCEU/#{file}" }

  # s.private_header_files = %w[
  #   PVFCEU/PVFCEU+Swift.h
  #   PVFCEU/PVFCEUEmulatorCore+Controls/PVFCEUEmulatorCore+Controls.h
  #   upstream/ppu.h
  #   upstream/*.h
  #   upstream/utils/**/*.h
  # ].map { |file| "Sources/#{file}" }

  s.resources = [
    'Resources/**/*.*'
  ]

  s.compiler_flags = '-DCORE_FCEUX_SUBSPEC_INCLUDED', '-DHAVE_ASPRINTF', '-DPSS_STYLE=1', '-DLSB_FIRST', '-Wno-write-strings'

  s.pod_target_xcconfig = {
    'PRODUCT_BUNDLE_IDENTIFIER': 'com.provenance-emu.FCEU',
    'OTHER_LDFLAGS' => '$(inherited) -ObjC',
    'CORE_FCEU_SUBSPEC_INCLUDED' => '-D\'CORE_FCEU_SUBSPEC_INCLUDED\'',
    'OTHER_SWIFT_FLAGS' => '$(CORE_FCEU_SUBSPEC_INCLUDED)',
    # 'GCC_C_LANGUAGE_STANDARD' => 'c99',
    # 'CLANG_CXX_LANGUAGE_STANDARD' => 'gnu++0x',
    # 'CLANG_CXX_LIBRARY' => 'libc++'
  }
end
