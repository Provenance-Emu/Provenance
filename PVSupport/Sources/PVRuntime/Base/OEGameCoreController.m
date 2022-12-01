/*
 Copyright (c) 2009, OpenEmu Team

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
     * Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.
     * Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in the
       documentation and/or other materials provided with the distribution.
     * Neither the name of the OpenEmu Team nor the
       names of its contributors may be used to endorse or promote products
       derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
 EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "OEGameCoreController.h"
#import "OEAbstractAdditions.h"
#import "OEGameCore.h"
#import <objc/runtime.h>

// unused?
NSString *const OEAdvancedPreferenceKey        = @"OEAdvancedPreferenceKey";

NSString *const OEGameCoreClassKey             = @"OEGameCoreClass";
NSString *const OEGameCorePlayerCountKey       = @"OEGameCorePlayerCount";
NSString *const OEGameCoreSystemIdentifiersKey = @"OESystemIdentifiers";
NSString *const OEGameCoreRequiredFilesKey     = @"OERequiredFiles";
NSString *const OEGameCoreDeprecatedKey                = @"OEDeprecated";
NSString *const OEGameCoreDeprecatedMinMacOSVersionKey = @"OEDeprecatedMinMacOSVersion";
NSString *const OEGameCoreSuggestedReplacement         = @"OESuggestedReplacementCore";
NSString *const OEGameCoreSupportDeadlineKey           = @"OESupportDeadline";
NSString *const OEGameCoreOptionsKey           = @"OEGameCoreOptions";

// sub-keys of OEGameCoreOptionsKey
NSString *const OEGameCoreSupportsCheatCodeKey = @"OEGameCoreSupportsCheatCode";
NSString *const OEGameCoreRequiresFilesKey     = @"OEGameCoreRequiresFiles";
NSString *const OEGameCoreHasGlitchesKey       = @"OEGameCoreHasGlitches";
NSString *const OEGameCoreSupportsMultipleDiscsKey = @"OEGameCoreSupportsMultipleDiscs";
NSString *const OEGameCoreSaveStatesNotSupportedKey = @"OEGameCoreSaveStatesNotSupported";
NSString *const OEGameCoreSupportsRewindingKey = @"OEGameCoreSupportsRewinding";
NSString *const OEGameCoreRewindIntervalKey = @"OEGameCoreRewindInterval";
NSString *const OEGameCoreRewindBufferSecondsKey = @"OEGameCoreRewindBufferSeconds";
NSString *const OEGameCoreSupportsFileInsertionKey = @"OEGameCoreSupportsFileInsertion";
NSString *const OEGameCoreSupportsDisplayModeChangeKey = @"OEGameCoreSupportsDisplayModeChange";

NSString *OEEventNamespaceKeys[] = { @"", @"OEGlobalNamespace", @"OEKeyboardNamespace", @"OEHIDNamespace", @"OEMouseNamespace", @"OEOtherNamespace" };


@interface OEGameCoreController ()
{
    NSMutableArray *_gameDocuments;
}

@end

@implementation OEGameCoreController

- (instancetype)init
{
    return [self initWithBundle:[NSBundle bundleForClass:[self class]]];
}

- (instancetype)initWithBundle:(NSBundle *)aBundle;
{
    if((self = [super init]))
    {
        _bundle            = aBundle;
        _pluginName        = ([_bundle objectForInfoDictionaryKey:@"CFBundleExecutable"] ? :
                              [_bundle objectForInfoDictionaryKey:@"CFBundleName"]);
        _gameCoreClass     = NSClassFromString([_bundle objectForInfoDictionaryKey:OEGameCoreClassKey]);
        _playerCount       = [[_bundle objectForInfoDictionaryKey:OEGameCorePlayerCountKey] integerValue];

        NSArray  *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
        NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : NSTemporaryDirectory();

        NSString *supportFolder = [basePath stringByAppendingPathComponent:@"OpenEmu"];
        _supportDirectoryPath   = [supportFolder stringByAppendingPathComponent:_pluginName];
        _biosDirectoryPath      = [supportFolder stringByAppendingPathComponent:@"BIOS"];

        _gameDocuments = [[NSMutableArray alloc] init];
    }
    return self;
}

- (NSArray<NSString *> *)systemIdentifiers
{
	return [[[self bundle] infoDictionary] objectForKey:OEGameCoreSystemIdentifiersKey];
}

- (NSDictionary<NSString *, NSDictionary<NSString *, id> *> *)coreOptions
{
	return [[[self bundle] infoDictionary] objectForKey:OEGameCoreOptionsKey];
}

- (NSArray<NSDictionary<NSString *, id> *> *)requiredFilesForSystemIdentifier:(NSString *)systemIdentifier
{
    id options = [self coreOptions];
    id system = [options valueForKey:systemIdentifier];
    return [system objectForKey:OEGameCoreRequiredFilesKey];
}

- (BOOL)requiresFilesForSystemIdentifier:(NSString *)systemIdentifier
{
    id options = [self coreOptions];
    id system = [options valueForKey:systemIdentifier];
    return [[system valueForKey:OEGameCoreRequiresFilesKey] boolValue];
}

- (BOOL)supportsCheatCodeForSystemIdentifier:(NSString *)systemIdentifier
{
    id options = [self coreOptions];
    id system = [options valueForKey:systemIdentifier];
    return [[system valueForKey:OEGameCoreSupportsCheatCodeKey] boolValue];
}

- (BOOL)hasGlitchesForSystemIdentifier:(NSString *)systemIdentifier
{
    id options = [self coreOptions];
    id system = [options valueForKey:systemIdentifier];
    return [[system valueForKey:OEGameCoreHasGlitchesKey] boolValue];
}

- (BOOL)supportsMultipleDiscsForSystemIdentifier:(NSString *)systemIdentifier
{
    id options = [self coreOptions];
    id system = [options valueForKey:systemIdentifier];
    return [[system valueForKey:OEGameCoreSupportsMultipleDiscsKey] boolValue];
}

- (BOOL)saveStatesNotSupportedForSystemIdentifier:(NSString *)systemIdentifier
{
    id options = [self coreOptions];
    id system = [options valueForKey:systemIdentifier];
    return [[system valueForKey:OEGameCoreSaveStatesNotSupportedKey] boolValue];
}

- (BOOL)supportsRewindingForSystemIdentifier:(NSString *)systemIdentifier
{
    id options = [self coreOptions];
    id system = [options valueForKey:systemIdentifier];
    return [[system valueForKey:OEGameCoreSupportsRewindingKey] boolValue];
}

- (BOOL)supportsFileInsertionForSystemIdentifier:(NSString *)systemIdentifier
{
    id options = [self coreOptions];
    id system = [options valueForKey:systemIdentifier];
    return [[system valueForKey:OEGameCoreSupportsFileInsertionKey] boolValue];
}

- (BOOL)supportsDisplayModeChangeForSystemIdentifier:(NSString *)systemIdentifier
{
    id options = [self coreOptions];
    id system = [options valueForKey:systemIdentifier];
    return [[system valueForKey:OEGameCoreSupportsDisplayModeChangeKey] boolValue];
}

- (NSUInteger)rewindIntervalForSystemIdentifier:(NSString *)systemIdentifier
{
    id options = [self coreOptions];
    id system = [options valueForKey:systemIdentifier];
    return [[system valueForKey:OEGameCoreRewindIntervalKey] unsignedIntegerValue];
}

- (NSUInteger)rewindBufferSecondsForSystemIdentifier:(NSString *)systemIdentifier
{
    id options = [self coreOptions];
    id system = [options valueForKey:systemIdentifier];
    return [[system valueForKey:OEGameCoreRewindBufferSecondsKey] unsignedIntegerValue];
    
}

- (void)dealloc
{
    [_gameDocuments makeObjectsPerformSelector:@selector(close)];
}


- (OEGameCore *)newGameCore
{
    return [[[self gameCoreClass] alloc] init];
}

@end
