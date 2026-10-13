//
//  PVThinCoreCallGate.m
//  PVCoreBridgeRetro
//
//  See PVThinCoreCallGate.h.
//

#import "PVThinCoreCallGate.h"
#include <pthread.h>
#include <stdatomic.h>

const NSTimeInterval PVThinCoreCallGateWaitForever = -1.0;

@implementation PVThinCoreCallGate {
    NSRecursiveLock *_lock;
    /// The thread holding the gate for teardown. Read and written only while
    /// holding `_lock`.
    pthread_t _teardownOwner;
    BOOL _hasTeardownOwner;
    /// Read without the lock (the fast refusal path), so atomic.
    atomic_bool _tearingDown;
}

- (instancetype)init {
    if ((self = [super init])) {
        _lock = [NSRecursiveLock new];
        _lock.name = @"PVThinCoreCallGate";
        atomic_init(&_tearingDown, false);
    }
    return self;
}

/// Must be called with `_lock` held.
- (BOOL)_callingThreadOwnsTeardown {
    return _hasTeardownOwner && pthread_equal(_teardownOwner, pthread_self()) != 0;
}

- (BOOL)_acquireWithTimeout:(NSTimeInterval)timeout {
    if (timeout < 0) {
        [_lock lock];
        return YES;
    }
    return [_lock lockBeforeDate:[NSDate dateWithTimeIntervalSinceNow:timeout]];
}

- (BOOL)enterWithTimeout:(NSTimeInterval)timeout {
    if (self.tearingDown) {
        // Fast refusal that never waits behind the teardown. Only the owner can
        // get past this: it already holds the (recursive) lock, so its tryLock
        // succeeds. Any other thread either fails the tryLock or, before the
        // owner has the lock, succeeds and is refused by the owner check.
        if (![_lock tryLock]) {
            return NO;
        }
        if ([self _callingThreadOwnsTeardown]) {
            return YES;
        }
        [_lock unlock];
        return NO;
    }
    if (![self _acquireWithTimeout:timeout]) {
        return NO;
    }
    // Teardown may have latched while we waited for the lock.
    if (self.tearingDown && ![self _callingThreadOwnsTeardown]) {
        [_lock unlock];
        return NO;
    }
    return YES;
}

- (void)leave {
    [_lock unlock];
}

- (BOOL)performWithTimeout:(NSTimeInterval)timeout block:(NS_NOESCAPE void (^)(void))block {
    if (![self enterWithTimeout:timeout]) {
        return NO;
    }
    @try {
        block();
    } @finally {
        [self leave];
    }
    return YES;
}

- (void)beginTeardown {
    atomic_store(&_tearingDown, true);
}

- (BOOL)enterForTeardownWithTimeout:(NSTimeInterval)timeout {
    [self beginTeardown];
    if (![self _acquireWithTimeout:timeout]) {
        return NO;
    }
    _teardownOwner = pthread_self();
    _hasTeardownOwner = YES;
    return YES;
}

- (void)leaveTeardown {
    _hasTeardownOwner = NO;
    [_lock unlock];
}

- (void)reopen {
    [_lock lock];
    _hasTeardownOwner = NO;
    atomic_store(&_tearingDown, false);
    [_lock unlock];
}

- (BOOL)isTearingDown {
    return atomic_load(&_tearingDown) ? YES : NO;
}

@end
