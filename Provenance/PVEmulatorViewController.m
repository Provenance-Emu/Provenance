//
//  PVEmulatorViewController.m
//  Provenance
//
//  Created by James Addyman on 08/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import "PVEmulatorViewController.h"
#import "PVGenesisEmulatorCore.h"
#import <QuartzCore/QuartzCore.h>

const float width = 320;
const float height = 224;
const float texWidth = 1;
const float texHeight = 1;
const GLfloat box[] = {0.0f, height, 1.0f, width, height, 1.0f, 0.0f, 0.0f, 1.0f, width, 0.0f, 1.0f};
const GLfloat tex[] = {0.0f, texHeight, texWidth, texHeight, 0.0f, 0.0f, texWidth, 0.0f};


@interface PVEmulatorViewController ()
{
	BOOL initialized;
	uint16_t *videoBuffer;
	
	GLint iOSFrameBuffer;
    GLuint GBTexture;
}

@property (nonatomic, retain) PVGenesisEmulatorCore *genesis;
@property (nonatomic, retain) EAGLContext *glContext;

@end

@implementation PVEmulatorViewController

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	initialized = NO;
	
	[self setPreferredFramesPerSecond:60];
	
	self.genesis = [[[PVGenesisEmulatorCore alloc] init] autorelease];
	NSString *gamePath = [[NSBundle mainBundle] pathForResource:@"Sonic2" ofType:@"smd"];
	[self.genesis loadFileAtPath:gamePath];
	
	videoBuffer = [self.genesis videoBuffer];
	
	[NSTimer scheduledTimerWithTimeInterval:1/[self.genesis frameInterval]
									 target:self
								   selector:@selector(runEmulator:)
								   userInfo:nil
									repeats:YES];
	
	self.glContext = [[[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1] autorelease];
	[EAGLContext setCurrentContext:self.glContext];
	
	GLKView *view = (GLKView *)self.view;
    view.context = self.glContext;
}

- (void)runEmulator:(NSTimer *)timer
{
	[self.genesis executeFrame];
}

-(void)draw
{
    if (!initialized)
    {
        initialized = YES;
        [self initGL];
    }
    
	[self renderFrame];
}

-(void)initGL
{
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &iOSFrameBuffer);
    
    glGenTextures(1, &GBTexture);
    
    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);
	
    glVertexPointer(3, GL_FLOAT, 0, box);
    glTexCoordPointer(2, GL_FLOAT, 0, tex);
    
    glClearColor(0.0, 0.0, 0.0, 0.0);
    
    glEnable(GL_TEXTURE_2D);
    glBindTexture(GL_TEXTURE_2D, GBTexture);
    [self setupTextureWithData:videoBuffer];
}

-(void)renderFrame
{
	glClearColor(0.0, 0.0, 0.0, 1.0);
	glClear(GL_COLOR_BUFFER_BIT);
    glBindFramebuffer(GL_FRAMEBUFFER, iOSFrameBuffer);
    glBindTexture(GL_TEXTURE_2D, GBTexture);
    glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, [self.genesis bufferSize].width, [self.genesis bufferSize].height, GL_RGB, GL_UNSIGNED_SHORT_5_6_5, videoBuffer);
    [self renderQuadWithViewportWidth:320 * 2 height:224 * 2];
}

-(void)setupTextureWithData: (GLvoid*) data
{
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, [self.genesis bufferSize].width, [self.genesis bufferSize].height, 0, GL_RGB, GL_UNSIGNED_SHORT_5_6_5, videoBuffer);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
}

-(void)renderQuadWithViewportWidth:(int)viewportWidth height:(int)viewportHeight
{
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
	glOrthof(0.0f, [self.genesis screenRect].size.width / 2, [self.genesis screenRect].size.height / 2, 0.0f, -1.0f, 1.0f);
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    glViewport(0, 0, viewportWidth, viewportHeight);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
	[self draw];
}

@end
