//
//  CitraWrapper.h
//  emuThreeDS
//
//  Created by Antique on 22/5/2023.
//

#import <Foundation/Foundation.h>
#import <MetalKit/MetalKit.h>
#import <UIKit/UIKit.h>

#import "InputBridge.h"

NS_ASSUME_NONNULL_BEGIN
@interface CitraWrapper : NSObject {
    CAMetalLayer *_metalLayer;
    NSString *_path;
    
    NSThread *_thread;
    uint64_t _title_id;
    
    NSString *_savefile;
    bool shouldSave;
    bool shouldLoad;
    bool shouldReset;
    bool shouldShutdown;
    bool shouldStretchAudio;
    bool finishedShutdown;
}

@property (nonatomic, readwrite) BOOL isPaused, isRunning;
@property (nonatomic, readwrite) BOOL shouldStretchAudio;
@property (nonatomic, readwrite) ButtonInputBridge *m_buttonA;
@property (nonatomic, readwrite) ButtonInputBridge *m_buttonB;
@property (nonatomic, readwrite) ButtonInputBridge *m_buttonX;
@property (nonatomic, readwrite) ButtonInputBridge *m_buttonY;
@property (nonatomic, readwrite) ButtonInputBridge *m_buttonL;
@property (nonatomic, readwrite) ButtonInputBridge *m_buttonR;
@property (nonatomic, readwrite) ButtonInputBridge *m_buttonZL;
@property (nonatomic, readwrite) ButtonInputBridge *m_buttonZR;
@property (nonatomic, readwrite) ButtonInputBridge *m_buttonStart;
@property (nonatomic, readwrite) ButtonInputBridge *m_buttonSelect;
@property (nonatomic, readwrite) ButtonInputBridge *m_buttonDpadUp;
@property (nonatomic, readwrite) ButtonInputBridge *m_buttonDpadDown;
@property (nonatomic, readwrite) ButtonInputBridge *m_buttonDpadLeft;
@property (nonatomic, readwrite) ButtonInputBridge *m_buttonDpadRight;
@property (nonatomic, readwrite) ButtonInputBridge *m_buttonDummy;
@property (nonatomic, readwrite) ButtonInputBridge *m_buttonHome;
@property (nonatomic, readwrite) AnalogInputBridge *m_analogCirclePad;
@property (nonatomic, readwrite) AnalogInputBridge *m_analogCirclePad2;
@property (nonatomic, readwrite) MotionInputBridge *m_motion;

+(CitraWrapper *) sharedInstance;
-(instancetype) init;


-(uint16_t*) GetIcon:(NSString *)path;
-(NSString *) GetPublisher:(NSString *)path;
-(NSString *) GetRegion:(NSString *)path;
-(NSString *) GetTitle:(NSString *)path;

-(void) prepareAudio;
-(void) useMetalLayer:(CAMetalLayer *)layer;
-(void) setShaderOption;
-(void) setOptions:(bool)resetButtons;
-(void) load:(NSString *)path;
-(void) pauseEmulation;
-(void) resumeEmulation;
-(void) resetEmulation;
-(void) shutdownEmulation;
-(void) resetController;
-(void) asyncResetController;
-(void) requestSave:(NSString *)path;
-(void) requestLoad:(NSString *)path;
-(void) run;
-(void) start;

-(void) rotate:(BOOL)rotate;
-(void) swap:(BOOL)swap;
-(void) layout:(int)option;

-(void) handleTouchEvent:(NSArray*)touches;
-(void) touchesBegan:(CGPoint)point;
-(void) touchesMoved:(CGPoint)point;
-(void) touchesEnded;

-(void) orientationChanged:(UIDeviceOrientation)orientation with:(CAMetalLayer *)surface;
-(void) refreshSize:(CAMetalLayer *)surface;

-(void) SaveState:(NSString *) savePath;
-(void) LoadState:(NSString *) savePath;

-(void) addCheat:(NSString *)code;
@end
NS_ASSUME_NONNULL_END
