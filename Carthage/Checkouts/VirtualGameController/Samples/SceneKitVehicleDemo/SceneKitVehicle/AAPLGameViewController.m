/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 */

#import <GameController/GameController.h>
#import <simd/simd.h>
#import <sys/utsname.h>

#import "AAPLGameViewController.h"
#import "AAPLGameView.h"
#import "AAPLOverlayScene.h"

@import VirtualGameController;
@import GameController;

#define MAX_SPEED 250

@implementation AAPLGameViewController {
    //some node references for manipulation
    SCNNode *_spotLightNode;
    SCNNode *_cameraNode;          //the node that owns the camera
    SCNNode *frontCameraNode;
    SCNNode *_vehicleNode;
    SCNPhysicsVehicle *_vehicle;
    SCNParticleSystem *_reactor;
    
    //accelerometer
    CMMotionManager *_motionManager;
    UIAccelerationValue	_accelerometer[3];
    CGFloat _orientation;
    
    //reactor's particle birth rate
    CGFloat _reactorDefaultBirthRate;
    
    // steering factor
    CGFloat _vehicleSteering;
    
    SCNNode * floor;
}

- (NSString *)deviceName
{
    static NSString *deviceName = nil;
    
    if (deviceName == nil) {
        struct utsname systemInfo;
        uname(&systemInfo);
        
        deviceName = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    }
    return deviceName;
}

- (BOOL)isHighEndDevice
{
    //return YES for iPhone 5s and iPad air, NO otherwise
    if ([[self deviceName] hasPrefix:@"iPad4"]
       || [[self deviceName] hasPrefix:@"iPhone6"]) {
        return YES;
    }
    
    return NO;
}

- (void)physicsWorld:(SCNPhysicsWorld *)world didBeginContact:(SCNPhysicsContact *)contact
{
    VgcController  * myController = [[VgcController controllers] firstObject];
    [myController vibrateDevice];
}

- (void)setupEnvironment:(SCNScene *)scene
{
    scene.physicsWorld.contactDelegate = self;
    
    // add an ambient light
    SCNNode *ambientLight = [SCNNode node];
    ambientLight.light = [SCNLight light];
    ambientLight.light.type = SCNLightTypeAmbient;
    ambientLight.light.color = [UIColor colorWithWhite:0.3 alpha:1.0];
    [[scene rootNode] addChildNode:ambientLight];
    
    //add a key light to the scene
    SCNNode *lightNode = [SCNNode node];
    lightNode.light = [SCNLight light];
    lightNode.light.type = SCNLightTypeSpot;
    if ([self isHighEndDevice])
        lightNode.light.castsShadow = YES;
    lightNode.light.color = [UIColor colorWithWhite:0.8 alpha:1.0];
    lightNode.position = SCNVector3Make(0, 80, 30);
    lightNode.rotation = SCNVector4Make(1,0,0,-M_PI/2.8);
    lightNode.light.spotInnerAngle = 0;
    lightNode.light.spotOuterAngle = 50;
    lightNode.light.shadowColor = [SKColor blackColor];
    lightNode.light.zFar = 500;
    lightNode.light.zNear = 50;
    [[scene rootNode] addChildNode:lightNode];
    
    //keep an ivar for later manipulation
    _spotLightNode = lightNode;
    
    //floor
    floor = [SCNNode node];
    floor.geometry = [SCNFloor floor];
    floor.geometry.firstMaterial.diffuse.contents = @"wood.png";
    floor.geometry.firstMaterial.diffuse.contentsTransform = SCNMatrix4MakeScale(2, 2, 1); //scale the wood texture
    floor.geometry.firstMaterial.locksAmbientWithDiffuse = YES;
    if ([self isHighEndDevice])
        ((SCNFloor*)floor.geometry).reflectionFalloffEnd = 10;
    
    SCNPhysicsBody *staticBody = [SCNPhysicsBody staticBody];
    floor.physicsBody = staticBody;
    [[scene rootNode] addChildNode:floor];
}

- (void)addTrainToScene:(SCNScene *)scene atPosition:(SCNVector3)pos
{
    SCNScene *trainScene = [SCNScene sceneNamed:@"train_flat"];
    
    //physicalize the train with simple boxes
    [trainScene.rootNode.childNodes enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        SCNNode *node = (SCNNode *)obj;
        if (node.geometry != nil) {
            node.position = SCNVector3Make(node.position.x + pos.x, node.position.y + pos.y, node.position.z + pos.z);
            
            SCNVector3 min, max;
            [node getBoundingBoxMin:&min max:&max];
            
            SCNPhysicsBody *body = [SCNPhysicsBody dynamicBody];
            SCNBox *boxShape = [SCNBox boxWithWidth:max.x - min.x height:max.y - min.y length:max.z - min.z chamferRadius:0.0];
            body.physicsShape = [SCNPhysicsShape shapeWithGeometry:boxShape options:nil];
            
            node.pivot = SCNMatrix4MakeTranslation(0, -min.y, 0);
            node.physicsBody = body;
            [[scene rootNode] addChildNode:node];
        }
    }];
    
    //add smoke
    SCNNode *smokeHandle = [scene.rootNode childNodeWithName:@"Smoke" recursively:YES];
    [smokeHandle addParticleSystem:[SCNParticleSystem particleSystemNamed:@"smoke" inDirectory:nil]];
    
    //add physics constraints between engine and wagons
    SCNNode *engineCar = [scene.rootNode childNodeWithName:@"EngineCar" recursively:NO];
    SCNNode *wagon1 = [scene.rootNode childNodeWithName:@"Wagon1" recursively:NO];
    SCNNode *wagon2 = [scene.rootNode childNodeWithName:@"Wagon2" recursively:NO];
    
    SCNVector3 min, max;
    [engineCar getBoundingBoxMin:&min max:&max];
    
    SCNVector3 wmin, wmax;
    [wagon1 getBoundingBoxMin:&wmin max:&wmax];
    
    // Tie EngineCar & Wagon1
    SCNPhysicsBallSocketJoint *joint = [SCNPhysicsBallSocketJoint jointWithBodyA:engineCar.physicsBody anchorA:SCNVector3Make(max.x, min.y, 0)
                                                                           bodyB:wagon1.physicsBody anchorB:SCNVector3Make(wmin.x, wmin.y, 0)];
    [scene.physicsWorld addBehavior:joint];
    
    // Wagon1 & Wagon2
    joint = [SCNPhysicsBallSocketJoint jointWithBodyA:wagon1.physicsBody anchorA:SCNVector3Make(wmax.x + 0.1, wmin.y, 0)
                                                bodyB:wagon2.physicsBody anchorB:SCNVector3Make(wmin.x - 0.1, wmin.y, 0)];
    [scene.physicsWorld addBehavior:joint];
}


- (void)addWoodenBlockToScene:(SCNScene *)scene withImageNamed:(NSString *)imageName atPosition:(SCNVector3)position
{
    //create a new node
    SCNNode *block = [SCNNode node];
    
    //place it
    block.position = position;
    
    //attach a box of 5x5x5
    block.geometry = [SCNBox boxWithWidth:5 height:5 length:5 chamferRadius:0];

    //use the specified images named as the texture
    block.geometry.firstMaterial.diffuse.contents = imageName;
    
    //turn on mipmapping
    block.geometry.firstMaterial.diffuse.mipFilter = SCNFilterModeLinear;
    
    //make it physically based
    block.physicsBody = [SCNPhysicsBody dynamicBody];
    
    //add to the scene
    [[scene rootNode] addChildNode:block];
}

- (void)setupSceneElements:(SCNScene *)scene
{
    // add a train
    [self addTrainToScene:scene atPosition:SCNVector3Make(-5, 20, -40)];
    
    // add wooden blocks
    [self addWoodenBlockToScene:scene withImageNamed:@"WoodCubeA.jpg" atPosition:SCNVector3Make(-10, 15, 10)];
    [self addWoodenBlockToScene:scene withImageNamed:@"WoodCubeB.jpg" atPosition:SCNVector3Make( -9, 10, 10)];
    [self addWoodenBlockToScene:scene withImageNamed:@"WoodCubeC.jpg" atPosition:SCNVector3Make(20, 15, -11)];
    [self addWoodenBlockToScene:scene withImageNamed:@"WoodCubeA.jpg" atPosition:SCNVector3Make(25, 5, -20)];
    
    // add walls
    SCNNode *wall = [SCNNode nodeWithGeometry:[SCNBox boxWithWidth:400 height:100 length:4 chamferRadius:0]];
    wall.geometry.firstMaterial.diffuse.contents = @"wall.jpg";
    wall.geometry.firstMaterial.diffuse.contentsTransform = SCNMatrix4Mult(SCNMatrix4MakeScale(24, 2, 1), SCNMatrix4MakeTranslation(0, 1, 0));
    wall.geometry.firstMaterial.diffuse.wrapS = SCNWrapModeRepeat;
    wall.geometry.firstMaterial.diffuse.wrapT = SCNWrapModeMirror;
    wall.geometry.firstMaterial.doubleSided = NO;
    wall.castsShadow = NO;
    wall.geometry.firstMaterial.locksAmbientWithDiffuse = YES;
        
    wall.position = SCNVector3Make(0, 50, -92);
    wall.physicsBody = [SCNPhysicsBody staticBody];
    [scene.rootNode addChildNode:wall];
    
    wall = [wall clone];
    wall.position = SCNVector3Make(-202, 50, 0);
    wall.rotation = SCNVector4Make(0, 1, 0, M_PI_2);
    [scene.rootNode addChildNode:wall];
        
    wall = [wall clone];
    wall.position = SCNVector3Make(202, 50, 0);
    wall.rotation = SCNVector4Make(0, 1, 0, -M_PI_2);
    [scene.rootNode addChildNode:wall];
    
    SCNNode *backWall = [SCNNode nodeWithGeometry:[SCNPlane planeWithWidth:400 height:100]];
    backWall.geometry.firstMaterial = wall.geometry.firstMaterial;
    backWall.position = SCNVector3Make(0, 50, 200);
    backWall.rotation = SCNVector4Make(0, 1, 0, M_PI);
    backWall.castsShadow = NO;
    backWall.physicsBody = [SCNPhysicsBody staticBody];
    [scene.rootNode addChildNode:backWall];
    
    // add ceil
    SCNNode *ceilNode = [SCNNode nodeWithGeometry:[SCNPlane planeWithWidth:400 height:400]];
    ceilNode.position = SCNVector3Make(0, 100, 0);
    ceilNode.rotation = SCNVector4Make(1, 0, 0, M_PI_2);
    ceilNode.geometry.firstMaterial.doubleSided = NO;
    ceilNode.castsShadow = NO;
    ceilNode.geometry.firstMaterial.locksAmbientWithDiffuse = YES;
    [scene.rootNode addChildNode:ceilNode];
    
    //add more block
    for(int i=0;i<4; i++) {
        [self addWoodenBlockToScene:scene withImageNamed:@"WoodCubeA.jpg" atPosition:SCNVector3Make(rand()%60 - 30, 20, rand()%40 - 20)];
        [self addWoodenBlockToScene:scene withImageNamed:@"WoodCubeB.jpg" atPosition:SCNVector3Make(rand()%60 - 30, 20, rand()%40 - 20)];
        [self addWoodenBlockToScene:scene withImageNamed:@"WoodCubeC.jpg" atPosition:SCNVector3Make(rand()%60 - 30, 20, rand()%40 - 20)];
    }
    
    // add cartoon book
    SCNNode *block = [SCNNode node];
    block.position = SCNVector3Make(20, 10, -16);
    block.rotation = SCNVector4Make(0, 1, 0, -M_PI_4);
    block.geometry = [SCNBox boxWithWidth:22 height:0.2 length:34 chamferRadius:0];
    SCNMaterial *frontMat = [SCNMaterial material];
    frontMat.locksAmbientWithDiffuse = YES;
    frontMat.diffuse.contents = @"book_front.jpg";
    frontMat.diffuse.mipFilter = SCNFilterModeLinear;
    SCNMaterial *backMat = [SCNMaterial material];
    backMat.locksAmbientWithDiffuse = YES;
    backMat.diffuse.contents = @"book_back.jpg";
    backMat.diffuse.mipFilter = SCNFilterModeLinear;
    block.geometry.materials = @[frontMat, backMat];
    block.physicsBody = [SCNPhysicsBody dynamicBody];
    [[scene rootNode] addChildNode:block];
    
    // add carpet
    SCNNode *rug = [SCNNode node];
    rug.position = SCNVector3Make(0, 0.01, 0);
    rug.rotation = SCNVector4Make(1, 0, 0, M_PI_2);
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(-50, -30, 100, 50) cornerRadius:2.5];
    path.flatness = 0.1;
    rug.geometry = [SCNShape shapeWithPath:path extrusionDepth:0.05];
    rug.geometry.firstMaterial.locksAmbientWithDiffuse = YES;
    rug.geometry.firstMaterial.diffuse.contents = @"carpet.jpg";
    [[scene rootNode] addChildNode:rug];
    
    // add ball
    SCNNode *ball = [SCNNode node];
    ball.position = SCNVector3Make(-5, 5, -18);
    ball.geometry = [SCNSphere sphereWithRadius:5];
    ball.geometry.firstMaterial.locksAmbientWithDiffuse = YES;
    ball.geometry.firstMaterial.diffuse.contents = @"ball.jpg";
    ball.geometry.firstMaterial.diffuse.contentsTransform = SCNMatrix4MakeScale(2, 1, 1);
    ball.geometry.firstMaterial.diffuse.wrapS = SCNWrapModeMirror;
    ball.physicsBody = [SCNPhysicsBody dynamicBody];
    ball.physicsBody.restitution = 0.9;
    [[scene rootNode] addChildNode:ball];
}


- (SCNNode *)setupVehicle:(SCNScene *)scene
{
    SCNScene *carScene = [SCNScene sceneNamed:@"rc_car"];
    SCNNode *chassisNode = [carScene.rootNode childNodeWithName:@"rccarBody" recursively:NO];
    
    // setup the chassis
    chassisNode.position = SCNVector3Make(0, 10, 30);
    chassisNode.rotation = SCNVector4Make(0, 1, 0, M_PI);
    
    SCNPhysicsBody *body = [SCNPhysicsBody dynamicBody];
    body.allowsResting = NO;
    body.mass = 80;
    body.restitution = 0.1;
    body.friction = 0.5;
    body.rollingFriction = 0;
    
    chassisNode.physicsBody = body;
    [scene.rootNode addChildNode:chassisNode];
    
    SCNNode *pipeNode = [chassisNode childNodeWithName:@"pipe" recursively:YES];
    _reactor = [SCNParticleSystem particleSystemNamed:@"reactor" inDirectory:nil];
    _reactorDefaultBirthRate = _reactor.birthRate;
    _reactor.birthRate = 0;
    [pipeNode addParticleSystem:_reactor];
    
    //add wheels
    SCNNode *wheel0Node = [chassisNode childNodeWithName:@"wheelLocator_FL" recursively:YES];
    SCNNode *wheel1Node = [chassisNode childNodeWithName:@"wheelLocator_FR" recursively:YES];
    SCNNode *wheel2Node = [chassisNode childNodeWithName:@"wheelLocator_RL" recursively:YES];
    SCNNode *wheel3Node = [chassisNode childNodeWithName:@"wheelLocator_RR" recursively:YES];
    
    SCNPhysicsVehicleWheel *wheel0 = [SCNPhysicsVehicleWheel wheelWithNode:wheel0Node];
    SCNPhysicsVehicleWheel *wheel1 = [SCNPhysicsVehicleWheel wheelWithNode:wheel1Node];
    SCNPhysicsVehicleWheel *wheel2 = [SCNPhysicsVehicleWheel wheelWithNode:wheel2Node];
    SCNPhysicsVehicleWheel *wheel3 = [SCNPhysicsVehicleWheel wheelWithNode:wheel3Node];

    SCNVector3 min, max;
    [wheel0Node getBoundingBoxMin:&min max:&max];
    CGFloat wheelHalfWidth = 0.5 * (max.x - min.x);
    
    wheel0.connectionPosition = SCNVector3FromFloat3(SCNVector3ToFloat3([wheel0Node convertPosition:SCNVector3Zero toNode:chassisNode]) + (vector_float3){wheelHalfWidth, 0.0, 0.0});
    wheel1.connectionPosition = SCNVector3FromFloat3(SCNVector3ToFloat3([wheel1Node convertPosition:SCNVector3Zero toNode:chassisNode]) - (vector_float3){wheelHalfWidth, 0.0, 0.0});
    wheel2.connectionPosition = SCNVector3FromFloat3(SCNVector3ToFloat3([wheel2Node convertPosition:SCNVector3Zero toNode:chassisNode]) + (vector_float3){wheelHalfWidth, 0.0, 0.0});
    wheel3.connectionPosition = SCNVector3FromFloat3(SCNVector3ToFloat3([wheel3Node convertPosition:SCNVector3Zero toNode:chassisNode]) - (vector_float3){wheelHalfWidth, 0.0, 0.0});
    
    // create the physics vehicle
    SCNPhysicsVehicle *vehicle = [SCNPhysicsVehicle vehicleWithChassisBody:chassisNode.physicsBody wheels:@[wheel0, wheel1, wheel2, wheel3]];
    [scene.physicsWorld addBehavior:vehicle];
    
    _vehicle = vehicle;
    
    return chassisNode;
}

- (SCNScene *)setupScene
{
    // create a new scene
    SCNScene *scene = [SCNScene scene];
    
    //global environment
    [self setupEnvironment:scene];
    
    //add elements
    [self setupSceneElements:scene];
    
    //setup vehicle
    _vehicleNode = [self setupVehicle:scene];
    
    //create a main camera
    _cameraNode = [[SCNNode alloc] init];
    _cameraNode.camera = [SCNCamera camera];
    _cameraNode.camera.zFar = 500;
    _cameraNode.position = SCNVector3Make(0, 60, 50);
    _cameraNode.rotation  = SCNVector4Make(1, 0, 0, -M_PI_4*0.75);
    [scene.rootNode addChildNode:_cameraNode];
    
    //add a secondary camera to the car
    frontCameraNode = [SCNNode node];
    frontCameraNode.position = SCNVector3Make(0, 3.5, 2.5);
    frontCameraNode.rotation = SCNVector4Make(0, 1, 0, M_PI);
    frontCameraNode.camera = [SCNCamera camera];
    frontCameraNode.camera.xFov = 75;
    frontCameraNode.camera.zFar = 500;
    
    [_vehicleNode addChildNode:frontCameraNode];
    
    return scene;
}

- (void)setupAccelerometer
{
    // Disable accelerometer because motion data will come from the peripheral
    return;
    
    //event
    _motionManager = [[CMMotionManager alloc] init];
    AAPLGameViewController * __weak weakSelf = self;
    
    if ([[GCController controllers] count] == 0 && [_motionManager isAccelerometerAvailable] == YES) {
        [_motionManager setAccelerometerUpdateInterval:1/60.0];
        [_motionManager startAccelerometerUpdatesToQueue:[NSOperationQueue mainQueue] withHandler:^(CMAccelerometerData *accelerometerData, NSError *error) {
            //[weakSelf accelerometerDidChange:accelerometerData.acceleration];
        }];
    }
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
 
    [[UIApplication sharedApplication] setStatusBarHidden:YES];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(controllerDidConnect:) name:@"VgcControllerDidConnectNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(foundService:) name:@"VgcPeripheralFoundService" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(peripheralDidConnect:) name:@"VgcPeripheralDidConnectNotification" object:nil];
    
    [VgcManager startAs:AppRoleMultiplayerPeer appIdentifier:@"vgc" customElements:nil customMappings:nil includesPeerToPeer:false enableLocalController:true];

    VgcManager.loggerLogLevel = LogLevelError;
    VgcManager.loggerUseNSLog = @YES;
    
    [[VgcManager peripheral] browseForServices];
    
    SCNView *scnView = (SCNView *) self.view;
    
    //set the background to back
    scnView.backgroundColor = [SKColor blackColor];
    
    //setup the scene
    SCNScene *scene = [self setupScene];
    
    //present it
    scnView.scene = scene;
    
    //tweak physics
    scnView.scene.physicsWorld.speed = 4.0;

    //setup overlays
    scnView.overlaySKScene = [[AAPLOverlayScene alloc] initWithSize:scnView.bounds.size];
    
    //setup accelerometer
    [self setupAccelerometer];
    
    //initial point of view
    scnView.pointOfView = _cameraNode;
    
    //plug game logic
    scnView.delegate = self;
    
    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
    doubleTap.numberOfTapsRequired = 2;
    doubleTap.numberOfTouchesRequired = 2;
    scnView.gestureRecognizers = @[doubleTap];

    [super viewDidLoad];
}


    - (void) peripheralDidConnect:(NSNotification *) aNotification {
        
        [[VgcManager peripheral] motion].enableAttitude = YES;
        [[[VgcManager peripheral] motion] start];
        
    }
        
- (void) foundService:(NSNotification *) aNotification {
    
    VgcService * service = (VgcService *)[aNotification object];
    [[VgcManager peripheral] connectToService:service];

}

- (void) handleDoubleTap:(UITapGestureRecognizer *) gesture
{
    SCNScene *scene = [self setupScene];
    
    SCNView *scnView = (SCNView *) self.view;
    //present it
    scnView.scene = scene;
    
    //tweak physics
    scnView.scene.physicsWorld.speed = 4.0;
    
    //initial point of view
    scnView.pointOfView = _cameraNode;
    
    ((AAPLGameView*)scnView).touchCount = 0;
}

// game logic
- (void)renderer:(id<SCNSceneRenderer>)aRenderer didSimulatePhysicsAtTime:(NSTimeInterval)time
{
    const float defaultEngineForce = 300.0;
    const float defaultBrakingForce = 3.0;
    const float steeringClamp = 0.6;
    const float cameraDamping = 0.3;
    
    AAPLGameView *scnView = (AAPLGameView*)self.view;
    
    CGFloat engineForce = 0;
    CGFloat brakingForce = 0;
    
    NSArray* controllers = [GCController controllers];
    
    float orientation = _orientation;
    
    //drive: 1 touch = accelerate, 2 touches = backward, 3 touches = brake
    if (scnView.touchCount == 1) {
        engineForce = defaultEngineForce;
        _reactor.birthRate = _reactorDefaultBirthRate;
    }
    else if (scnView.touchCount == 2) {
        engineForce = -defaultEngineForce;
        _reactor.birthRate = 0;
    }
    else if (scnView.touchCount == 3) {
        brakingForce = 100;
        _reactor.birthRate = 0;
    }
    else {
        brakingForce = defaultBrakingForce;
        _reactor.birthRate = 0;
    }
    
    //controller support
    if (controllers && [controllers count] > 0) {
        GCController *controller = controllers[0];
        GCGamepad *pad = [controller gamepad];
        GCControllerDirectionPad *dpad = [pad dpad];
        
        static float orientationCum = 0;
        
#define INCR_ORIENTATION 0.03
#define DECR_ORIENTATION 0.8
        
        if (dpad.right.pressed) {
            if (orientationCum < 0) orientationCum *= DECR_ORIENTATION;
            orientationCum += INCR_ORIENTATION;
            if (orientationCum > 1) orientationCum = 1;
        }
        else if (dpad.left.pressed) {
            if (orientationCum > 0) orientationCum *= DECR_ORIENTATION;
            orientationCum -= INCR_ORIENTATION;
            if (orientationCum < -1) orientationCum = -1;
        }
        else {
            orientationCum *= DECR_ORIENTATION;
        }
        
        orientation = orientationCum;
        
        if (pad.buttonX.pressed) {
            engineForce = defaultEngineForce;
            _reactor.birthRate = _reactorDefaultBirthRate;
        }
        else if (pad.buttonA.pressed) {
            engineForce = -defaultEngineForce;
            _reactor.birthRate = 0;
        }
        else if (pad.buttonB.pressed) {
            brakingForce = 100;
            _reactor.birthRate = 0;
        }
        else {
            brakingForce = defaultBrakingForce;
            _reactor.birthRate = 0;
        }
    }
    
    _vehicleSteering = -orientation;
    if (orientation==0)
        _vehicleSteering *= 0.9;
    if (_vehicleSteering < -steeringClamp)
        _vehicleSteering = -steeringClamp;
    if (_vehicleSteering > steeringClamp)
        _vehicleSteering = steeringClamp;
    
    //update the vehicle steering and acceleration
    [_vehicle setSteeringAngle:_vehicleSteering forWheelAtIndex:0];
    [_vehicle setSteeringAngle:_vehicleSteering forWheelAtIndex:1];
    
    /*
    [_vehicle applyEngineForce:engineForce forWheelAtIndex:2];
    [_vehicle applyEngineForce:engineForce forWheelAtIndex:3];
    
    [_vehicle applyBrakingForce:brakingForce forWheelAtIndex:2];
    [_vehicle applyBrakingForce:brakingForce forWheelAtIndex:3];
     */
    
    //check if the car is upside down
    [self reorientCarIfNeeded];

    // make camera follow the car node
    SCNNode *car = [_vehicleNode presentationNode];
    SCNVector3 carPos = car.position;
    vector_float3 targetPos = {carPos.x, 30., carPos.z + 25.};
    vector_float3 cameraPos = SCNVector3ToFloat3(_cameraNode.position);
    cameraPos = vector_mix(cameraPos, targetPos, (vector_float3)(cameraDamping));
    _cameraNode.position = SCNVector3FromFloat3(cameraPos);
    
    if (scnView.inCarView) {
        //move spot light in front of the camera
        SCNVector3 frontPosition = [scnView.pointOfView.presentationNode convertPosition:SCNVector3Make(0, 0, -30) toNode:nil];
        _spotLightNode.position = SCNVector3Make(frontPosition.x, 80., frontPosition.z);
        _spotLightNode.rotation = SCNVector4Make(1,0,0,-M_PI/2);
    }
    else {
        //move spot light on top of the car
        _spotLightNode.position = SCNVector3Make(carPos.x, 80., carPos.z + 30.);
        _spotLightNode.rotation = SCNVector4Make(1,0,0,-M_PI/2.8);
    }
    
    //speed gauge
    AAPLOverlayScene *overlayScene = (AAPLOverlayScene*)scnView.overlaySKScene;
    overlayScene.speedNeedle.zRotation = -(_vehicle.speedInKilometersPerHour * M_PI / MAX_SPEED);
}

- (void)reorientCarIfNeeded
{
    SCNNode *car = [_vehicleNode presentationNode];
    SCNVector3 carPos = car.position;

    // make sure the car isn't upside down, and fix it if it is
    static int ticks = 0;
    static int check = 0;
    ticks++;
    if (ticks == 30) {
        SCNMatrix4 t = car.worldTransform;
        if (t.m22 <= 0.1) {
            check++;
            if (check == 3) {
                static int try = 0;
                try++;
                if (try == 3) {
                    try = 0;
                    
                    //hard reset
                    _vehicleNode.rotation = SCNVector4Make(0, 0, 0, 0);
                    _vehicleNode.position = SCNVector3Make(carPos.x, carPos.y + 10, carPos.z);
                    [_vehicleNode.physicsBody resetTransform];
                }
                else {
                    //try to upturn with an random impulse
                    SCNVector3 pos = SCNVector3Make(-10*((rand()/(float)RAND_MAX)-0.5),0,-10*((rand()/(float)RAND_MAX)-0.5));
                    [_vehicleNode.physicsBody applyForce:SCNVector3Make(0, 300, 0) atPosition:pos impulse:YES];
                }
                
                check = 0;
            }
        }
        else {
            check = 0;
        }
        
        ticks=0;
    }
}

// When a Central is connected to by a Peripheral...
- (void) controllerDidConnect:(NSNotification *) aNotification {
    
    VgcController * controller = (VgcController *)[aNotification object];
    
    // Handlers for the various incoming peripheral actions
    
    [controller.motion setValueChangedHandler:^(VgcMotion * input) {
        [self attitudeDidChange:input];
        
    }];
    
    [controller.elements.image setValueChangedHandler:^(VgcController * vgcController, Element * element) {
        
        UIImage * image = [UIImage imageWithData:element.value];
        SCNMaterial * material = floor.geometry.firstMaterial;
        material.diffuse.contents = image;

        //VgcController  * myController = [[VgcController controllers] firstObject];
        [vgcController vibrateDevice];
    }];
    
    [controller.extendedGamepad.leftShoulder setValueChangedHandler:^(GCControllerButtonInput * button, float value, BOOL pressed) {
        SCNView *scnView = (SCNView *) self.view;
        scnView.pointOfView = _cameraNode;
    }];
    
    [controller.extendedGamepad.rightShoulder setValueChangedHandler:^(GCControllerButtonInput * button, float value, BOOL pressed) {
        SCNView *scnView = (SCNView *) self.view;
        scnView.pointOfView = frontCameraNode;
    }];

    [controller.extendedGamepad.leftTrigger setValueChangedHandler:^(GCControllerButtonInput * button, float value, BOOL pressed) {
        NSLog(@"Got value change on LEFT TRIGGER: %@", [NSNumber numberWithFloat:value]);
    }];
    
    [controller.extendedGamepad.rightTrigger setValueChangedHandler:^(GCControllerButtonInput * button, float value, BOOL pressed) {
        NSLog(@"Got value change on RIGHT TRIGGER: %@", [NSNumber numberWithFloat:value]);
    }];
    
    NSLog(@"Got controller: %@", controller.deviceInfo.vendorName);
    
}

//- (void)accelerometerDidChange:(CMAcceleration)acceleration
- (void)attitudeDidChange:(VgcMotion *)motion
{
#define kFilteringFactor			0.5
    
    /*
     //Use a basic low-pass filter to only keep the gravity in the accelerometer values
     _accelerometer[0] = acceleration.x * kFilteringFactor + _accelerometer[0] * (1.0 - kFilteringFactor);
     _accelerometer[1] = acceleration.y * kFilteringFactor + _accelerometer[1] * (1.0 - kFilteringFactor);
     _accelerometer[2] = acceleration.z * kFilteringFactor + _accelerometer[2] * (1.0 - kFilteringFactor);
     */
    
    //_orientation = motion.attitude.y*3;
    _orientation = -(motion.attitude.x)*1.5;
    
    [self reorientCarIfNeeded];
    
    [_vehicle applyEngineForce:-(motion.attitude.y) * 700 forWheelAtIndex:2];
    [_vehicle applyEngineForce:-(motion.attitude.y) * 700 forWheelAtIndex:3];
    
    //[_vehicle applyBrakingForce:motion.attitude.z * 3 forWheelAtIndex:2];
    //[_vehicle applyBrakingForce:motion.attitude.z * 3 forWheelAtIndex:3];
    
}


//- (void)accelerometerDidChange:(CMAcceleration)acceleration
- (void)accelerometerDidChange:(GCAcceleration)acceleration
{
    return;
#define kFilteringFactor			0.5
    
    /*
    //Use a basic low-pass filter to only keep the gravity in the accelerometer values
    _accelerometer[0] = acceleration.x * kFilteringFactor + _accelerometer[0] * (1.0 - kFilteringFactor);
    _accelerometer[1] = acceleration.y * kFilteringFactor + _accelerometer[1] * (1.0 - kFilteringFactor);
    _accelerometer[2] = acceleration.z * kFilteringFactor + _accelerometer[2] * (1.0 - kFilteringFactor);
    */
    
    if (acceleration.x > 0) {
        _orientation = acceleration.y*3;
    }
    else {
        _orientation = acceleration.z*3;
    }

    [self reorientCarIfNeeded];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [_motionManager stopAccelerometerUpdates];
    _motionManager = nil;
}

- (BOOL)shouldAutorotate
{
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskLandscape;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

@end
