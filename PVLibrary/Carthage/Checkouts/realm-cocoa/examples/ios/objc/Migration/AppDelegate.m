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
#import "DataModels.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];

    // copy over old data files for migration
    NSURL *defaultRealmURL = [RLMRealmConfiguration defaultConfiguration].fileURL;
    NSURL *defaultRealmParentURL = [defaultRealmURL URLByDeletingLastPathComponent];
    NSURL *v0URL = [[NSBundle mainBundle] URLForResource:@"default-v0" withExtension:@"realm"];
    [[NSFileManager defaultManager] removeItemAtURL:defaultRealmURL error:nil];
    [[NSFileManager defaultManager] copyItemAtURL:v0URL toURL:defaultRealmURL error:nil];

    // trying to open an outdated realm file without first registering a new schema version and migration block
    // with throw
    @try {
        [RLMRealm defaultRealm];
    }
    @catch (NSException *exception) {
        NSLog(@"Trying to open an outdated realm a migration block threw an exception.");
    }

    // define a migration block
    // you can define this inline, but we will reuse this to migrate realm files from multiple versions
    // to the most current version of our data model
    RLMMigrationBlock migrationBlock = ^(RLMMigration *migration, uint64_t oldSchemaVersion) {
        if (oldSchemaVersion < 1) {
            [migration enumerateObjects:Person.className block:^(RLMObject *oldObject, RLMObject *newObject) {
                if (oldSchemaVersion < 1) {
                    // combine name fields into a single field
                    newObject[@"fullName"] = [NSString stringWithFormat:@"%@ %@", oldObject[@"firstName"], oldObject[@"lastName"]];
                }
            }];
        }
        if (oldSchemaVersion < 2) {
            [migration enumerateObjects:Person.className block:^(RLMObject *oldObject, RLMObject *newObject) {
                // give JP a dog
                if ([newObject[@"fullName"] isEqualToString:@"JP McDonald"]) {
                    Pet *jpsDog = [[Pet alloc] initWithValue:@[@"Jimbo", @(AnimalTypeDog)]];
                    [newObject[@"pets"] addObject:jpsDog];
                }
            }];
        }
        if (oldSchemaVersion < 3) {
            [migration enumerateObjects:Pet.className block:^(RLMObject *oldObject, RLMObject *newObject) {
                // convert type string to type enum if we have outdated Pet object
                if (oldObject && oldObject.objectSchema[@"type"].type == RLMPropertyTypeString) {
                    newObject[@"type"] = @([Pet animalTypeForString:oldObject[@"type"]]);
                }
            }];
        }
        NSLog(@"Migration complete.");
    };

    RLMRealmConfiguration *configuration = [RLMRealmConfiguration defaultConfiguration];

    // set the schema verion and migration block for the defualt realm
    configuration.schemaVersion = 3;
    configuration.migrationBlock = migrationBlock;

    [RLMRealmConfiguration setDefaultConfiguration:configuration];

    // now that we have set a schema version and migration block for the configuration,
    // performing the migration and opening the Realm will succeed
    [RLMRealm defaultRealm];

    // print out all migrated objects in the default realm
    NSLog(@"Migrated objects in the default Realm: %@", [[Person allObjects] description]);

    //
    // Migrate other Realm versions
    //
    NSURL *v1URL = [[NSBundle mainBundle] URLForResource:@"default-v1" withExtension:@"realm"];
    NSURL *v2URL = [[NSBundle mainBundle] URLForResource:@"default-v2" withExtension:@"realm"];
    NSURL *realmv1URL = [defaultRealmParentURL URLByAppendingPathComponent:@"default-v1.realm"];
    NSURL *realmv2URL = [defaultRealmParentURL URLByAppendingPathComponent:@"default-v2.realm"];
    [[NSFileManager defaultManager] removeItemAtURL:realmv1URL error:nil];
    [[NSFileManager defaultManager] copyItemAtURL:v1URL toURL:realmv1URL error:nil];
    [[NSFileManager defaultManager] removeItemAtURL:realmv2URL error:nil];
    [[NSFileManager defaultManager] copyItemAtURL:v2URL toURL:realmv2URL error:nil];

    // set schemave versions and migration blocks form Realms at each path
    RLMRealmConfiguration *realmv1Configuration = [configuration copy];
    realmv1Configuration.fileURL = realmv1URL;

    RLMRealmConfiguration *realmv2Configuration = [configuration copy];
    realmv2Configuration.fileURL = realmv2URL;

    // manully migration v1Path, v2Path is migrated implicitly on access
    [RLMRealm performMigrationForConfiguration:realmv1Configuration error:nil];

    // print out all migrated objects in the migrated realms
    RLMRealm *realmv1 = [RLMRealm realmWithConfiguration:realmv1Configuration error:nil];
    NSLog(@"Migrated objects in the Realm migrated from v1: %@", [[Person allObjectsInRealm:realmv1] description]);
    RLMRealm *realmv2 = [RLMRealm realmWithConfiguration:realmv2Configuration error:nil];
    NSLog(@"Migrated objects in the Realm migrated from v2: %@", [[Person allObjectsInRealm:realmv2] description]);

    return YES;
}

@end
