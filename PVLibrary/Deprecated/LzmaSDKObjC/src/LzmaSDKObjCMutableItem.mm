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


#import "LzmaSDKObjCMutableItem.h"
#import "LzmaSDKObjCItem+Private.h"
#import "LzmaSDKObjCMutableItem+Private.h"

@implementation LzmaSDKObjCMutableItem

// getters in superclass, setters here.
@dynamic modificationDate;
@dynamic creationDate;
@dynamic accessDate;

- (NSString *) path {
	return _path;
}

- (NSString *) sourceFilePath {
	return (_content && [_content isKindOfClass:[NSString class]]) ? (NSString*)_content : nil;
}

- (void) setPath:(nonnull NSString *) path isDirectory:(BOOL) isDirectory {
	NSParameterAssert(path);
	_path = path;
	if (isDirectory) {
		_flags |= LzmaObjcItemFlagIsDir;
		_content = nil;
	} else {
		_flags &= ~(LzmaObjcItemFlagIsDir);
	};
}

- (NSData *) fileData {
	return (_content && [_content isKindOfClass:[NSData class]]) ? (NSData*)_content : nil;
}

- (void) setFileData:(NSData *) fileData {
	const uint64_t size = fileData ? [fileData length] : 0;
	if (size) {
		_content = fileData;
		_orgSize = size;
		_flags &= ~(LzmaObjcItemFlagIsDir);
		_mDate = _cDate = _aDate = (time_t)[[NSDate date] timeIntervalSince1970];
	} else {
		_content = nil;
		_orgSize = 0;
	}
}

- (void) setAccessDate:(nullable NSDate *) date {
	_aDate = date ? (time_t)[date timeIntervalSince1970] : 0;
}

- (void) setCreationDate:(nullable NSDate *) date {
	_cDate = date ? (time_t)[date timeIntervalSince1970] : 0;
}

- (void) setModificationDate:(nullable NSDate *) date {
	_mDate = date ? (time_t)[date timeIntervalSince1970] : 0;
}

- (void) dealloc {
	_content = nil;
}

@end
