[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fdrewmccormack%2FSwiftCloudDrive%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/drewmccormack/SwiftCloudDrive)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fdrewmccormack%2FSwiftCloudDrive%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/drewmccormack/SwiftCloudDrive)

# SwiftCloudDrive

Author: Drew McCormack (Mastodon: @drewmccormack@mastodon.cloud)

An easy to use Swift wrapper around iCloud Drive. 

SwiftCloudDrive handles complexities like file coordination, accessing security scoped resources, 
file conflicts, and cloud metadata queries, to provide straightforward async functions 
for working with files in iCloud. It makes handling files in the cloud almost
as easy as working locally with `FileManager`.

## When is SwiftCloudDrive a Good Solution?

For advanced uses of iCloud, you should probably use Apple's
frameworks directly. This gives you most control, in exchange
for a steep learning curve.

For example, if you need complete control over when files in iCloud Drive get 
downloaded to a device, or have an app like Apple's Photos, where it is often 
desirable to leave files in the cloud until they are requested by the user, 
you should not use SwiftCloudDrive.

If you want all of your app's iCloud Drive files on device, as well as
in the cloud, SwiftCloudDrive can get you up and running much faster.
You don't have to worry about file coordination, metadata queries, or conflict
resolution, which are all part of working with iCloud Drive. SwiftCloudDrive
will give you a simple class to upload, download, query, and update, which 
works much the same as the `FileManager` type you are already familiar with.

## Using SwiftCloudDrive

### Integrating the Package

To get started, add the SwiftCloudDrive package to your Xcode project,
and then enable iCloud Drive in the Signing & Capabilities
tab of your app's target in Xcode. You can accept the default 
container identifier, or choose a custom one.

### Setting Up a Drive

If you are using the default iCloud container, setting up a `CloudDrive` in
your app's source code can be as simple as this

```swift
import SwiftCloudDrive
let drive = try await CloudDrive()
```

If you have a custom iCloud container, simply pass the identifier in.

```swift
let customDrive = try await CloudDrive(storage: .iCloudContainer(containerIdentifier: "iCloud.com.yourcompany.app"))
```

In the cases above, you will be accessing files directly in the root of
the container, but you can also anchor your `CloudDrive` at a particular 
subdirectory of the container, like this

```swift
let subDrive = try await CloudDrive(relativePathToRootInContainer: "Sub/Directory/Of/Choice")
```

The `CloudDrive` will create the directory for you, if it doesn't exist.
    
### Querying File Status

Once you have a `CloudDrive` object, you can query file status just like you
do with `FileManager`. There is one big difference though: because files may
be remote and have to download, all function calls are `async`.

To determine if a directory exists, you would do this

```swift
let path = RootRelativePath(path: "Path/To/Dir")
let exists = try await drive.directoryExists(at: path)
```

If you want to know if a particular file exists, you would use this

```swift
let exists = try await drive.fileExists(at: path)
```

### Working with Paths

As you can see in the previous section, the `RootRelativePath` struct 
is used to reference paths relative to the root of the `CloudDrive`.

If you use particular fixed paths often, it is useful to extend `RootRelativePath`
to define static constants.

```swift
extension RootRelativePath {
    static let images = Self(path: "Images")
}

let imagesExist = try await drive.directoryExists(at: .images)
let dogImageExists = try await drive.fileExists(at: .images.appending("Dog.jpeg"))
```

As you can see, the `RootRelativePath` also defines an `appending` function
which makes it simple to extend an existing path.

### Creating Directories

Creating a directory in the cloud is just as easy. Note that if there are missing
intermediate directories, these are always created too.

```swift
try await drive.createDirectory(at: .images)
```

### Uploading and Downloading Files

To move files into the cloud, you can 'upload' a local file to the container,
or you can write `Data` directly into a file.

```swift
let data = "Some text".data(using: .utf8)!
try await drive.writeFile(with: data, at: .root.appending("file.txt"))
```

In this case we use the built in static constant `root` to build a path, but 
we could also have just used `RootRelativePath("file.txt")`.

To upload a file from outside of the cloud container, you use code like this

```swift
try await drive.upload(from: "/Users/eddy/Desktop/image.jpeg", to: .images.appending("image.jpeg"))
```

### Updating Files

Once you have a file in the cloud, you can change it by uploading again, but you must 
first delete the old version, otherwise an error will arise.

```swift
let cloudPath: RootRelativePath = .images.appending("image.jpeg")
try? await drive.removeFile(at: cloudPath)
try await drive.upload(from: "/Users/eddy/Desktop/image_new.jpeg", to: cloudPath)
```

Alternatively, you can write the contents without first removing the existing file.

```swift
try await drive.writeFile(with: newImageData, at: cloudPath)
```

If you need even finer control, you can make any in-place update you favor, like this

```swift
try await drive.updateFile(at: imagePath) { fileURL in
    // Make any changes you like to the file at `fileURL`
    // You can also throw an error
}
```

### Removing Files and Directories

As we have already seen, you can very easily remove files and directories.

```swift
try await drive.removeFile(at: cloudFilePath)
try await drive.removeDirectory(at: cloudDirPath)
```

If the wrong type of item is encountered, the removal fails and an error
is thrown.

### Observing Remote Changes

When working with changes on remote devices, it is important to know when 
new files have downloaded, or updates have been applied. You can register a `CloudDriveObserver`
for this purpose.

```swift
class Controller: CloudDriveObserver {
    func cloudDriveDidChange(_ drive: CloudDrive, rootRelativePaths: [RootRelativePath]) {
        // Decide if data needs refetching due to remote changes,
        // or if changes need to be applied in the UI
    }
}

let controller = Controller()
drive.observer = controller
```

Note that the relative paths passed to the observer are not necessarily new files, 
but could be files with updates, or even files that were removed. 
Your code should take these possibilities into account, and adapt appropriately.
