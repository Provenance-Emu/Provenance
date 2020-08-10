# :frozen_string_literal => true

# Be sure to run `pod lib lint ProvenanceCores.podspec' to ensure this is a
# valid spec before submitting.

Pod::Spec.new do |s|
  s.name             = 'ProvenanceCores'
  s.version          = '1.5'
  s.summary          = 'Provenance Emulator Cores'
  
  s.description      = <<-DESC
  ProvenanceCores is the iOS library for the NewsCorp ProvenanceCores platform.
  DESC
  
  s.homepage = 'https://github.com/Provenance/Provenance'
  s.license = { :type => 'Provenance License', :file => 'LICENSE.md' }
  s.author  = {
    'James Addyman' => 'james@provenance-emu.com',
    'Joseph Mattiello' => 'joe@provenance-emu.com'
  }
  s.source           = {
    :git => 'https://github.com/Provenance/Provenance.git',
    :tag => s.version.to_s
  }

  s.cocoapods_version = '>= 1.8.0'

  s.swift_versions = ['5.0', '5.1']
  s.platform = :ios, '10.3'

  s.ios.deployment_target = '10.0'
  s.tvos.deployment_target = '10.0'

  s.frameworks = 'UIKit', 'Foundation'

  s.module_name = 'ProvenanceCores'
  s.header_dir = 'ProvenanceCores'
  s.default_subspecs = 'Atari800', 'PokeMini'

  @cores_source_root = 'Cores'

	s.dependency 'PVSupport'
	s.dependency 'PVLibrary'

	s.frameworks = 'Foundation'
	s.pod_target_xcconfig = {
		'OTHER_LDFLAGS' => '$(inherited) -ObjC',
		'GCC_C_LANGUAGE_STANDARD' => 'gnu99',
	}

    # ------ Atari800
    s.subspec 'Atari800' do |core|
      # core.frameworks = 'CoreGraphics'
      # core.weak_frameworks = 'AdSupport'

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
      ].map { |file| "#{@cores_source_root}/Atari800/atari800-src/#{file}" }

      core_sources = %w[
        **/*.{swift,m,mm}
      ].map { |file| "#{@cores_source_root}/Atari800/#{file}" }

      core.source_files = upstream_sources + core_sources

      core.public_header_files = %w[
        atari800-src/platform.h
        PVAtari800/PVAtari800.h
        Atari800Core/Source/ATR800GameCore.h
      ].map { |file| "#{@cores_source_root}/Atari800/#{file}" }

      core.libraries = 'z', 'edit'

      # core.info_plist = { 'CFBundleIdentifier' => 'com.provenance-emu.PVAtari800' }
      core.pod_target_xcconfig = { 'PRODUCT_BUNDLE_IDENTIFIER': 'com.provenance-emu.PVAtari800' }
      core.resources = [
        "#{@cores_source_root}/Atari800/PVAtari800/Core.plist"
      ]

      core.pod_target_xcconfig = {
        'OTHER_LDFLAGS' => '$(inherited) -ObjC',
        'CORE_ATARI800_SUBSPEC_INCLUDED' => '-D\'CORE_ATARI800_SUBSPEC_INCLUDED\'',
        'OTHER_SWIFT_FLAGS' => '$(CORE_ATARI800_SUBSPEC_INCLUDED)',
        'GCC_C_LANGUAGE_STANDARD' => 'gnu99',
        'CLANG_CXX_LANGUAGE_STANDARD' => 'gnu++0x',
        'CLANG_CXX_LIBRARY' => 'libc++'
      }
    end

        # ------ PokiMini
        s.subspec 'PokeMini' do |core|
          core.frameworks = 'AudioToolbox', 'OpenGLES'
          core_root = "#{@cores_source_root}/PokeMini"

          upstream_sources = %w[
            CommandLine.c
            freebios.c
            Hardware.c
            Joystick.c
            MinxAudio.c
            MinxColorPRC.c
            MinxCPU_CE.c
            MinxCPU_CF.c
            MinxCPU_SP.c
            MinxCPU_XX.c
            MinxCPU.c
            MinxIO.c
            MinxIRQ.c
            MinxLCD.c
            MinxPRC.c
            MinxTimers.c
            Missing.c
            Multicart.c
            NoUI.c
            PMCommon.c
            PokeMini_BG2.c
            PokeMini_BG3.c
            PokeMini_BG4.c
            PokeMini_BG5.c
            PokeMini_BG6.c
            PokeMini_ColorPal.c
            PokeMini_Font12.c
            PokeMini_Icons12.c
            PokeMini.c
            Video_x1.c
            Video_x2.c
            Video_x3.c
            Video_x4.c
            Video_x5.c
            Video_x6.c
            Video.c
            CommandLine.h
            Endianess.h
            Hardware.h
            IOMap.h
            Joystick.h
            Keyboard.h
            MinxAudio.h
            MinxColorPRC.h
            MinxCPU_noBranch.h
            MinxCPU.h
            MinxIO.h
            MinxIRQ.h
            MinxLCD.h
            MinxPRC.h
            MinxTimers.h
            Missing.h
            Multicart.h
            PMCommon.h
            PokeMini_Version.h
            PokeMini.h
            UI.h
            Video_x1.h
            Video_x2.h
            Video_x3.h
            Video_x4.h
            Video_x5.h
            Video_x6.h
            Video.h
					].map { |file| "#{core_root}/Sources/PokeMini-libretro/source/#{file}" } + 
					["#{core_root}/Sources/PokeMini-libretro/{resource,freebios}/**/*.{h,c}"] +
					["#{core_root}/Sources/PokeMini-libretro/libretro/libretro-common/include/**/*.{h}"]

          core_sources = %w[
            **/*.{swift,m,mm}
          ].map { |file| "#{core_root}/Sources/#{file}" }

          core.source_files = upstream_sources + core_sources

          core.public_header_files = %w[
            PokeMini.h
            PVPokeMiniEmulatorCore.h
					].map { |file| "#{core_root}/Sources/#{file}" }
					
					core.preserve_path = "#{core_root}/Sources/PokeMini-libretro/libretro/libretro-common/include"

					core.private_header_files = "#{core_root}/Sources/PokeMini-libretro/libretro/libretro-common/include/**/*.h"

          # core.info_plist = { 'CFBundleIdentifier' => 'com.provenance-emu.PVAtari800' }
          core.pod_target_xcconfig = { 'PRODUCT_BUNDLE_IDENTIFIER': 'com.provenance-emu.PVPokeMini' }
          core.resources = [
            "#{core_root}/Resources/**/*.*"
          ]

					core.xcconfig = { 'HEADER_SEARCH_PATHS' => '"${SRCROOT}/Sources/PokeMini-libretro/libretro/libretro-common/include"' }

          core.pod_target_xcconfig = {
            'OTHER_LDFLAGS' => '$(inherited) -ObjC',
            'CORE_POKEMINI_SUBSPEC_INCLUDED' => '-D\'CORE_POKEMINI_SUBSPEC_INCLUDED\'',
						'OTHER_SWIFT_FLAGS' => '$(CORE_POKEMINI_SUBSPEC_INCLUDED)',
						'GCC_C_LANGUAGE_STANDARD' => 'gnu99',
						'GCC_PREPROCESSOR_DEFINITIONS' => 'NO_ZIP=1',
          }
        end
  # s.subspec 'Alphas' do |sp|
  # end
end
