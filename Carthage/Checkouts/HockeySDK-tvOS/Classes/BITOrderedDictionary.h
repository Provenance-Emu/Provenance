#import <Foundation/Foundation.h>
#import "HockeySDKNullability.h"

NS_ASSUME_NONNULL_BEGIN
@interface BITOrderedDictionary : NSMutableDictionary
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Woverriding-method-mismatch"
  @property (nonatomic, strong) NSMutableDictionary *dictionary;
#pragma clang diagnostic pop
  @property (nonatomic, strong) NSMutableArray *order;

- (instancetype)initWithCapacity:(NSUInteger)numItems;
- (void)setObject:(id)anObject forKey:(id<NSCopying>)aKey;

@end
NS_ASSUME_NONNULL_END
