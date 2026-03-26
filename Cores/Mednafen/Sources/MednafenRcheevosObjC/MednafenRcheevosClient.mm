//
//  MednafenRcheevosClient.mm
//  MednafenRcheevosObjC
//
//  Objective-C++ implementation of the Mednafen rc_client bridge.
//
//  ## Architecture
//
//  rc_client requires two C callbacks supplied at creation time:
//
//    read_memory   — called synchronously by rcheevos to read emulator RAM;
//                    implemented here by looking up the address in the registered
//                    MednafenRcheevosRegion array.
//
//    server_call   — called to make HTTP requests to the RA server; implemented
//                    here with NSURLSession.  The callback may be invoked from a
//                    URLSession worker thread — rc_client's internal locking
//                    ensures this is safe.
//
//  C function pointers cannot capture ObjC context directly.  We use the
//  userdata slot (rc_client_set_userdata / rc_client_get_userdata) to bridge
//  back to `self`.  The same trick is used for per-call callbacks: an ObjC block
//  is transferred as a retained void* via __bridge_retained / __bridge_transfer
//  and released inside the C trampoline once the callback fires.
//

#import "include/MednafenRcheevosObjC.h"

#include <rc_client.h>
#include <stdint.h>
#include <string.h>

// ---------------------------------------------------------------------------
// MARK: - C trampolines
// ---------------------------------------------------------------------------

/// Read bytes from the emulated memory map at the given rcheevos address.
static uint32_t mdfn_read_memory_cb(uint32_t address, uint8_t *buffer,
                                    uint32_t numBytes, rc_client_t *client) {
    MednafenRcheevosClient *self =
        (__bridge MednafenRcheevosClient *)rc_client_get_userdata(client);
    return [self _readAddress:address intoBuffer:buffer numBytes:numBytes];
}

/// Make an HTTP request to the RA server on behalf of rc_client.
static void mdfn_server_call_cb(const rc_api_request_t *request,
                                rc_client_server_callback_t callback,
                                void *callbackData,
                                rc_client_t *client) {
    MednafenRcheevosClient *self =
        (__bridge MednafenRcheevosClient *)rc_client_get_userdata(client);
    [self _performServerRequest:request callback:callback callbackData:callbackData];
}

/// Forward rc_client events to the ObjC delegate.
static void mdfn_event_handler_cb(const rc_client_event_t *event,
                                  rc_client_t *client) {
    MednafenRcheevosClient *self =
        (__bridge MednafenRcheevosClient *)rc_client_get_userdata(client);
    [self _handleEvent:event];
}

// Trampoline for rc_client_begin_login_with_token / rc_client_begin_load_game.
// userdata is a retained Block<void(int, const char*)>.
typedef void (^RcCallbackBlock)(int result, const char *errorMessage);

static void rc_callback_trampoline(int result, const char *errorMessage,
                                   rc_client_t *client, void *userdata) {
    RcCallbackBlock block =
        (__bridge_transfer RcCallbackBlock)userdata;  // releases retained block
    if (block) block(result, errorMessage);
}

// ---------------------------------------------------------------------------
// MARK: - Private interface
// ---------------------------------------------------------------------------

static const NSUInteger kMaxRegions = 8;

@interface MednafenRcheevosClient () {
    rc_client_t *_client;
    MednafenRcheevosRegion _regions[kMaxRegions];
    NSUInteger _regionCount;
    BOOL _isGameLoaded;
}
@end

// ---------------------------------------------------------------------------
// MARK: - Implementation
// ---------------------------------------------------------------------------

@implementation MednafenRcheevosClient

- (instancetype)init {
    self = [super init];
    if (!self) return nil;

    _client = rc_client_create(mdfn_read_memory_cb, mdfn_server_call_cb);
    if (!_client) return nil;

    rc_client_set_userdata(_client, (__bridge void *)self);
    rc_client_set_event_handler(_client, mdfn_event_handler_cb);
    _regionCount = 0;
    _isGameLoaded = NO;
    return self;
}

- (void)dealloc {
    if (_client) {
        rc_client_destroy(_client);
        _client = NULL;
    }
}

- (BOOL)isGameLoaded { return _isGameLoaded; }

// ---------------------------------------------------------------------------
// MARK: - Memory regions
// ---------------------------------------------------------------------------

- (void)setRegions:(const MednafenRcheevosRegion *)regions count:(NSUInteger)count {
    NSUInteger n = MIN(count, kMaxRegions);
    for (NSUInteger i = 0; i < n; i++) {
        _regions[i] = regions[i];
    }
    _regionCount = n;
}

- (uint32_t)_readAddress:(uint32_t)address
              intoBuffer:(uint8_t *)buffer
               numBytes:(uint32_t)numBytes {
    for (NSUInteger i = 0; i < _regionCount; i++) {
        const MednafenRcheevosRegion *r = &_regions[i];
        if (address >= r->rcAddress && address < r->rcAddress + r->size) {
            uint32_t offset   = address - r->rcAddress;
            uint32_t readable = numBytes < (r->size - offset) ? numBytes : (r->size - offset);

            if (r->byteSwapMode == MednafenRcheevosByteSwapModeWord16) {
                // Saturn Work RAM: Mednafen stores uint16 values big-endian on
                // little-endian hosts.  Logical byte at position k lives at
                // physical position k^1 (swap within each 16-bit word).
                // Example: uint16 value 0xABCD is stored as [0xCD, 0xAB] in host
                // memory; rcheevos expects [0xAB, 0xCD] (big-endian / Saturn order).
                for (uint32_t j = 0; j < readable; j++) {
                    buffer[j] = r->ptr[(offset + j) ^ 1u];
                }
            } else {
                memcpy(buffer, r->ptr + offset, readable);
            }
            return readable;
        }
    }
    return 0; // address not in any registered region
}

// ---------------------------------------------------------------------------
// MARK: - Server requests
// ---------------------------------------------------------------------------

- (void)_performServerRequest:(const rc_api_request_t *)request
                     callback:(rc_client_server_callback_t)callback
                 callbackData:(void *)callbackData {
    if (!request->url) {
        rc_api_server_response_t empty = {};
        empty.http_status_code = 0;
        callback(&empty, callbackData);
        return;
    }

    NSString *urlString = [NSString stringWithUTF8String:request->url];
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        rc_api_server_response_t empty = {};
        empty.http_status_code = 400;
        callback(&empty, callbackData);
        return;
    }

    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
    urlRequest.timeoutInterval = 30.0;

    const char *postData = request->post_data;
    if (postData && strlen(postData) > 0) {
        urlRequest.HTTPMethod = @"POST";
        urlRequest.HTTPBody = [NSData dataWithBytes:postData length:strlen(postData)];
        [urlRequest setValue:@"application/x-www-form-urlencoded"
          forHTTPHeaderField:@"Content-Type"];
    } else {
        urlRequest.HTTPMethod = @"GET";
    }
    [urlRequest setValue:@"Provenance/PVRcheevos" forHTTPHeaderField:@"User-Agent"];

    [[NSURLSession sharedSession]
        dataTaskWithRequest:urlRequest
          completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
              rc_api_server_response_t serverResponse = {};
              if (data && !error) {
                  // rc_api_server_response_t.body must remain valid until the callback returns.
                  // dataTaskWithRequest completion holds `data` alive across this scope.
                  serverResponse.body = (const char *)data.bytes;
                  serverResponse.body_length = (uint32_t)data.length;
                  serverResponse.http_status_code =
                      (int)[(NSHTTPURLResponse *)response statusCode];
              } else {
                  serverResponse.http_status_code = 0;
              }
              callback(&serverResponse, callbackData);
          }] resume];
}

// ---------------------------------------------------------------------------
// MARK: - Game lifecycle
// ---------------------------------------------------------------------------

- (void)loginAndLoadGame:(NSString *)md5Hash
              completion:(void (^)(BOOL success, NSString *_Nullable errorMessage))completion {
    NSParameterAssert(md5Hash);

    // Load stored RA credentials.  Keys match PVCheevos RetroCredentialsManager.
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *username = [defaults stringForKey:@"ra_username"];
    NSString *token    = [defaults stringForKey:@"ra_session_token"];

    if (!username.length || !token.length) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, @"No RetroAchievements credentials. Log in via Settings > RetroAchievements.");
            });
        }
        return;
    }

    NSString *hash = [md5Hash copy];
    __weak typeof(self) weakSelf = self;
    // Capture the client pointer directly so callbacks work even if self is mid-dealloc.
    rc_client_t *rawClient = _client;

    // Helper block that loads the game once we are authenticated.
    // Completion is always invoked, regardless of whether self is still alive.
    RcCallbackBlock loadBlock = ^(int result2, const char *errMsg2) {
        if (result2 == RC_OK) {
            __strong typeof(weakSelf) s = weakSelf;
            if (s) s->_isGameLoaded = YES;
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{ completion(YES, nil); });
            }
        } else {
            NSString *msg2 = errMsg2
                ? [NSString stringWithUTF8String:errMsg2]
                : @"RetroAchievements game load failed.";
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, msg2); });
            }
        }
    };

    // If already authenticated (e.g. loading a second game in the same session)
    // skip the login round-trip and go straight to loading the game.
    if (rc_client_get_user_info(rawClient) != NULL) {
        rc_client_begin_load_game(
            rawClient,
            hash.UTF8String,
            rc_callback_trampoline,
            (__bridge_retained void *)loadBlock);
        return;
    }

    const char *cUsername = username.UTF8String;
    const char *cToken    = token.UTF8String;

    // Step 1: Login.
    RcCallbackBlock loginBlock = ^(int result, const char *errMsg) {
        if (result != RC_OK) {
            NSString *msg = errMsg
                ? [NSString stringWithUTF8String:errMsg]
                : @"RetroAchievements login failed.";
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, msg); });
            }
            return;
        }

        // Step 2: Load game.
        rc_client_begin_load_game(
            rawClient,
            hash.UTF8String,
            rc_callback_trampoline,
            (__bridge_retained void *)loadBlock);
    };

    rc_client_begin_login_with_token(
        _client,
        cUsername, cToken,
        rc_callback_trampoline,
        (__bridge_retained void *)loginBlock);
}

- (void)unloadGame {
    if (_client) {
        rc_client_unload_game(_client);
    }
    _isGameLoaded = NO;
}

- (void)doFrame {
    if (_client && _isGameLoaded) {
        rc_client_do_frame(_client);
    }
}

// ---------------------------------------------------------------------------
// MARK: - Event dispatch
// ---------------------------------------------------------------------------

- (void)_handleEvent:(const rc_client_event_t *)event {
    id<MednafenRcheevosDelegate> delegate = self.delegate;
    if (!delegate) return;

    switch (event->type) {

        case RC_CLIENT_EVENT_ACHIEVEMENT_TRIGGERED: {
            if (!event->achievement) break;
            const rc_client_achievement_t *ach = event->achievement;
            uint32_t achID     = ach->id;
            uint32_t pts       = ach->points;
            NSString *title    = ach->title ? @(ach->title) : @"";
            NSString *desc     = ach->description ? @(ach->description) : @"";
            BOOL hardcore      = rc_client_get_hardcore_enabled(_client) != 0;
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([delegate respondsToSelector:@selector(rcheevosDidUnlockAchievementID:title:description:points:isHardcore:)]) {
                    [delegate rcheevosDidUnlockAchievementID:achID
                                                       title:title
                                                 description:desc
                                                      points:pts
                                                  isHardcore:hardcore];
                }
            });
            break;
        }

        case RC_CLIENT_EVENT_ACHIEVEMENT_PROGRESS_INDICATOR_SHOW: {
            if (!event->achievement) break;
            const rc_client_achievement_t *ach = event->achievement;
            uint32_t achID     = ach->id;
            NSString *title    = ach->title ? @(ach->title) : @"";
            NSString *progress = ach->measured_progress ? @(ach->measured_progress) : @"";
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([delegate respondsToSelector:@selector(rcheevosShowProgressForAchievementID:title:progressText:)]) {
                    [delegate rcheevosShowProgressForAchievementID:achID
                                                             title:title
                                                      progressText:progress];
                }
            });
            break;
        }

        case RC_CLIENT_EVENT_ACHIEVEMENT_CHALLENGE_INDICATOR_SHOW: {
            if (!event->achievement) break;
            uint32_t achID = event->achievement->id;
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([delegate respondsToSelector:@selector(rcheevosShowChallengeForAchievementID:)]) {
                    [delegate rcheevosShowChallengeForAchievementID:achID];
                }
            });
            break;
        }

        case RC_CLIENT_EVENT_ACHIEVEMENT_CHALLENGE_INDICATOR_HIDE: {
            if (!event->achievement) break;
            uint32_t achID = event->achievement->id;
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([delegate respondsToSelector:@selector(rcheevosHideChallengeForAchievementID:)]) {
                    [delegate rcheevosHideChallengeForAchievementID:achID];
                }
            });
            break;
        }

        case RC_CLIENT_EVENT_LEADERBOARD_STARTED: {
            if (!event->leaderboard) break;
            const rc_client_leaderboard_t *lb = event->leaderboard;
            uint32_t lbID     = lb->id;
            NSString *title   = lb->title ? @(lb->title) : @"";
            NSString *desc    = lb->description ? @(lb->description) : @"";
            NSString *score   = lb->tracker_value ? @(lb->tracker_value) : @"";
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([delegate respondsToSelector:@selector(rcheevosLeaderboardStartedWithID:title:description:scoreText:)]) {
                    [delegate rcheevosLeaderboardStartedWithID:lbID
                                                         title:title
                                                   description:desc
                                                     scoreText:score];
                }
            });
            break;
        }

        case RC_CLIENT_EVENT_LEADERBOARD_FAILED: {
            if (!event->leaderboard) break;
            uint32_t lbID = event->leaderboard->id;
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([delegate respondsToSelector:@selector(rcheevosLeaderboardFailedWithID:)]) {
                    [delegate rcheevosLeaderboardFailedWithID:lbID];
                }
            });
            break;
        }

        case RC_CLIENT_EVENT_LEADERBOARD_SUBMITTED: {
            if (!event->leaderboard) break;
            const rc_client_leaderboard_t *lb = event->leaderboard;
            uint32_t lbID     = lb->id;
            NSString *title   = lb->title ? @(lb->title) : @"";
            NSString *desc    = lb->description ? @(lb->description) : @"";
            NSString *score   = lb->tracker_value ? @(lb->tracker_value) : @"";
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([delegate respondsToSelector:@selector(rcheevosLeaderboardSubmittedWithID:title:description:scoreText:)]) {
                    [delegate rcheevosLeaderboardSubmittedWithID:lbID
                                                           title:title
                                                     description:desc
                                                       scoreText:score];
                }
            });
            break;
        }

        default:
            break;
    }
}

@end
