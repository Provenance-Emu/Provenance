//
//  MultiplayerManager.h
//  Cytrus
//
//  Created by Jarrod Norwell on 23/10/2024.
//  Copyright © 2024 Jarrod Norwell. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, ErrorChange) {
    // Reasons why connection was closed
    ErrorChangeLostConnection,
    ErrorChangeHostKicked,
    
    // Reasons why connection was rejected
    ErrorChangeUnknownError,
    ErrorChangeNameCollision,
    ErrorChangeMacCollision,
    ErrorChangeConsoleIdCollision,
    ErrorChangeWrongVersion,
    ErrorChangeWrongPassword,
    ErrorChangeCouldNotConnect,
    ErrorChangeRoomIsFull,
    ErrorChangeHostBanned,
    
    // Reasons why moderation request failed
    ErrorChangePermissionDenied,
    ErrorChangeNoSuchUser
};

typedef NS_ENUM(NSUInteger, StateChange) {
    StateChangeUninitialized,
    StateChangeIdle,
    StateChangeJoining,
    StateChangeJoined,
    StateChangeModerator
};

@interface NetworkRoom : NSObject
@property (nonatomic, strong) NSString *name, *details, *ip, *gameName;
@property (nonatomic, assign) uint16_t port;
@property (nonatomic, assign) BOOL hasPassword;
@property (nonatomic, assign) NSInteger maxPlayers, numberOfPlayers;

-(NetworkRoom *) initWithName:(NSString *)name details:(NSString *)details ip:(NSString *)ip gameName:(NSString *)gameName port:(uint16_t)port hasPassword:(BOOL)hasPassword maxPlayers:(NSInteger)maxPlayers numberOfPlayers:(NSInteger)numberOfPlayers;
@end

@interface MultiplayerManager : NSObject {
    StateChange _roomState;
}

+(MultiplayerManager *) sharedInstance NS_SWIFT_NAME(shared());

-(NSArray <NetworkRoom *> *) rooms;

-(void) connect:(NetworkRoom *)room withUsername:(NSString *)username andPassword:(NSString * _Nullable)password
      withErrorChange:(void(^)(ErrorChange error))errorChange withStateChange:(void(^)(StateChange state))stateChange;
-(void) disconnect;

-(StateChange) state;

-(void) updateWebAPIURL;
@end

NS_ASSUME_NONNULL_END
