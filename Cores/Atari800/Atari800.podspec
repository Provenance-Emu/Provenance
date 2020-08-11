# :frozen_string_literal => true

# Be sure to run `pod lib lint ProvenanceCores.podspec' to ensure this is a
# valid spec before submitting.

Pod::Spec.new do |s|
  s.name             = 'Atari800'
  s.version          = '1.5'
  s.summary          = 'Atari800 Provenance Emulator Cores'

  s.description      = <<-DESC
  Atari800 is the iOS framework for the Provenance Atari800 emulator core.
  Upsream core http://sourceforge.net/projects/atari800/
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

  s.module_name = 'Atari800'
  s.header_dir = 'Atari800'

  s.frameworks = 'Foundation'
  s.libraries = 'z', 'edit'

  s.dependency 'PVSupport', '~> 1.5'
  s.dependency 'PVLibrary', '~> 1.5'

  s.pod_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -ObjC',
    'GCC_C_LANGUAGE_STANDARD' => 'gnu99'
  }

  upstream_sources = %w[
    rtime.c
    ide.c
    crc32.c
    cycle_map.c
    colours_pal.c
    pbi_mio.c
    log.c
    afile.c
    img_tape.c
    pokeysnd.c
    util.c
    colours_external.c
    pbi_scsi.c
    artifact.c
    ui_basic.c
    pbi_bb.c
    binload.c
    colours.c
    statesav.c
    cartridge.c
    memory.c
    mzpokeysnd.c
    sio.c
    pbi.c
    monitor.c
    pokey.c
    esc.c
    compfile.c
    pia.c
    remez.c
    cassette.c
    cfg.c
    sndsave.c
    antic.c
    atari.c
    screen.c
    sysrom.c
    colours_ntsc.c
    emuos.c
    devices.c
    input.c
    sound.c
    cpu.c
    gtia.c
    afile.h
    akey.h
    antic.h
    atari.h
    cartridge.h
    cassette.h
    cfg.h
    colours.h
    colours_ntsc.h
    config.h
    devices.h
    gtia.h
    ide.h
    input.h
    memory.h
    pbi.h
    pia.h
    platform.h
    pokey.h
    pokeysnd.h
    rtime.h
    sio.h
    sound.h
    statesav.h
    sysrom.h
    ui.h
  ].map { |file| "Sources/atari800-src/#{file}" }

  core_sources = %w[
    PVAtari800.h
    ATR800GameCore/**/*.{swift,h,m,mm}
  ].map { |file| "Sources/#{file}" }

  s.source_files = upstream_sources + core_sources

  s.public_header_files = %w[
    atari800-src/platform.h
    ATR800GameCore/ATR800GameCore.h
    PVAtari800.h
  ].map { |file| "Sources/#{file}" }

  s.pod_target_xcconfig = { 'PRODUCT_BUNDLE_IDENTIFIER': 'com.provenance-emu.PVAtari800' }
  s.resources = [
    'Resources/**/*.*'
  ]

  s.pod_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -ObjC',
    'CORE_ATARI800_SUBSPEC_INCLUDED' => '-D\'CORE_ATARI800_SUBSPEC_INCLUDED\'',
    'OTHER_SWIFT_FLAGS' => '$(CORE_ATARI800_SUBSPEC_INCLUDED)',
    'GCC_C_LANGUAGE_STANDARD' => 'gnu99',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'gnu++0x',
    'CLANG_CXX_LIBRARY' => 'libc++'
  }
end
