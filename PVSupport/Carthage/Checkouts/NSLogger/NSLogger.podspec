Pod::Spec.new do |s|
  s.name     = 'NSLogger'
  s.version  = '1.9.0'
  s.license  = 'BSD'
  s.summary  = 'A modern, flexible logging tool.'
  s.homepage = 'https://github.com/fpillet/NSLogger'
  s.author   = { 'Florent Pillet' => 'fpillet@gmail.com' }
  s.source   = { :git => 'https://github.com/fpillet/NSLogger.git', :tag => 'v1.9.0' }
  s.screenshot  = "https://github.com/fpillet/NSLogger/raw/master/Screenshots/mainwindow.png"

  s.description = 'NSLogger is a high perfomance logging utility which displays traces emitted by ' \
                  'client applications running on Mac OS X or iOS (iPhone OS). It replaces your '   \
                  'usual NSLog()-based traces and provides powerful additions like display '        \
                  'filtering, image and binary logging, traces buffering, timing information, etc. ' \
                  'Download a prebuilt desktop viewer from https://github.com/fpillet/NSLogger/releases'

  s.ios.deployment_target  = '8.0'
  s.osx.deployment_target  = '10.10'
  s.tvos.deployment_target = '9.0'
  
  s.requires_arc = false
  
  s.default_subspec = 'ObjC'

  #
  # The 'Default' subspec is the default: only has C / Obj-C support
  # unused NSLogger functions will be stripped from the final build
  #
  s.subspec 'ObjC' do |ss|
    ss.source_files = 'Client/iOS/*.{h,m}'
    ss.public_header_files = 'Client/iOS/*.h'
    ss.ios.frameworks = 'CFNetwork', 'SystemConfiguration', 'UIKit'
    ss.osx.frameworks = 'CFNetwork', 'SystemConfiguration', 'CoreServices', 'AppKit'
    ss.xcconfig = {
      'OTHER_CFLAGS' => '-Wno-nullability-completeness',
      'GCC_PREPROCESSOR_DEFINITIONS' => '${inherited} NSLOGGER_WAS_HERE=1 NSLOGGER_BUILD_USERNAME="${USER}"'
    }
  end
  
  #
  # The 'Swift' subspec builds on ObjC and offers a Swiftified (albeit limited) API
  # Since there's a direct dependency on 'NSLogger/Default', Swift developers can simply include
  # 'NSLogger/Swift' in their Podfile
  #
  # NSLogger is automatically disabled in Release builds. If you want to keep it enabled in release builds,
  # you can define a NSLOGGER_ENABLED flag which forces calling into the framework.
  #
  s.subspec 'Swift' do |ss|
    ss.dependency 'NSLogger/ObjC'
    ss.source_files = 'Client/iOS/*.swift'
    ss.pod_target_xcconfig = {
        'OTHER_SWIFT_FLAGS' => '$(inherited) -DNSLOGGER_DONT_IMPORT_FRAMEWORK',
        'OTHER_SWIFT_FLAGS[config=Release]' => '$(inherited) -DNSLOGGER_DONT_IMPORT_FRAMEWORK -DNSLOGGER_DISABLED'
    }
  end

  #
  # The 'NoStrip' subspec prevents unused functions from being stripped by the linker.
  # this is useful when other frameworks linked into the application dynamically look for
  # NSLogger functions and use them if present. Use 'NSLogger/NoStrip' instead of regular
  # 'NSLogger' pod, add 'NSLogger/Swift' as needed.
  #
  s.subspec 'NoStrip' do |ss|
    ss.dependency 'NSLogger/ObjC'
    ss.xcconfig = {
      'GCC_PREPROCESSOR_DEFINITIONS' => '${inherited} NSLOGGER_ALLOW_NOSTRIP=1'
    }
  end

end
