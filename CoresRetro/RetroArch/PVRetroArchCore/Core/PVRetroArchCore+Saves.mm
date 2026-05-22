//
//  PVRetroArch+Saves.m
//  PVRetroArch
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import "PVRetroArchCoreBridge+Saves.h"
#include "content.h"
#include "core_info.h"
#include "core.h"

@import PVCoreBridge;
#import <PVCoreObjCBridge/PVCoreObjCBridge.h>

extern bool _isInitialized;
bool firstLoad = true;
NSString *autoLoadStatefileName;
@implementation PVRetroArchCoreBridge (Saves)
#pragma mark - Properties
-(BOOL)supportsSaveStates {
    BOOL supportsSaveStates = core_info_current_supports_savestate();
    DLOG(@"%@ supportsSaveStates: %@", self.coreIdentifier, supportsSaveStates ? @"Yes" : @"No");
    return supportsSaveStates;
}
#pragma mark - Methods

- (BOOL)saveStateToFileAtPath:(NSString *)fileName error:(NSError **)error {
	ILOG(@"[SAVE-DIAG] saveStateToFileAtPath ENTER core=%@ path=%@ isInitialized=%d",
	     self.coreIdentifier, fileName, _isInitialized);

	if (!_isInitialized) {
		ELOG(@"[SAVE-DIAG] FAIL: core not initialized");
		if (error) {
			NSDictionary *userInfo = @{
				NSLocalizedDescriptionKey: @"Failed to save state.",
				NSLocalizedFailureReasonErrorKey: @"Core is not initialized.",
				NSLocalizedRecoverySuggestionErrorKey: @"Wait for the core to finish loading before saving."
			};
			*error = [NSError errorWithDomain:CoreError.PVEmulatorCoreErrorDomain
										  code:PVEmulatorCoreErrorCodeCouldNotSaveState
									  userInfo:userInfo];
		}
		return NO;
	}

	if (!core_info_current_supports_savestate()) {
		ELOG(@"[SAVE-DIAG] FAIL: core_info_current_supports_savestate() == false for %@", self.coreIdentifier);
		if (error) {
			NSDictionary *userInfo = @{
				NSLocalizedDescriptionKey: @"Failed to save state.",
				NSLocalizedFailureReasonErrorKey: @"This core does not support save states.",
				NSLocalizedRecoverySuggestionErrorKey: @""
			};
			*error = [NSError errorWithDomain:CoreError.PVEmulatorCoreErrorDomain
										  code:PVEmulatorCoreErrorCodeDoesNotSupportSaveStates
									  userInfo:userInfo];
		}
		return NO;
	}

	// Log serialize size up front — Mupen64Plus-Next has historically reported
	// 0 mid-frame or before the first retro_run() landed; that path makes
	// content_save_state() bail with no file written. The .jpg thumbnail
	// Provenance writes BEFORE this call remains as a ghost.
	size_t serSize = core_serialize_size();
	ILOG(@"[SAVE-DIAG] core_serialize_size() = %zu bytes", serSize);
	if (serSize == 0) {
		ELOG(@"[SAVE-DIAG] FAIL: core_serialize_size() returned 0 — save state binary cannot be written");
	}

	// Verify destination directory exists before asking RA to write. RA's
	// task_save_handler silently bails inside intfstream_open_file() when
	// the parent directory is missing — no error logged on the RA side.
	NSString *parentDir = [fileName stringByDeletingLastPathComponent];
	BOOL parentIsDir = NO;
	BOOL parentExists = [[NSFileManager defaultManager] fileExistsAtPath:parentDir isDirectory:&parentIsDir];
	ILOG(@"[SAVE-DIAG] parent dir=%@ exists=%d isDir=%d", parentDir, parentExists, parentIsDir);
	if (!parentExists || !parentIsDir) {
		WLOG(@"[SAVE-DIAG] parent dir missing — creating %@", parentDir);
		NSError *mkdirErr = nil;
		if (![[NSFileManager defaultManager] createDirectoryAtPath:parentDir
		                              withIntermediateDirectories:YES
		                                               attributes:nil
		                                                    error:&mkdirErr]) {
			ELOG(@"[SAVE-DIAG] FAIL: createDirectory failed: %@", mkdirErr.localizedDescription);
		}
	}

	bool queued = content_save_state(fileName.UTF8String, true);
	ILOG(@"[SAVE-DIAG] content_save_state queued=%d", queued);
	if (!queued) {
		ELOG(@"[SAVE-DIAG] FAIL: content_save_state returned false — task could not be queued (another blocking task active, or serialize_size==0)");
		if (error) {
			NSDictionary *userInfo = @{
				NSLocalizedDescriptionKey: @"Failed to save state.",
				NSLocalizedFailureReasonErrorKey: @"Failed to queue save state task.",
				NSLocalizedRecoverySuggestionErrorKey: @""
			};
			*error = [NSError errorWithDomain:CoreError.PVEmulatorCoreErrorDomain
										  code:PVEmulatorCoreErrorCodeCouldNotSaveState
									  userInfo:userInfo];
		}
		return NO;
	}

	content_wait_for_save_state_task();

	if (![[NSFileManager defaultManager] fileExistsAtPath:fileName]) {
		ELOG(@"[SAVE-DIAG] FAIL: file not present after content_wait_for_save_state_task — RA's task_save_handler silently dropped the write. Check upstream RA logs for [State] messages.");
		// Surface what IS in the parent dir so a stale ghost / wrong path is obvious from logs.
		NSArray<NSString *> *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:parentDir error:nil];
		ILOG(@"[SAVE-DIAG] parent dir contents at failure: %@", dirContents);
		if (error) {
			NSDictionary *userInfo = @{
				NSLocalizedDescriptionKey: @"Failed to save state.",
				NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"Save state file was not created at path: %@", fileName],
				NSLocalizedRecoverySuggestionErrorKey: @"Check file permissions and available disk space."
			};
			*error = [NSError errorWithDomain:CoreError.PVEmulatorCoreErrorDomain
										  code:PVEmulatorCoreErrorCodeCouldNotSaveState
									  userInfo:userInfo];
		}
		return NO;
	}

	// Confirm the file actually contains the expected payload (non-zero, roughly
	// matches serialize_size). A zero-byte .svs would still pass the existence
	// check but be useless to load — log loudly so we catch that case too.
	NSError *attrErr = nil;
	NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:fileName error:&attrErr];
	uint64_t fileSize = [attrs[NSFileSize] unsignedLongLongValue];
	ILOG(@"[SAVE-DIAG] SUCCESS: wrote %llu bytes to %@ (serialize_size was %zu)", fileSize, fileName, serSize);
	if (fileSize == 0) {
		WLOG(@"[SAVE-DIAG] WARNING: 0-byte save state written — load will fail");
	}

	return YES;
}

- (BOOL)saveStateToFileAtPath:(NSString *)fileName {
	NSError *error = nil;
	return [self saveStateToFileAtPath:fileName error:&error];
}

- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void (^)(NSError *))block {
	/// RetroArch's save/load pipeline calls into the core from the same context as the UI runloop; waiting on a global queue led to `core_serialize_size` / task-queue crashes during load (nested RAM backup save).
	dispatch_async(dispatch_get_main_queue(), ^{
		NSError *error = nil;
		BOOL success = [self saveStateToFileAtPath:fileName error:&error];
		block(success ? nil : error);
	});
}

- (BOOL)loadStateFromFileAtPath:(NSString *)fileName error:(NSError **)error {
	if (!_isInitialized) {
		autoLoadStatefileName = fileName;
		[NSThread detachNewThreadSelector:@selector(autoloadWaitThread) toTarget:self withObject:nil];
		if (error) {
			NSDictionary *userInfo = @{
				NSLocalizedDescriptionKey: @"Loading state queued.",
				NSLocalizedFailureReasonErrorKey: @"Core is not initialized, state will load after initialization.",
				NSLocalizedRecoverySuggestionErrorKey: @""
			};
			*error = nil;
		}
		return YES;
	}

	if (!core_info_current_supports_savestate()) {
		if (error) {
			NSDictionary *userInfo = @{
				NSLocalizedDescriptionKey: @"Failed to load state.",
				NSLocalizedFailureReasonErrorKey: @"This core does not support save states.",
				NSLocalizedRecoverySuggestionErrorKey: @""
			};
			*error = [NSError errorWithDomain:CoreError.PVEmulatorCoreErrorDomain
										  code:PVEmulatorCoreErrorCodeDoesNotSupportSaveStates
									  userInfo:userInfo];
		}
		return NO;
	}

	if (![[NSFileManager defaultManager] fileExistsAtPath:fileName]) {
		if (error) {
			NSDictionary *userInfo = @{
				NSLocalizedDescriptionKey: @"Failed to load state.",
				NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"Save state file not found at path: %@", fileName],
				NSLocalizedRecoverySuggestionErrorKey: @"Make sure the save state file exists."
			};
			*error = [NSError errorWithDomain:CoreError.PVEmulatorCoreErrorDomain
										  code:PVEmulatorCoreErrorCodeCouldNotLoadState
									  userInfo:userInfo];
		}
		return NO;
	}

	// fbalpha2012 (and some other arcade cores) serialize absolute Z80 cpu_readmap
	// pointer values that become stale on the next run. Calling core_reset() first
	// reinitializes the memory-bank pointer tables so that retro_unserialize() only
	// needs to restore data (registers, RAM) without corrupting the maps.
	// Without this, ZetReadOpArg crashes with EXC_BAD_ACCESS on the first retro_run()
	// after a state load.
	BOOL needsPreReset = [self.coreIdentifier containsString:@"fbalpha"] ||
	                     [self.coreIdentifier containsString:@"fbneo"] ||
	                     [self.coreIdentifier containsString:@"mame"];
	if (needsPreReset) {
		DLOG(@"Saves: calling core_reset() before state load to reinitialize memory maps (%@)", self.coreIdentifier);
		core_reset();
	}

	bool queued = NO;
	if (firstLoad && [self.coreIdentifier containsString:@"opera"]) {
		autoLoadStatefileName = fileName;
		queued = content_load_state(autoLoadStatefileName.UTF8String, true, true);
		[NSThread detachNewThreadSelector:@selector(autoloadWaitThread) toTarget:self withObject:nil];
	} else {
		queued = content_load_state(fileName.UTF8String, false, true);
	}

	if (!queued) {
		if (error) {
			NSDictionary *userInfo = @{
				NSLocalizedDescriptionKey: @"Failed to load state.",
				NSLocalizedFailureReasonErrorKey: @"Failed to queue load state task.",
				NSLocalizedRecoverySuggestionErrorKey: @""
			};
			*error = [NSError errorWithDomain:CoreError.PVEmulatorCoreErrorDomain
										  code:PVEmulatorCoreErrorCodeCouldNotLoadState
									  userInfo:userInfo];
		}
		return NO;
	}

	content_wait_for_load_state_task();

	return YES;
}

- (BOOL)loadStateFromFileAtPath:(NSString *)fileName {
	NSError *error = nil;
	return [self loadStateFromFileAtPath:fileName error:&error];
}

#define LOAD_WAIT_INTERVAL 1
- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(NSError *))block {
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		ILOG(@"Loading State: Loading...\n");
		while (!_isInitialized) {
			sleep(LOAD_WAIT_INTERVAL);
		}

		dispatch_async(dispatch_get_main_queue(), ^{
			NSError *error = nil;
			BOOL success = [self loadStateFromFileAtPath:fileName error:&error];
			block(success ? nil : error);
		});
	});
}

// Opera needs around 15 second lead time to fill memory the 1st time it loads
#define OPERA_START_WAIT_TIME 15
#define START_WAIT_TIME 1
- (void)autoloadWaitThread
{
	@autoreleasepool
	{
		//Wait here until we get the signal for full initialization
        ILOG(@"Loading State: Waiting while loading\n");
        if([self.coreIdentifier containsString:@"opera"]) {
            sleep(OPERA_START_WAIT_TIME);
        } else {
            sleep(START_WAIT_TIME);
        }
        if (self.isRunning) {
            ILOG(@"Loading State: Waited while loading\n");
            dispatch_sync(dispatch_get_main_queue(), ^{
                if (content_load_state(autoLoadStatefileName.UTF8String, false, true)) {
                    content_wait_for_load_state_task();
                }
                firstLoad = false;
            });
        }
	}
}

@end
