// ================================================================
// Copyright (c) 2007, Google Inc.
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
//
// * Redistributions of source code must retain the above copyright
//   notice, this list of conditions and the following disclaimer.
// * Redistributions in binary form must reproduce the above
//   copyright notice, this list of conditions and the following disclaimer
//   in the documentation and/or other materials provided with the
//   distribution.
// * Neither the name of Google Inc. nor the names of its
//   contributors may be used to endorse or promote products derived from
//   this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
// ================================================================
//
//  GMAppleDouble.h
//  MacFUSE
//
//  Created by ted on 12/29/07.
//

/*!
 * @header GMAppleDouble
 *
 * A utility class to construct an AppleDouble (._) file.
 *
 * AppleDouble files contain information about a corresponding file and are 
 * typically used on file systems that do not support extended attributes.
 */

#import <Foundation/Foundation.h>

#define GM_EXPORT __attribute__((visibility("default")))

/*!
 * <pre>
 * Based on "AppleSingle/AppleDouble Formats for Foreign Files Developer's Note"
 *
 * Notes:
 * DoubleEntryFileDatesInfo
 *    File creation, modification, backup, and access times as number of seconds 
 *    before or after 12:00 AM Jan 1 2000 GMT as SInt32.
 *  DoubleEntryFinderInfo
 *    16 bytes of FinderInfo followed by 16 bytes of extended FinderInfo.
 *    New FinderInfo should be zero'd out. For a directory, when the Finder 
 *    encounters an entry with the init'd bit cleared, it will initialize the 
 *    frView field of the to a value indicating how the contents of the
 *    directory should be shown. Recommend to set frView to value of 256.
 *  DoubleEntryMacFileInfo
 *    This is a 32 bit flag that stores locked (bit 0) and protected (bit 1).
 * </pre>
 */
typedef enum {
	DoubleEntryInvalid = 0,
	DoubleEntryDataFork = 1,
	DoubleEntryResourceFork = 2,
	DoubleEntryRealName = 3,
	DoubleEntryComment = 4,
	DoubleEntryBlackAndWhiteIcon = 5,
	DoubleEntryColorIcon = 6,
	DoubleEntryFileDatesInfo = 8,  // See notes
	DoubleEntryFinderInfo = 9,     // See notes
	DoubleEntryMacFileInfo = 10,   // See notes
	DoubleEntryProDosFileInfo = 11,
	DoubleEntryMSDosFileinfo = 12,
	DoubleEntryShortName = 13,
	DoubleEntryAFPFileInfo = 14,
	DoubleEntryDirectoryID = 15,
} GMAppleDoubleEntryID;

/*!
 * @class
 * @discussion This class represents a single entry in an AppleDouble file.
 */
GM_EXPORT @interface GMAppleDoubleEntry : NSObject {
@private
	GMAppleDoubleEntryID entryID_;
	NSData* data_;  // Format depends on entryID_
}
/*! 
 * @abstract Initializes an AppleDouble entry with ID and data.
 * @param entryID A valid entry identifier
 * @param data Raw data for the entry
 */
- (id)initWithEntryID:(GMAppleDoubleEntryID)entryID data:(NSData *)data;

/*! @abstract The entry ID */
- (GMAppleDoubleEntryID)entryID;

/*! @abstract The entry data */
- (NSData *)data;
@end

/*!
 * @class
 * @discussion This class can be used to construct raw AppleDouble data.
 */
GM_EXPORT @interface GMAppleDouble : NSObject {  
@private
	NSMutableArray* entries_;
}

/*! @abstract An autoreleased empty GMAppleDouble file */
+ (GMAppleDouble *)appleDouble;

/*! 
 * @abstract An autoreleased GMAppleDouble file.
 * @discussion The GMAppleDouble is pre-filled with entries from the raw
 * AppleDouble file data.
 * @param data Raw AppleDouble file data.
 */
+ (GMAppleDouble *)appleDoubleWithData:(NSData *)data;

/*! 
 * @abstract Adds an entry to the AppleDouble file.
 * @param entry The entry to add
 */
- (void)addEntry:(GMAppleDoubleEntry *)entry;

/*! 
 * @abstract Adds an entry to the AppleDouble file with ID and data.
 * @param entryID The ID of the entry to add
 * @param data The raw data for the entry to add (retained)
 */
- (void)addEntryWithID:(GMAppleDoubleEntryID)entryID data:(NSData *)data;

/*! 
 * @abstract Adds entries based on the provided raw AppleDouble file data.
 * @discussion This will attempt to parse the given data as an AppleDouble file
 * and add all entries found.
 * @param data Raw AppleDouble file data
 * @param data The raw data for the entry to add (retained)
 * @result YES if the provided data was parsed correctly.
 */
- (BOOL)addEntriesFromAppleDoubleData:(NSData *)data;

/*!
 * @abstract The set of GMAppleDoubleEntry present in this GMAppleDouble.
 * @result An array of GMAppleDoubleEntry.
 */
- (NSArray *)entries;

/*!
 * @abstract Constructs raw data for the AppleDouble file.
 * @result The raw data for an AppleDouble file represented by this GMAppleDouble.
 */
- (NSData *)data;

@end

#undef GM_EXPORT