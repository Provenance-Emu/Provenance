//
//  URKArchive.h
//  UnrarKit
//
//

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import "UnrarKitMacros.h"

RarosHppIgnore
#import "raros.hpp"
#pragma clang diagnostic pop

DllHppIgnore
#import "dll.hpp"
#pragma clang diagnostic pop

@class URKFileInfo;

/**
 *  Defines the various error codes that the listing and extraction methods return.
 *  These are returned in NSError's [code]([NSError code]) field.
 */
typedef NS_ENUM(NSInteger, URKErrorCode) {

    /**
     *  The last file of the archive has been read
     */
    URKErrorCodeEndOfArchive = ERAR_END_ARCHIVE,
    
    /**
     *  The library ran out of memory while reading the archive
     */
    URKErrorCodeNoMemory = ERAR_NO_MEMORY,
    
    /**
     *  The header's CRC doesn't match the decompressed data's CRC
     */
    URKErrorCodeBadData = ERAR_BAD_DATA,
    
    /**
     *  The archive is not a valid RAR file
     */
    URKErrorCodeBadArchive = ERAR_BAD_ARCHIVE,
    
    /**
     *  The archive is an unsupported RAR format or version
     */
    URKErrorCodeUnknownFormat = ERAR_UNKNOWN_FORMAT,
    
    /**
     *  Failed to open a reference to the file
     */
    URKErrorCodeOpen = ERAR_EOPEN,
    
    /**
     *  Failed to create the target directory for extraction
     */
    URKErrorCodeCreate = ERAR_ECREATE,
    
    /**
     *  Failed to close the archive
     */
    URKErrorCodeClose = ERAR_ECLOSE,
    
    /**
     *  Failed to read the archive
     */
    URKErrorCodeRead = ERAR_EREAD,

    /**
     *  Failed to write a file to disk
     */
    URKErrorCodeWrite = ERAR_EWRITE,

    /**
     *  The archive header's comments are larger than the buffer size
     */
    URKErrorCodeSmall = ERAR_SMALL_BUF,

    /**
     *  The cause of the error is unspecified
     */
    URKErrorCodeUnknown = ERAR_UNKNOWN,

    /**
     *  A password was not given for a password-protected archive
     */
    URKErrorCodeMissingPassword = ERAR_MISSING_PASSWORD,
    
    /**
     *  The given password was incorrect
     */
    URKErrorCodeBadPassword = ERAR_BAD_PASSWORD,
    
    /**
     *  No data was returned from the archive
     */
    URKErrorCodeArchiveNotFound = 101,
    
    /**
     *  User cancelled the operation
     */
    URKErrorCodeUserCancelled = 102,
    
    /**
     *  Error converting string to UTF-8
     */
    URKErrorCodeStringConversion = 103,
};

typedef NSString *const URKProgressInfoKey;


/**
 *  Defines the keys passed in `-[NSProgress userInfo]` for certain methods
 */
static URKProgressInfoKey _Nonnull
    /**
     *  For `extractFilesTo:overwrite:error:`, this key contains an instance of URKFileInfo with the file currently being extracted
     */
    URKProgressInfoKeyFileInfoExtracting = @"URKProgressInfoKeyFileInfoExtracting";

NS_ASSUME_NONNULL_BEGIN

extern NSString *URKErrorDomain;

/**
 *  An Objective-C/Cocoa wrapper around the unrar library
 */
@interface URKArchive : NSObject
// Minimum of iOS 9, macOS 10.11 SDKs
#if (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED > 90000) || (defined(MAC_OS_X_VERSION_MIN_REQUIRED) && MAC_OS_X_VERSION_MIN_REQUIRED > 101100)
<NSProgressReporting>
#endif


/**
 *  The URL of the archive
 */
@property(nullable, weak, atomic, readonly) NSURL *fileURL;

/**
 *  The filename of the archive
 */
@property(nullable, weak, atomic, readonly) NSString *filename;

/**
 *  The password of the archive
 */
@property(nullable, nonatomic, strong) NSString *password;

/**
 *  The total uncompressed size (in bytes) of all files in the archive. Returns nil on errors
 */
@property(nullable, atomic, readonly) NSNumber *uncompressedSize;

/**
 *  The total compressed size (in bytes) of the archive. Returns nil on errors
 */
@property(nullable, atomic, readonly) NSNumber *compressedSize;

/**
 *  True if the file is one volume of a multi-part archive
 */
@property(atomic, readonly) BOOL hasMultipleVolumes;

/**
 *  Can be used for progress reporting, but it's not necessary. You can also use
 *  implicit progress reporting. If you don't use it, one will still be created,
 *  which will become a child progress of whichever one is the current NSProgress
 *  instance.
 *
 *  To use this, assign it before beginning an operation that reports progress. Once
 *  the method you're calling has a reference to it, it will nil it out. Please check
 *  for nil before assigning it to avoid concurrency conflicts.
 */
@property(nullable, strong) NSProgress *progress;

/**
 *  When performing operations on a RAR archive, the contents of compressed files are checked
 *  against the record of what they were when the archive was created. If there's a mismatch,
 *  either the metadata (header) or archive contents have become corrupted. You can defeat this check by
 *  setting this property to YES, though there may be security implications to turning the
 *  warnings off, as it may indicate a maliciously crafted archive intended to exploit a vulnerability.
 *
 *  It's recommended to leave the decision of how to treat archives with mismatched CRCs to the user
 */
@property (assign) BOOL ignoreCRCMismatches;


/**
 *  **DEPRECATED:** Creates and returns an archive at the given path
 *
 *  @param filePath A path to the archive file
 */
+ (nullable instancetype)rarArchiveAtPath:(NSString *)filePath __deprecated_msg("Use -initWithPath:error: instead");

/**
 *  **DEPRECATED:** Creates and returns an archive at the given URL
 *
 *  @param fileURL The URL of the archive file
 */
+ (nullable instancetype)rarArchiveAtURL:(NSURL *)fileURL __deprecated_msg("Use -initWithURL:error: instead");

/**
 *  **DEPRECATED:** Creates and returns an archive at the given path, with a given password
 *
 *  @param filePath A path to the archive file
 *  @param password The passowrd of the given archive
 */
+ (nullable instancetype)rarArchiveAtPath:(NSString *)filePath password:(NSString *)password __deprecated_msg("Use -initWithPath:password:error: instead");

/**
 *  **DEPRECATED:** Creates and returns an archive at the given URL, with a given password
 *
 *  @param fileURL  The URL of the archive file
 *  @param password The passowrd of the given archive
 */
+ (nullable instancetype)rarArchiveAtURL:(NSURL *)fileURL password:(NSString *)password __deprecated_msg("Use -initWithURL:password:error: instead");


/**
 *  Do not use the default initializer
 */
- (instancetype)init NS_UNAVAILABLE;

/**
 *  Creates and returns an archive at the given path
 *
 *  @param filePath A path to the archive file
 *  @param error    Contains any error during initialization
 *
 *  @return Returns an initialized URKArchive, unless there's a problem creating a bookmark to the path
 */
- (nullable instancetype)initWithPath:(NSString *)filePath error:(NSError **)error;

/**
 *  Creates and returns an archive at the given URL
 *
 *  @param fileURL The URL of the archive file
 *  @param error   Contains any error during initialization
 *
 *  @return Returns an initialized URKArchive, unless there's a problem creating a bookmark to the URL
 */
- (nullable instancetype)initWithURL:(NSURL *)fileURL error:(NSError **)error;

/**
 *  Creates and returns an archive at the given path, with a given password
 *
 *  @param filePath A path to the archive file
 *  @param password The passowrd of the given archive
 *  @param error    Contains any error during initialization
 *
 *  @return Returns an initialized URKArchive, unless there's a problem creating a bookmark to the path
 */
- (nullable instancetype)initWithPath:(NSString *)filePath password:(NSString *)password error:(NSError **)error;

/**
 *  Creates and returns an archive at the given URL, with a given password
 *
 *  @param fileURL  The URL of the archive file
 *  @param password The passowrd of the given archive
 *  @param error    Contains any error during initialization
 *
 *  @return Returns an initialized URKArchive, unless there's a problem creating a bookmark to the URL
 */
- (nullable instancetype)initWithURL:(NSURL *)fileURL password:(NSString *)password error:(NSError **)error;


/**
 *  Determines whether a file is a RAR archive by reading the signature
 *
 *  @param filePath Path to the file being checked
 *
 *  @return YES if the file exists and contains a signature indicating it is a RAR archive
 */
+ (BOOL)pathIsARAR:(NSString *)filePath;

/**
 *  Determines whether a file is a RAR archive by reading the signature
 *
 *  @param fileURL URL of the file being checked
 *
 *  @return YES if the file exists and contains a signature indicating it is a RAR archive
 */
+ (BOOL)urlIsARAR:(NSURL *)fileURL;

/**
 *  Lists the names of the files in the archive
 *
 *  @param error Contains an NSError object when there was an error reading the archive
 *
 *  @return Returns a list of NSString containing the paths within the archive's contents, or nil if an error was encountered
 */
- (nullable NSArray<NSString*> *)listFilenames:(NSError **)error;

/**
 *  Lists the various attributes of each file in the archive
 *
 *  @param error Contains an NSError object when there was an error reading the archive
 *
 *  @return Returns a list of URKFileInfo objects, which contain metadata about the archive's files, or nil if an error was encountered
 */
- (nullable NSArray<URKFileInfo*> *)listFileInfo:(NSError **)error;

/**
 *  Iterates the header of the archive, calling the block with each archived file's info.
 *
 *  WARNING: There is no filtering of duplicate header entries. If a file is listed twice, `action`
 *  will be called twice with that file's path
 *
 *  @param action The action to perform using the data. Must be non-nil
 *
 *       - *fileInfo* The metadata of the file within the archive
 *       - *stop*     Set to YES to stop reading the archive
 *
 *  @param error Contains an NSError object when there was an error reading the archive
 *
 *  @return Returns NO if an error was encountered
 */
- (BOOL) iterateFileInfo:(void(^)(URKFileInfo *fileInfo, BOOL *stop))action
                   error:(NSError **)error;

/**
 *  Lists the URLs of volumes in a single- or multi-volume archive
 *
 *  @param error Contains an NSError object when there was an error reading the archive
 *
 *  @return Returns the list of URLs of all volumes of the archive
 */
- (nullable NSArray<NSURL*> *)listVolumeURLs:(NSError **)error;

/**
 *  Writes all files in the archive to the given path. Supports NSProgress for progress reporting, which also
 *  allows cancellation in the middle of extraction. Use the progress property (as explained in the README) to
 *  retrieve more detailed information, such as the current file being extracted, number of files extracted,
 *  and the URKFileInfo instance being extracted
 *
 *  @param filePath  The destination path of the unarchived files
 *  @param overwrite YES to overwrite files in the destination directory, NO otherwise
 *  @param error     Contains an NSError object when there was an error reading the archive
 *
 *  @return YES on successful extraction, NO if an error was encountered
 */
- (BOOL)extractFilesTo:(NSString *)filePath
             overwrite:(BOOL)overwrite
                 error:(NSError **)error;

/**
 *  **DEPRECATED:** Writes all files in the archive to the given path
 *
 *  @param filePath      The destination path of the unarchived files
 *  @param overwrite     YES to overwrite files in the destination directory, NO otherwise
 *  @param progressBlock Called every so often to report the progress of the extraction
 *
 *       - *currentFile*                The info about the file that's being extracted
 *       - *percentArchiveDecompressed* The percentage of the archive that has been decompressed
 *
 *  @param error     Contains an NSError object when there was an error reading the archive
 *
 *  @return YES on successful extraction, NO if an error was encountered
 */
- (BOOL)extractFilesTo:(NSString *)filePath
             overwrite:(BOOL)overwrite
              progress:(nullable void (^)(URKFileInfo *currentFile, CGFloat percentArchiveDecompressed))progressBlock
                 error:(NSError **)error __deprecated_msg("Use -extractFilesTo:overwrite:error: instead, and if using the progress block, replace with NSProgress as described in the README");

/**
 *  Unarchive a single file from the archive into memory. Supports NSProgress for progress reporting, which also
 *  allows cancellation in the middle of extraction
 *
 *  @param fileInfo The info of the file within the archive to be expanded. Only the filename property is used
 *  @param error    Contains an NSError object when there was an error reading the archive
 *
 *  @return An NSData object containing the bytes of the file, or nil if an error was encountered
 */
- (nullable NSData *)extractData:(URKFileInfo *)fileInfo
                           error:(NSError **)error;

/**
 *  **DEPRECATED:** Unarchive a single file from the archive into memory
 *
 *  @param fileInfo      The info of the file within the archive to be expanded. Only the filename property is used
 *  @param progressBlock Called every so often to report the progress of the extraction
 *
 *       - *percentDecompressed* The percentage of the archive that has been decompressed
 *
 *  @param error    Contains an NSError object when there was an error reading the archive
 *
 *  @return An NSData object containing the bytes of the file, or nil if an error was encountered
 */
- (nullable NSData *)extractData:(URKFileInfo *)fileInfo
                        progress:(nullable void (^)(CGFloat percentDecompressed))progressBlock
                           error:(NSError **)error __deprecated_msg("Use -extractData:error: instead, and if using the progress block, replace with NSProgress as described in the README");

/**
 *  Unarchive a single file from the archive into memory. Supports NSProgress for progress reporting, which also
 *  allows cancellation in the middle of extraction
 *
 *  @param filePath The path of the file within the archive to be expanded
 *
 *       - *percentDecompressed* The percentage of the file that has been decompressed
 *
 *  @param error    Contains an NSError object when there was an error reading the archive
 *
 *  @return An NSData object containing the bytes of the file, or nil if an error was encountered
 */
- (nullable NSData *)extractDataFromFile:(NSString *)filePath
                                   error:(NSError **)error;

/**
 *  **DEPRECATED:** Unarchive a single file from the archive into memory
 *
 *  @param filePath      The path of the file within the archive to be expanded
 *  @param progressBlock Called every so often to report the progress of the extraction
 *
 *       - *percentDecompressed* The percentage of the file that has been decompressed
 *
 *  @param error    Contains an NSError object when there was an error reading the archive
 *
 *  @return An NSData object containing the bytes of the file, or nil if an error was encountered
 */
- (nullable NSData *)extractDataFromFile:(NSString *)filePath
                                progress:(nullable void (^)(CGFloat percentDecompressed))progressBlock
                                   error:(NSError **)error __deprecated_msg("Use -extractDataFromFile:error: instead, and if using the progress block, replace with NSProgress as described in the README");

/**
 *  Loops through each file in the archive in alphabetical order, allowing you to perform an
 *  action using its info. Supports NSProgress for progress reporting, which also allows
 *  cancellation of the operation in the middle
 *
 *  @param action The action to perform using the data
 *
 *       - *fileInfo* The metadata of the file within the archive
 *       - *stop*     Set to YES to stop reading the archive
 *
 *  @param error  Contains an error if any was returned
 *
 *  @return YES if no errors were encountered, NO otherwise
 */
- (BOOL)performOnFilesInArchive:(void(^)(URKFileInfo *fileInfo, BOOL *stop))action
                          error:(NSError **)error;

/**
 *  Extracts each file in the archive into memory, allowing you to perform an action
 *  on it (not sorted). Supports NSProgress for progress reporting, which also allows
 *  cancellation of the operation in the middle
 *
 *  @param action The action to perform using the data
 *
 *       - *fileInfo* The metadata of the file within the archive
 *       - *fileData* The full data of the file in the archive
 *       - *stop*     Set to YES to stop reading the archive
 *
 *  @param error  Contains an error if any was returned
 *
 *  @return YES if no errors were encountered, NO otherwise
 */
- (BOOL)performOnDataInArchive:(void(^)(URKFileInfo *fileInfo, NSData *fileData, BOOL *stop))action
                         error:(NSError **)error;

/**
 *  Unarchive a single file from the archive into memory. Supports NSProgress for progress reporting, which also
 *  allows cancellation in the middle of extraction
 *
 *  @param filePath   The path of the file within the archive to be expanded
 *  @param error      Contains an NSError object when there was an error reading the archive
 *  @param action     The block to run for each chunk of data, each of size <= bufferSize
 *
 *       - *dataChunk*           The data read from the archived file. Read bytes and length to write the data
 *       - *percentDecompressed* The percentage of the file that has been decompressed
 *
 *  @return YES if all data was read successfully, NO if an error was encountered
 */
- (BOOL)extractBufferedDataFromFile:(NSString *)filePath
                              error:(NSError **)error
                             action:(void(^)(NSData *dataChunk, CGFloat percentDecompressed))action;

/**
 *  YES if archive protected with a password, NO otherwise
 */
- (BOOL)isPasswordProtected;

/**
 *  Tests whether the provided password unlocks the archive
 *
 *  @return YES if correct password or archive is not password protected, NO if password is wrong
 */
- (BOOL)validatePassword;

/**
 Iterate through the archive, checking for any errors, including CRC mismatches between
 the archived file and its header
 
 @return YES if the data is all correct, false if any check failed (_even if ignoreCRCMismatches is YES_)
 */
- (BOOL)checkDataIntegrity;

/**
 Iterate through the archive, checking for any errors, including CRC mismatches between
 the archived file and its header. If any file's CRC doesn't match, run the given block
 to allow the API consumer to decide whether to ignore mismatches. NOTE: This may be a
 security risk. The block is intended to prompt the user, which is why it's forced onto
 the main thread, rather than making a design-time decision
 
 @param ignoreCRCMismatches This block, called on the main thread, allows a consuming API to
                            prompt the user whether or not he'd like to ignore CRC mismatches.
                            This block is called the first time a CRC mismatch is detected, if
                            at all. It won't be called if all CRCs match. If this returns YES,
                            then all further CRC mismatches will be ignored for the
                            archive instance
 
 @return YES if the data is all correct and/or the block returns YES; returns false if
         any check failed and the given block also returns NO
 */
- (BOOL)checkDataIntegrityIgnoringCRCMismatches:(BOOL(^)(void))ignoreCRCMismatches;

/**
 Check a particular file, to determine if its data matches the CRC
 checksum stored at the time it written

 @param filePath The file in the archive to check
 
 @return YES if the data is correct, false if any check failed
 */
- (BOOL)checkDataIntegrityOfFile:(NSString *)filePath;

@end
NS_ASSUME_NONNULL_END
