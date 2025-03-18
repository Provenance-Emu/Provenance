//
//  MultiplayerManager.m
//  Cytrus
//
//  Created by Jarrod Norwell on 23/10/2024.
//  Copyright © 2024 Jarrod Norwell. All rights reserved.
//

#import "MultiplayerManager.h"

#include <iostream>
#include <memory>

#include "core/core.h"
#include "core/hle/service/cfg/cfg.h"
#include "network/announce_multiplayer_session.h"
#include "network/network.h"
#include "network/network_settings.h"
#include "network/room.h"

std::shared_ptr<Network::AnnounceMultiplayerSession> session;
std::weak_ptr<Network::AnnounceMultiplayerSession> w_session;

static void OnStateChanged(const Network::RoomMember::State& state) {
    switch (state) {
    case Network::RoomMember::State::Idle:
        LOG_DEBUG(Network, "Network is idle");
        break;
    case Network::RoomMember::State::Joining:
        LOG_DEBUG(Network, "Connection sequence to room started");
        break;
    case Network::RoomMember::State::Joined:
        LOG_DEBUG(Network, "Successfully joined to the room");
        break;
    case Network::RoomMember::State::Moderator:
        LOG_DEBUG(Network, "Successfully joined the room as a moderator");
        break;
    default:
        break;
    }
}

static void OnNetworkError(const Network::RoomMember::Error& error) {
    switch (error) {
    case Network::RoomMember::Error::LostConnection:
        LOG_DEBUG(Network, "Lost connection to the room");
        break;
    case Network::RoomMember::Error::CouldNotConnect:
        LOG_ERROR(Network, "Error: Could not connect");
        std::exit(1);
        break;
    case Network::RoomMember::Error::NameCollision:
        LOG_ERROR(
            Network,
            "You tried to use the same nickname as another user that is connected to the Room");
        std::exit(1);
        break;
    case Network::RoomMember::Error::MacCollision:
        LOG_ERROR(Network, "You tried to use the same MAC-Address as another user that is "
                           "connected to the Room");
        std::exit(1);
        break;
    case Network::RoomMember::Error::ConsoleIdCollision:
        LOG_ERROR(Network, "Your Console ID conflicted with someone else in the Room");
        std::exit(1);
        break;
    case Network::RoomMember::Error::WrongPassword:
        LOG_ERROR(Network, "Room replied with: Wrong password");
        std::exit(1);
        break;
    case Network::RoomMember::Error::WrongVersion:
        LOG_ERROR(Network,
                  "You are using a different version than the room you are trying to connect to");
        std::exit(1);
        break;
    case Network::RoomMember::Error::RoomIsFull:
        LOG_ERROR(Network, "The room is full");
        std::exit(1);
        break;
    case Network::RoomMember::Error::HostKicked:
        LOG_ERROR(Network, "You have been kicked by the host");
        break;
    case Network::RoomMember::Error::HostBanned:
        LOG_ERROR(Network, "You have been banned by the host");
        break;
    default:
        LOG_ERROR(Network, "Unknown network error: {}", error);
        break;
    }
}

static void OnMessageReceived(const Network::ChatEntry& msg) {
    std::cout << std::endl << msg.nickname << ": " << msg.message << std::endl << std::endl;
}

static void OnStatusMessageReceived(const Network::StatusMessageEntry& msg) {
    std::string message;
    switch (msg.type) {
    case Network::IdMemberJoin:
        message = fmt::format("{} has joined", msg.nickname);
        break;
    case Network::IdMemberLeave:
        message = fmt::format("{} has left", msg.nickname);
        break;
    case Network::IdMemberKicked:
        message = fmt::format("{} has been kicked", msg.nickname);
        break;
    case Network::IdMemberBanned:
        message = fmt::format("{} has been banned", msg.nickname);
        break;
    case Network::IdAddressUnbanned:
        message = fmt::format("{} has been unbanned", msg.nickname);
        break;
    }
    if (!message.empty())
        std::cout << std::endl << "* " << message << std::endl << std::endl;
}


@implementation NetworkRoom
-(NetworkRoom *) initWithName:(NSString *)name details:(NSString *)details ip:(NSString *)ip gameName:(NSString *)gameName port:(uint16_t)port hasPassword:(BOOL)hasPassword maxPlayers:(NSInteger)maxPlayers numberOfPlayers:(NSInteger)numberOfPlayers {
    if (self = [super init]) {
        self.name = name;
        self.details = details;
        self.ip = ip;
        self.gameName = gameName;
        self.port = port;
        self.hasPassword = hasPassword;
        self.maxPlayers = maxPlayers;
        self.numberOfPlayers = numberOfPlayers;
    } return self;
}
@end

@implementation MultiplayerManager
-(MultiplayerManager *) init {
    if(self = [super init]) {
        NetSettings::values.web_api_url = [[[NSUserDefaults standardUserDefaults] stringForKey:@"cytrus.webAPIURL"] UTF8String];
        Network::Init();
        
        session = std::make_shared<Network::AnnounceMultiplayerSession>();
        w_session = session;
    } return self;
}

+(MultiplayerManager *) sharedInstance {
    static MultiplayerManager *sharedInstance = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

-(NSArray<NetworkRoom *> *) rooms {
    if (const auto& sess = w_session.lock()) {
        NSMutableArray *convertedRooms = @[].mutableCopy;
        const auto& rooms = sess->GetRoomList();
        
        for (const auto& room : rooms)
            [convertedRooms addObject:[[NetworkRoom alloc]
                                       initWithName:[NSString stringWithCString:room.name.c_str() encoding:NSUTF8StringEncoding]
                                       details:[NSString stringWithCString:room.description.c_str() encoding:NSUTF8StringEncoding]
                                       ip:[NSString stringWithCString:room.ip.c_str() encoding:NSUTF8StringEncoding]
                                       gameName:[NSString stringWithCString:room.preferred_game.c_str() encoding:NSUTF8StringEncoding]
                                       port:room.port
                                       hasPassword:room.has_password
                                       maxPlayers:room.max_player
                                       numberOfPlayers:room.members.size()]];
        
        return convertedRooms;
    }
    
    return @[];
}

-(void) connect:(NetworkRoom *)room withUsername:(NSString *)username andPassword:(NSString * _Nullable)password
      withErrorChange:(void(^)(ErrorChange error))errorChange withStateChange:(void(^)(StateChange state))stateChange {
    std::string pwd{};
    if (password)
        pwd = password.UTF8String;
    
    if (auto rm = Network::GetRoomMember().lock()) {
        rm->BindOnChatMessageRecieved(OnMessageReceived);
        rm->BindOnStatusMessageReceived(OnStatusMessageReceived);
        rm->BindOnStateChanged([self, stateChange](const Network::RoomMember::State& state) {
            _roomState = (StateChange)state;
            stateChange((StateChange)state);
        });
        rm->BindOnError([errorChange](const Network::RoomMember::Error& error) { errorChange((ErrorChange)error); });
        
        rm->Join(username.UTF8String,
                          Service::CFG::GetConsoleIdHash(Core::System::GetInstance()),
                          room.ip.UTF8String, room.port, 0, Network::NoPreferredMac, pwd);
    }
}

-(void) disconnect {
    if (auto rm = Network::GetRoomMember().lock()) {
        rm->Leave();
    }
}

-(StateChange) state {
    return _roomState;
}

-(void) updateWebAPIURL {
    NSLog(@"updated web api url");
    Network::Shutdown();
    NetSettings::values.web_api_url = [[[NSUserDefaults standardUserDefaults] stringForKey:@"cytrus.webAPIURL"] UTF8String];
    Network::Init();
}
@end
