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

- (void)didMoveToParentViewController:(UIViewController *)parent
{
	[super didMoveToParentViewController:parent];
	
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
	{
		if (UIInterfaceOrientationIsLandscape([self interfaceOrientation]))
		{
			[[self view] setFrame:CGRectMake(([[self.view superview] bounds].size.width - 1024) / 2, 0, 1024, 768)];
		}
		else
		{
			[self.view setFrame:CGRectMake(0, 0, 768, 576)];
		}
	}
	else
	{
		if (UIInterfaceOrientationIsLandscape([self interfaceOrientation]))
		{
			[[self view] setFrame:CGRectMake(([[self.view superview] bounds].size.width - 427) / 2, 0, 427, 320)];
		}
		else
		{
			[self.view setFrame:CGRectMake(0, 0, 320, 240)];
		}
	}
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
	{
		[UIView animateWithDuration:duration
							  delay:0.0
							options:UIViewAnimationOptionBeginFromCurrentState
						 animations:^{
							 [[self view] setFrame:CGRectMake(([[self.view superview] bounds].size.width - 1024) / 2, 0, 1024, 768)];
						 }
						 completion:^(BOOL finished) {
						 }];
	}
	else
	{
		[UIView animateWithDuration:duration
							  delay:0.0
							options:UIViewAnimationOptionBeginFromCurrentState
						 animations:^{
							 [[self view] setFrame:CGRectMake(([[self.view superview] bounds].size.width - 427) / 2, 0, 427, 320)];
						 }
						 completion:^(BOOL finished) {
						 }];
	}
}

- (void)setupTexture
{
	glGenTextures(1, &texture);
	glBindTexture(GL_TEXTURE_2D, texture);
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, self.emulatorCore.bufferSize.width, self.emulatorCore.bufferSize.height, 0, GL_RGB, GL_UNSIGNED_SHORT_5_6_5, self.emulatorCore.videoBuffer);
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
	glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, screenSize.width, screenSize.height, GL_RGB, GL_UNSIGNED_SHORT_5_6_5, self.emulatorCore.videoBuffer);
		
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
