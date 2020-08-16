/*
 *   Copyright (c) 2015 - 2020 Oleh Kulykov <olehkulykov@gmail.com>
 *
 *   Permission is hereby granted, free of charge, to any person obtaining a copy
 *   of this software and associated documentation files (the "Software"), to deal
 *   in the Software without restriction, including without limitation the rights
 *   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 *   copies of the Software, and to permit persons to whom the Software is
 *   furnished to do so, subject to the following conditions:
 *
 *   The above copyright notice and this permission notice shall be included in
 *   all copies or substantial portions of the Software.
 *
 *   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 *   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 *   THE SOFTWARE.
 */


#import "LzmaSDKObjCReader.h"
#import "LzmaSDKObjCMutableItem.h"

@class LzmaSDKObjCWriter;

/**
 @brief Writer delegate. All methods is optional & called from main thread.
 */
@protocol LzmaSDKObjCWriterDelegate <NSObject>

@optional
/**
 @brief Reports write/archive progress for all file(s).
 Quality depends on size of the @b kLzmaSDKObjCStreamWriteSize, @b kLzmaSDKObjCDecoderWriteSize.
 @param progress Write/compress progress [0.0; 1.0]
 */
- (void) onLzmaSDKObjCWriter:(nonnull LzmaSDKObjCWriter *) writer
			   writeProgress:(float) progress;

@end

@interface LzmaSDKObjCWriter : NSObject

/**
 @brief Archive password getter.
 Called when @b encodeContent and/or @b encodeHeader is YES.
 */
@property (nonatomic, copy) NSString * _Nullable (^ _Nullable passwordGetter)(void);


/**
 @brief Type of the assigned archive. Determined during initialization.
 @warning Readonly property. If can't be determined - create writer with custom type.
 */
@property (nonatomic, assign, readonly) LzmaSDKObjCFileType fileType;


/**
 @brief URL to the archive file. Destination archive file.
 */
@property (nonatomic, strong, readonly) NSURL * _Nullable fileURL;


/**
 @brief Last error from operation.
 */
@property (nonatomic, strong, readonly) NSError * _Nullable lastError;


/**
 @brief Archive writer delegate.
 */
@property (nonatomic, weak) id<LzmaSDKObjCWriterDelegate> _Nullable delegate;


/**
 Compression method.
 Default is `LzmaSDKObjCMethodLZMA2`.
 */
@property (nonatomic) LzmaSDKObjCMethod method;


/**
 @brief Create solid archive.
 Default is `YES`.
 */
@property (nonatomic) BOOL solid;


/**
 Compression level, [1..9]. 9 - ultra.
 Default is 7.
 */
@property (nonatomic) unsigned char compressionLevel;


/**
 Compress archive header.
 Default is `YES`.
 */
@property (nonatomic) BOOL compressHeader;


/**
 Full process archive header.
 Default is `YES`.
 */
@property (nonatomic) BOOL compressHeaderFull;


/**
 Encode archive content, e.g. items/files encoded with password.
 Required password for test/extract archive content.
 Also required `passwordGetter` block.
 Default is `NO`.
 */
@property (nonatomic) BOOL encodeContent;


/**
 Encode archive header, e.g. no visible content. 
 Required password for open/list archive content.
 Also required `passwordGetter` block.
 Default is `NO`.
 */
@property (nonatomic) BOOL encodeHeader;


/**
 Write creation time to header.
 Default is `YES`.
 */
@property (nonatomic) BOOL writeCreationTime;


/**
 Write access time to header.
 Default is `YES`.
 */
@property (nonatomic) BOOL writeAccessTime;


/**
 Write modification time to header.
 Default is `YES`.
 */
@property (nonatomic) BOOL writeModificationTime;


/**
 @brief Initialize archive with file url.
 @warning If `fileURL` is nil -> assertion.
 @warning Prev. path will be deleted.
 @warning Type detected from archive file extension using @b LzmaSDKObjCDetectFileType function.
 @param fileURL File url to the archive. Can't be nil.
 */
- (nonnull id) initWithFileURL:(nonnull NSURL *) fileURL;


/**
 @brief Initialize archive with file url and archive type.
 @warning If `fileURL` is nil -> assertion.
 @warning Prev. path will be deleted.
 @param fileURL File url to the archive. Can't be nil.
 @param type Manualy defined type of the archive.
 */
- (nonnull id) initWithFileURL:(nonnull NSURL *) fileURL andType:(LzmaSDKObjCFileType) type;


/**
 @brief Add file data with a given file path in archive.
 @param data File data to encode. Should not be nil or empty.
 @param path Path in arcvive. Example: `file.txt` or `dir/file.txt`, etc.
 @warning If `data` is nil -> assertion.
 @warning If `path` is nil -> assertion.
 @return YES - stored and added, otherwice NO.
 */
- (BOOL) addData:(nonnull NSData *) data forPath:(nonnull NSString *) path;


/**
 @brief Add source full path, e.g. file or directory full path with a given file path in archive.
 If source path is directory - all directory content will be added.
 @param aPath File or directory full path. Should not be nil.
 @param path Path in arcvive. Example: `file.txt` or `dir/file.txt`, etc.
 @return YES - source path exists and readable, and item(s) stored and added, otherwice NO.
 */
- (BOOL) addPath:(nonnull NSString *) aPath forPath:(nonnull NSString *) path;


/**
 @brief Open archive with `fileURL`.
 @warning Prev. path will be deleted.
 @param error Open error. Same error can be received via @b lastError property.
 @return YES - output file was opened and prepared, otherwice NO(check @b lastError property).
 */
- (BOOL) open:(NSError * _Nullable * _Nullable) error;


/**
 @brief Encode, e.g. compress all items to `fileURL`.
 @warning Call after all items are added and archive is opened.
 Can be called within separate thread.
 @return YES - all items processed, otherwice NO(check @b lastError property).
 */
- (BOOL) write;

#pragma mark - Unavailable
- (nullable instancetype) init NS_UNAVAILABLE;
+ (nullable instancetype) new NS_UNAVAILABLE;

@end
