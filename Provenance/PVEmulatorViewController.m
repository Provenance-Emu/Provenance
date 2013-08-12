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

@interface PVEmulatorViewController ()
{
	uint16_t * videoBuffer;
	BOOL inited;
}

@property (nonatomic, retain) PVGenesisEmulatorCore *genesis;
@property (nonatomic, retain) EAGLContext *glContext;
@property (nonatomic, assign) GLuint gameTexture;
@property (nonatomic, retain) CADisplayLink *displayLink;

@end

@implementation PVEmulatorViewController

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	self.genesis = [[[PVGenesisEmulatorCore alloc] init] autorelease];
	NSString *gamePath = [[NSBundle mainBundle] pathForResource:@"Sonic2" ofType:@"smd"];
	[self.genesis loadFileAtPath:gamePath];
	
	self.glContext = [[[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1] autorelease];
	[EAGLContext setCurrentContext:self.glContext];
	
	GLKView *view = (GLKView *)self.view;
    view.context = self.glContext;
	inited = NO;
}

- (void)prepareOpenGL
{
    glDisable(GL_DITHER);
    glDisable(GL_ALPHA_TEST);
    glDisable(GL_BLEND);
    glDisable(GL_STENCIL_TEST);
    glDisable(GL_FOG);
    glDisable(GL_TEXTURE_2D);
    glDisable(GL_DEPTH_TEST);
	
    glGenTextures(1, &_gameTexture);
	
    glEnable(GL_TEXTURE_2D);
    glBindTexture(GL_TEXTURE_2D, [self gameTexture]);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, 256, 224, 0, GL_RGB, GL_UNSIGNED_SHORT_5_6_5, 0);
	
	const GLfloat box[] =
	{
		0.0f, 224.0f, 1.0f,
		256.0f, 224.0f, 1.0f,
		0.0f, 0.0f, 1.0f,
		256.0f, 0.0f, 1.0f
	};
	
	const GLfloat tex[] =
	{
		0.0f, 1.0f,
		1.0f, 1.0f,
		0.0f, 0.0f,
		1.0f, 0.0f
	};
	
	glEnableClientState(GL_VERTEX_ARRAY);
	glEnableClientState(GL_TEXTURE_COORD_ARRAY);
	
	glVertexPointer(3, GL_FLOAT, 0, box);
	glTexCoordPointer(2, GL_FLOAT, 0, tex);
}

- (void)update
{
	[self.genesis executeFrame];
	videoBuffer = [self.genesis videoBuffer];
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
	if (videoBuffer != NULL)
	{
		if (inited == NO)
		{
			inited = YES;
			[self prepareOpenGL];
		}
		
		glClearColor(0, 0, 0, 0);
		glClear(GL_COLOR_BUFFER_BIT);
		
		CGSize texSize = CGSizeMake(256 , 224);
		
		glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, texSize.width, texSize.height, GL_RGB, GL_UNSIGNED_SHORT_5_6_5, videoBuffer);
		
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
		
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		
		glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
		
		glActiveTexture(GL_TEXTURE0);
		glClientActiveTexture(GL_TEXTURE0);
		
		
		glMatrixMode(GL_PROJECTION);
		glLoadIdentity();
		
		glOrthof(0.0f, texSize.width * 2, texSize.height * 2, 0.0f, -1.0f, 1.0f);
		
		glMatrixMode(GL_MODELVIEW);
		glLoadIdentity();
		glViewport(0, 0, texSize.width * 2, texSize.height * 2);
		
		glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
	}
}

@end
