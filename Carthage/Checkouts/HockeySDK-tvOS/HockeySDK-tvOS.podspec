Pod::Spec.new do |s|
  s.name              = 'HockeySDK-tvOS'
  s.version           = '5.1.0'

  s.summary           = 'Collect live crash reports, provide update notifications, add authentication capabilities, and get usage data.'
  s.description       = <<-DESC
                        HockeyApp is a service to distribute beta apps, collect crash reports and
                        communicate with your app's users.
                        
                        It improves the testing process dramatically and can be used for both beta
                        and App Store builds.
                        DESC

  s.homepage          = 'http://hockeyapp.net/'
  s.documentation_url = "http://hockeyapp.net/help/sdk/tvos/#{s.version}/"

  s.license           = { :type => 'MIT', :file => 'HockeySDK-tvOS/LICENSE' }
  s.author            = { 'Microsoft' => 'support@hockeyapp.net' }

  s.platform          = :tvos, '10.0'
  
  s.preserve_path = 'HockeySDK-tvOS/README.md'

  s.source = { :http => "https://github.com/bitstadium/HockeySDK-tvOS/releases/download/#{s.version}/HockeySDK-tvOS-#{s.version}.zip" }

  s.resource_bundle = { 'HockeySDKResources' => ['HockeySDK-tvOS/HockeySDK.embeddedframework/HockeySDKResources.bundle/*.png', 'HockeySDK-tvOS/HockeySDK.embeddedframework/HockeySDKResources.bundle/*.lproj'] }

  s.frameworks = 'Foundation', 'Security', 'SystemConfiguration', 'UIKit'
  s.libraries = 'c++', 'z'
  s.vendored_frameworks = 'HockeySDK-tvOS/HockeySDK.embeddedframework/HockeySDK.framework'

end
