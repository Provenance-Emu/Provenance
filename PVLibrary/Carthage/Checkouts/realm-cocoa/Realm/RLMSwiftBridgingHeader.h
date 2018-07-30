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

#import <Realm/RLMArray.h>
#import <Realm/RLMObject.h>

@interface RLMRealm (Swift)
+ (void)resetRealmState;
@end

@interface RLMArray (Swift)

- (instancetype)initWithObjectClassName:(NSString *)objectClassName;

- (NSUInteger)indexOfObjectWhere:(NSString *)predicateFormat args:(va_list)args;
- (RLMResults *)objectsWhere:(NSString *)predicateFormat args:(va_list)args;

@end

@interface RLMResults (Swift)

- (NSUInteger)indexOfObjectWhere:(NSString *)predicateFormat args:(va_list)args;
- (RLMResults *)objectsWhere:(NSString *)predicateFormat args:(va_list)args;

@end

@interface RLMObjectBase (Swift)

- (instancetype)initWithRealm:(RLMRealm *)realm schema:(RLMObjectSchema *)schema defaultValues:(BOOL)useDefaults;

+ (RLMResults *)objectsWhere:(NSString *)predicateFormat args:(va_list)args;
+ (RLMResults *)objectsInRealm:(RLMRealm *)realm where:(NSString *)predicateFormat args:(va_list)args;

@end
