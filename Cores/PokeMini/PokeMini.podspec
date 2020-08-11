# :frozen_string_literal => true

# Be sure to run `pod lib lint PokeMini.podspec' to ensure this is a
# valid spec before submitting.

Pod::Spec.new do |s|
    s.name             = 'PokeMini'
    s.version          = '1.5'
    s.summary          = 'PokeMini Provenance Emulator Core'

    s.description      = <<-DESC
    PokeMini is the iOS library for the NewsCorp PokeMini platform.
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

    s.frameworks = 'AudioToolbox', 'Foundation', 'OpenGLES'

    s.module_name = 'PokeMini'
    s.header_dir = 'PokeMini'

    s.dependency 'PVSupport'
    s.dependency 'PVLibrary'

    s.pod_target_xcconfig = {
        'OTHER_LDFLAGS' => '$(inherited) -ObjC',
        'GCC_C_LANGUAGE_STANDARD' => 'gnu99'
    }

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
    ].map { |file| "Sources/PokeMini-libretro/source/#{file}" } +
        ['Sources/PokeMini-libretro/{resource,freebios}/**/*.{h,c}'] +
        ['Sources/PokeMini-libretro/libretro/libretro-common/include/**/*.{h}']

    core_sources = %w[
        **/*.{swift,m,mm}
    ].map { |file| "Sources/#{file}" }

    s.source_files = upstream_sources + core_sources

    s.public_header_files = %w[
        PokeMini.h
        PVPokeMiniEmulatorCore.h
    ].map { |file| "Sources/#{file}" }

    # s.preserve_path = "Sources/PokeMini-libretro/libretro/libretro-common/include"

    s.private_header_files = "Sources/PokeMini-libretro/libretro/libretro-common/include/**/*.h"
    s.resources = [
        "Resources/**/*.*"
    ]

    # s.xcconfig = { 'HEADER_SEARCH_PATHS' => '$(inherited) "${SRCROOT}/Sources/PokeMini-libretro/libretro/libretro-common/include"' }

    # s.pod_target_xcconfig = {
    #     'OTHER_LDFLAGS' => '$(inherited) -ObjC',
    #     'CORE_POKEMINI_SUBSPEC_INCLUDED' => '-D\'CORE_POKEMINI_SUBSPEC_INCLUDED\'',
    #     'OTHER_SWIFT_FLAGS' => '$(inherited) $(CORE_POKEMINI_SUBSPEC_INCLUDED)',
    #     'GCC_C_LANGUAGE_STANDARD' => 'gnu99',
    #     'CLANG_CXX_LANGUAGE_STANDARD' => 'gnu++0x',
    #     'CLANG_CXX_LIBRARY' => 'libc++',
    #     'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) NO_ZIP=1',
    #     'PRODUCT_BUNDLE_IDENTIFIER' => 'com.provenance-emu.PVPokeMini'
    # }
end
