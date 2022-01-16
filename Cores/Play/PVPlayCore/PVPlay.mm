//
//  PVPlay.mm
//  PVPlay
//
//  Created by Joseph Mattiello on 9/5/21.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import "PVPlayCore.h"
#import "PVPlayCore+Controls.h"
#import "PVPlayCore+Video.h"

#include "PathUtils.h"
#include "Utf8.h"

using namespace Framework;

fs::path PathUtils::GetRoamingDataPath()
{
	__strong __typeof__(_current) current = _current;
	if (current == nil) {
		NSURL *url = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
		std::string directory = [url fileSystemRepresentation];
		return fs::path(directory);
	}
	NSString *path = current.batterySavesPath;
	return fs::path(path.fileSystemRepresentation);
}

fs::path PathUtils::GetAppResourcesPath()
{
	NSBundle* bundle = [NSBundle bundleForClass:[PVPlayCore class]];
	NSURL* bundleURL = [bundle resourceURL];
	return fs::path([bundleURL fileSystemRepresentation]);
}

fs::path PathUtils::GetPersonalDataPath()
{
	return GetRoamingDataPath();
}

fs::path PathUtils::GetCachePath()
{
	NSURL* url = [[NSFileManager defaultManager] URLForDirectory:NSCachesDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
	std::string directory = [url fileSystemRepresentation];
	return fs::path(directory);
}

void PathUtils::EnsurePathExists(const fs::path& path)
{
	typedef fs::path PathType;
	PathType buildPath;
	for(PathType::iterator pathIterator(path.begin());
		pathIterator != path.end(); pathIterator++)
	{
		buildPath /= (*pathIterator);
		std::error_code existsErrorCode;
		bool exists = fs::exists(buildPath, existsErrorCode);
		if(existsErrorCode)
		{
			if(existsErrorCode.value() == ENOENT)
			{
				exists = false;
			}
			else
			{
				throw std::runtime_error("Couldn't ensure that path exists.");
			}
		}
		if(!exists)
		{
			fs::create_directory(buildPath);
		}
	}
}

////////////////////////////////////////////
//NativeString <-> Path Function Utils
////////////////////////////////////////////

template <typename StringType>
static std::string GetNativeStringFromPathInternal(const StringType&);

template <>
std::string GetNativeStringFromPathInternal(const std::string& str)
{
	return str;
}

template <typename StringType>
static StringType GetPathFromNativeStringInternal(const std::string&);

template <>
std::string GetPathFromNativeStringInternal(const std::string& str)
{
	return str;
}

////////////////////////////////////////////
//NativeString <-> Path Function Implementations
////////////////////////////////////////////

std::string PathUtils::GetNativeStringFromPath(const fs::path& path)
{
	return GetNativeStringFromPathInternal(path.native());
}

fs::path PathUtils::GetPathFromNativeString(const std::string& str)
{
	auto cvtStr = GetPathFromNativeStringInternal<fs::path::string_type>(str);
	return fs::path(cvtStr);
}
