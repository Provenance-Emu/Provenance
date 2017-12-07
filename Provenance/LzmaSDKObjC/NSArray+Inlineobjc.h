/*
 *   Copyright (c) 2015 - 2016 Kulykov Oleh <info@resident.name>
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

#ifndef __NSARRAY_INLINEOBJC_H__
#define __NSARRAY_INLINEOBJC_H__ 1

#if defined(DEBUG) || defined(_DEBUG)
#ifndef DEBUG
#define DEBUG 1
#endif
#endif


/**
 @brief Return number of objects.
 @param array An array for test.
 @return Number of objects or 0 on nil array.
 */
NS_INLINE NSUInteger NSArrayCount(NSArray * array)
{
#if defined(DEBUG)
	if (array)
	{
		assert([array isKindOfClass:[NSArray class]]);
	}
#endif
	return (array) ? [array count] : 0;
}


/**
 @brief Check is array has no objects or nil.
 @param array An array for test.
 @return YES if no objects or nil, othervice NO.
 */
NS_INLINE BOOL NSArrayIsEmpty(NSArray * array)
{
#if defined(DEBUG)
	if (array)
	{
		assert([array isKindOfClass:[NSArray class]]);
	}
#endif
	return (array) ? ([array count] == 0) : YES;
}


/**
 @brief Check is array has objects and not nil.
 @param array An array for test.
 @return YES if not nil and have objects, othervice NO.
 */
NS_INLINE BOOL NSArrayIsNotEmpty(NSArray * array)
{
#if defined(DEBUG)
	if (array)
	{
		assert([array isKindOfClass:[NSArray class]]);
	}
#endif
	return (array) ? ([array count] > 0) : NO;
}


/**
 @brief Get array object at index.
 @param array The target array.
 @param index Index of required object.
 @return Object or nil if array empty or index dosn't exists.
 */
NS_INLINE id NSArrayObjectAtIndex(NSArray * array, const NSUInteger index)
{
#if defined(DEBUG)
	if (array)
	{
		assert([array isKindOfClass:[NSArray class]]);
	}
#endif
	const NSUInteger count = array ? [array count] : 0;
	return (index < count) ? [array objectAtIndex:index] : nil;
}


/**
 @brief Get index of object in array.
 @param array The target array.
 @param object The target object.
 @return Index or 'NSNotFound' if array empty or object dosn't exists.
 */
NS_INLINE NSUInteger NSArrayIndexOfObject(NSArray * array, id object)
{
#if defined(DEBUG)
	if (array)
	{
		assert([array isKindOfClass:[NSArray class]]);
	}
#endif
	return (array && object) ? [array indexOfObject:object] : NSNotFound;
}


/**
 @brief Get serialized binary data from array.
 @param array The array for serialization.
 @return NSData with binary content.
 */
NS_INLINE NSData * NSArraySerializeToBinaryData(NSArray * array)
{
	if (array)
	{
#if defined(DEBUG)
		assert([array isKindOfClass:[NSArray class]]);
#endif
		if ([array count])
		{
			NSDictionary * dictionary = [NSDictionary dictionaryWithObject:array forKey:@"NSArray_BinarySerialized_Array"];
			if (dictionary)
			{
				NSError * error = nil;
				NSData * res = [NSPropertyListSerialization dataWithPropertyList:dictionary format:NSPropertyListBinaryFormat_v1_0 options:0 error:&error];
				if (!error) return res;
			}
		}
	}
	return nil;
}


/**
 @brief Get deserialized array from binary data.
 @param binaryData The binary data for deserialization.
 @return NSData with binary content.
 */
NS_INLINE NSArray * NSArrayDeserializeFromBinaryData(NSData * binaryData)
{
	if (binaryData)
	{
#if defined(DEBUG)
		assert([binaryData isKindOfClass:[NSData class]]);
#endif
		NSError * error = nil;
		NSPropertyListFormat format = (NSPropertyListFormat)0;
		id res =  [NSPropertyListSerialization propertyListWithData:binaryData options:0 format:&format error:&error];
		if (!error && res && [res isKindOfClass:[NSDictionary class]])
		{
			return [(NSDictionary *)res objectForKey:@"NSArray_BinarySerialized_Array"];
		}
	}
	return nil;
}


/**
 @brief Get array next index from started index.
 @param array The target array.
 @param index Started index.
 @return Next array index from started or NSNotFound on error.
 */
NS_INLINE NSUInteger NSArrayNextIndexFrom(NSArray * array, const NSUInteger index)
{
	if (array)
	{
#if defined(DEBUG)
		assert([array isKindOfClass:[NSArray class]]);
#endif
		const NSUInteger nextIndex = index + 1;
		if (nextIndex < [array count])
		{
			return nextIndex;
		}
	}
	return NSNotFound;
}


/**
 @brief Get array previous index from started index.
 @param array The target array.
 @param index Started index.
 @return Previous array index from started or NSNotFound on error.
 */
NS_INLINE NSUInteger NSArrayPreviousIndexFrom(NSArray * array, const NSUInteger index)
{
	if (array)
	{
#if defined(DEBUG)
		assert([array isKindOfClass:[NSArray class]]);
#endif
		if (index > 0 && index < NSNotFound)
		{
			const NSUInteger prevIndex = index - 1;
			if (prevIndex < [array count])
			{
				return prevIndex;
			}
		}
	}
	return NSNotFound;
}

#endif

