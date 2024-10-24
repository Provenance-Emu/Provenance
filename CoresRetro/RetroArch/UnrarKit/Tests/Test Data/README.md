[![Build Status](https://travis-ci.org/abbeycode/UnrarKit.svg?branch=master)](https://travis-ci.org/abbeycode/UnrarKit)
[![Documentation Coverage](https://img.shields.io/cocoapods/metrics/doc-percent/UnrarKit.svg)](http://cocoadocs.org/docsets/UnrarKit)

# About

UnrarKit is here to enable Mac and iOS apps to easily work with RAR files for read-only operations. It is currently based on version 5.2.1 of the [UnRAR library](http://www.rarlab.com/rar/unrarsrc-5.2.1.tar.gz).

There is a main project, with unit tests, and a basic iOS example project, which demonstrates how to use the library. To see all of these, open the main workspace file.

I'm always open to improvements, so please submit your pull requests, or [create issues](https://github.com/abbeycode/UnrarKit/issues) for someone else to implement.


# Installation

UnrarKit supports both [CocoaPods](https://cocoapods.org/) and [Carthage](https://github.com/Carthage/Carthage). CocoaPods does not support dynamic framework targets (as of v0.39.0), so in that case, please use Carthage.

Cartfile:

    github "abbeycode/UnrarKit"

Podfile:

    pod "UnrarKit"

# Example Usage

```Objective-C
NSError *archiveError = nil;
URKArchive *archive = [[URKArchive alloc] initWithPath:@"An Archive.rar" error:&archiveError];
NSError *error = nil;
```

## Listing the file names in an archive
```Objective-C
NSArray<String*> *filesInArchive = [archive listFilenames:&error];
for (NSString *name in filesInArchive) {
    NSLog(@"Archived file: %@", name);
}
```

## Listing the file details in an archive
```Objective-C
NSArray<URKFileInfo*> *fileInfosInArchive = [archive listFileInfo:&error];
for (URKFileInfo *info in fileInfosInArchive) {
    NSLog(@"Archive name: %@ | File name: %@ | Size: %lld", info.archiveName, info.filename, info.uncompressedSize);
}
```

## Working with passwords
```Objective-C
NSArray<URKFileInfo*> *fileInfosInArchive = [archive listFileInfo:&error];
if (archive.isPasswordProtected) {
    NSString *givenPassword = // prompt user
    archive.password = givenPassword
}

// You can now extract the files
```

## Extracting files to a directory
```Objective-C
BOOL extractFilesSuccessful = [archive extractFilesTo:@"some/directory"
                                            overWrite:NO
                                             progress:
    ^(URKFileInfo *currentFile, CGFloat percentArchiveDecompressed) {
        NSLog(@"Extracting %@: %f%% complete", currentFile.filename, percentArchiveDecompressed);
    }
                                                error:&error];
```

## Extracting a file into memory
```Objective-C
NSData *extractedData = [archive extractDataFromFile:@"a file in the archive.jpg"
                                            progress:^(CGFloat percentDecompressed) {
                                                         NSLog(@"Extracting, %f%% complete", percentDecompressed);
                                            }
                                               error:&error];
```

## Streaming a file

For large files, you may not want the whole contents in memory at once. You can handle it one "chunk" at a time, like so:

```Objective-C
BOOL success = [archive extractBufferedDataFromFile:@"a file in the archive.jpg"
                                              error:&error
                                             action:
                ^(NSData *dataChunk, CGFloat percentDecompressed) {
                    NSLog(@"Decompressed: %f%%", percentDecompressed);
                    // Do something with the NSData chunk
                }];
```

# Progress Reporting

The following methods support `NSProgress` and `NSProgressReporting`:

* `extractFilesTo:overwrite:error:`
* `extractData:error:`
* `extractDataFromFile:error:`
* `performOnFilesInArchive:error:`
* `performOnDataInArchive:error:`
* `extractBufferedDataFromFile:error:action:`

## Using implicit `NSProgress` hierarchy

You can create your own instance of `NSProgress` and observe its `fractionCompleted` property with KVO to monitor progress like so:

```Objective-C
    static void *ExtractDataContext = &ExtractDataContext;

    URKArchive *archive = [[URKArchive alloc] initWithURL:aFileURL error:nil];

    NSProgress *extractDataProgress = [NSProgress progressWithTotalUnitCount:1];
    [extractDataProgress becomeCurrentWithPendingUnitCount:1];
    
    NSString *observedSelector = NSStringFromSelector(@selector(fractionCompleted));
    
    [extractDataProgress addObserver:self
                          forKeyPath:observedSelector
                             options:NSKeyValueObservingOptionInitial
                             context:ExtractDataContext];
    
    NSError *extractError = nil;
    NSData *data = [archive extractDataFromFile:firstFile error:&extractError];

    [extractDataProgress resignCurrent];
    [extractDataProgress removeObserver:self forKeyPath:observedSelector];
```

## Using your own explicit `NSProgress` instance

If you don't have a hierarchy of `NSProgress` instances, or if you want to observe more details during progress updates in `extractFilesTo:overwrite:error:`, you can create your own instance of `NSProgress` and set the `URKArchive` instance's `progress` property, like so:

```Objective-C
    static void *ExtractFilesContext = &ExtractFilesContext;

    URKArchive *archive = [[URKArchive alloc] initWithURL:aFileURL error:nil];
    
    NSProgress *extractFilesProgress = [NSProgress progressWithTotalUnitCount:1];
    archive.progress = extractFilesProgress;
    
    NSString *observedSelector = NSStringFromSelector(@selector(localizedDescription));
    
    [self.descriptionsReported removeAllObjects];
    [extractFilesProgress addObserver:self
                           forKeyPath:observedSelector
                              options:NSKeyValueObservingOptionInitial
                              context:ExtractFilesContext];
    
    NSError *extractError = nil;
    BOOL success = [archive extractFilesTo:extractURL.path
                                 overwrite:NO
                                     error:&extractError];
    
    [extractFilesProgress removeObserver:self forKeyPath:observedSelector];
```

## Cancellation with `NSProgress`

Using either method above, you can call `[progress cancel]` to stop the operation in progress. It will cause the operation to fail, returning `nil` or `NO` (depending on the return type, and give an error with error code `URKErrorCodeUserCancelled`.


# Notes

To open in Xcode, use the [UnrarKit.xcworkspace](UnrarKit.xcworkspace) file, which includes the other projects.

# Documentation

Full documentation for the project is available on [CocoaDocs](http://cocoadocs.org/docsets/UnrarKit).


# Logging

For all OS versions from 2016 onward (macOS 10.12, iOS 10, tvOS 10, watchOS 3), UnzipKit uses the new [Unified Logging framework](https://developer.apple.com/documentation/os/logging) for logging and Activity Tracing. You can view messages at the Info or Debug level to view more details of how UnzipKit is working, and use Activity Tracing to help pinpoint the code path that's causing a particular error.

As a fallback, regular `NSLog` is used on older OSes, with all messages logged at the same level.

When debugging your own code, if you'd like to decrease the verbosity of the UnrarKit framework, you can run the following command:

    sudo log config --mode "level:default" --subsystem com.abbey-code.UnrarKit

The available levels, in order of increasing verbosity, are `default`, `info`, `debug`, with `debug` being the default.

## Logging guidelines

These are the general rules governing the particulars of how activities and log messages are classified and written. They were written after the initial round of log messages were, so there may be some inconsistencies (such as an incorrect log level). If you think you spot one, open an issue or a pull request!

### Logging

Log messages should follow these conventions.

1. Log messages don't have final punctuation (like these list items)
1. Messages that note a C function is about to be called, rather than a higher level UnrarKit or Cocoa method, end with "...", since it's not expected for them to log any details of their own

#### Default log level

There should be no messages at this level, so that it's possible for a consumer of the API to turn off _all_ diagnostic logging from it, as detailed above. It's only possible to `log config --mode "level:off"` for a process, not a subsystem.

#### Info log level

Info level log statements serve the following specific purposes.

1. Major action is taken, such as initializing an archive object, or deleting a file from an archive
1. Noting each public method has been called, and the arguments with which it was called
1. Signposting the major actions a public method takes
1. Notifying that an atypical condition has occurred (such as an action causing an early stop in a block or a NO return value)
1. Noting that a loop is about to occur, which will contain debug-level messages for each iteration

#### Debug log level

Most messages fall into this category, making it extremely verbose. All non-error messages that don't fall into either of the other two categories should be debug-level, with some examples of specific cases below.

1. Any log message in a private method
1. Noting variable and argument values in a method
1. Indicating that everything is working as expected
1. Indicating what happens during each iteration of a loop (or documenting that an iteration has happened at all)

#### Error log level

1. Every `NSError` generated should get logged with the same detail message as the `NSError` object itself
1. `NSError` log messages should contain the string of the error code's enumeration value (e.g. `"URKErrorCodeArchiveNotFound"`) when it is known at design time
1. Errors should reported everywhere they're encountered, making it easier to trace their flows through the call stack
1. Early exits that result in desired work not being performed

#### Fault log level

So far, there is only one case that gets logged at Fault-level: when a Cocoa framework methods that come back with an error

### Activities
1. Public methods have an English activity names with spaces, and are title-case
1. Private methods each have an activity with the method's name
1. Sub-activities are created for significant scope changes, such as when inside an action block, but not if no significant work is done before entering that action
1. Top-level activities within a method have variables named `activity`, with more specific labels given to sub-activities
1. If a method is strictly an overload that calls out to another overload without doing anything else, it should not define its own activity

# Pushing a new CocoaPods version

New tagged builds (in any branch) get pushed to CocoaPods automatically, provided they meet the following criteria:

1. All builds and tests succeed
2. The library builds successfully for CocoaPods and for Carthage
3. The build is tagged with something resembling a version number (`#.#.#(-beta#)`, e.g. **2.9** or **2.9-beta5**)
4. `pod spec lint` passes, making sure the CocoaPod is 100% valid

Before pushing a build, you must:

1. Add the release notes to the [CHANGELOG.md](CHANGELOG.md), and commit
2. Run [set-version](Scripts/set-version.sh), like so:
     
    `./Scripts/set-version.sh <version number>`
    
    This does the following:
    
    1. Updates the [UnrarKit-Info.plist](Resources/UnrarKit-Info.plist) file to indicate the new version number, and commits it

    2. Makes an annotated tag whose message contains the release notes entered in Step 1

Once that's done, you can call `git push --follow-tags` [<sup id=a1>1</sup>](#f1), and let [Travis CI](https://travis-ci.org/abbeycode/UnrarKit/builds) take care of the rest. 

# Credits

* Dov Frankel (dov@abbey-code.com)
* Rogerio Pereira Araujo (rogerio.araujo@gmail.com)
* Vicent Scott (vkan388@gmail.com)



<hr>

<span id="f1">1</span>: Or set `followTags = true` in your git config to always get this behavior:

    git config --global push.followTags true

[↩](#a1)