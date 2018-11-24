#import <Foundation/NSJSONSerialization.h>
#import <OMGHTTPURLRQ/OMGHTTPURLRQ.h>
#import <Foundation/NSURLResponse.h>
#import <CoreFoundation/CFString.h>
#import <Foundation/NSOperation.h>
#import <Foundation/NSURLError.h>
#import <CoreFoundation/CFURL.h>
#import <Foundation/NSThread.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSError.h>
#import <Foundation/NSURL.h>
#import "PMKOMGHTTPURLRQ.h"

#if !COCOAPODS
#import <PMKFoundation/NSURLSession+AnyPromise.h>
#else
#import "NSURLSession+AnyPromise.h"
#endif

static id PMKURLRequestFromURLFormat(NSError **err, id urlFormat, ...);
static id go(NSURLSession *, NSMutableURLRequest *);


@implementation NSURLSession (PMKOMG)

- (AnyPromise *)GET:(id)urlFormat, ... {
    id err;
    id rq = PMKURLRequestFromURLFormat(&err, urlFormat);
    if (err) return [AnyPromise promiseWithValue:err];
    return go(self, rq);
}

- (AnyPromise *)GET:(NSString *)url query:(NSDictionary *)params {
    id err;
    id rq = [OMGHTTPURLRQ GET:url:params error:&err];
    if (err) return [AnyPromise promiseWithValue:err];
    return go(self, rq);
}

- (AnyPromise *)POST:(NSString *)url formURLEncodedParameters:(NSDictionary *)params {
    id err;
    id rq = [OMGHTTPURLRQ POST:url:params error:&err];
    if (err) return [AnyPromise promiseWithValue:err];
    return go(self, rq);
}

- (AnyPromise *)POST:(NSString *)urlString JSON:(NSDictionary *)params {
    id err;
    id rq = [OMGHTTPURLRQ POST:urlString JSON:params error:&err];
    if (err) return [AnyPromise promiseWithValue:err];
    return go(self, rq);
}

- (AnyPromise *)PUT:(NSString *)url formURLEncodedParameters:(NSDictionary *)params {
    id err;
    id rq = [OMGHTTPURLRQ PUT:url:params error:&err];
    if (err) return [AnyPromise promiseWithValue:err];
    return go(self, rq);

}

- (AnyPromise *)DELETE:(NSString *)url formURLEncodedParameters:(NSDictionary *)params {
    id err;
    id rq = [OMGHTTPURLRQ DELETE:url :params error:&err];
    if (err) return [AnyPromise promiseWithValue:err];
    return go(self, rq);
}

- (AnyPromise *)PATCH:(NSString *)url JSON:(NSDictionary *)params {
    id err;
    id rq = [OMGHTTPURLRQ PATCH:url JSON:params error:&err];
    if (err) return [AnyPromise promiseWithValue:err];
    return go(self, rq);
}

@end


static id PMKURLRequestFromURLFormat(NSError **err, id urlFormat, ...) {
    if ([urlFormat isKindOfClass:[NSString class]]) {
        va_list arguments;
        va_start(arguments, urlFormat);
        urlFormat = [[NSString alloc] initWithFormat:urlFormat arguments:arguments];
        va_end(arguments);
    } else if ([urlFormat isKindOfClass:[NSURL class]]) {
        NSMutableURLRequest *rq = [[NSMutableURLRequest alloc] initWithURL:urlFormat];
        [rq setValue:OMGUserAgent() forHTTPHeaderField:@"User-Agent"];
        return rq;
    } else {
        urlFormat = [urlFormat description];
    }
    return [OMGHTTPURLRQ GET:urlFormat:nil error:err];
}

static id go(NSURLSession *session, NSMutableURLRequest *rq) {
    if ([rq valueForHTTPHeaderField:@"User-Agent"] == nil) {
        [rq setValue:OMGUserAgent() forHTTPHeaderField:@"User-Agent"];
    }
    return [session promiseDataTaskWithRequest:rq];
}
