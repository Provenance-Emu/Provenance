//
//  SteamControllerManager.m
//  SteamController
//
//  Created by Jesús A. Álvarez on 16/12/2018.
//  Copyright © 2018 namedfork. All rights reserved.
//

#import "SteamControllerManager.h"
#import "SteamController.h"

@import CoreBluetooth;

#ifndef STEAMCONTROLLER_NO_SWIZZLING
@import ObjectiveC.runtime;
#endif

#ifndef STEAMCONTROLLER_NO_PRIVATE_API
@import Darwin.POSIX.dlfcn;
#endif

@interface SteamController (Private)
- (void)didConnect;
- (void)didDisconnect;
@end

@interface SteamControllerManager () <CBCentralManagerDelegate, CBPeripheralDelegate>
@end

@implementation SteamControllerManager
{
    CBCentralManager *centralManager;
    CBUUID *controllerServiceUUID;
    NSMutableDictionary<NSUUID*,SteamController*> *controllers;
    NSMutableSet<CBPeripheral*> *connectingPeripherals;
}

+ (instancetype)sharedManager {
    static dispatch_once_t onceToken;
    static SteamControllerManager *sharedManager = nil;
    dispatch_once(&onceToken, ^{
        sharedManager = [SteamControllerManager new];
    });
    return sharedManager;
}

- (instancetype)init {
    if ((self = [super init])) {
        controllerServiceUUID = [CBUUID UUIDWithString:@"100F6C32-1735-4313-B402-38567131E5F3"];
        centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
        controllers = [NSMutableDictionary dictionaryWithCapacity:4];
        connectingPeripherals = [NSMutableSet setWithCapacity:4];
    }
    return self;
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI {
    [connectingPeripherals addObject:peripheral];
    [central connectPeripheral:peripheral options:nil];
}

- (SteamController*)controllerForPeripheral:(CBPeripheral*)peripheral {
    NSUUID *uuid = peripheral.identifier;
    SteamController *controller = nil;
    @synchronized (controllers) {
        controller = controllers[uuid];
        if (controller == nil) {
            controller = [[SteamController alloc] initWithPeripheral:peripheral];
            controllers[uuid] = controller;
        }
    }
    return controller;
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    SteamController *controller = [self controllerForPeripheral:peripheral];
    [connectingPeripherals removeObject:peripheral];
    [controller didConnect];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    SteamController *controller = nil;
    @synchronized (controllers) {
        controller = controllers[peripheral.identifier];
        [controllers removeObjectForKey:peripheral.identifier];
    }
    [connectingPeripherals removeObject:peripheral];
    [controller didDisconnect];
}

- (void)centralManagerDidUpdateState:(nonnull CBCentralManager *)central {
    if (central.state == CBManagerStatePoweredOn) {
        [self scanForControllers];
    }
}

- (NSArray<SteamController *> *)controllers {
    return controllers.allValues;
}

- (void)scanForControllers:(id)sender {
    [self scanForControllers];
}

- (void)scanForControllers {
    if (centralManager.state == CBManagerStatePoweredOn) {
        [centralManager scanForPeripheralsWithServices:@[controllerServiceUUID] options:nil];
        NSArray *peripherals = [centralManager retrieveConnectedPeripheralsWithServices:@[controllerServiceUUID]];
        for (CBPeripheral *peripheral in peripherals) {
            if (peripheral.state == CBPeripheralStateDisconnected) {
                [connectingPeripherals addObject:peripheral];
                [centralManager connectPeripheral:peripheral options:nil];
            } // TODO: something if it's disconnected?
        }
    }
}

#pragma mark - Swizzling

#ifndef STEAMCONTROLLER_NO_SWIZZLING
+ (void)load {
    Method m1 = class_getClassMethod([GCController class], @selector(controllers));
    Method m2 = class_getClassMethod([SteamControllerManager class], @selector(controllers));
    Method m3 = class_getClassMethod([SteamControllerManager class], @selector(originalControllers));
    method_exchangeImplementations(m1, m3);
    method_exchangeImplementations(m1, m2);
}

+ (NSArray<GCController*>*)originalControllers {
    return @[];
}

+ (NSArray<GCController*>*)controllers {
    NSArray<GCController*>* originalControllers = [SteamControllerManager originalControllers];
    NSArray<GCController*>* steamControllers = [SteamControllerManager sharedManager].controllers;
    return [originalControllers arrayByAddingObjectsFromArray:steamControllers];
}
#endif

@end


#pragma mark - IOKit

#ifndef STEAMCONTROLLER_NO_PRIVATE_API
typedef mach_port_t    io_object_t;
typedef io_object_t    io_connect_t;
typedef io_object_t    io_enumerator_t;
typedef io_object_t    io_iterator_t;
typedef io_object_t    io_registry_entry_t;
typedef io_object_t    io_service_t;
typedef char           io_name_t[128];
typedef struct IONotificationPort *IONotificationPortRef;
static IONotificationPortRef (*IONotificationPortCreate)(mach_port_t masterPort);
#define kIOMasterPortDefault 0
static CFMutableDictionaryRef (*IOServiceMatching)(const char *name);
static CFRunLoopSourceRef (*IONotificationPortGetRunLoopSource)(IONotificationPortRef notify);
typedef void (*IOServiceMatchingCallback)(void *refcon, io_iterator_t iterator);
static kern_return_t (*IOServiceAddMatchingNotification)(IONotificationPortRef notifyPort, const io_name_t notificationType, CFDictionaryRef matching CF_RELEASES_ARGUMENT, IOServiceMatchingCallback callback, void *refCon, io_iterator_t *notification);
static io_object_t (*IOIteratorNext)(io_iterator_t iterator);
static kern_return_t (*IOObjectRelease)(io_object_t object);

static void didConnectHIDDevice(void *refcon, io_iterator_t iterator) {
    io_object_t obj;
    while ((obj = IOIteratorNext(iterator))) {
        IOObjectRelease(obj);
    };
    // delay scanning so disconnected notifications fire first
    [[SteamControllerManager sharedManager] performSelector:@selector(scanForControllers) withObject:nil afterDelay:0.01];
}

@implementation SteamControllerManager (Listening)

+ (BOOL)listenForConnections {
    static dispatch_once_t onceToken;
    static BOOL loadedSymbols = NO;
    dispatch_once(&onceToken, ^{
        void * IOKit = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOLOAD);
        if (IOKit) {
#define LoadSymbol(sym) sym = dlsym(IOKit, #sym); if (!sym) {dlclose(IOKit); return;}
            LoadSymbol(IONotificationPortCreate);
            LoadSymbol(IOServiceMatching);
            LoadSymbol(IONotificationPortGetRunLoopSource);
            LoadSymbol(IOServiceAddMatchingNotification);
            LoadSymbol(IOIteratorNext);
            LoadSymbol(IOObjectRelease);
            dlclose(IOKit);
            loadedSymbols = YES;
        }
    });
    
    if (!loadedSymbols) {
        return NO;
    }
    
    IONotificationPortRef notificationPort = IONotificationPortCreate(kIOMasterPortDefault);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), IONotificationPortGetRunLoopSource(notificationPort), kCFRunLoopDefaultMode);
    CFMutableDictionaryRef matchingDict = IOServiceMatching("IOHIDUserDevice");
    io_iterator_t portIterator = 0;
    kern_return_t result = IOServiceAddMatchingNotification(notificationPort,
                                                            "IOServicePublish",
                                                            matchingDict,
                                                            didConnectHIDDevice,
                                                            NULL,
                                                            &portIterator);
    if (result == KERN_SUCCESS) {
        didConnectHIDDevice(NULL, portIterator);
        return YES;
    }
    return NO;
}

@end

#endif
