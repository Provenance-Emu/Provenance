Pod::Spec.new do |s|
  s.name               = 'sReto'
  s.version            = '3.0.0'
  s.summary            = 'P2P Framework for realtime collaboration in Swift with independent modules for WLAN, Bluetooth and Remote support'
  s.homepage           = 'https://github.com/ls1intum/sReto'
  s.license            = 'MIT'
  s.author             = { 'Chair for Applied Software Engineering' => 'ios@in.tum.de' }
  s.social_media_url   = 'https://twitter.com/ls1intum'

  s.requires_arc          = true
  s.ios.deployment_target = '9.0'
  s.tvos.deployment_target = '9.0'
  s.osx.deployment_target = '10.9'

  s.source             = { :git => 'https://github.com/ls1intum/sReto.git', :tag => s.version }

  s.default_subspec    = 'WlanModule'
  
  s.subspec 'Core' do |c|
  	c.source_files     = 'Source/sReto/Core/**/*.swift'
  end

  s.subspec 'Bonjour' do |b|
  	b.source_files     = 'Source/sReto/Modules/Bonjour/**/*.swift'
  	b.dependency         'sReto/Core'
  	b.dependency         'CocoaAsyncSocket', '7.6.2'
  end
  
  s.subspec 'WlanModule' do |wm|
  	wm.source_files    = 'Source/sReto/Modules/WlanModule/*.swift'
  	wm.dependency        'sReto/Bonjour'
  end
  
  s.subspec 'BluetoothModule' do |bm|
  	bm.source_files    = 'Source/sReto/Modules/BluetoothModule/*.swift'
  	bm.dependency        'sReto/Bonjour'
  	bm.dependency        'sReto/no-arc'
  end
  
  s.subspec 'RemoteModule' do |rm|
    rm.source_files    = 'Source/sReto/Modules/RemoteModule/**/*.swift'
  	rm.dependency        'sReto/Core'
    rm.dependency        'SocketRocket', '0.5.1'
  end
  
  s.subspec 'AllModules' do |am|
    am.dependency        'sReto/RemoteModule'
    am.dependency        'sReto/WlanModule'
    am.dependency        'sReto/BluetoothModule'
  end
  
  s.subspec 'no-arc' do |n|
    n.source_files     = 'Source/sReto/Modules/BluetoothModule/DNSSD/*'
    n.requires_arc     = false
  end

end
