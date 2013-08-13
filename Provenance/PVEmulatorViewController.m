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

static GLKVector3 vertices[8];
static GLKVector2 textureCoordinates[8];
static GLKVector3 triangleVertices[6];
static GLKVector2 triangleTexCoords[6];
static GLKBaseEffect *effect;

@interface PVEmulatorViewController ()
{
	uint16_t *videoBuffer;
	GLuint texture;
}

@property (nonatomic, retain) PVGenesisEmulatorCore *genesis;
@property (nonatomic, retain) EAGLContext *glContext;

@end

@implementation PVEmulatorViewController

+ (void)initialize
{
	vertices[0] = GLKVector3Make(-0.5, -0.5,  0.5); // Left  bottom
	textureCoordinates[0] = GLKVector2Make(0.0f, 1.0f);
	
	vertices[1] = GLKVector3Make( 0.5, -0.5,  0.5); // Right bottom
	textureCoordinates[1] = GLKVector2Make(1.0f, 1.0f);
	
	vertices[2] = GLKVector3Make( 0.5,  0.5,  0.5); // Right top
	textureCoordinates[2] = GLKVector2Make(1.0f, 0.0f);
	
	vertices[3] = GLKVector3Make(-0.5,  0.5,  0.5); // Left  top
	textureCoordinates[3] = GLKVector2Make(0.0f, 0.0f);
	
	int vertexIndices[6] = {
		// Front
		0, 1, 2,
		0, 2, 3,
	};
	
	for (int i = 0; i < 6; i++) {
		triangleVertices[i]  = vertices[vertexIndices[i]];
		triangleTexCoords[i] = textureCoordinates[vertexIndices[i]];
	}
	
	effect = [[GLKBaseEffect alloc] init];
}


- (void)viewDidLoad
{
	[super viewDidLoad];
	
	[self setPreferredFramesPerSecond:60];
	
	self.genesis = [[[PVGenesisEmulatorCore alloc] init] autorelease];
	NSString *gamePath = [[NSBundle mainBundle] pathForResource:@"Sonic2" ofType:@"smd"];
	[self.genesis loadFileAtPath:gamePath];
	
	videoBuffer = [self.genesis videoBuffer];
	
	while (!videoBuffer)
	{
		[self.genesis executeFrame];
	}
	
	[NSTimer scheduledTimerWithTimeInterval:1/[self.genesis frameInterval]
									 target:self
								   selector:@selector(runEmulator:)
								   userInfo:nil
									repeats:YES];
	
	self.glContext = [[[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2] autorelease];
	[EAGLContext setCurrentContext:self.glContext];
	
	GLKView *view = (GLKView *)self.view;
    view.context = self.glContext;
	
	[self setupTexture];
}

- (void)runEmulator:(NSTimer *)timer
{
	[self.genesis executeFrame];
}

- (void)setupTexture
{
	glGenTextures(1, &texture);
	glBindTexture(GL_TEXTURE_2D, texture);
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, [self.genesis bufferSize].width, [self.genesis bufferSize].height, 0, GL_RGB, GL_UNSIGNED_SHORT_5_6_5, videoBuffer);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
	glClearColor(0.5, 0.5, 0.5, 0.5);
	glClear(GL_COLOR_BUFFER_BIT);
	
	glBindTexture(GL_TEXTURE_2D, texture);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, [self.genesis bufferSize].width, [self.genesis bufferSize].height, 0, GL_RGB, GL_UNSIGNED_SHORT_5_6_5, videoBuffer);
	
	CGRect screenBound = [[UIScreen mainScreen] bounds];
    CGSize screenSize = screenBound.size;
    CGFloat screenWidth = screenSize.width;
    CGFloat screenHeight = screenSize.height;
	
    effect.transform.modelviewMatrix =  GLKMatrix4MakeScale(screenWidth, 224, 1);
    effect.transform.projectionMatrix = GLKMatrix4MakeOrtho(-1 * screenWidth/2, screenWidth/2, -screenHeight/2, screenHeight/2, -1, 1);
	
	if (texture)
	{
		effect.texture2d0.envMode = GLKTextureEnvModeReplace;
		effect.texture2d0.target = GLKTextureTarget2D;
		effect.texture2d0.name = texture;
		effect.texture2d0.enabled = YES;
		effect.useConstantColor = YES;
	}
	
    [effect prepareToDraw];
    
    glDisable(GL_DEPTH_TEST);
    glDisable(GL_CULL_FACE);
    
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, 0, triangleVertices);
    
	if (texture)
	{
        glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
        glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, 0, triangleTexCoords);
    }
	
    glDrawArrays(GL_TRIANGLES, 0, 6);
	
	if (texture)
	{
        glDisableVertexAttribArray(GLKVertexAttribTexCoord0);
	}
	
    glDisableVertexAttribArray(GLKVertexAttribPosition);
}

@end
