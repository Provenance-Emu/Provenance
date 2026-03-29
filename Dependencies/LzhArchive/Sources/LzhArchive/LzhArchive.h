#ifndef _LZHARCH_H
#define _LZHARCH_H
#import <Foundation/Foundation.h>

#include "utf8.h"
NS_ASSUME_NONNULL_BEGIN

@interface LzhArchive : NSObject
+ (BOOL)unLzhFileAtPath:(NSString *)path toDestination:(NSString *)destination overwrite:(BOOL)overwrite;
@end
NS_ASSUME_NONNULL_END

#endif /* _LZHARCH_H */
