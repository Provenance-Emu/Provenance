////////////////////////////////////////////////////////////////////////////
//
// Copyright 2014 Realm Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////

#import "AppDelegate.h"
#import <Realm/Realm.h>

// Define your models
@interface Dog : RLMObject
@property NSString *name;
@property NSInteger age;
@property (readonly) RLMLinkingObjects *owners;
@end
RLM_ARRAY_TYPE(Dog)

@interface Person : RLMObject
@property NSString      *name;
@property RLMArray<Dog> *dogs;
@end

@implementation Person
@end

@implementation Dog
+ (NSDictionary *)linkingObjectsProperties
{
    // Define "owners" as the inverse relationship to Person.dogs
    return @{ @"owners": [RLMPropertyDescriptor descriptorWithClass:Person.class propertyName:@"dogs"] };
}
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];

    [[NSFileManager defaultManager] removeItemAtURL:[RLMRealmConfiguration defaultConfiguration].fileURL error:nil];

    RLMRealm *realm = [RLMRealm defaultRealm];
    [realm transactionWithBlock:^{
        [Person createInRealm:realm withValue:@[@"John", @[@[@"Fido", @1]]]];
        [Person createInRealm:realm withValue:@[@"Mary", @[@[@"Rex", @2]]]];
    }];

    // Log all dogs and their owners using the "owners" inverse relationship
    RLMResults *allDogs = [Dog allObjects];
    for (Dog *dog in allDogs) {
        NSArray *ownerNames = [dog.owners valueForKeyPath:@"name"];
        NSLog(@"%@ has %lu owners (%@)", dog.name, (unsigned long)ownerNames.count, ownerNames);
    }
    return YES;
}

@end
