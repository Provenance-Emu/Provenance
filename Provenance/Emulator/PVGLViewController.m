//
//  PVEmulatorViewController.m
//  Provenance
//
//  Created by James Addyman on 08/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import "PVGLViewController.h"
#import "PVEmulatorCore.h"
#import <QuartzCore/QuartzCore.h>

@interface PVGLViewController ()
{
	GLKVector3 vertices[8];
	GLKVector2 textureCoordinates[8];
	GLKVector3 triangleVertices[6];
	GLKVector2 triangleTexCoords[6];
	
	GLuint texture;
}

@property (nonatomic, strong) EAGLContext *glContext;
@property (nonatomic, strong) GLKBaseEffect *effect;
@end

@implementation PVGLViewController

+ (void)initialize
{
}

- (void)dealloc
{
	glDeleteTextures(1, &texture);
	self.effect = nil;
	self.glContext = nil;
	self.emulatorCore = nil;
}

- (instancetype)initWithEmulatorCore:(PVEmulatorCore *)emulatorCore
{
	if ((self = [super init]))
	{
		self.emulatorCore = emulatorCore;
	}
	
	return self;
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	[self.view setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin];
	
	[self setPreferredFramesPerSecond:60];
	
	self.glContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
	[EAGLContext setCurrentContext:self.glContext];
	
	GLKView *view = (GLKView *)self.view;
    view.context = self.glContext;
	
	self.effect = [[GLKBaseEffect alloc] init];
	
	[self setupTexture];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
	if (UIInterfaceOrientationIsLandscape([self interfaceOrientation]))
	{
		CGFloat newWidth = ([self.emulatorCore screenRect].size.width / [self.emulatorCore screenRect].size.height) * [[self.parentViewController view] bounds].size.height;
		
		[[self view] setFrame:CGRectMake(([[self.view superview] bounds].size.width - newWidth) / 2, 0, newWidth, [[self.parentViewController view] bounds].size.height)];
	}
	else
	{
		CGFloat newHeight = ([self.emulatorCore screenRect].size.height / [self.emulatorCore screenRect].size.width) * [[self.parentViewController view] bounds].size.width;
		[self.view setFrame:CGRectMake(0, 0, [[self.parentViewController view] bounds].size.width, newHeight)];
	}
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	[self.view setFrame:[[self.parentViewController view] bounds]];
	
	if (UIInterfaceOrientationIsLandscape([self interfaceOrientation]))
	{
		CGFloat newWidth = ([self.emulatorCore screenRect].size.width / [self.emulatorCore screenRect].size.height) * [[self.parentViewController view] bounds].size.height;
		
		[[self view] setFrame:CGRectMake(([[self.view superview] bounds].size.width - newWidth) / 2, 0, newWidth, [[self.parentViewController view] bounds].size.height)];
	}
	else
	{
		CGFloat newHeight = ([self.emulatorCore screenRect].size.height / [self.emulatorCore screenRect].size.width) * [[self.parentViewController view] bounds].size.width;
		[self.view setFrame:CGRectMake(0, 0, [[self.parentViewController view] bounds].size.width, newHeight)];
	}
}

- (void)setupTexture
{
	glGenTextures(1, &texture);
	glBindTexture(GL_TEXTURE_2D, texture);
	glTexImage2D(GL_TEXTURE_2D, 0, [self.emulatorCore internalPixelFormat], self.emulatorCore.bufferSize.width, self.emulatorCore.bufferSize.height, 0, [self.emulatorCore pixelFormat], [self.emulatorCore pixelType], self.emulatorCore.videoBuffer);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
	glClearColor(1.0, 1.0, 1.0, 1.0);
	glClear(GL_COLOR_BUFFER_BIT);
	
	CGSize screenSize = [self.emulatorCore screenRect].size;
	CGSize bufferSize = [self.emulatorCore bufferSize];
	
	CGFloat texWidth = (screenSize.width / bufferSize.width);
	CGFloat texHeight = (screenSize.height / bufferSize.height);
	
	vertices[0] = GLKVector3Make(-1.0, -1.0,  1.0); // Left  bottom
	vertices[1] = GLKVector3Make( 1.0, -1.0,  1.0); // Right bottom
	vertices[2] = GLKVector3Make( 1.0,  1.0,  1.0); // Right top
	vertices[3] = GLKVector3Make(-1.0,  1.0,  1.0); // Left  top

	textureCoordinates[0] = GLKVector2Make(0.0f, texHeight); // Left bottom
	textureCoordinates[1] = GLKVector2Make(texWidth, texHeight); // Right bottom
	textureCoordinates[2] = GLKVector2Make(texWidth, 0.0f); // Right top
	textureCoordinates[3] = GLKVector2Make(0.0f, 0.0f); // Left top
	
	int vertexIndices[6] = {
		// Front
		0, 1, 2,
		0, 2, 3,
	};
	
	for (int i = 0; i < 6; i++) {
		triangleVertices[i]  = vertices[vertexIndices[i]];
		triangleTexCoords[i] = textureCoordinates[vertexIndices[i]];
	}
	
	glBindTexture(GL_TEXTURE_2D, texture);
	glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, self.emulatorCore.bufferSize.width, self.emulatorCore.bufferSize.height, [self.emulatorCore pixelFormat], [self.emulatorCore pixelType], self.emulatorCore.videoBuffer);
		
	if (texture)
	{
		self.effect.texture2d0.envMode = GLKTextureEnvModeReplace;
		self.effect.texture2d0.target = GLKTextureTarget2D;
		self.effect.texture2d0.name = texture;
		self.effect.texture2d0.enabled = YES;
		self.effect.useConstantColor = YES;
	}
	
    [self.effect prepareToDraw];
    
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
