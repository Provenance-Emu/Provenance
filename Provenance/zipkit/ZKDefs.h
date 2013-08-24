//
//  ZKDefs.h
//  ZipKit
//
//  Created by Karl Moskowski on 01/04/09.
//

#define ZK_TARGET_OS_MAC (TARGET_OS_MAC && !(TARGET_OS_EMBEDDED || TARGET_OS_IPHONE))
#define ZK_TARGET_OS_IPHONE (TARGET_OS_EMBEDDED || TARGET_OS_IPHONE || TARGET_OS_IPHONE_SIMULATOR)

enum ZKReturnCodes {
	zkFailed = -1,
	zkCancelled = 0,
	zkSucceeded = 1,
};

// File & path naming
extern NSString* const ZKArchiveFileExtension;
extern NSString* const ZKMacOSXDirectory;
extern NSString* const ZKDotUnderscore;
extern NSString* const ZKExpansionDirectoryName;

// Keys for dictionary passed to size calculation thread
extern NSString* const ZKPathsKey;
extern NSString* const ZKusingResourceForkKey;

// Keys for dictionary returned from ZKDataArchive inflation
extern NSString* const ZKFileDataKey;
extern NSString* const ZKFileAttributesKey;
extern NSString* const ZKPathKey;

// Zipping & Unzipping
extern const NSUInteger ZKZipBlockSize;
extern const NSUInteger ZKNotificationIterations;

// Magic numbers and lengths for zip records
extern const NSUInteger ZKCDHeaderMagicNumber;
extern const NSUInteger ZKCDHeaderFixedDataLength;

extern const NSUInteger ZKCDTrailerMagicNumber;
extern const NSUInteger ZKCDTrailerFixedDataLength;

extern const NSUInteger ZKLFHeaderMagicNumber;
extern const NSUInteger ZKLFHeaderFixedDataLength;

extern const NSUInteger ZKCDTrailer64MagicNumber;
extern const NSUInteger ZKCDTrailer64FixedDataLength;

extern const NSUInteger ZKCDTrailer64LocatorMagicNumber;
extern const NSUInteger ZKCDTrailer64LocatorFixedDataLength;
