#include "osal_files.h"
#import <Foundation/Foundation.h>
#include <string>

/* global functions */

#ifdef __cplusplus
extern "C"{
#endif

EXPORT int CALL osal_path_existsA(const char *path)
{
	NSString* nsPath = [NSString stringWithUTF8String:path];
	return [[NSFileManager defaultManager] fileExistsAtPath:nsPath];
}

EXPORT int CALL osal_path_existsW(const wchar_t *_path)
{
	NSString* nsPath = [[NSString alloc] initWithBytes:_path length:wcslen(_path)*sizeof(*_path) encoding:NSUTF32LittleEndianStringEncoding];
	return [[NSFileManager defaultManager] fileExistsAtPath:nsPath];
}

EXPORT int CALL osal_is_directory(const wchar_t * _name)
{
	NSString* nsPath = [[NSString alloc] initWithBytes:_name length:wcslen(_name)*sizeof(*_name) encoding:NSUTF32LittleEndianStringEncoding];
	BOOL isDirectory;
	if ([[NSFileManager defaultManager] fileExistsAtPath:nsPath isDirectory:&isDirectory] && isDirectory)
	{
		return 1;
	}
	return 0;
}

EXPORT int CALL osal_mkdirp(const wchar_t *_dirpath)
{
	NSString* nsPath = [[NSString alloc] initWithBytes:_dirpath length:wcslen(_dirpath)*sizeof(*_dirpath) encoding:NSUTF32LittleEndianStringEncoding];
	if (![[NSFileManager defaultManager] createDirectoryAtPath:nsPath withIntermediateDirectories:YES attributes:nil error:nil])
	{
		return 1;
	}
	return 0;
}

struct IOSDirSearch
{
	const void *dirNSString;
	const void *enumerator;
	std::wstring currentFilePath;
};

EXPORT void * CALL osal_search_dir_open(const wchar_t *_pathname)
{
	NSString *nsPath = [[NSString alloc] initWithBytes:_pathname length:wcslen(_pathname)*sizeof(*_pathname) encoding:NSUTF32LittleEndianStringEncoding];
	IOSDirSearch *dirSearch = new IOSDirSearch;
	dirSearch->dirNSString = CFBridgingRetain(nsPath);
	dirSearch->enumerator = CFBridgingRetain([[NSFileManager defaultManager] enumeratorAtPath:nsPath]);
	return dirSearch;
}

EXPORT const wchar_t * CALL osal_search_dir_read_next(void * dir_handle)
{
	IOSDirSearch *dirSearch = (IOSDirSearch*)dir_handle;
	NSString *dirPath = (__bridge NSString *)dirSearch->dirNSString;
	NSDirectoryEnumerator *dirEnum = (__bridge NSDirectoryEnumerator *)dirSearch->enumerator;

	NSString *file = [dirEnum nextObject];
	NSString *filePath = [dirPath stringByAppendingPathComponent:file];
	BOOL isDirectory;
	if ([[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:&isDirectory] && isDirectory)
	{
		[dirEnum skipDescendants];
	}
	NSData* data = [filePath dataUsingEncoding:NSUTF32LittleEndianStringEncoding];
	dirSearch->currentFilePath = (const wchar_t *)[data bytes];
	return dirSearch->currentFilePath.c_str();
}

EXPORT void CALL osal_search_dir_close(void * dir_handle)
{
	IOSDirSearch *dirSearch = (IOSDirSearch*)dir_handle;
	CFRelease(dirSearch->dirNSString);
	CFRelease(dirSearch->enumerator);
	delete dirSearch;
}

#ifdef __cplusplus
}
#endif
