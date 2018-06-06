#import <Foundation/Foundation.h>

@interface BITAppVersionMetaInfo : NSObject {
}
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *version;
@property (nonatomic, copy) NSString *shortVersion;
@property (nonatomic, copy) NSString *minOSVersion;
@property (nonatomic, copy) NSString *notes;
@property (nonatomic, copy) NSDate *date;
@property (nonatomic, copy) NSNumber *size;
@property (nonatomic, copy) NSNumber *mandatory;
@property (nonatomic, copy) NSNumber *versionID;
@property (nonatomic, copy) NSDictionary *uuids;

- (NSString *)nameAndVersionString;
- (NSString *)versionString;
- (NSString *)dateString;
- (NSString *)sizeInMB;
- (NSString *)notesOrEmptyString;
- (void)setDateWithTimestamp:(NSTimeInterval)timestamp;
- (BOOL)isValid;
- (BOOL)hasUUID:(NSString *)uuid;
- (BOOL)isEqualToAppVersionMetaInfo:(BITAppVersionMetaInfo *)anAppVersionMetaInfo;

+ (BITAppVersionMetaInfo *)appVersionMetaInfoFromDict:(NSDictionary *)dict;

@end
