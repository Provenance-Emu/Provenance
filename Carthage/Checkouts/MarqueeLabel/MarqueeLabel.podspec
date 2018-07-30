Pod::Spec.new do |s|
  s.name         = "MarqueeLabel"
  s.version      = "3.1.5"
  s.summary      = "A drop-in replacement for UILabel, which automatically adds a scrolling marquee effect when needed."
  s.homepage     = "https://github.com/cbpowell/MarqueeLabel"
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = "Charles Powell"
  s.source       = { :git => "https://github.com/cbpowell/MarqueeLabel.git", :tag => s.version.to_s }
  s.frameworks   = 'UIKit', 'QuartzCore'
  s.requires_arc = true
  s.ios.deployment_target = '6.0'
  s.tvos.deployment_target = '9.0'
  
  s.default_subspec = 'ObjC'
  
  s.subspec 'ObjC' do |ss|
    ss.ios.deployment_target = '6.0'
    ss.tvos.deployment_target = '9.0'
    ss.source_files = 'Sources/**/*.{h,m}'
  end
  
  s.subspec 'Swift' do |ss|
    ss.ios.deployment_target = '8.0'
    ss.tvos.deployment_target = '9.0'
    ss.source_files = 'Sources/**/*.swift'
  end
end
