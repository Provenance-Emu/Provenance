//
//  EmulatorViewController.m
//  emulator
//
//  Created by Karen Tsai (angelXwind) on 2014/3/5.
//  Copyright (c) 2014 Karen Tsai (angelXwind). All rights reserved.
//

#import "EmulatorViewController.h"

#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>
#import <OpenGLES/EAGL.h>

#include "types.h"
#include "profiler/profiler.h"
#include "cfg/cfg.h"
#include "rend/TexCache.h"
#include "hw/maple/maple_devs.h"
#include "hw/maple/maple_if.h"
#import <sys/kdebug_signpost.h>

#define USE_CRT_SHADER 0

extern u16 kcode[4];
extern u32 vks[4];
extern s8 joyx[4],joyy[4];
extern u8 rt[4],lt[4];

@interface EmulatorViewController () {
	GLuint crtFragmentShader;
	GLuint crtShaderProgram;
	int crtUniform_DisplayRect;
	int crtUniform_EmulatedImage;
	int crtUniform_EmulatedImageSize;
	int crtUniform_FinalRes;

	GLuint defaultVertexShader;
}

@property (strong, nonatomic) EAGLContext *context;
@property (strong, nonatomic) GLKBaseEffect *effect;

- (void)setupGL;
- (void)tearDownGL;
- (void)emuThread;

@end

//who has time for headers
extern int screen_width,screen_height;
bool rend_single_frame();
bool gles_init();
extern "C" int reicast_main(int argc, char* argv[]);


#include <mach/mach.h>
#include <mach/mach_time.h>
#include <pthread.h>

void move_pthread_to_realtime_scheduling_class(pthread_t pthread)
{
	mach_timebase_info_data_t timebase_info;
	mach_timebase_info(&timebase_info);

	const uint64_t NANOS_PER_MSEC = 1000000ULL;
	double clock2abs = ((double)timebase_info.denom / (double)timebase_info.numer) * NANOS_PER_MSEC;

	thread_time_constraint_policy_data_t policy;
	policy.period      = 0;
	policy.computation = (uint32_t)(5 * clock2abs); // 5 ms of work
	policy.constraint  = (uint32_t)(10 * clock2abs);
	policy.preemptible = FALSE;

	int kr = thread_policy_set(pthread_mach_thread_np(pthread_self()),
							   THREAD_TIME_CONSTRAINT_POLICY,
							   (thread_policy_t)&policy,
							   THREAD_TIME_CONSTRAINT_POLICY_COUNT);
	if (kr != KERN_SUCCESS) {
		mach_error("thread_policy_set:", kr);
		exit(1);
	}
}

void MakeCurrentThreadRealTime()
{
	move_pthread_to_realtime_scheduling_class(pthread_self());
}

@implementation EmulatorViewController

-(void)emuThread
{
//    #if !TARGET_OS_SIMULATOR
    install_prof_handler(1);
 //   #endif
    
	char *Args[3];
	const char *P;

	P = (const char *)[self.diskImage UTF8String];
	Args[0] = "dc";
	Args[1] = "-config";
	Args[2] = P&&P[0]? (char *)malloc(strlen(P)+32):0;

	if(Args[2])
	{
		strcpy(Args[2],"config:image=");
		strcat(Args[2],P);
	}

	MakeCurrentThreadRealTime();

	reicast_main(Args[2]? 3:1,Args);
}

- (void)viewDidLoad
{
    [super viewDidLoad];

#if !TARGET_OS_TV
	self.controllerView = [[PadViewController alloc] initWithNibName:@"PadViewController" bundle:nil];
#endif
	
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];

	// Not sure what this effects in our case without making 2 contexts and swapping
//	[self.context setMultiThreaded:YES];

    if (!self.context) {
        NSLog(@"Failed to create ES context");
    }
    
    self.emuView = (EmulatorView *)self.view;
//	self.emuView.opaque = YES;
    self.emuView.context = self.context;
    self.emuView.drawableDepthFormat = GLKViewDrawableDepthFormat24;

	// Set preferred refresh rate
	[self setPreferredFramesPerSecond:60];

	[self.controllerView setControlOutput:self.emuView];
    
    self.connectObserver = [[NSNotificationCenter defaultCenter] addObserverForName:GCControllerDidConnectNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        if ( GCController.controllers.count ){
            [self toggleHardwareController:YES];
        }
    }];
    self.disconnectObserver = [[NSNotificationCenter defaultCenter] addObserverForName:GCControllerDidDisconnectNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        if (GCController.controllers.count == 0) {
            [self toggleHardwareController:NO];
        }
    }];
    
    if ([[GCController controllers] count]) {
        [self toggleHardwareController:YES];
	}

#if !TARGET_OS_TV
	[self addChildViewController:self.controllerView];
	self.controllerView.view.frame = self.view.bounds;
	self.controllerView.view.translatesAutoresizingMaskIntoConstraints = YES;
	self.controllerView.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleWidth;
	[self.view addSubview:self.controllerView.view];
	[self.controllerView didMoveToParentViewController:self];
#endif

    self.iCadeReader = [[iCadeReaderView alloc] init];
    [self.view addSubview:self.iCadeReader];
    self.iCadeReader.delegate = self;
    self.iCadeReader.active = YES;
	
    [self setupGL];

    if (!gles_init())
        die("OPENGL FAILED");

#if USE_CRT_SHADER
	[EAGLContext setCurrentContext:self.context];
	defaultVertexShader = [self compileShaderResource:@"default_vertex" ofType:GL_VERTEX_SHADER];
	[self setupCRTShader];
#endif
    
    NSThread* myThread = [[NSThread alloc] initWithTarget:self
                                                 selector:@selector(emuThread)
                                                   object:nil];
    [myThread start];  // Actually create the thread
}

- (void)dealloc
{
	if (crtShaderProgram > 0)
	{
		glDeleteProgram(crtShaderProgram);
	}
	if (crtFragmentShader > 0)
	{
		glDeleteShader(crtFragmentShader);
	}
	if (defaultVertexShader > 0)
	{
		glDeleteShader(defaultVertexShader);
	}

    [self tearDownGL];
    
    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }
}

//- (void)didReceiveMemoryWarning
//{
//    [super didReceiveMemoryWarning];
//
//    if ([self isViewLoaded] && ([[self view] window] == nil)) {
//        self.view = nil;
//
//        [self tearDownGL];
//
//        if ([EAGLContext currentContext] == self.context) {
//            [EAGLContext setCurrentContext:nil];
//        }
//        self.context = nil;
//    }
//
//    // Dispose of any resources that can be recreated.
//}

- (void)setupGL
{
    [EAGLContext setCurrentContext:self.context];
    
}

- (void)tearDownGL
{
    [EAGLContext setCurrentContext:self.context];
    
}

#pragma mark - GLKView and GLKViewController delegate methods

- (void)update
{

}

- (void)toggleHardwareController:(BOOL)useHardware {
    if (useHardware) {

		[self.controllerView hideController];

#if TARGET_OS_TV
		for(GCController*c in GCController.controllers) {
			if ((c.gamepad != nil || c.extendedGamepad != nil) && (c != _gController)) {

				self.gController = c;
				break;
			}
		}
#else
		self.gController = [GCController controllers].firstObject;
#endif
		// TODO: ADd multi player  using gController.playerIndex and iterate all controllers

		if (self.gController.extendedGamepad) {
			[self.gController.extendedGamepad.buttonA setValueChangedHandler:^(GCControllerButtonInput *button, float value, BOOL pressed) {
				if (pressed && value >= 0.1) {
					kcode[0] &= ~(DC_BTN_A);
				} else {
					kcode[0] |= (DC_BTN_A);
				}
			}];
			[self.gController.extendedGamepad.buttonB setValueChangedHandler:^(GCControllerButtonInput *button, float value, BOOL pressed) {
				if (pressed && value >= 0.1) {
					kcode[0] &= ~(DC_BTN_B);
				} else {
					kcode[0] |= (DC_BTN_B);
				}
			}];
			[self.gController.extendedGamepad.buttonX setValueChangedHandler:^(GCControllerButtonInput *button, float value, BOOL pressed) {
				if (pressed && value >= 0.1) {
					kcode[0] &= ~(DC_BTN_X);
				} else {
					kcode[0] |= (DC_BTN_X);
				}
			}];
			[self.gController.extendedGamepad.buttonY setValueChangedHandler:^(GCControllerButtonInput *button, float value, BOOL pressed) {
				if (pressed && value >= 0.1) {
					kcode[0] &= ~(DC_BTN_Y);
				} else {
					kcode[0] |= (DC_BTN_Y);
				}
			}];
			[self.gController.extendedGamepad.rightTrigger setValueChangedHandler:^(GCControllerButtonInput *button, float value, BOOL pressed) {
                                 if (pressed) {
					 rt[0] = (255);
				 } else {
					 rt[0] = (0);
				 }		 
                        }];
			[self.gController.extendedGamepad.leftTrigger setValueChangedHandler:^(GCControllerButtonInput *button, float value, BOOL pressed) {
                                 if (pressed) {
					 lt[0] = (255);
				 } else {
					 lt[0] = (0);
				 }
                        }];
			
			// Either trigger for start
			[self.gController.extendedGamepad.rightShoulder setValueChangedHandler:^(GCControllerButtonInput *button, float value, BOOL pressed) {
				if (pressed && value >= 0.1) {
					kcode[0] &= ~(DC_BTN_START);
				} else {
					kcode[0] |= (DC_BTN_START);
				}
			}];
			[self.gController.extendedGamepad.leftShoulder setValueChangedHandler:^(GCControllerButtonInput *button, float value, BOOL pressed) {
				if (pressed && value >= 0.1) {
					kcode[0] &= ~(DC_BTN_START);
				} else {
					kcode[0] |= (DC_BTN_START);
				}
			}];
			[self.gController.extendedGamepad.dpad setValueChangedHandler:^(GCControllerDirectionPad *dpad, float xValue, float yValue){
				if (dpad.right.isPressed) {
					kcode[0] &= ~(DC_DPAD_RIGHT);
				} else {
					kcode[0] |= (DC_DPAD_RIGHT);
				}
				if (dpad.left.isPressed) {
					kcode[0] &= ~(DC_DPAD_LEFT);
				} else {
					kcode[0] |= (DC_DPAD_LEFT);
				}
				if (dpad.up.isPressed) {
					kcode[0] &= ~(DC_DPAD_UP);
				} else {
					kcode[0] |= (DC_DPAD_UP);
				}
				if (dpad.down.isPressed) {
					kcode[0] &= ~(DC_DPAD_DOWN);
				} else {
					kcode[0] |= (DC_DPAD_DOWN);
				}
			}];
			[self.gController.extendedGamepad.leftThumbstick.xAxis setValueChangedHandler:^(GCControllerAxisInput *axis, float value){
				s8 v=(s8)(value*127); //-127 ... + 127 range

				NSLog(@"Joy X: %i", v);
				joyx[0] = v;
			}];
			[self.gController.extendedGamepad.leftThumbstick.yAxis setValueChangedHandler:^(GCControllerAxisInput *axis, float value){
				s8 v=(s8)(value*127 * - 1); //-127 ... + 127 range

				NSLog(@"Joy Y: %i", v);
				joyy[0] = v;
			}];

			// TODO: Right dpad
//			[self.gController.extendedGamepad.rightThumbstick.xAxis setValueChangedHandler:^(GCControllerAxisInput *axis, float value){
//				s8 v=(s8)(value*127); //-127 ... + 127 range
//
//				NSLog(@"Joy X: %i", v);
//				joyx[0] = v;
//			}];
//			[self.gController.extendedGamepad.rightThumbstick.yAxis setValueChangedHandler:^(GCControllerAxisInput *axis, float value){
//				s8 v=(s8)(value*127 * - 1); //-127 ... + 127 range
//
//				NSLog(@"Joy Y: %i", v);
//				joyy[0] = v;
//			}];
		}
        else if (self.gController.gamepad) {
            [self.gController.gamepad.buttonA setValueChangedHandler:^(GCControllerButtonInput *button, float value, BOOL pressed) {
				if (pressed && value >= 0.1) {
					[self.emuView handleKeyDown:self.controllerView.img_abxy_a];
				} else {
					[self.emuView handleKeyUp:self.controllerView.img_abxy_a];
				}
            }];
            [self.gController.gamepad.buttonB setValueChangedHandler:^(GCControllerButtonInput *button, float value, BOOL pressed) {
				if (pressed && value >= 0.1) {
					[self.emuView handleKeyDown:self.controllerView.img_abxy_b];
				} else {
					[self.emuView handleKeyUp:self.controllerView.img_abxy_b];
				}
            }];
            [self.gController.gamepad.buttonX setValueChangedHandler:^(GCControllerButtonInput *button, float value, BOOL pressed) {
				if (pressed && value >= 0.1) {
					[self.emuView handleKeyDown:self.controllerView.img_abxy_x];
				} else {
					[self.emuView handleKeyUp:self.controllerView.img_abxy_x];
				}
            }];
            [self.gController.gamepad.buttonY setValueChangedHandler:^(GCControllerButtonInput *button, float value, BOOL pressed) {
				if (pressed && value >= 0.1) {
					[self.emuView handleKeyDown:self.controllerView.img_abxy_y];
				} else {
					[self.emuView handleKeyUp:self.controllerView.img_abxy_y];
				}
            }];
            [self.gController.gamepad.dpad setValueChangedHandler:^(GCControllerDirectionPad *dpad, float xValue, float yValue){
				if (dpad.right.isPressed) {
					[self.emuView handleKeyDown:self.controllerView.img_dpad_r];
				} else {
					[self.emuView handleKeyUp:self.controllerView.img_dpad_r];
				}
				if (dpad.left.isPressed) {
					[self.emuView handleKeyDown:self.controllerView.img_dpad_l];
				} else {
					[self.emuView handleKeyUp:self.controllerView.img_dpad_l];
				}
				if (dpad.up.isPressed) {
					[self.emuView handleKeyDown:self.controllerView.img_dpad_u];
				} else {
					[self.emuView handleKeyUp:self.controllerView.img_dpad_u];
				}
				if (dpad.down.isPressed) {
					[self.emuView handleKeyDown:self.controllerView.img_dpad_d];
				} else {
					[self.emuView handleKeyUp:self.controllerView.img_dpad_d];
				}
            }];

			[self.gController.gamepad.rightShoulder setValueChangedHandler:^(GCControllerButtonInput *button, float value, BOOL pressed) {
				if (pressed && value >= 0.1) {
					[self.emuView handleKeyDown:self.controllerView.img_rt];
				} else {
					[self.emuView handleKeyUp:self.controllerView.img_rt];
				}
			}];

			[self.gController.gamepad.leftShoulder setValueChangedHandler:^(GCControllerButtonInput *button, float value, BOOL pressed) {
				if (pressed && value >= 0.1) {
					[self.emuView handleKeyDown:self.controllerView.img_lt];
				} else {
					[self.emuView handleKeyUp:self.controllerView.img_lt];
				}
			}];

            //Add controller pause handler here
        }
    } else {
        self.gController = nil;
		[self.controllerView showController:self.view];
    }
}


- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
//    kdebug_signpost_start(10, 0, 0, 0, 0);
	screen_width = view.drawableWidth;
    screen_height = view.drawableHeight;

    glClearColor(0.65f, 0.65f, 0.65f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

	while(!rend_single_frame()) ;

#if USE_CRT_SHADER
	glUseProgram(crtShaderProgram);
	glUniform4f(crtUniform_DisplayRect, 0,0, 320, 640); // TODO: Correct sizes?
	glUniform1i(crtUniform_EmulatedImage, 0);
	glUniform2f(crtUniform_EmulatedImageSize, 320, 640);
	float finalResWidth = view.drawableWidth;
	float finalResHeight = view.drawableHeight;
	glUniform2f(crtUniform_FinalRes, finalResWidth, finalResHeight);
#endif
//	kdebug_signpost_end(10, 0, 0, 0, 0);
}

/*** CRT Shader borrowed from BrainDX for Provenance app ***/
- (void)setupCRTShader
{
	crtFragmentShader = [self compileShaderResource:@"crt_fragment" ofType:GL_FRAGMENT_SHADER];
	crtShaderProgram = [self linkVertexShader:defaultVertexShader withFragmentShader:crtFragmentShader];
	crtUniform_DisplayRect = glGetUniformLocation(crtShaderProgram, "DisplayRect");
	crtUniform_EmulatedImage = glGetUniformLocation(crtShaderProgram, "EmulatedImage");
	crtUniform_EmulatedImageSize = glGetUniformLocation(crtShaderProgram, "EmulatedImageSize");
	crtUniform_FinalRes = glGetUniformLocation(crtShaderProgram, "FinalRes");
}

- (GLuint)compileShaderResource:(NSString*)shaderResourceName ofType:(GLenum)shaderType
{
	NSString* shaderPath = [[NSBundle mainBundle] pathForResource:shaderResourceName ofType:@"glsl"];
	if ( shaderPath == NULL )
	{
		NSLog(@"No shader path");
		return 0;
	}

	NSString* shaderSource = [NSString stringWithContentsOfFile:shaderPath encoding:NSASCIIStringEncoding error:nil];
	if ( shaderSource == NULL )
	{
		NSLog(@"No shader source");
		return 0;
	}

	const char* shaderSourceCString = [shaderSource cStringUsingEncoding:NSASCIIStringEncoding];
	if ( shaderSourceCString == NULL )
	{
		NSLog(@"Nil shaderSourceCString");
		return 0;
	}

	GLuint shader = glCreateShader( shaderType );
	if ( shader == 0 )
	{
		NSLog(@"Nil shader");
		return 0;
	}

	glShaderSource( shader, 1, &shaderSourceCString, NULL );
	glCompileShader( shader );

	GLint compiled;
	glGetShaderiv( shader, GL_COMPILE_STATUS, &compiled );
	if ( compiled == 0 )
	{
		GLint infoLogLength = 0;
		glGetShaderiv( shader, GL_INFO_LOG_LENGTH, &infoLogLength );
		if ( infoLogLength > 1 )
		{
			char* infoLog = (char*)malloc( infoLogLength );
			glGetShaderInfoLog( shader, infoLogLength, NULL, infoLog );
			printf( "Error compiling shader: %s", infoLog );
			free( infoLog );
		}

		NSLog(@"Compile fail");

		glDeleteShader( shader );
		return 0;
	}

	NSLog(@"Shader success %@", shaderResourceName);

	return shader;
}

- (GLuint)linkVertexShader:(GLuint)vertexShader withFragmentShader:(GLuint)fragmentShader
{
	GLuint shaderProgram = glCreateProgram();
	if ( shaderProgram == 0 )
	{
		return 0;
	}

	glAttachShader( shaderProgram, vertexShader );
	glAttachShader( shaderProgram, fragmentShader );

	glBindAttribLocation( shaderProgram, GLKVertexAttribPosition, "vPosition" );
	glBindAttribLocation( shaderProgram, GLKVertexAttribTexCoord0, "vTexCoord" );

	glLinkProgram( shaderProgram );

	GLint linkStatus;
	glGetProgramiv( shaderProgram, GL_LINK_STATUS, &linkStatus );
	if ( linkStatus == 0 )
	{
		GLint infoLogLength = 0;
		glGetProgramiv( shaderProgram, GL_INFO_LOG_LENGTH, &infoLogLength );
		if ( infoLogLength > 1 )
		{
			char* infoLog = (char*)malloc( infoLogLength );
			glGetProgramInfoLog( shaderProgram, infoLogLength, NULL, infoLog );
			printf( "Error linking program: %s", infoLog );
			free( infoLog );
		}

		glDeleteProgram( shaderProgram );
		return 0;
	}

	return shaderProgram;
}

@end
