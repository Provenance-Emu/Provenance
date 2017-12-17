[![Platform](https://img.shields.io/cocoapods/p/LzmaSDK-ObjC.svg?style=flat)](http://cocoapods.org/pods/LzmaSDK-ObjC)
[![Version](https://img.shields.io/cocoapods/v/LzmaSDK-ObjC.svg?style=flat)](http://cocoapods.org/pods/LzmaSDK-ObjC)
[![License](https://img.shields.io/cocoapods/l/LzmaSDK-ObjC.svg?style=flat)](http://cocoapods.org/pods/LzmaSDK-ObjC)
[![Build Status](https://travis-ci.org/OlehKulykov/LzmaSDKObjC.svg?branch=master)](https://travis-ci.org/OlehKulykov/LzmaSDKObjC)
[![OnlineDocumentation Status](https://img.shields.io/badge/online%20documentation-generated-brightgreen.svg)](http://cocoadocs.org/docsets/LzmaSDK-ObjC)


It's not yet another wrapper around C part of the [LZMA SDK] with all it's limitations.   
Based on C++ [LZMA SDK] version 16.04 (1604 - latest for now) and patched for iOS & Mac OS platforms.   
Can be used with Swift and Objective-C.


### Description
----------------
It's not yet another wrapper around C part of the [LZMA SDK] with all it's limitations. 
Based on C++ [LZMA SDK] version 16.04 (1604 - latest for now) and patched for iOS & Mac OS platforms.

The main advantages is:
- List, extract **7z** files (**Lzma** & **Lzma2** *compression method*).
- List, extract **encrypted** (*password protected*) **7z** files (**Lzma** & **Lzma2** *compression method*).
- List, extract **encrypted** (*password protected*) + **encrypted header** (*no visible content, files list, without password*) **7z** files (**Lzma** & **Lzma2** *compression method*).
- Create **7z** archives (**Lzma** & **Lzma2** *compression method*).
- Create **encrypted** (*password protected*) **7z** archives (**Lzma** & **Lzma2** *compression method*).
- Create **encrypted** (*password protected*) + **encrypted header** (*no visible content, files list, without password*) **7z** archives (**Lzma** & **Lzma2** *compression method*).
- Manage memory allocations during listing/extracting. See below section: **Tune up speed, performance and disk IO operations**.
- Tuned up for using less than 500Kb for listing/extracting, can be easly changed runtime (*no hardcoded definitions*). See below section: **Tune up speed, performance and disk IO operations**.
- Manage IO read/write operations, aslo can be easly changed runtime (*no hardcoded definitions*). See below section: **Tune up speed, performance and disk IO operations**.
- Track smoothed progress, which becomes possible with prev.
- Support reading and extracting archive files with size more than 4GB.
- UTF8 support.
- Extra compression/decompression functionality of single **NSData** object with **Lzma2**.


### Installation with [CocoaPods]
#### Podfile
```ruby
use_frameworks!
platform :ios, '8.0'

target '<REPLACE_WITH_YOUR_TARGET>' do
    pod 'LzmaSDK-ObjC', :inhibit_warnings => true
end
```

> Use frameworks (dynamic linking) to include Lzma codecs code in your application.


### Example Swift and Objective-C
-----------
#### List and extract

##### Create and setup reader with archive path and/or archive type, optionaly delegate and optionaly password getter block, in case of encrypted archive
##### Swift
```swift
import LzmaSDK_ObjC
...

// select full path to archive file with 7z extension
let archivePath = "path to archive"

// 1.1 Create reader object.
let reader = LzmaSDKObjCReader(fileURL: NSURL(fileURLWithPath: archivePath)
// 1.2 Or create with predefined archive type if path doesn't containes suitable extension
let reader = LzmaSDKObjCReader(fileURL: NSURL(fileURLWithPath: archivePath), andType: LzmaSDKObjCFileType7z)

// Optionaly: assign delegate for tracking extract progress.
reader.delegate = self

// If achive encrypted - define password getter handler.
// NOTES:
// - Encrypted file needs password for extract process.
// - Encrypted file with encrypted header needs password for list(iterate) and extract archive items.
reader.passwordGetter = {
	return "password to my achive"
}
...

// Delegate extension
extension ReaderDelegateObject: LzmaSDKObjCReaderDelegate {
	func onLzmaSDKObjCReader(reader: LzmaSDKObjCReader, extractProgress progress: Float) {
		print("Reader progress: \(progress) %")
	}
}
```
##### Objective-C
```objc
// select full path to archive file with 7z extension
NSString * archivePath = <path to archive>;

// 1.1 Create and hold strongly reader object.
self.reader = [[LzmaSDKObjCReader alloc] initWithFileURL:[NSURL fileURLWithPath:archivePath]];
// 1.2 Or create with predefined archive type if path doesn't containes suitable extension
self.reader = [[LzmaSDKObjCReader alloc] initWithFileURL:[NSURL fileURLWithPath:archivePath]
						 andType:LzmaSDKObjCFileType7z];

// Optionaly: assign weak delegate for tracking extract progress.
_reader.delegate = self;

// If achive encrypted - define password getter handler.
// NOTES:
// - Encrypted file needs password for extract process.
// - Encrypted file with encrypted header needs password for list(iterate) and extract archive items.
_reader.passwordGetter = ^NSString*(void){
	return @"password to my achive";
};
```


##### Open archive, e.g. find out type of achive, locate decoder and read archive header
##### Swift
```swift
// Try open archive.
do {
	try reader.open()
}
catch let error as NSError {
	print("Can't open archive: \(error.localizedDescription) ")
}
```
##### Objective-C
```objc
// Open archive, with or without error. Error can be nil.
NSError * error = nil;
if (![_reader open:&error]) {
	NSLog(@"Open error: %@", error);
}
NSLog(@"Open error: %@", _reader.lastError);
```


##### Iterate archive items, select and store required items for future processing
##### Swift
```swift
var items = [LzmaSDKObjCItem]()  // Array with selected items.
// Iterate all archive items, track what items do you need & hold them in array.
reader.iterateWithHandler({(item: LzmaSDKObjCItem, error: NSError?) -> Bool in
	items.append(item) // if needs this item - store to array.
	return true // true - continue iterate, false - stop iteration
})
```
##### Objective-C
```objc
NSMutableArray * items = [NSMutableArray array]; // Array with selected items.
// Iterate all archive items, track what items do you need & hold them in array.
[_reader iterateWithHandler:^BOOL(LzmaSDKObjCItem * item, NSError * error){
	NSLog(@"\n%@", item);
	if (item) [items addObject:item]; // if needs this item - store to array.
	return YES; // YES - continue iterate, NO - stop iteration
}];
NSLog(@"Iteration error: %@", _reader.lastError);
```


##### Extract or test archive items
##### Swift
```swift
// Extract selected items from prev. step.
// true - create subfolders structure for the items.
// false - place item file to the root of path(in this case items with the same names will be overwrited automaticaly).
if reader.extract(items, toPath: "/Volumes/Data/1/", withFullPaths: true) {
	print("Extract failed: \(reader.lastError?.localizedDescription)")
}

// Test selected items from prev. step.
if reader.test(items) {
	print("Test failed: \(reader.lastError?.localizedDescription)")
}
````
##### Objective-C
```objc
// Extract selected items from prev. step.
// YES - create subfolders structure for the items.
// NO - place item file to the root of path(in this case items with the same names will be overwrited automaticaly).
[_reader extract:items
          toPath:@"/extract/path"
    withFullPaths:YES]; 
NSLog(@"Extract error: %@", _reader.lastError);

// Test selected items from prev. step.
[_reader test:items];
NSLog(@"test error: %@", _reader.lastError);
```

##### Create 7z archive
##### Swift
```swift
// Create writer
let writer = LzmaSDKObjCWriter(fileURL: NSURL(fileURLWithPath: "/Path/MyArchive.7z"))

// Add file data's or paths
writer.addData(NSData(...), forPath: "MyArchiveFileName.txt") // Add file data
writer.addPath("/Path/somefile.txt", forPath: "archiveDir/somefile.txt") // Add file at path
writer.addPath("/Path/SomeDirectory", forPath: "SomeDirectory") // Recursively add directory with all contents

// Setup writer
writer.delegate = self // Track progress
writer.passwordGetter = { // Password getter
	return "1234"
}

// Optional settings 
writer.method = LzmaSDKObjCMethodLZMA2 // or LzmaSDKObjCMethodLZMA
writer.solid = true
writer.compressionLevel = 9
writer.encodeContent = true
writer.encodeHeader = true
writer.compressHeader = true
writer.compressHeaderFull = true
writer.writeModificationTime = false
writer.writeCreationTime = false
writer.writeAccessTime = false

// Open archive file
do {
	try writer.open()
} catch let error as NSError {
	print(error.localizedDescription)
}

// Write archive within current thread
writer.write()

// or
dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)) {
	writer.write()
}
```
##### Objective-C
```objc
// Create writer
LzmaSDKObjCWriter * writer = [[LzmaSDKObjCWriter alloc] initWithFileURL:[NSURL fileURLWithPath:@"/Path/MyArchive.7z"]];

// Add file data's or paths
[writer addData:[NSData ...] forPath:@"MyArchiveFileName.txt"]; // Add file data
[writer addPath:@"/Path/somefile.txt" forPath:@"archiveDir/somefile.txt"]; // Add file at path
[writer addPath:@"/Path/SomeDirectory" forPath:@"SomeDirectory"]; // Recursively add directory with all contents

// Setup writer
writer.delegate = self; // Track progress
writer.passwordGetter = ^NSString*(void) { // Password getter
	return @"1234";
};

// Optional settings 
writer.method = LzmaSDKObjCMethodLZMA2; // or LzmaSDKObjCMethodLZMA
writer.solid = YES;
writer.compressionLevel = 9;
writer.encodeContent = YES;
writer.encodeHeader = YES;
writer.compressHeader = YES;
writer.compressHeaderFull = YES;
writer.writeModificationTime = NO;
writer.writeCreationTime = NO;
writer.writeAccessTime = NO;

// Open archive file
NSError * error = nil;
[writer open:&error];

// Write archive within current thread
[writer write];

// or
dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
	[writer write];
});
```


##### Compress/decompress single data buffer
##### Swift
```swift
// Compress data with compression maximum compression ratio.
let compressedData = LzmaSDKObjCBufferCompressLZMA2(sourceData, 1)
// Decompress previvously compressed data.
let decompressedData = LzmaSDKObjCBufferDecompressLZMA2(compressedData)
```
##### Objective-C
```objc
// Compress data with compression maximum compression ratio.
NSData * compressedData = LzmaSDKObjCBufferCompressLZMA2(sourceData, 1);
// Decompress previvously compressed data.
NSData * decompressedData = LzmaSDKObjCBufferDecompressLZMA2(compressedData);
```


### Tune up speed, performance and disk IO operations
-----------------------------------------------------
Original C++ part of the [LZMA SDK] was patched to have a possibility to tune up default(*hardcoded*) settings.
For list and extract functionality was defined next global variables: ```kLzmaSDKObjCStreamReadSize```, ```kLzmaSDKObjCStreamWriteSize```, ```kLzmaSDKObjCDecoderReadSize``` and ```kLzmaSDKObjCDecoderWriteSize```.
This variables holds size values in bytes, so, for the single reader object summary of this 4's values will be allocated.

Keep in mind: operations with **memory much more faster** than **disk IO operations**, so read below situations:
```c
switch (<what do I need ?>) {
	case <I need faster list and extract>:
		//TODO: Increase stream and decoder size of buffers
		Result:
			1. more allocated memory
			2. less IO read/write operations and less delays
			3. less smoothed progress
			4. more CPU load (do a job, not distracted to read/write data)
		break;

	case <I need use less memory or more smoothed progress>:
		//TODO: Decrease stream and decoder size of buffers
		Result:
			1. less allocated memory
			2. more IO read/write operations and more delays
			3. more smoothed progress
			4. less CPU load (wait for read/write data)
		break;

	default:
		//TODO: use current settings
		break;
	};
```
> NOTE: Modify global variables **before** creating & using reader object.

> NOTE: This allocation sizes doesn't affet to memory allocated for the archive dictionary.


### Features list (TODO/DONE)
-----------------------------
- [x] **Lzma/*.7z**
  - [x] **List**
    - [x] Regular archive. ```tests/files/lzma.7z```
    - [x] Encrypted archive with AES256. ```tests/files/lzma_aes256.7z```
    - [x] Encrypted archive + encrypted header(*no visible content, files list, without password*) with AES256. ```tests/files/lzma_aes256_encfn.7z```
  - [x] **Extract**
    - [x] Regular archive. ```tests/files/lzma.7z```
    - [x] Encrypted archive with AES256. ```tests/files/lzma_aes256.7z```
    - [x] Encrypted archive + encrypted header(*no visible content, files list, without password*) with AES256. ```tests/files/lzma_aes256_encfn.7z```
  - [x] **Create**
    - [x] Regular archive.
    - [x] Encrypted archive with AES256.
    - [x] Encrypted archive + encrypted header(*no visible content, files list, without password*) with AES256.
- [x] **Lzma2/*.7z**
  - [x] **List**
    - [x] Regular archive. ```tests/files/lzma2.7z```
    - [x] Encrypted archive with AES256. ```tests/files/lzma2_aes256.7z```
    - [x] Encrypted archive + encrypted header(*no visible content, files list, without password*) with AES256. ```tests/files/lzma2_aes256_encfn.7z```
  - [x] **Extract**
    - [x] Regular archive. ```tests/files/lzma2.7z```
    - [x] Encrypted archive with AES256. ```tests/files/lzma2_aes256.7z```
    - [x] Encrypted archive + encrypted header(*no visible content, files list, without password*) with AES256. ```tests/files/lzma2_aes256_encfn.7z```
  - [x] **Create**
    - [x] Regular archive.
    - [x] Encrypted archive with AES256.
    - [x] Encrypted archive + encrypted header(*no visible content, files list, without password*) with AES256.
- [ ] **Omit unused code**, reduce buildable, original code size.


### License
-----------
By using this all you are accepting original [LZMA SDK] and MIT license (*see below*):

The MIT License (MIT)

Copyright (c) 2015 - 2017 Kulykov Oleh <info@resident.name>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.


[LZMA SDK]:http://www.7-zip.org/sdk.html
[CocoaPods]:http://cocoapods.org/pods/LzmaSDK-ObjC

