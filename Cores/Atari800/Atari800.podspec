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

  s.module_name = 'PVAtari800'
  s.header_dir = 'PVAtari800'

  s.frameworks = 'Foundation'
  s.libraries = 'z', 'edit'

  s.dependency 'PVSupport', '~> 1.5'
  s.dependency 'PVLibrary', '~> 1.5'

  upstream_sources = %w[
    afile.c
    afile.h
    akey.h
    antic.c
    antic.h
    artifact.c
    atari.c
    atari.h
    binload.c
    cartridge.c
    cartridge.h
    cartridge_info.c
    cartridge_info.h
    cassette.c
    cassette.h
    cfg.c
    cfg.h
    colours_external.c
    colours_ntsc.c
    colours_ntsc.h
    colours_pal.c
    colours.c
    colours.h
    compfile.c
    config.h
    cpu.c
    crc32.c
    cycle_map.c
    devices.c
    devices.h
    emuos.c
    esc.c
    gtia.c
    gtia.h
    ide.c
    ide.h
    img_tape.c
    input.c
    input.h
    log.c
    memory.c
    memory.h
    monitor.c
    mzpokeysnd.c
    pbi_bb.c
    pbi_mio.c
    pbi_scsi.c
    pbi.c
    pbi.h
    pia.c
    pia.h
    platform.h
    pokey.c
    pokey.h
    pokeysnd.c
    pokeysnd.h
    remez.c
    rtime.c
    rtime.h
    screen.c
    sio.c
    sio.h
    sndsave.c
    sound.c
    sound.h
    statesav.c
    statesav.h
    sysrom.c
    sysrom.h
    ui_basic.c
    ui.h
    util.c
    roms/*.{h,c}
  ].map { |file| "Sources/upstream/src/#{file}" }

  core_sources = %w[
    config.h
    PVAtari800.h
    ATR800GameCore/**/*.{swift,h,m,mm}
  ].map { |file| "Sources/#{file}" }

  s.source_files = upstream_sources + core_sources

  s.public_header_files = %w[
    ATR800GameCore/ATR800GameCore.h
    PVAtari800.h
  ].map { |file| "Sources/#{file}" }

  s.private_header_files = %w[
    upstream/src/platform.h
    config.h
  ].map { |file| "Sources/#{file}" }

  s.resources = [
    'Resources/**/*.*'
  ]

  s.compiler_flags = '-DCORE_ATARI800_SUBSPEC_INCLUDED', '-DGWINSZ_IN_SYS_IOCTL'

  s.pod_target_xcconfig = {
    'PRODUCT_BUNDLE_IDENTIFIER': 'com.provenance-emu.PVAtari800',
    'OTHER_LDFLAGS' => '$(inherited) -ObjC',
    'CORE_ATARI800_SUBSPEC_INCLUDED' => '-D\'CORE_ATARI800_SUBSPEC_INCLUDED\'',
    'OTHER_SWIFT_FLAGS' => '$(CORE_ATARI800_SUBSPEC_INCLUDED)',
    'GCC_C_LANGUAGE_STANDARD' => 'gnu99',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'gnu++0x',
    'CLANG_CXX_LIBRARY' => 'libc++'
  }
end
