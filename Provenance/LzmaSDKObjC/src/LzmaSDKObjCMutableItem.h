/*
 *   Copyright (c) 2015 - 2017 Kulykov Oleh <info@resident.name>
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


#import "LzmaSDKObjCItem.h"

@interface LzmaSDKObjCMutableItem : LzmaSDKObjCItem

/**
 @brief Full item path. 
 If file - no "/" at the end.
 If directory - "/" at the end.
 */
@property (nonatomic, strong, readonly) NSString * _Nonnull path;


/**
 @brief File path asociated with item.
 */
@property (nonatomic, strong, readonly) NSString * _Nullable sourceFilePath;


/**
 @brief Set custom data for the file.
 If data not empty - mark item as file and set all dates to `now`.
 */
@property (nonatomic, strong) NSData * _Nullable fileData;


/**
 @brief Modification date if available, or nil.
 */
@property (nonatomic, strong, setter=setModificationDate:) NSDate * _Nullable modificationDate;


/**
 @brief Creation date if available, or nil.
 */
@property (nonatomic, strong, setter=setCreationDate:) NSDate * _Nullable creationDate;


/**
 @brief Last access date time if available, or nil.
 */
@property (nonatomic, strong, setter=setAccessDate:) NSDate * _Nullable accessDate;


- (void) setAccessDate:(nullable NSDate *) date;

- (void) setCreationDate:(nullable NSDate *) date;

- (void) setModificationDate:(nullable NSDate *) date;

/**
 @brief Set full item path with directory flag.
 */
- (void) setPath:(nonnull NSString *) path isDirectory:(BOOL) isDirectory;

@end
