# :frozen_string_literal => true

# Be sure to run `pod lib lint PokeMini.podspec' to ensure this is a
# valid spec before submitting.

Pod::Spec.new do |s|
    s.name             = 'PVPokeMini'
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

    s.module_name = 'PVPokeMini'
    s.header_dir = 'PVPokeMini'

    s.dependency 'PVSupport'
    s.dependency 'PVLibrary'

    s.pod_target_xcconfig = {
        'OTHER_LDFLAGS' => '$(inherited) -ObjC',
        'GCC_C_LANGUAGE_STANDARD' => 'gnu99'
    }

    upstream_sources = %w[
        CommandLine.c
        CommandLine.h
        Endianess.h
        freebios.c
        Hardware.c
        Hardware.h
        IOMap.h
        Joystick.c
        Joystick.h
        Keyboard.h
        MinxAudio.c
        MinxAudio.h
        MinxColorPRC.c
        MinxColorPRC.h
        MinxCPU_CE.c
        MinxCPU_CF.c
        MinxCPU_noBranch.h
        MinxCPU_SP.c
        MinxCPU_XX.c
        MinxCPU.c
        MinxCPU.h
        MinxIO.c
        MinxIO.h
        MinxIRQ.c
        MinxIRQ.h
        MinxLCD.c
        MinxLCD.h
        MinxPRC.c
        MinxPRC.h
        MinxTimers.c
        MinxTimers.h
        Missing.c
        Missing.h
        Multicart.c
        Multicart.h
        PMCommon.c
        PMCommon.h
        PokeMini.c
        PokeMini.h
        UI.h
        Video_x1.c
        Video_x1.h
        Video_x2.c
        Video_x2.h
        Video_x3.c
        Video_x3.h
        Video_x4.c
        Video_x4.h
        Video_x5.c
        Video_x5.h
        Video_x6.c
        Video_x6.h
        Video.c
        Video.h
    ].map { |file| "Sources/upstream/source/#{file}" } +
    %w[
        freebios/**/*.{h,c}
        resource/**/*.{h,c}
        libretro/libretro-common/streams/*.c
    ].map { |file| "Sources/upstream/#{file}" }

    core_sources = [
        'Sources/*.{swift,h,m,mm,c}'
    ]

    s.source_files = upstream_sources + core_sources

    s.public_header_files = %w[
        PVPokeMini.h
        PVPokeMiniEmulatorCore.h
    ].map { |file| "Sources/#{file}" }

    s.header_mappings_dir = 'Sources/upstream/libretro/libretro-common/include/'

    s.private_header_files = "Sources/upstream/libretro/libretro-common/include/**/*.h"
    s.resources = [
        "Resources/**/*.*"
    ]

    s.xcconfig = { 'HEADER_SEARCH_PATHS' => '$(inherited) "${PODS_TARGET_SRCROOT}/Sources/upstream/libretro/libretro-common/include"' }
    s.compiler_flags = '-DCORE_POKEMINI_SUBSPEC_INCLUDED -DIOS'

    s.pod_target_xcconfig = {
        'OTHER_LDFLAGS' => '$(inherited) -ObjC',
        'CORE_POKEMINI_SUBSPEC_INCLUDED' => '-D\'CORE_POKEMINI_SUBSPEC_INCLUDED\'',
        'OTHER_SWIFT_FLAGS' => '$(inherited) $(CORE_POKEMINI_SUBSPEC_INCLUDED)',
        'GCC_C_LANGUAGE_STANDARD' => 'gnu99',
        'CLANG_CXX_LANGUAGE_STANDARD' => 'gnu++0x',
        'CLANG_CXX_LIBRARY' => 'libc++',
        'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) NO_ZIP=1 IOS=1',
        'PRODUCT_BUNDLE_IDENTIFIER' => 'com.provenance-emu.PVPokeMini'
    }
end
