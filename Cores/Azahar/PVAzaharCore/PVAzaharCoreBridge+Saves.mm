#import "PVAzaharCoreBridge.h"
#import "PVAzaharCoreBridge+Private.h"
#include <memory>
#include <vector>
#include "core/core.h"

static NSString * const PVAzaharErrorDomain = @"org.provenance-emu.PVAzahar";
static const NSTimeInterval PVAzaharStateTimeout = 10.0;

namespace {
/// Result slot shared with the emu-thread job. A timed-out job may still run later, so it must
/// never write to the caller's stack (see runOnEmuThreadAndWait:timeout:).
struct PVAzaharSaveResult {
    std::vector<u8> buffer;   // SaveStateBuffer output
    bool ok = false;          // LoadStateBuffer result
};
}

static NSError *PVAzaharStateError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:PVAzaharErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey: message}];
}

// The base class marks the error: variants deprecated in favour of the completion-handler ones.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
@implementation PVAzaharCoreBridge (Saves)

- (BOOL)saveStateToFileAtPath:(NSString *)path error:(NSError **)error {
    auto result = std::make_shared<PVAzaharSaveResult>();
    const BOOL ran = [self runOnEmuThreadAndWait:[result] {
        result->buffer = Core::System::GetInstance().SaveStateBuffer();
    } timeout:PVAzaharStateTimeout];
    if (!ran || result->buffer.empty()) {
        if (error) { *error = PVAzaharStateError(1, @"Azahar did not produce a save state"); }
        return NO;
    }
    NSData *data = [NSData dataWithBytes:result->buffer.data() length:result->buffer.size()];
    return [data writeToFile:path options:NSDataWritingAtomic error:error];
}

- (BOOL)loadStateFromFileAtPath:(NSString *)path error:(NSError **)error {
    NSData *data = [NSData dataWithContentsOfFile:path options:0 error:error];
    if (!data) { return NO; }
    auto buffer = std::make_shared<std::vector<u8>>((const u8 *)data.bytes, (const u8 *)data.bytes + data.length);
    auto result = std::make_shared<PVAzaharSaveResult>();
    const BOOL ran = [self runOnEmuThreadAndWait:[buffer, result] {
        result->ok = Core::System::GetInstance().LoadStateBuffer(std::move(*buffer));
    } timeout:PVAzaharStateTimeout];
    if (!ran || !result->ok) {
        if (error) { *error = PVAzaharStateError(2, @"Azahar rejected this save state (different core version or title)"); }
        return NO;
    }
    return YES;
}

- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(SaveStateCompletion)block {
    NSString *path = [fileName copy];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *e = nil;
        const BOOL ok = [self saveStateToFileAtPath:path error:&e];
        block(ok ? nil : e);
    });
}

- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(SaveStateCompletion)block {
    NSString *path = [fileName copy];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *e = nil;
        const BOOL ok = [self loadStateFromFileAtPath:path error:&e];
        block(ok ? nil : e);
    });
}

@end
#pragma clang diagnostic pop
