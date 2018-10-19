//
//  ViewController.m
//  ObjectiveC_iOS
//
//  Created by Rob Reuss on 11/18/15.
//  Copyright © 2015 Rob Reuss. All rights reserved.
//

#import "ViewController.h"
@import VirtualGameController;
@import GameController;

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor darkGrayColor];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(controllerDidConnect:) name:@"VgcControllerDidConnectNotification" object:nil];    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(foundService:) name:@"VgcPeripheralFoundService" object:nil];

    
    BOOL centralMode = true;
    
    if (centralMode) {
        
        [VgcManager startAs:AppRoleCentral appIdentifier:@"vgc" includesPeerToPeer: true];
        
        VgcManager.loggerLogLevel = LogLevelError;
        VgcManager.loggerUseNSLog = @YES;
        
    } else {
        
        [VgcManager startAs:AppRolePeripheral appIdentifier:@"vgc" includesPeerToPeer: true];
        DeviceInfo * deviceInfo = [[DeviceInfo alloc] initWithDeviceUID:@"" vendorName:@"" attachedToDevice:NO profileType:ProfileTypeExtendedGamepad controllerType:ControllerTypeSoftware supportsMotion:YES];
        [[VgcManager peripheral] setDeviceInfo:deviceInfo];
        
        [[VgcManager peripheral] browseForServices];
        
        // Just a couple of quick test buttons to demonstrate sending element vaues
        
        UIButton * leftShoulder = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        leftShoulder.backgroundColor = [UIColor lightGrayColor];
        leftShoulder.frame = CGRectMake(0, 24, self.view.bounds.size.width * .50, 100);
        leftShoulder.autoresizingMask = UIViewAutoresizingFlexibleWidth + UIViewAutoresizingFlexibleRightMargin;
        [leftShoulder setTitle:@"Left Shoulder" forState:UIControlStateNormal];
        [leftShoulder addTarget:self action:@selector(buttonPress:) forControlEvents:UIControlEventTouchDown + UIControlEventTouchUpInside];
        [leftShoulder setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        leftShoulder.tag = 0;
        [self.view addSubview:leftShoulder];
        
        UIButton * rightShoulder = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        rightShoulder.backgroundColor = [UIColor lightGrayColor];
        rightShoulder.frame = CGRectMake((self.view.bounds.size.width * .50) + 2, 24, (self.view.bounds.size.width * .50) - 2, 100);
        rightShoulder.autoresizingMask = UIViewAutoresizingFlexibleWidth + UIViewAutoresizingFlexibleLeftMargin;
        [rightShoulder setTitle:@"Right Shoulder" forState:UIControlStateNormal];
        [rightShoulder addTarget:self action:@selector(buttonPress:) forControlEvents:UIControlEventTouchDown + UIControlEventTouchUpInside];
        [rightShoulder setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        rightShoulder.tag = 1;
        [self.view addSubview:rightShoulder];
        
        UIButton * leftTrigger = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        leftTrigger.backgroundColor = [UIColor lightGrayColor];
        leftTrigger.frame = CGRectMake(0, 125, self.view.bounds.size.width * .50, 100);
        leftTrigger.autoresizingMask = UIViewAutoresizingFlexibleWidth + UIViewAutoresizingFlexibleRightMargin;
        [leftTrigger setTitle:@"Left Trigger" forState:UIControlStateNormal];
        [leftTrigger addTarget:self action:@selector(buttonPress:) forControlEvents:UIControlEventTouchDown + UIControlEventTouchUpInside];
        [leftTrigger setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        leftTrigger.tag = 2;
        [self.view addSubview:leftTrigger];
        
        UIButton * rightTrigger = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        rightTrigger.backgroundColor = [UIColor lightGrayColor];
        rightTrigger.autoresizingMask = UIViewAutoresizingFlexibleWidth + UIViewAutoresizingFlexibleLeftMargin;
        rightTrigger.frame = CGRectMake((self.view.bounds.size.width * .50) + 2, 125, (self.view.bounds.size.width * .50) - 2, 100);
        [rightTrigger setTitle:@"Right Trigger" forState:UIControlStateNormal];
        [rightTrigger setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        rightTrigger.tag = 3;
        [rightTrigger addTarget:self action:@selector(buttonPress:) forControlEvents:UIControlEventTouchDown + UIControlEventTouchUpInside];
        [self.view addSubview:rightTrigger];
    }
}

// METHODS FOR PERIPHERAL MODE

// When a Peripheral finds a Central service...
- (void) foundService:(NSNotification *) aNotification {
    
    VgcService * service = (VgcService *)[aNotification object];
    NSLog(@"Found service: %@ and automatically connecting to it", service.fullName);
    [[VgcManager peripheral] connectToService:service];
    
    // Demonstrate that motion is working...
    [[[VgcManager peripheral] motion] start];
    
}

// Send a test value
- (void) buttonPress:(UIButton *)sender {
    
    Element * element;
    
    switch (sender.tag) {
        case 0:
            element = [[VgcManager elements] leftShoulder];
            break;
            
        case 1:
            element = [[VgcManager elements] rightShoulder];
            break;
            
        case 2:
            element = [[VgcManager elements] leftTrigger];
            break;
            
        case 3:
            element = [[VgcManager elements] rightTrigger];
            break;
            
        default:
            break;
    }
    
    // Toggle the element value
    
    if ([element.value isEqualToValue:@1.0]) {
        
        element.value = @0.0;
        [[VgcManager peripheral] sendElementState:element];
        
    } else {
        
        element.value = @1.0;
        [[VgcManager peripheral] sendElementState:element];
        
    }
    
    NSLog(@"Sent element value %@", element.value);
}


// METHODS FOR CENTRAL MODE

// When a Central is connected to by a Peripheral...
- (void) controllerDidConnect:(NSNotification *) aNotification {
    
    VgcController * controller = (VgcController *)[aNotification object];
    
    // Handlers for the various buttons
    
    //[controller.extendedGamepad setValueChangedHandler:^(GCExtendedGamepad *extendedGamepad, GCControllerElement *element) {
    //    NSLog(@"Got value change on element: %@", element.description);
    //}];
    
    [controller.extendedGamepad.leftShoulder setValueChangedHandler:^(GCControllerButtonInput * button, float value, BOOL pressed) {
        NSLog(@"Got value change on LEFT SHOULDER: %@", [NSNumber numberWithFloat:value]);
    }];
    
    [controller.extendedGamepad.rightShoulder setValueChangedHandler:^(GCControllerButtonInput * button, float value, BOOL pressed) {
        NSLog(@"Got value change on RIGHT SHOULDER: %@", [NSNumber numberWithFloat:value]);
    }];
    
    [controller.extendedGamepad.leftTrigger setValueChangedHandler:^(GCControllerButtonInput * button, float value, BOOL pressed) {
        NSLog(@"Got value change on LEFT TRIGGER: %@", [NSNumber numberWithFloat:value]);
    }];
    
    [controller.extendedGamepad.rightTrigger setValueChangedHandler:^(GCControllerButtonInput * button, float value, BOOL pressed) {
        NSLog(@"Got value change on RIGHT TRIGGER: %@", [NSNumber numberWithFloat:value]);
    }];
    
    NSLog(@"Got controller: %@", controller.deviceInfo.vendorName);
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
