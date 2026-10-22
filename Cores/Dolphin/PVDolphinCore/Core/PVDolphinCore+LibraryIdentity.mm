@import PVCoreBridge;
#import "PVDolphinCore+LibraryIdentity.h"
#include "LibraryDiscIdentity.h"
#include "DiscIO/Volume.h"
#include "DiscIO/Blob.h"
#include <exception>

namespace {
NSDictionary<NSString *, id> *UnresolvedIdentity(NSError **error) {
    if (error) {
        *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadCorruptFileError
                                userInfo:@{NSLocalizedDescriptionKey: @"The file has no readable supported disc identity."}];
    }
    return nil;
}
}

@implementation PVDolphinCoreBridge (LibraryIdentity)

+ (NSDictionary<NSString *, id> *)libraryDiscIdentityAtPath:(NSString *)path error:(NSError **)error {
    if (error) {
        *error = nil;
    }
    const char *filePath = path.fileSystemRepresentation;
    if (path.length == 0 || !filePath) {
        return UnresolvedIdentity(error);
    }
    try {
        // unique_ptr closes the volume/reader on every return and exception path.
        auto reader = DiscIO::CreateBlobReader(filePath);
        if (!reader || !PVLibraryIdentity::HasReadableIdentityBytes(*reader)) {
            return UnresolvedIdentity(error);
        }
        auto volume = DiscIO::CreateVolume(std::move(reader));
        if (!volume) {
            return UnresolvedIdentity(error);
        }
        const auto identity = PVLibraryIdentity::Read(*volume);
        if (!identity) {
            return UnresolvedIdentity(error);
        }
        NSString *gameID = [[NSString alloc] initWithBytes:identity->gameID.data()
                                                  length:identity->gameID.size()
                                                encoding:NSUTF8StringEncoding];
        if (gameID.length == 0) {
            return UnresolvedIdentity(error);
        }
        return @{@"gameID": gameID, @"discNumber": @(identity->discNumber), @"revision": @(identity->revision)};
    } catch (const std::exception&) {
        return UnresolvedIdentity(error);
    } catch (...) {
        return UnresolvedIdentity(error);
    }
}

+ (NSDictionary<NSString *, id> *)libraryIdentityAtPath:(NSString *)path {
    return [self libraryDiscIdentityAtPath:path error:nil];
}

@end
