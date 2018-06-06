#import "BITOrderedDictionary.h"

@implementation BITOrderedDictionary

- (instancetype)init {
  if ((self = [super init])) {
    _dictionary = [NSMutableDictionary new];
    _order = [NSMutableArray new];
  }
  return self;
}

- (instancetype)initWithCapacity:(NSUInteger)numItems {
  self = [super init];
  if ( self != nil )
  {
    _dictionary = [[NSMutableDictionary alloc] initWithCapacity:numItems];
    _order = [NSMutableArray new];
  }
  return self;
}

- (void)setObject:(id)anObject forKey:(id<NSCopying>)aKey {
  if(!self.dictionary[aKey]) {
    [self.order addObject:aKey];
  }
  self.dictionary[aKey] = anObject;
}

- (NSEnumerator *)keyEnumerator {
  return [self.order objectEnumerator];
}

- (id)objectForKey:(id)key {
  return self.dictionary[key];
}

- (NSUInteger)count {
  return [self.dictionary count];
}

@end
