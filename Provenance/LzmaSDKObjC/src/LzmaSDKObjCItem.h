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


#import <Foundation/Foundation.h>


/**
 @brief Archive item class for the file or directory.
 */
@interface LzmaSDKObjCItem : NSObject


/**
 @brief Getter for orinal file size.
 */
@property (nonatomic, assign, readonly) unsigned long long originalSize;


/**
 @bief Item CRC32 if available.
 */
@property (nonatomic, assign, readonly) NSUInteger crc32;


/**
 @brief Getter for check archive item is encrypted with password or not.
 */
@property (nonatomic, assign, readonly) BOOL isEncrypted;


/**
 @brief Check archive item is directory.
 */
@property (nonatomic, assign, readonly) BOOL isDirectory;


/**
 @brief Getter for the file name.
 @warning If item is directory this propoerty return nil.
 */
@property (nonatomic, strong, readonly) NSString * _Nullable fileName;


/**
 @brief Getter for the directory path where item located or nil.
 @code
 // If full item path is=dir1/subdir2/readme.txt
 // then directoryPath=dir1/subdir2
 @endcode
 */
@property (nonatomic, strong, readonly) NSString * _Nullable directoryPath;


/**
 @brief Getter for the modification date if available, or nil.
 */
@property (nonatomic, strong, readonly) NSDate * _Nullable modificationDate;


/**
 @brief Getter for the creation date if available, or nil.
 */
@property (nonatomic, strong, readonly) NSDate * _Nullable creationDate;


/**
 @brief Getter for the last access date time if available, or nil.
 */
@property (nonatomic, strong, readonly) NSDate * _Nullable accessDate;

@end

