Pod::Spec.new do |s|
  s.name                   = "XCDLumberjackNSLogger"
  s.version                = "1.1.1"
  s.summary                = "A CocoaLumberjack logger which sends logs to NSLogger"
  s.homepage               = "https://github.com/0xced/XCDLumberjackNSLogger"
  s.license                = { :type => "MIT", :file => "LICENSE" }
  s.author                 = { "Cédric Luthi" => "cedric.luthi@gmail.com" }
  s.social_media_url       = "http://twitter.com/0xced"
  s.ios.deployment_target  = "8.0"
  s.osx.deployment_target  = "10.10"
  s.tvos.deployment_target = "9.0"
  s.source                 = { :git => "https://github.com/0xced/XCDLumberjackNSLogger.git", :tag => s.version.to_s }
  s.source_files           = "XCDLumberjackNSLogger/XCDLumberjackNSLogger.{h,m}"
  s.requires_arc           = true
  
  s.dependency "CocoaLumberjack", ">= 2.0"
  s.dependency "NSLogger",        ">= 1.7"
end
