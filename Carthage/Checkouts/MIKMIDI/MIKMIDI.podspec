Pod::Spec.new do |s|
  
  s.name         = 'MIKMIDI'
  s.version      = '1.6.2'
  s.summary      = 'Library useful for programmers writing Objective-C or Swift OS X or iOS apps that use MIDI.'
  s.description  = <<-DESC
                     MIKMIDI is a library intended to simplify implementing Objective-C or Swift apps 
                     for OS X or iOS that use MIDI. It includes the ability to communicate with external
					 MIDI devices, to read and write MIDI files, to record and play back MIDI, etc.
 					 It provides Objective-C abstractions around CoreMIDI, as well as a number of useful
 					 higher level feature not included in CoreMIDI itself.'
                     DESC
  s.homepage     = 'https://github.com/mixedinkey-opensource/MIKMIDI'
  s.license      = 'MIT'
  s.author       = { 'Andrew Madsen' => 'andrew@mixedinkey.com' }
  s.social_media_url = 'https://twitter.com/armadsen'

  s.ios.deployment_target = '6.0'
  s.osx.deployment_target = '10.7'
  
  s.source       = { :git => 'https://github.com/mixedinkey-opensource/MIKMIDI.git', :tag => s.version.to_s }
  s.source_files = 'Source/**/*.{h,m}'
  s.private_header_files = 'Source/MIKMIDIPrivateUtilities.h'
  s.requires_arc = true
  
  s.osx.frameworks = 'CoreMIDI', 'AudioToolbox', 'AudioUnit'
  s.ios.frameworks = 'CoreMIDI', 'AudioToolbox'
  s.ios.library = 'xml2'
  s.xcconfig = { 'HEADER_SEARCH_PATHS' => '"$(SDK_DIR)"/usr/include/libxml2' }

end