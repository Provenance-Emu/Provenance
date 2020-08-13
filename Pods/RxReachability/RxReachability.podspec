#
# Be sure to run `pod lib lint RxReachability.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'RxReachability'
  s.version          = '1.1.0'
  s.summary          = 'RxSwift bindings for Reachability'

  s.description      = <<-DESC
  RxReachability adds easy to use RxSwift bindings for [ReachabilitySwift](https://github.com/ashleymills/Reachability.swift).
  You can react to network reachability changes and even retry observables when network comes back up.
                        DESC

  s.homepage          = 'https://github.com/RxSwiftCommunity/RxReachability'
  s.license           = { :type => 'MIT', :file => 'LICENSE' }
  s.authors        = {  'Ivan Bruel'        => 'ivan.bruel@gmail.com',
                        'Bruno Oliveira'    => 'bm.oliveira.dev@gmail.com',
                        'RxSwiftCommunity'  => 'https://github.com/RxSwiftCommunity' 
                      }
  s.source            = { :git => 'https://github.com/RxSwiftCommunity/RxReachability.git', :tag => s.version.to_s }
  s.social_media_url  = 'https://rxswift.slack.com'
  s.source_files      = 'RxReachability/Sources/**/*'
  
  s.ios.deployment_target   = '8.0'
  s.osx.deployment_target   = '10.10'
  s.tvos.deployment_target  = '9.0'

  s.frameworks = 'Foundation'

  s.swift_version    = '5.0'

  s.dependency 'ReachabilitySwift', '~> 5.0'
  s.dependency 'RxSwift', '~> 5'
  s.dependency 'RxCocoa', '~> 5'
end
