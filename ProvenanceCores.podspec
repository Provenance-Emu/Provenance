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

  s.frameworks = 'UIKit'
  s.frameworks = 'Foundation'

  s.module_name = 'ProvenanceCores'
  # s.header_dir = 'ProvenanceCores'

  # s.default_subspecs = 'Atari800s'

  @cores_source_root = 'Cores'

  # s.subspec 'Cores' do |sp|
    s.dependency 'PVSupport'
    s.dependency 'PVLibrary'

    s.frameworks = 'Foundation', 'OpenGLES', 'UIKit', 'CoreGraphics', 'AudioToolbox'
    s.libraries = 'z', 'edit'
    s.pod_target_xcconfig = {
      'OTHER_LDFLAGS' => '$(inherited) -ObjC'
    }

    # # Atari800
    s.subspec 'Atari800' do |core|
      core.frameworks = 'Foundation'

      core.source_files = "#{@cores_source_root}/Atari800/**/*.{swift,m,mm,c,cpp}"

      core.pod_target_xcconfig = {
        'OTHER_LDFLAGS' => '$(inherited) -ObjC',
        'CORE_ATARI800_SUBSPEC_INCLUDED' => '-D\'CORE_ATARI800_SUBSPEC_INCLUDED\'',
        'OTHER_SWIFT_FLAGS' => '$(CORE_ATARI800_SUBSPEC_INCLUDED)'
      }
    end
  # end
end
