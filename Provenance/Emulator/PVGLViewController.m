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

#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>

@interface PVGLViewController() <PVRenderDelegate>
{
	GLKVector3 vertices[8];
	GLKVector2 textureCoordinates[8];
	GLKVector3 triangleVertices[6];
	GLKVector2 triangleTexCoords[6];
	
	GLuint texture;
    
    // Alternate-thread rendering
    GLuint RenderBuffer;
    EAGLContext*          _alternateContext;
}

@property (nonatomic, strong) EAGLContext *glContext;
@property (nonatomic, strong) GLKBaseEffect *effect;
@end

@implementation PVGLViewController

EAGLContext* CreateBestEAGLContext()
{
    EAGLContext *context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
    if (context == nil) {
        context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    }
    return context;
}

+ (void)initialize
{
}

- (void)dealloc
{
	glDeleteTextures(1, &texture);
	self.effect = nil;
	self.glContext = nil;
	self.emulatorCore = nil;
    _alternateContext = nil;
}

- (instancetype)initWithEmulatorCore:(PVEmulatorCore *)emulatorCore
{
	if ((self = [super init]))
	{
		self.emulatorCore = emulatorCore;
        if([emulatorCore rendersToOpenGL]) {
            emulatorCore.renderDelegate = self;
        }
	}
	
	return self;
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	[self setPreferredFramesPerSecond:60];
	
    self.glContext = CreateBestEAGLContext();
	[EAGLContext setCurrentContext:self.glContext];
	
	GLKView *view = (GLKView *)self.view;
    view.context = self.glContext;
	
	self.effect = [[GLKBaseEffect alloc] init];
	
	[self setupTexture];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];

    if (!CGRectIsEmpty([self.emulatorCore screenRect]))
    {
        CGSize aspectSize = [self.emulatorCore aspectSize];
        CGFloat ratio = 0;
        if (aspectSize.width > aspectSize.height) {
            ratio = aspectSize.width / aspectSize.height;
        } else {
            ratio = aspectSize.height / aspectSize.width;
        }

        CGSize parentSize = CGSizeZero;
        if ([self parentViewController])
        {
            parentSize = [[[self parentViewController] view] bounds].size;
        }
        else
        {
            parentSize = [[self.view window] bounds].size;
        }


        CGFloat height = 0;
        CGFloat width = 0;

        if (parentSize.width > parentSize.height) {
            height = parentSize.height;
            width = roundf(height * ratio);
            if (width > parentSize.width)
            {
                width = parentSize.width;
                height = roundf(width / ratio);
            }
        } else {
            width = parentSize.width;
            height = roundf(width / ratio);
            if (height > parentSize.height)
            {
                height = parentSize.width;
                width = roundf(height / ratio);
            }
        }

        CGPoint origin = CGPointMake(roundf((parentSize.width - width) / 2.0), 0);
        if (([self.traitCollection userInterfaceIdiom] == UIUserInterfaceIdiomPhone) && (parentSize.height > parentSize.width))
        {
            origin.y = 40.0f; // directly below menu button at top of screen
        }
        else
        {
            origin.y = roundf((parentSize.height - height) / 2.0); // centered
        }

        [[self view] setFrame:CGRectMake(origin.x, origin.y, width, height)];
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
    void (^renderBlock)() = ^() {
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

//        if (texture)
//        {
//            self.effect.texture2d0.envMode = GLKTextureEnvModeReplace;
//            self.effect.texture2d0.target = GLKTextureTarget2D;
//            self.effect.texture2d0.name = texture;
//            self.effect.texture2d0.enabled = YES;
//            self.effect.useConstantColor = YES;
//        }

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
    };

    if (self.emulatorCore.isSpeedModified)
    {
        renderBlock();
    }
    else
    {
        @synchronized(self.emulatorCore)
        {
//            renderBlock();
        }
    }
}

#pragma mark - PVRenderDelegate protocol methods

- (void)setEnableVSync:(BOOL)flag
{
//    [self updateEnableVSync:flag];
}

- (void)willExecute
{
    if([_emulatorCore rendersToOpenGL]) {
        [self beginDrawToIOSurface];
    }
}

- (void)didExecute
{
    [self endDrawToIOSurface];
}

- (void)willRenderOnAlternateThread
{
    if(_alternateContext == NULL) {
        _alternateContext = [[EAGLContext alloc] initWithAPI:_glContext.API sharegroup:[_glContext sharegroup]];

        if (!_alternateContext || ![EAGLContext setCurrentContext:_alternateContext]) {
            // Handle errors here
            NSLog(@"Failed to create alternate context");
        }
    }
}

- (void)startRenderingOnAlternateThread
{
    [self renderStart];
    
    
}

- (void)willRenderFrameOnAlternateThread
{

}

- (void)didRenderFrameOnAlternateThread
{
    [self renderEnd];
    
    if([_alternateContext presentRenderbuffer:GL_RENDERBUFFER] == NO)
    {
        NSLog(@"SwapBuffers: [_alternateContext presentRenderbuffer:GL_RENDERBUFFER_OES] failed");
    }
}

#pragma mark - gl

- (void)renderStart {
//    @synchronized(self.emulatorCore) {
        // 1. Ensure context A is not bound to the texture
        [EAGLContext setCurrentContext:_glContext];
        glBindTexture(GL_TEXTURE_2D, 0);
        
        // 2. Call flush on context A
        glFlush();
        
        // 3. Modify the texture on context B
        [EAGLContext setCurrentContext:_alternateContext];
        glBindTexture(GL_TEXTURE_2D, texture);
//    }
}

-(void)renderEnd {
//    @synchronized(self.emulatorCore) {
    // 4. Call flush on context B
        glFlush();
        
        // 5. Rebind the texture on context A
        [EAGLContext setCurrentContext:_glContext];
        glBindTexture(GL_TEXTURE_2D, texture);
//    }
}

- (void)beginDrawToIOSurface
{

    [self renderStart];
//    [EAGLContext setCurrentContext:_glContext];
    
    GLenum status = glGetError();
    if(status)
    {
        NSLog(@"drawIntoIOSurface: OpenGL error %04X", status);
//        glDeleteTextures(1, &texture);
//        texture = 0;
//        
//        glDeleteRenderbuffers(1, &_depthStencilRB);
//        _depthStencilRB = 0;
    }
    
}

- (void)endDrawToIOSurface
{

    [self renderEnd];
    [_glContext presentRenderbuffer:GL_RENDERBUFFER];
//    GLKView *view = (GLKView *)self.view;
//    dispatch_sync(dispatch_get_main_queue(), ^{
//        [view display];
//    });
}
@end
