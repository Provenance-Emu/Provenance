#pragma once
#import <Foundation/Foundation.h>
#import <PVSupport/PVSupport.h>
#import <PVSupport/PVEmulatorCore.h>
#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>

@interface CGSH_ViewController : GLKViewController
@property (strong, nonatomic) EAGLContext *context;
@end
