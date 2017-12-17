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
#import "LzmaSDKObjCItem+Private.h"

@implementation LzmaSDKObjCItem

- (unsigned long long) originalSize {
	return _orgSize;
}

- (NSUInteger) crc32 {
	return _crc;
}

- (BOOL) isEncrypted {
	return (_flags & LzmaObjcItemFlagIsEncrypted) ? YES : NO;
}

- (BOOL) isDirectory {
	return (_flags & LzmaObjcItemFlagIsDir) ? YES : NO;
}

- (NSString *) fileName {
	return (NSStringIsNotEmpty(_path) && !self.isDirectory) ? [_path lastPathComponent] : nil;
}

- (NSString *) directoryPath {
	if (NSStringIsNotEmpty(_path)) {
		if (self.isDirectory) return _path;
		else {
			NSString * path = [_path stringByDeletingLastPathComponent];
			if (NSStringIsNotEmpty(path)) return path;
		}
	}
	return nil;
}

- (NSDate *) modificationDate {
	return _mDate ? [NSDate dateWithTimeIntervalSince1970:NSTimeInterval(_mDate)] : nil;
}

- (NSDate *) creationDate {
	return _cDate ? [NSDate dateWithTimeIntervalSince1970:NSTimeInterval(_cDate)] : nil;
}

- (NSDate *) accessDate {
	return _aDate ? [NSDate dateWithTimeIntervalSince1970:NSTimeInterval(_aDate)] : nil;
}

#if defined(DEBUG) || defined(_DEBUG)
- (NSString *) debugDescription {
	return [NSString stringWithFormat:@"[\npath=%@\nsize=%llu\nmodf.date=%@\ncret.date=%@\naccs.date=%@\nencrypted=%@\nCRC=%u\ndirectory=%@\n]",
			_path,
			_orgSize,
			self.modificationDate,
			self.creationDate,
			self.accessDate,
			self.isEncrypted ? @"YES" : @"NO",
			_crc,
			self.isDirectory ? @"YES" : @"NO"
			];
}

- (NSString *) description {
	return [self debugDescription];
}
#endif

- (void) dealloc {
	_path = nil;
}


@end
