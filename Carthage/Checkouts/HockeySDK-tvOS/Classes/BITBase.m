#import "BITBase.h"

/// Data contract class for type Base.
@implementation BITBase

///
/// Adds all members of this class to a dictionary
/// @return The dictionary with members of this class.
///
- (NSDictionary *)serializeToDictionary {
    NSMutableDictionary *dict = [super serializeToDictionary].mutableCopy;
    if (self.baseType != nil) {
        [dict setObject:self.baseType forKey:@"baseType"];
    }
    return dict;
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)coder {
  self = [super initWithCoder:coder];
  if(self) {
    _baseType = [coder decodeObjectForKey:@"self.baseType"];
  }

  return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
  [super encodeWithCoder:coder];
  [coder encodeObject:self.baseType forKey:@"self.baseType"];
}

@end
