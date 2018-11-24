#import "MKDirections+AnyPromise.h"


@implementation MKDirections (PromiseKit)

- (AnyPromise *)calculateDirections {
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve) {
        [self calculateDirectionsWithCompletionHandler:^(id rsp, id err){
            resolve(err ?: rsp);
        }];
    }];
}

- (AnyPromise *)calculateETA {
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve) {
        [self calculateETAWithCompletionHandler:^(id rsp, id err){
            resolve(err ?: rsp);
        }];
    }];
}

@end
