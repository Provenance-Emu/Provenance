//
//  PVGLViewController.m
//  Provenance
//
//  Created by James Addyman on 08/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import "PVGLViewController.h"
#import <PVSupport/PVEmulatorCore.h>
#import <PVSupport/DebugUtils.h>
#import "Provenance-Swift.h"
#import <QuartzCore/QuartzCore.h>

struct PVVertex
{
    GLfloat x, y, z;
    GLfloat u, v;
};

#define BUFFER_OFFSET(x) ((char *)NULL + (x))

struct RenderSettings {
    BOOL crtFilterEnabled;
    BOOL smoothingEnabled;
} RenderSettings;

@interface PVGLViewController () <PVRenderDelegate>
{
    GLuint alternateThreadFramebufferBack;
    GLuint alternateThreadFramebufferFront;
    GLuint alternateThreadColorTextureBack;
    GLuint alternateThreadColorTextureFront;
    GLuint alternateThreadDepthRenderbuffer;
    
    GLuint blitFragmentShader;
    GLuint blitShaderProgram;
    int blitUniform_EmulatedImage;
    
    GLuint crtFragmentShader;
    GLuint crtShaderProgram;
    int crtUniform_DisplayRect;
    int crtUniform_EmulatedImage;
    int crtUniform_EmulatedImageSize;
    int crtUniform_FinalRes;
    
    GLuint defaultVertexShader;
    
    GLuint indexVBO, vertexVBO;
    
	GLuint texture;
    
    struct RenderSettings renderSettings;
}

@property (nonatomic, strong) EAGLContext *glContext;
@property (nonatomic, strong) EAGLContext *alternateThreadGLContext;
@property (nonatomic, strong) EAGLContext *alternateThreadBufferCopyGLContext;
@property (nonatomic, assign) GLESVersion glesVersion;

@end

@implementation PVGLViewController

+ (void)initialize
{
}

- (void)dealloc
{
    if (alternateThreadDepthRenderbuffer > 0)
    {
        glDeleteRenderbuffers(1, &alternateThreadDepthRenderbuffer);
    }
    if (alternateThreadColorTextureFront > 0)
    {
        glDeleteTextures(1, &alternateThreadColorTextureFront);
    }
    if (alternateThreadColorTextureBack > 0)
    {
        glDeleteTextures(1, &alternateThreadColorTextureBack);
    }
    if (alternateThreadFramebufferBack > 0)
    {
        glDeleteFramebuffers(1, &alternateThreadFramebufferBack);
    }
    if (alternateThreadFramebufferFront > 0)
    {
        glDeleteFramebuffers(1, &alternateThreadFramebufferFront);
    }
    if (crtShaderProgram > 0)
    {
        glDeleteProgram(crtShaderProgram);
    }
    if (crtFragmentShader > 0)
    {
        glDeleteShader(crtFragmentShader);
    }
    if (blitShaderProgram > 0)
    {
        glDeleteProgram(blitShaderProgram);
    }
    if (blitFragmentShader > 0)
    {
        glDeleteShader(blitFragmentShader);
    }
    if (defaultVertexShader > 0)
    {
        glDeleteShader(defaultVertexShader);
    }
    glDeleteTextures(1, &texture);
    
    [[PVSettingsModel sharedInstance] removeObserver:self forKeyPath:@"crtFilterEnabled"];
    [[PVSettingsModel sharedInstance] removeObserver:self forKeyPath:@"imageSmoothing"];
}

- (instancetype)initWithEmulatorCore:(PVEmulatorCore *)emulatorCore
{
	if ((self = [super init]))
	{
		self.emulatorCore = emulatorCore;
        if ([self.emulatorCore rendersToOpenGL])
        {
            self.emulatorCore.renderDelegate = self;
        }
        
        renderSettings.crtFilterEnabled = [[PVSettingsModel sharedInstance] crtFilterEnabled];
        renderSettings.smoothingEnabled = [[PVSettingsModel sharedInstance] imageSmoothing];
        
        [[PVSettingsModel sharedInstance] addObserver:self forKeyPath:@"crtFilterEnabled" options:NSKeyValueObservingOptionNew context:nil];
        [[PVSettingsModel sharedInstance] addObserver:self forKeyPath:@"imageSmoothing" options:NSKeyValueObservingOptionNew context:nil];
	}

	return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"crtFilterEnabled"]) {
        renderSettings.crtFilterEnabled = [[PVSettingsModel sharedInstance] crtFilterEnabled];
    } else if ([keyPath isEqualToString:@"imageSmoothing"]) {
        renderSettings.smoothingEnabled = [[PVSettingsModel sharedInstance] imageSmoothing];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)viewDidLoad
{
	[super viewDidLoad];

	[self setPreferredFramesPerSecond:60];

    self.glContext = [self bestContext];

    if (self.glContext == nil) {
        // TODO: Alert NO gl here
        return;
    }

    ILOG(@"Initiated GLES version %lu", (unsigned long)self.glContext.API);

	[EAGLContext setCurrentContext:self.glContext];

	GLKView *view = (GLKView *)self.view;
    view.context = self.glContext;
    
    [self setupVBOs];
	[self setupTexture];
    defaultVertexShader = [self compileShaderResource:@"shaders/default/default_vertex" ofType:GL_VERTEX_SHADER];
    [self setupBlitShader];
    [self setupCRTShader];
    
    alternateThreadFramebufferBack = 0;
    alternateThreadFramebufferFront = 0;
    alternateThreadColorTextureBack = 0;
    alternateThreadColorTextureFront = 0;
    alternateThreadDepthRenderbuffer = 0;
}

-(EAGLContext*)bestContext {
    EAGLContext* context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
    self.glesVersion = GLESVersion3;
    if (context == nil)
    {
        context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        self.glesVersion = GLESVersion2;
        if (context == nil) {
            context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
            self.glesVersion = GLESVersion1;
        }
    }

    return context;
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    UIEdgeInsets parentSafeAreaInsets = UIEdgeInsetsZero;
    if (@available(iOS 11.0, tvOS 11.0, *)) {
        parentSafeAreaInsets = self.parentViewController.view.safeAreaInsets;
    }
    
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
            origin.y = parentSafeAreaInsets.top + 40.0f; // directly below menu button at top of screen
        }
        else
        {
            origin.y = roundf((parentSize.height - height) / 2.0); // centered
        }

        [[self view] setFrame:CGRectMake(origin.x, origin.y, width, height)];
    }
}

- (GLuint)compileShaderResource:(NSString*)shaderResourceName ofType:(GLenum)shaderType
{
    NSString* shaderPath = [[NSBundle mainBundle] pathForResource:shaderResourceName ofType:@"glsl"];
    if ( shaderPath == NULL )
    {
        return 0;
    }
    
    NSString* shaderSource = [NSString stringWithContentsOfFile:shaderPath encoding:NSASCIIStringEncoding error:nil];
    if ( shaderSource == NULL )
    {
        return 0;
    }
    
    const char* shaderSourceCString = [shaderSource cStringUsingEncoding:NSASCIIStringEncoding];
    if ( shaderSourceCString == NULL )
    {
        return 0;
    }
    
    GLuint shader = glCreateShader( shaderType );
    if ( shader == 0 )
    {
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
        
        glDeleteShader( shader );
        return 0;
    }
    
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

- (void)setupBlitShader
{
    blitFragmentShader = [self compileShaderResource:@"shaders/blit/blit_fragment" ofType:GL_FRAGMENT_SHADER];
    blitShaderProgram = [self linkVertexShader:defaultVertexShader withFragmentShader:blitFragmentShader];
    blitUniform_EmulatedImage = glGetUniformLocation(blitShaderProgram, "EmulatedImage");
}

- (void)setupCRTShader
{
    crtFragmentShader = [self compileShaderResource:@"shaders/crt/crt_fragment" ofType:GL_FRAGMENT_SHADER];
    crtShaderProgram = [self linkVertexShader:defaultVertexShader withFragmentShader:crtFragmentShader];
    crtUniform_DisplayRect = glGetUniformLocation(crtShaderProgram, "DisplayRect");
    crtUniform_EmulatedImage = glGetUniformLocation(crtShaderProgram, "EmulatedImage");
    crtUniform_EmulatedImageSize = glGetUniformLocation(crtShaderProgram, "EmulatedImageSize");
    crtUniform_FinalRes = glGetUniformLocation(crtShaderProgram, "FinalRes");
}

- (void)setupTexture
{
	glGenTextures(1, &texture);
	glBindTexture(GL_TEXTURE_2D, texture);
	glTexImage2D(GL_TEXTURE_2D, 0, [self.emulatorCore internalPixelFormat], self.emulatorCore.bufferSize.width, self.emulatorCore.bufferSize.height, 0, [self.emulatorCore pixelFormat], [self.emulatorCore pixelType], self.emulatorCore.videoBuffer);
	if (renderSettings.smoothingEnabled)
	{
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	}
	else
	{
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	}
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
}

- (void)setupVBOs
{
    glGenBuffers(1, &vertexVBO);
    [self updateVBOWithScreenRect:self.emulatorCore.screenRect andVideoBufferSize:self.emulatorCore.bufferSize];
    
    GLushort indices[6] = { 0, 1, 2, 0, 2, 3 };
    glGenBuffers(1, &indexVBO);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexVBO);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
}

- (void)updateVBOWithScreenRect:(CGRect)screenRect andVideoBufferSize:(CGSize)videoBufferSize
{
    GLfloat texLeft = screenRect.origin.x / videoBufferSize.width;
    GLfloat texTop = screenRect.origin.y / videoBufferSize.height;
    GLfloat texRight = ( screenRect.origin.x + screenRect.size.width ) / videoBufferSize.width;
    GLfloat texBottom = ( screenRect.origin.y + screenRect.size.height ) / videoBufferSize.height;
    if ([self.emulatorCore rendersToOpenGL])
    {
        // Rendered textures are flipped upside down
        texTop = ( screenRect.origin.y + screenRect.size.height ) / videoBufferSize.height;
        texBottom = screenRect.origin.y / videoBufferSize.height;
    }
    
    struct PVVertex quadVertices[4] =
    {
        { -1.0f, -1.0f, 1.0f, texLeft, texBottom},
        {1.0f, -1.0f, 1.0f, texRight, texBottom},
        {1.0f, 1.0f, 1.0f, texRight, texTop},
        {-1.0f, 1.0f, 1.0f, texLeft, texTop}
    };
    
    glBindBuffer(GL_ARRAY_BUFFER, vertexVBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(quadVertices), quadVertices, GL_DYNAMIC_DRAW);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    __block CGRect screenRect;
    __block const void* videoBuffer;
    __block GLenum videoBufferPixelFormat;
    __block GLenum videoBufferPixelType;
    __block CGSize videoBufferSize;
    
    void (^fetchVideoBuffer)(void) = ^()
    {
        screenRect = [self.emulatorCore screenRect];
        videoBufferPixelFormat = [self.emulatorCore pixelFormat];
        videoBufferPixelType = [self.emulatorCore pixelType];
        videoBufferSize = [self.emulatorCore bufferSize];
        videoBuffer = [self.emulatorCore videoBuffer];
    };

    MAKEWEAK(self);

    void (^renderBlock)(void) = ^()
    {
        MAKESTRONG(self);

        glClearColor(1.0, 1.0, 1.0, 1.0);
        glClear(GL_COLOR_BUFFER_BIT);
        
        GLuint frontBufferTex;
        if ([self.emulatorCore rendersToOpenGL])
        {
            frontBufferTex = strongself->alternateThreadColorTextureFront;
            [self.emulatorCore.frontBufferLock lock];
        }
        else
        {
            glBindTexture(GL_TEXTURE_2D, strongself->texture);
            glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, videoBufferSize.width, videoBufferSize.height, videoBufferPixelFormat, videoBufferPixelType, videoBuffer);
            frontBufferTex = strongself->texture;
        }
        
        if (frontBufferTex)
        {
            glActiveTexture(GL_TEXTURE0);
            glBindTexture(GL_TEXTURE_2D, frontBufferTex);
        }
        
        if (strongself->renderSettings.crtFilterEnabled)
        {
            glUseProgram(strongself->crtShaderProgram);
            glUniform4f(strongself->crtUniform_DisplayRect, screenRect.origin.x, screenRect.origin.y, screenRect.size.width, screenRect.size.height);
            glUniform1i(strongself->crtUniform_EmulatedImage, 0);
            glUniform2f(strongself->crtUniform_EmulatedImageSize, videoBufferSize.width, videoBufferSize.height);
            float finalResWidth = view.drawableWidth;
            float finalResHeight = view.drawableHeight;
            glUniform2f(strongself->crtUniform_FinalRes, finalResWidth, finalResHeight);
        }
        else
        {
            glUseProgram(strongself->blitShaderProgram);
            glUniform1i(strongself->blitUniform_EmulatedImage, 0);
        }
        
        glDisable(GL_DEPTH_TEST);
        glDisable(GL_CULL_FACE);
        
        [self updateVBOWithScreenRect:screenRect andVideoBufferSize:videoBufferSize];
        
        glBindBuffer(GL_ARRAY_BUFFER, strongself->vertexVBO);
        
        glEnableVertexAttribArray(GLKVertexAttribPosition);
        glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(struct PVVertex), BUFFER_OFFSET(0));
        
        glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
        glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, sizeof(struct PVVertex), BUFFER_OFFSET(12));
        
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, strongself->indexVBO);
        glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_SHORT, NULL);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
        
        glDisableVertexAttribArray(GLKVertexAttribTexCoord0);
        glDisableVertexAttribArray(GLKVertexAttribPosition);
        
        glBindTexture(GL_TEXTURE_2D, 0);
        
        if ([strongself->_emulatorCore rendersToOpenGL])
        {
            glFlush();
            [strongself->_emulatorCore.frontBufferLock unlock];
        }
    };
    
    if ([self.emulatorCore rendersToOpenGL])
    {
        if ((!self.emulatorCore.isSpeedModified && ![self.emulatorCore isEmulationPaused]) || self.emulatorCore.isFrontBufferReady)
        {
            [self.emulatorCore.frontBufferCondition lock];
            while (!self.emulatorCore.isFrontBufferReady && ![self.emulatorCore isEmulationPaused]) [self.emulatorCore.frontBufferCondition wait];
            BOOL isFrontBufferReady = self.emulatorCore.isFrontBufferReady;
            [self.emulatorCore.frontBufferCondition unlock];
            if (isFrontBufferReady)
            {
                fetchVideoBuffer();
                renderBlock();
                [self.emulatorCore.frontBufferCondition lock];
                [self.emulatorCore setIsFrontBufferReady:NO];
                [self.emulatorCore.frontBufferCondition signal];
                [self.emulatorCore.frontBufferCondition unlock];
            }
        }
    }
    else
    {
        if (self.emulatorCore.isSpeedModified)
        {
            fetchVideoBuffer();
            renderBlock();
        }
        else
        {
            if (self.emulatorCore.isDoubleBuffered)
            {
                [self.emulatorCore.frontBufferCondition lock];
                while (!self.emulatorCore.isFrontBufferReady && ![self.emulatorCore isEmulationPaused]) [self.emulatorCore.frontBufferCondition wait];
                [self.emulatorCore setIsFrontBufferReady:NO];
                [self.emulatorCore.frontBufferLock lock];
                fetchVideoBuffer();
                renderBlock();
                [self.emulatorCore.frontBufferLock unlock];
                [self.emulatorCore.frontBufferCondition unlock];
            }
            else
            {
                @synchronized(self.emulatorCore)
                {
                    fetchVideoBuffer();
                    renderBlock();
                }
            }
        }
    }
}

#pragma mark - PVRenderDelegate protocol methods

- (void)startRenderingOnAlternateThread
{
    self.emulatorCore.glesVersion = self.glesVersion;
    self.alternateThreadBufferCopyGLContext = [[EAGLContext alloc] initWithAPI:[self.glContext API] sharegroup:[self.glContext sharegroup]];
    [EAGLContext setCurrentContext:self.alternateThreadBufferCopyGLContext];
    
    if (alternateThreadFramebufferFront == 0)
    {
        glGenFramebuffers(1, &alternateThreadFramebufferFront);
    }
    glBindFramebuffer(GL_FRAMEBUFFER, alternateThreadFramebufferFront);
    
    if (alternateThreadColorTextureFront == 0)
    {
        glGenTextures(1, &alternateThreadColorTextureFront);
        glBindTexture(GL_TEXTURE_2D, alternateThreadColorTextureFront);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        NSAssert( !((unsigned int)self.emulatorCore.bufferSize.width & ((unsigned int)self.emulatorCore.bufferSize.width - 1)), @"Emulator buffer width is not a power of two!" );
        NSAssert( !((unsigned int)self.emulatorCore.bufferSize.height & ((unsigned int)self.emulatorCore.bufferSize.height - 1)), @"Emulator buffer height is not a power of two!" );
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, self.emulatorCore.bufferSize.width, self.emulatorCore.bufferSize.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
        glBindTexture(GL_TEXTURE_2D, 0);
    }
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, alternateThreadColorTextureFront, 0);
    NSAssert(glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE, @"Front framebuffer incomplete!");
    
    glActiveTexture(GL_TEXTURE0);
    glEnable(GL_TEXTURE_2D);
    glUseProgram(blitShaderProgram);
    glUniform1i(blitUniform_EmulatedImage, 0);
    
    self.alternateThreadGLContext = [[EAGLContext alloc] initWithAPI:[self.glContext API] sharegroup:[self.glContext sharegroup]];
    [EAGLContext setCurrentContext:self.alternateThreadGLContext];
    
    // Setup framebuffer
    if (alternateThreadFramebufferBack == 0)
    {
        glGenFramebuffers(1, &alternateThreadFramebufferBack);
    }
    glBindFramebuffer(GL_FRAMEBUFFER, alternateThreadFramebufferBack);
    
    // Setup color textures to render into
    if (alternateThreadColorTextureBack == 0)
    {
        glGenTextures(1, &alternateThreadColorTextureBack);
        glBindTexture(GL_TEXTURE_2D, alternateThreadColorTextureBack);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        NSAssert( !((unsigned int)self.emulatorCore.bufferSize.width & ((unsigned int)self.emulatorCore.bufferSize.width - 1)), @"Emulator buffer width is not a power of two!" );
        NSAssert( !((unsigned int)self.emulatorCore.bufferSize.height & ((unsigned int)self.emulatorCore.bufferSize.height - 1)), @"Emulator buffer height is not a power of two!" );
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, self.emulatorCore.bufferSize.width, self.emulatorCore.bufferSize.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
        glBindTexture(GL_TEXTURE_2D, 0);
    }
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, alternateThreadColorTextureBack, 0);
    
    // Setup depth buffer
    if (alternateThreadDepthRenderbuffer == 0)
    {
        glGenRenderbuffers(1, &alternateThreadDepthRenderbuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, alternateThreadDepthRenderbuffer);
        glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, self.emulatorCore.bufferSize.width, self.emulatorCore.bufferSize.height);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, alternateThreadDepthRenderbuffer);
    }
    
    glViewport(self.emulatorCore.screenRect.origin.x, self.emulatorCore.screenRect.origin.y, self.emulatorCore.screenRect.size.width, self.emulatorCore.screenRect.size.height);
}

- (void)didRenderFrameOnAlternateThread
{
    // Release back buffer
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glFlush();
    
    // Blit back buffer to front buffer
    [self.emulatorCore.frontBufferLock lock];
    
    // NOTE: We switch contexts here because we don't know what state
    // the emulator core might have OpenGL in and we need to avoid
    // changing any state it's relying on. It's more efficient and
    // less verbose to switch contexts than to try do a bunch of
    // state retrieval and restoration.
    [EAGLContext setCurrentContext:self.alternateThreadBufferCopyGLContext];
    glBindFramebuffer(GL_FRAMEBUFFER, alternateThreadFramebufferFront);
    glViewport(self.emulatorCore.screenRect.origin.x, self.emulatorCore.screenRect.origin.y, self.emulatorCore.screenRect.size.width, self.emulatorCore.screenRect.size.height);
    
    glBindTexture(GL_TEXTURE_2D, alternateThreadColorTextureBack);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    
    glBindBuffer(GL_ARRAY_BUFFER, vertexVBO);
    
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(struct PVVertex), BUFFER_OFFSET(0));

    glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
    glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, sizeof(struct PVVertex), BUFFER_OFFSET(12));
    
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexVBO);
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_SHORT, NULL);
    
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
    
    glBindTexture(GL_TEXTURE_2D, 0);
    
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    
    glFlush();
    
    [self.emulatorCore.frontBufferLock unlock];
    
    // Notify render thread that the front buffer is ready
    [self.emulatorCore.frontBufferCondition lock];
    [self.emulatorCore setIsFrontBufferReady:YES];
    [self.emulatorCore.frontBufferCondition signal];
    [self.emulatorCore.frontBufferCondition unlock];
    
    // Switch context back to emulator's
    [EAGLContext setCurrentContext:self.alternateThreadGLContext];
    glBindFramebuffer(GL_FRAMEBUFFER, alternateThreadFramebufferBack);
}

@end
