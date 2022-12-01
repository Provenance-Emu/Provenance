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

#import <Foundation/Foundation.h>

extern NSString *const OEAdvancedPreferenceKey;

extern NSString *const OEGameCoreClassKey;
extern NSString *const OEGameCorePlayerCountKey;
extern NSString *const OEGameCoreSystemIdentifiersKey;
/// Boolean key. When set to YES and the current macOS version at least
/// the one specified by the OEGameCoreDeprecatedMinMacOSVersionKey key,
/// a warning message is shown when opening a game with this core.
extern NSString *const OEGameCoreDeprecatedKey;
/// String key. The minimum macOS version required for the deprecation warning
/// to take effect.
extern NSString *const OEGameCoreDeprecatedMinMacOSVersionKey;
/// Dictionary key specifying a suggested replacement core for each system.
/// When the core is automatically removed, these cores will set as the new
/// defaults for each system where the default was the removed core.
extern NSString *const OEGameCoreSuggestedReplacement;
/// The date after which the core will be automatically removed.
/// If the macOS version is lesser than the one specified by
/// OEGameCoreDeprecatedMinMacOSVersionKey, it has no effect.
extern NSString *const OEGameCoreSupportDeadlineKey;
extern NSString *const OEGameCoreOptionsKey;

// sub-keys of OEGameCoreOptionsKey
extern NSString *const OEGameCoreSupportsCheatCodeKey;
extern NSString *const OEGameCoreRequiresFilesKey;
extern NSString *const OEGameCoreRequiredFilesKey;
extern NSString *const OEGameCoreHasGlitchesKey;
extern NSString *const OEGameCoreSupportsMultipleDiscsKey;
extern NSString *const OEGameCoreSaveStatesNotSupportedKey;
extern NSString *const OEGameCoreSupportsRewindingKey;
extern NSString *const OEGameCoreRewindIntervalKey;
extern NSString *const OEGameCoreRewindBufferSecondsKey;
extern NSString *const OEGameCoreSupportsFileInsertionKey;
extern NSString *const OEGameCoreSupportsDisplayModeChangeKey;

@class OEGameCore;

@interface OEGameCoreController : NSObject

- (instancetype)initWithBundle:(NSBundle *)aBundle;

@property(readonly) NSBundle   *bundle;
@property(readonly) Class       gameCoreClass;

@property(readonly) NSString   *pluginName;
@property(readonly) NSArray<NSString *> *systemIdentifiers;
@property(readonly) NSDictionary<NSString *, NSDictionary<NSString *, id> *> *coreOptions;

@property(readonly) NSString   *supportDirectoryPath;
@property(readonly) NSString   *biosDirectoryPath;
@property(readonly) NSUInteger  playerCount;

- (bycopy OEGameCore *)newGameCore;
- (NSArray<NSDictionary<NSString *, id> *> *)requiredFilesForSystemIdentifier:(NSString *)systemIdentifier;
- (BOOL)requiresFilesForSystemIdentifier:(NSString *)systemIdentifier;
- (BOOL)supportsCheatCodeForSystemIdentifier:(NSString *)systemIdentifier;
- (BOOL)hasGlitchesForSystemIdentifier:(NSString *)systemIdentifier;
- (BOOL)saveStatesNotSupportedForSystemIdentifier:(NSString *)systemIdentifier;
- (BOOL)supportsMultipleDiscsForSystemIdentifier:(NSString *)systemIdentifier;
- (BOOL)supportsRewindingForSystemIdentifier:(NSString *)systemIdentifier;
- (BOOL)supportsFileInsertionForSystemIdentifier:(NSString *)systemIdentifier;
- (BOOL)supportsDisplayModeChangeForSystemIdentifier:(NSString *)systemIdentifier;
- (NSUInteger)rewindIntervalForSystemIdentifier:(NSString *)systemIdentifier;
- (NSUInteger)rewindBufferSecondsForSystemIdentifier:(NSString *)systemIdentifier;

@end
