#### Version 1.1.1

* Support for CocoaLumberjack 3.0.0 by loosening dependencies’ version requirements (#8)

#### Version 1.1.0

* XCDLumberjackNSLogger builds as a framework and is therefore compatible with Carthage (#1)
* tvOS support
* Use filename as tag if no context to tag mapping is found (#5)
* New method to automatically bind a XCDLumberjackNSLogger instance to user defaults

#### Version 1.0.2

* XCDLumberjackNSLogger is less strict about CocoaLumberjack and NSLogger required versions

#### Version 1.0.1

* Log pretty printed NSData as data
* Use proper thread identifier and queue name
* Added a `debugDescription` implementation

#### Version 1.0.0

* Initial version
