[![Build Status](https://travis-ci.org/ls1intum/sReto.svg)](https://travis-ci.org/ls1intum/sReto)
[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/sReto.svg)](https://img.shields.io/cocoapods/v/sReto.svg)
[![Platform](https://img.shields.io/cocoapods/p/sReto.svg?style=flat)](http://cocoadocs.org/docsets/sReto)
[![Twitter](https://img.shields.io/badge/twitter-@ls1intum-blue.svg?style=flat)](http://twitter.com/ls1intum)

sReto
========
Reto: P2P Framework for realtime collaboration in Swift.

sReto 2.0 is compatible with Swift 3!
If you want to support Swift 2, please use older versions, e.g. 1.4.1.

Notice: There is also a Java version for the use of Reto on Windows and Unix: [jReto](https://github.com/ls1intum/jReto)

About
-----

Reto is an extensible P2P networking framework implemented in Swift and Java 8. It offers the same APIs in both languages.

The most important features of the framework are:

  - Peer discovery
  - Establishing connections between peers
  - Performing cancellable data transfers
  - Offers support for routed connections (i.e., peers that can not directly communicate can still be discovered and use other peers to forward data)

Reto is designed to be easily extensible to use other networking technologies by implementing Reto "Module"s; by default, it comes with two modules:

  - WlanModule: Enables peer discovery and connectivity in local area networks by using Bonjour for discovery and standard TCP/IP connections for data transfers
  - RemoteP2PModule: Uses an online server to facilitate communication between peers. This module enables peers to discover each other and communicate over the Internet; however, a RemoteP2P server is required. 


Installation
------------

The recommended approach for installing sReto is via the [CocoaPods](http://cocoapods.org) package manager, as it provides flexible dependency management.

sReto 2.0 can be integrated as framework on iOS 9.0+ and OS X 10.9+. Even though it is implemented in Swift, it can be used in both Objective C and Swift projects. Here are the steps required to include Reto using CocoaPods.

### via CocoaPods

Install CocoaPods if not already available:

``` bash
$ [sudo] gem install cocoapods
$ pod setup
```

Change to the directory of your Xcode project, and Create and Edit your Podfile and add sReto as framework:

``` bash
$ cd /path/to/MyProject
$ pod init
$ edit Podfile
platform :ios, '8.0'
# Or platform :osx, '10.9'

use_frameworks!

pod 'sReto'
# this will install the WLAN module and all its dependencies

# Bluetooth and Remote are optional modules
pod 'sReto/BluetoothModule'
pod 'sReto/RemoteModule'

# Alternatively you can also install all modules with:
pod 'sReto/AllModules'

```

Install into your project:

``` bash
$ pod install
```

Open your project in Xcode from the .xcworkspace file (not the usual project file)

``` bash
$ open MyProject.xcworkspace
```

Import the module in your code:
  1. In Swift, import Reto using "import sReto" depending on your target platform.
  2. In Objective-C, import Reto using "@import sReto;"

Please note that if your installation fails, it may be because you are installing with a version of Git lower than CocoaPods is expecting. Please ensure that you are running Git **>= 1.8.0** by executing `git --version`. You can get a full picture of the installation details by executing `pod install --verbose`.

 
Usage
-----

**Starting Discovery/Advertisement**

Advertisement and discovery is managed by the `LocalPeer` class. A `LocalPeer` requires one or more Reto Modules to function. In this example, we will use the `WlanModule`.

*Swift*

```swift
// 1. Create the modules for the communication mechanisms to be used
let wlanModule = WlanModule(type: "ExampleType", dispatchQueue: DispatchQueue.main)
let bluetoothModule = BluetoothModule(type: "ExampleType", dispatchQueue: DispatchQueue.main)
let remoteModule = RemoteP2PModule(baseUrl: NSURL(string: "http://www.example.com")!, dispatchQueue: DispatchQueue.main)
// 2. Create a LocalPeer and pass an array of modules
let localPeer = LocalPeer(modules: [wlanModule], dispatchQueue: DispatchQueue.main)
// 3. Start the LocalPeer
localPeer.start(
  onPeerDiscovered: { peer in 
    print("Discovered peer: \(peer)") 
  },
  onPeerRemoved: { peer in 
    print("Removed peer: \(peer)") 
  },
  onIncomingConnection: { peer, connection in 
    print("Received incoming connection: \(connection) from peer: \(peer)") 
  },
  displayName: "MyLocalPeer"
)
```

*Objective C*

```objc
// 1. Create the modules for the communication mechanisms to be used
WlanModule* wlanModule = [[WlanModule alloc] initWithType: "ExampleType" dispatchQueue: dispatch_get_main_queue()];
// 2. Create a LocalPeer and pass an array of modules
LocalPeer* localPeer = [[LocalPeer alloc] initWithModules: @[wlanModule] dispatchQueue: dispatch_get_main_queue())
// 3. Start the LocalPeer
[localPeer startOnPeerDiscovered:^(RemotePeer *peer) {
  NSLog(@"Found peer: %@", peer);
} onPeerRemoved:^(RemotePeer *peer) {
  NSLog(@"Removed peer: %@", peer);
} onIncomingConnection:^(RemotePeer *peer, Connection *connection) {
  NSLog(@"Received incoming connection: %@ from peer: %@", connection, peer);
} displayName: @"MyLocalPeer"];
```

Any two applications that use the same type parameter for the WlanModule will discover each other in a local area network. Therefore, you should choose a unique type parameter.

In Swift and Java, a dispatch queue is passed to the LocalPeer; any networking operations will be executed using this queue. Furthermore, all callbacks occur on this queue, too.

The same principle is used in Java; here, an Executor is used instead of a dispatch queue. All callbacks are dispatched using this Executor's thread.

In many cases, it is ok to use the main dispatch queue / an Executor that runs on the GUI thread, since Reto will not perform any blocking operations on the queue. If a lot of data is being sent and processed, it may be a good idea to move these operations to a background thread, though.

When starting the `LocalPeer`, three closures are passed as parameters.

  - The onPeerDiscovered closure is called whenever a new peer was discovered.
  - The onPeerRemoved closure is called whenever a peer was lost
  - The onIncomingConnection closure is called whenever a `RemotePeer` established a connection with the `LocalPeer`.

The first closure gives you access to `RemotePeer` objects, which can be used to establish connections with those peers.

**Establishing Connections and Sending Data**

*Swift*

```swift
// 1. Establishing a connection
let connection = someRemotePeer.connect()
// 2. Registering a callback the onClose event
connection.onClose = { connection in 
  print("Connection closed.") 
}
// 3. Receiving data
connection.onData = { data in 
  print("Received data!") 
}
// 4. Sending data
let someData = Data()
connection.send(data: someData)
```

*Objective C*

```objc
// 1. Establishing a connection
Connection *connection = [someRemotePeer connect];
// 2. Registering a callback the onClose event
connection.onClose = ^(Connection* connection) {
  NSLog(@"Connection closed.");
};
// 3. Receiving data
connection.onData = ^(Connection* connection, NSData* data) {
  NSLog(@"Received data!");
}
// 4. Sending data
[connection sendData: someData];
```

A `Connection` can be established by simply calling the `connect` method on a `RemotePeer`. 

It allows you to register a number of callbacks for various events, for example, `onClose`, which is called when the connection closes. Most of these callbacks are optional, however, you must set the `onTransfer` or `onData` callbacks if you wish to receive data using a connection.

In this example, the `onData` callback is set, which is called when data was received. For more control over data transfers, use the `onTransfer` callback.


**Data Transfers** 

While the above techniques can be used to send data, you may want access about more information. The `Transfer` class gives access to more information and tools. The following just gives a short example of how using these features might look; however, the `Transfer` class offers more methods and features. Check the class documentation to learn more.

*Swift*

```swift
// 1. Configuring a connection to receive transfers example
someConnection.onTransfer = { 
  connection, transfer in 
  // 2. Configuring a transfer to let you handle data as it is received, instead of letting the transfer buffer all data
  transfer.onPartialData = { transfer, data in 
    print("Received a chunk of data!") 
  }
  // 3. Registering for progress updates
  transfer.onProgress = { transfer in 
    print("Current progress: \(transfer.progress) of \(transfer.length)") 
  }
}
 
// 4. Sending a transfer example with a data provider
let transfer = someConnection.send(dataLength: someData.count, dataProvider: { range in return someData })
// 5. Registering for progress updates
transfer.onProgress = { transfer in 
  print("Current progress: \(transfer.progress) of \(transfer.length)") 
}
```

*Objective C*

```objc
// 1. Configuring a connection to receive transfers example
connection.onTransfer = ^(Connection* connection, InTransfer* transfer) {
  // 2. Configuring a transfer to let you handle data as it is received, instead of letting the transfer buffer all data
  transfer.onPartialData = ^(Transfer* transfer, NSData* data) {
    NSLog(@"Received a chunk of data!");
  };
  // 3. Registering for progress updates
  transfer.onProgress = ^(Transfer* transfer) {
    NSLog(@"Current progress: %li of %li", transfer.progress, (long)transfer.length);
  };
};
// 4. Sending a transfer example with a data provider
Transfer* transfer = [connection sendWithDataLength: 1 dataProvider:^NSData *(NSRange range) {
  return somehowProvideDataForRange(range);
}];
// 5. Registering for progress updates
transfer.onProgress = ^(Transfer* transfer) {
  NSLog(@"Current progress: %li of %li", transfer.progress, transfer.length);
};
```
