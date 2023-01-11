//
//  PVGLViewController.m
//  Provenance
//
//  Created by James Addyman on 08/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import "PVGLViewController.h"
@import PVSupport;
@import QuartzCore;
@import ReplayKit;
#import "Provenance-Swift.h"

#ifndef USE_EFFECT
#define USE_EFFECT 1
#endif

#ifndef USE_DISPLAY_LINK
#define USE_DISPLAY_LINK 0
#endif

#define USE_METAL (TARGET_OS_MACCATALYST || TARGET_OS_OSX)

#if !USE_METAL
#import <OpenGLES/gltypes.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>
#import <OpenGLES/EAGL.h>
#else
@import Metal;
@import OpenGL;
@import MetalKit;
@import AppKit;
@import GLUT;
#endif

#define SHADER_DIR "GLES"
#define VERTEX_DIR SHADER_DIR "/Vertex"
#define BLITTER_DIR SHADER_DIR "/Blitters"
#define FILTER_DIR SHADER_DIR "/Filters"

#if USE_METAL
@interface PVGLViewController () <PVRenderDelegate, MTKViewDelegate>
#else
@interface PVGLViewController () <PVRenderDelegate>
#endif
{
    GLuint alternateThreadFramebufferBack;
    GLuint alternateThreadColorTextureBack;
    GLuint alternateThreadDepthRenderbuffer;
    
    GLuint alternateThreadColorTextureFront;
    GLuint alternateThreadFramebufferFront;

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

#if USE_METAL
@property (nonatomic, strong) CIContext *glContext;
@property (nonatomic, strong) CIContext *alternateThreadGLContext;
@property (nonatomic, strong) CIContext *alternateThreadBufferCopyGLContext;
@property (nonatomic, strong) MTKView *mtlview;
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
#else
@property (nonatomic, strong) EAGLContext *glContext;
@property (nonatomic, strong) EAGLContext *alternateThreadGLContext;
@property (nonatomic, strong) EAGLContext *alternateThreadBufferCopyGLContext;
#endif

#if USE_DISPLAY_LINK
@property (nonatomic, strong) CADisplayLink *displayLink;
#endif
#if USE_EFFECT && !USE_METAL
@property (nonatomic, strong) GLKBaseEffect *effect;
#endif

@property (nonatomic, assign) GLESVersion glesVersion;

@end

PV_OBJC_DIRECT_MEMBERS
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
    if (alternateThreadColorTextureBack > 0)
    {
        glDeleteTextures(1, &alternateThreadColorTextureBack);
    }
    if (alternateThreadFramebufferBack > 0)
    {
        glDeleteFramebuffers(1, &alternateThreadFramebufferBack);
    }

    if (alternateThreadColorTextureFront > 0)
    {
        glDeleteTextures(1, &alternateThreadColorTextureFront);
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
    
    [[PVSettingsModel shared] removeObserver:self forKeyPath:@"crtFilterEnabled"];
    [[PVSettingsModel shared] removeObserver:self forKeyPath:@"lcdFilterEnabled"];
    [[PVSettingsModel shared] removeObserver:self forKeyPath:@"imageSmoothing"];
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
        
        renderSettings.crtFilterEnabled = [[PVSettingsModel shared] crtFilterEnabled];
        renderSettings.lcdFilterEnabled = [[PVSettingsModel shared] lcdFilterEnabled];
        renderSettings.smoothingEnabled = [[PVSettingsModel shared] imageSmoothing];
        
        [[PVSettingsModel shared] addObserver:self forKeyPath:@"crtFilterEnabled" options:NSKeyValueObservingOptionNew context:nil];
        [[PVSettingsModel shared] addObserver:self forKeyPath:@"lcdFilterEnabled" options:NSKeyValueObservingOptionNew context:nil];
        [[PVSettingsModel shared] addObserver:self forKeyPath:@"imageSmoothing" options:NSKeyValueObservingOptionNew context:nil];
	}

	return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"crtFilterEnabled"]) {
        renderSettings.crtFilterEnabled = [[PVSettingsModel shared] crtFilterEnabled];
    } else if ([keyPath isEqualToString:@"lcdFilterEnabled"]) {
        renderSettings.lcdFilterEnabled = [[PVSettingsModel shared] lcdFilterEnabled];
    } else if ([keyPath isEqualToString:@"imageSmoothing"]) {
        renderSettings.smoothingEnabled = [[PVSettingsModel shared] imageSmoothing];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#if USE_DISPLAY_LINK
-(void)render {
    [self.core executeFrame];
//    [self.view render];
}
#endif

- (void)viewDidLoad
{
	[super viewDidLoad];

    [self updatePreferredFPS];

#if !USE_METAL
    self.glContext = [self bestContext];

    if (self.glContext == nil) {
        // TODO: Alert NO gl here
        return;
    }

    ILOG(@"Initiated GLES version %lu", (unsigned long)self.glContext.API);

        // TODO: Need to benchmark this

    self.glContext.multiThreaded = PVSettingsModel.shared.videoOptions.multiThreadedGL;

    [EAGLContext setCurrentContext:self.glContext];

    GLKView *view = (GLKView *)self.view;
#else
    self.device = MTLCreateSystemDefaultDevice();

    MTKView *view = [[MTKView alloc] initWithFrame:self.view.bounds device:self.device];
    self.mtlview = view;
    [self.view addSubview:self.mtlview];
    view.device = self.device;
    view.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0);
    view.depthStencilPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    view.sampleCount = 4;
    view.delegate = self;
    self.commandQueue = [_device newCommandQueue];


        // Set paused and only trigger redraw when needs display is set.
    view.paused = NO;
    view.enableSetNeedsDisplay = NO;

     // Setup display link.
//     CVDisplayLinkCreateWithActiveCGDisplays(&displayLink);
//     CVDisplayLinkSetOutputCallback(displayLink, &MyDisplayLinkCallback, (__bridge void*)self);
//     CVDisplayLinkStart(displayLink);
#endif

    view.opaque = YES;
    view.layer.opaque = YES;
#if !USE_METAL
    view.context = self.glContext;
#else
#endif
    view.userInteractionEnabled = NO;

#if USE_DISPLAY_LINK
    self.displayLink = [CADisplayLink displayLinkWithTarget: self selector: @selector(render)];
    [self.displayLink addToRunLoop: [NSRunLoop currentRunLoop] forMode: NSDefaultRunLoopMode];
#endif
    
#if USE_EFFECT && !USE_METAL
    self.effect = [[GLKBaseEffect alloc] init];
#endif
    
    GLenum depthFormat = self.emulatorCore.depthFormat;
    switch (depthFormat) {
        case GL_DEPTH_COMPONENT16:
#if USE_METAL
            view.depthStencilPixelFormat = MTLPixelFormatRG8Unorm_sRGB;
#else
            view.drawableDepthFormat = GLKViewDrawableDepthFormat16;
#endif
            break;
        case GL_DEPTH_COMPONENT24:
#if USE_METAL
            view.depthStencilPixelFormat = MTLPixelFormatX24_Stencil8;
#else
            view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
#endif
            break;
        default:
            break;
    }

        // Set scaling factor for retina displays.
    if (PVSettingsModel.shared.nativeScaleEnabled) {
        CGFloat scale = [[UIScreen mainScreen] scale];
        if (scale != 1.0f) {
            view.layer.contentsScale = scale;
            view.layer.rasterizationScale = scale;
            view.contentScaleFactor = scale;
        }

            // Enable multisampling
        if(PVSettingsModel.shared.videoOptions.multiSampling) {
#if USE_METAL
            [view setSampleCount:4];
#else
            view.drawableMultisample = GLKViewDrawableMultisample4X;
#endif
        }
    }

    [self setupVBOs];
    [self setupTexture];
#if USE_METAL
#else
    NSError *error;
    defaultVertexShader = [self compileShaderResource:[NSString stringWithFormat:@"%s/default_vertex", VERTEX_DIR] ofType:GL_VERTEX_SHADER error:&error];
    
    if(error) {
        ELOG(@"%@", error.localizedDescription)
    }
    assert(defaultVertexShader != GL_NO_ERROR);
    
    [self setupBlitShader];
    [self setupCRTShader];
//    [self setupLCDShader];
#endif
    
    alternateThreadFramebufferBack = 0;
    alternateThreadColorTextureBack = 0;
    alternateThreadDepthRenderbuffer = 0;

    alternateThreadFramebufferFront = 0;
    alternateThreadColorTextureFront = 0;
}

#if !USE_METAL
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
#endif

- (void) updatePreferredFPS {
    float preferredFPS = self.emulatorCore.frameInterval;
    VLOG(@"updatePreferredFPS (%f)", preferredFPS);
    if (preferredFPS  < 10) {
        VLOG(@"Cores frame interval (%f) too low. Setting to 60", preferredFPS);
        preferredFPS = 60;
    }

#if !USE_METAL
    [self setPreferredFramesPerSecond:preferredFPS];
    WLOG(@"Actual FPS: %f", self.framesPerSecond);
#else
    [self setFramesPerSecond:preferredFPS];
#endif
    VLOG(@"Actual FPS: %f", self.framesPerSecond);
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    UIEdgeInsets parentSafeAreaInsets = self.parentViewController.view.safeAreaInsets;
    
    if (!CGRectIsEmpty([self.emulatorCore screenRect]))
    {
        CGSize aspectSize = [self.emulatorCore aspectSize];
        CGFloat ratio = 0.0;
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

        CGFloat height = 0.0;
        CGFloat width = 0.0;

        if (parentSize.width > parentSize.height) {
            if (PVSettingsModel.shared.integerScaleEnabled) { height = (floor(parentSize.height/aspectSize.height)) * aspectSize.height;}
            else
            {height = parentSize.height;}
            width = roundf(height * ratio);
            if (width > parentSize.width)
            {
                width = parentSize.width;
                height = roundf(width / ratio);
            }
        } else {
            if (PVSettingsModel.shared.integerScaleEnabled) { width = (floor(parentSize.width/aspectSize.width)) * aspectSize.width;}
            else
            {width = parentSize.width;}
            height = roundf(width / ratio);
            if (height > parentSize.height)
            {
                height = parentSize.width;
                width = roundf(height / ratio);
            }
        }

        CGPoint origin = CGPointMake(roundf((parentSize.width - width) / 2.0), 0.0);
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

    [self updatePreferredFPS];
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

#if !TARGET_OS_TV
- (void)createShadersDirs {
    // TODO: This is a hack, dir should come from arg
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error;
    NSString *docsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true).firstObject;
    
    [fm createDirectoryAtPath:[docsPath stringByAppendingPathComponent:@VERTEX_DIR] withIntermediateDirectories:true attributes:nil error:&error];
    if (error) {
        ELOG(@"%@", error.localizedDescription);
    }
    [fm createDirectoryAtPath:[docsPath stringByAppendingPathComponent:@BLITTER_DIR] withIntermediateDirectories:true attributes:nil error:&error];
    if (error) {
        ELOG(@"%@", error.localizedDescription);
    }
    [fm createDirectoryAtPath:[docsPath stringByAppendingPathComponent:@FILTER_DIR] withIntermediateDirectories:true attributes:nil error:&error];
    if (error) {
        ELOG(@"%@", error.localizedDescription);
    }
}
#endif

#if !USE_METAL
- (GLuint)compileShaderResource:(NSString*)shaderResourceName ofType:(GLenum)shaderType error:(NSError**)inError {
    // TODO: check shaderType == GL_VERTEX_SHADER
    NSString *fileName = [shaderResourceName stringByAppendingPathExtension:@"glsl"];

    NSString *docsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true).firstObject stringByAppendingPathComponent:fileName];
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSString* shaderPath;
    NSString* bundleShaderPath = [[NSBundle mainBundle] pathForResource:shaderResourceName
                                                                 ofType:@"glsl"];
#if !TARGET_OS_TV
    if(![fm fileExistsAtPath:docsPath]) {
        [self createShadersDirs];
        NSError *error;

        [fm copyItemAtPath:bundleShaderPath
                    toPath:docsPath
                     error:&error];
        if (error) {
            if(inError) {
                *inError = error;
            }
            ELOG(@"%@", error.localizedDescription);
        }
    }
    
    if([fm fileExistsAtPath:docsPath]) {
        shaderPath = docsPath;
    } else {
        shaderPath = bundleShaderPath;
    }
#else
    shaderPath = bundleShaderPath;
#endif
    if ( shaderPath == NULL )
    {
        if(inError) {
            *inError = [NSError errorWithDomain:@"org.provenance.core"
                                           code:-1
                                       userInfo:@{NSLocalizedDescriptionKey : @"shaderPath is null"}];
        }
        ELOG(@"Nil shaderPath");
        return 0;
    }
    
    NSError *error;
    NSString* shaderSource = [NSString stringWithContentsOfFile:shaderPath
                                                       encoding:NSASCIIStringEncoding
                                                          error:&error];
    if ( shaderSource == NULL )
    {
        ELOG(@"Nil shaderSource: %@ %@", shaderPath, error.localizedDescription);
        if(inError) {
            *inError = [NSError errorWithDomain:@"org.provenance.core" code:-1 userInfo:@{NSLocalizedDescriptionKey:@"shaderSource is null"}];
        }
        return 0;
    }
    
    const char* shaderSourceCString = [shaderSource cStringUsingEncoding:NSASCIIStringEncoding];
    if ( shaderSourceCString == NULL )
    {
        ELOG(@"Nil shaderSourceCString");
        if(inError) {
            *inError = [NSError errorWithDomain:@"org.provenance.core" code:-1 userInfo:@{NSLocalizedDescriptionKey:@"shaderSourceCString is null"}];
        }
        return 0;
    }
    
    GLuint shader = glCreateShader( shaderType );
    if ( shader == 0 )
    {
        ELOG(@"Nil shader");
        if(inError) {
            *inError = [NSError errorWithDomain:@"org.provenance.core" code:-1 userInfo:@{NSLocalizedDescriptionKey:@"shader is null"}];
        }
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
            NSString *log = [NSString stringWithCString:infoLog encoding:NSUTF8StringEncoding];
            ELOG(@"Error compiling shader: %@", log );
            if(inError) {
                *inError = [NSError errorWithDomain:@"org.provenance.core" code:-1 userInfo:@{NSLocalizedDescriptionKey:@"Error compiling shader" , NSLocalizedFailureReasonErrorKey:log}];
            }
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
            ELOG(@"Error linking program: %s", infoLog );
            free( infoLog );
        }
        
        glDeleteProgram( shaderProgram );
        return 0;
    }
    
    return shaderProgram;
}

- (void)setupBlitShader
{
    NSError *error;
    blitFragmentShader = [self compileShaderResource:[NSString stringWithFormat:@"%s/blit_fragment", BLITTER_DIR] ofType:GL_FRAGMENT_SHADER error:&error];
    assert(blitFragmentShader != GL_NO_ERROR);
    blitShaderProgram = [self linkVertexShader:defaultVertexShader withFragmentShader:blitFragmentShader];
    assert(blitShaderProgram != GL_NO_ERROR);
    blitUniform_EmulatedImage = glGetUniformLocation(blitShaderProgram, "EmulatedImage");
}

- (void)setupCRTShader
{
    NSError *error;
    crtFragmentShader = [self compileShaderResource:[NSString stringWithFormat:@"%s/crt_fragment", FILTER_DIR] ofType:GL_FRAGMENT_SHADER error:&error];
    assert(crtFragmentShader != GL_NO_ERROR);
    crtShaderProgram = [self linkVertexShader:defaultVertexShader withFragmentShader:crtFragmentShader];
    assert(crtShaderProgram != GL_NO_ERROR);
    crtUniform_DisplayRect = glGetUniformLocation(crtShaderProgram, "DisplayRect");
    crtUniform_EmulatedImage = glGetUniformLocation(crtShaderProgram, "EmulatedImage");
    crtUniform_EmulatedImageSize = glGetUniformLocation(crtShaderProgram, "EmulatedImageSize");
    crtUniform_FinalRes = glGetUniformLocation(crtShaderProgram, "FinalRes");
}

- (void)setupLCDShader
{
    NSError *error;
    crtFragmentShader = [self compileShaderResource:[NSString stringWithFormat:@"%s/crt_fragment", FILTER_DIR] ofType:GL_FRAGMENT_SHADER error:&error];
    assert(crtFragmentShader != GL_NO_ERROR);
    crtShaderProgram = [self linkVertexShader:defaultVertexShader withFragmentShader:crtFragmentShader];
    assert(crtShaderProgram != GL_NO_ERROR);
    crtUniform_DisplayRect = glGetUniformLocation(crtShaderProgram, "DisplayRect");
    crtUniform_EmulatedImage = glGetUniformLocation(crtShaderProgram, "EmulatedImage");
    crtUniform_EmulatedImageSize = glGetUniformLocation(crtShaderProgram, "EmulatedImageSize");
    crtUniform_FinalRes = glGetUniformLocation(crtShaderProgram, "FinalRes");
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    if (self.emulatorCore.skipEmulationLoop)
        return;
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
        MAKESTRONG_RETURN_IF_NIL(self);
#if DEBUG
        glClearColor(1.0, 1.0, 1.0, 1.0);
        glClear(GL_COLOR_BUFFER_BIT);
#endif
        const BOOL rendersToOpenGL = strongself->_emulatorCore.rendersToOpenGL;
        const BOOL crtEnabled = strongself->renderSettings.crtFilterEnabled &&
        ![strongself->_emulatorCore.screenType.lowercaseString containsString:@"lcd"];
        const BOOL lcdEnabled = strongself->renderSettings.lcdFilterEnabled &&
        [strongself->_emulatorCore.screenType.lowercaseString containsString:@"lcd"];
        
        GLuint frontBufferTex;
        if (UNLIKELY(rendersToOpenGL))
        {
            frontBufferTex = strongself->alternateThreadColorTextureFront;
            [strongself.emulatorCore.frontBufferLock lock];
        }
        else
        {
            glBindTexture(GL_TEXTURE_2D, strongself->texture);
            glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, videoBufferSize.width, videoBufferSize.height, videoBufferPixelFormat, videoBufferPixelType, videoBuffer);
            frontBufferTex = strongself->texture;
            
#if USE_EFFECT
            if (strongself->texture)
            {
                self.effect.texture2d0.envMode = GLKTextureEnvModeReplace;
                self.effect.texture2d0.target = GLKTextureTarget2D;
                self.effect.texture2d0.name = strongself->texture;
                self.effect.texture2d0.enabled = YES;
                self.effect.useConstantColor = YES;
            }

            [strongself.effect prepareToDraw];
#endif
        }
        
        if (frontBufferTex)
        {
            glActiveTexture(GL_TEXTURE0);
            glBindTexture(GL_TEXTURE_2D, frontBufferTex);
        }
        
        if (crtEnabled)
        {
            glUseProgram(strongself->crtShaderProgram);
            glUniform4f(strongself->crtUniform_DisplayRect, screenRect.origin.x, screenRect.origin.y, screenRect.size.width, screenRect.size.height);
            glUniform1i(strongself->crtUniform_EmulatedImage, 0);
            glUniform2f(strongself->crtUniform_EmulatedImageSize, videoBufferSize.width, videoBufferSize.height);
            float finalResWidth = view.drawableWidth;
            float finalResHeight = view.drawableHeight;
            glUniform2f(strongself->crtUniform_FinalRes, finalResWidth, finalResHeight);
        }
        else if (lcdEnabled)
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
        
        if (UNLIKELY(rendersToOpenGL)) {
            glFlush();
            [strongself->_emulatorCore.frontBufferLock unlock];
        }
    };
    
    if (UNLIKELY(self.emulatorCore.rendersToOpenGL)) {
        // TODO: should isEmulationPaused be the always &&, not before the | ? @JoeMatt
        // if (LIKELY(!self.emulatorCore.isSpeedModified) && LIKELY(!self.emulatorCore.isEmulationPaused) && LIKELY(self.emulatorCore.isFrontBufferReady))
        if ((LIKELY(!self.emulatorCore.isSpeedModified) && LIKELY(!self.emulatorCore.isEmulationPaused)) || LIKELY(self.emulatorCore.isFrontBufferReady))
        {
            [self.emulatorCore.frontBufferCondition lock];
            while (UNLIKELY(!self.emulatorCore.isFrontBufferReady) && LIKELY(!self.emulatorCore.isEmulationPaused))
            {
                [self.emulatorCore.frontBufferCondition wait];
            }
            BOOL isFrontBufferReady = self.emulatorCore.isFrontBufferReady;
            [self.emulatorCore.frontBufferCondition unlock];
            if (isFrontBufferReady)
            {
                fetchVideoBuffer();
                renderBlock();
                [_emulatorCore.frontBufferCondition lock];
                _emulatorCore.isFrontBufferReady = NO;
                [_emulatorCore.frontBufferCondition signal];
                [_emulatorCore.frontBufferCondition unlock];
            }
        }
    }
    else {
        if (UNLIKELY(self.emulatorCore.isSpeedModified))
        {
            fetchVideoBuffer();
            renderBlock();
        }
        else
        {
            if (UNLIKELY(self.emulatorCore.isDoubleBuffered))
            {
                [self.emulatorCore.frontBufferCondition lock];
                while (UNLIKELY(!self.emulatorCore.isFrontBufferReady) && LIKELY(!self.emulatorCore.isEmulationPaused))
                {
                    [self.emulatorCore.frontBufferCondition wait];
                }
                _emulatorCore.isFrontBufferReady = NO;
                [_emulatorCore.frontBufferLock lock];
                fetchVideoBuffer();
                renderBlock();
                [_emulatorCore.frontBufferLock unlock];
                [_emulatorCore.frontBufferCondition unlock];
            }
            else {
                @synchronized(self.emulatorCore)
                {
                    fetchVideoBuffer();
                    renderBlock();
                }
            }
        }
    }
}
#else
// Mac OS Stuff
// MARK: - MTKViewDelegate

/*!
 @method mtkView:drawableSizeWillChange:
 @abstract Called whenever the drawableSize of the view will change
 @discussion Delegate can recompute view and projection matricies or regenerate any buffers to be compatible with the new view size or resolution
 @param view MTKView which called this method
 @param size New drawable size in pixels
 */
- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {

}

/*!
 @method drawInMTKView:
 @abstract Called on the delegate when it is asked to render into the view
 @discussion Called on the delegate when it is asked to render into the view
 */
- (void)drawInMTKView:(nonnull MTKView *)view {
        //guard let safeCurrentDrawable = self.currentDrawable,
        //      let safeCommandBuffer = self.commandQueue.makeCommandBuffer()
        //else {
        //    return
        //}
        //
        //let image: CIImage
        //let baseImage: CIImage = CIImage(bitmapData: NSData(bytes: &self.buffer, length: 640 * 480 * PVMTLView.elementLength) as Data, bytesPerRow: 640 * PVMTLView.elementLength, size: PVMTLView.imageSize, format: CIFormat.ARGB8, colorSpace: self.rgbColorSpace)
        //
        //if self.nearestNeighborRendering {
        //    image = baseImage.samplingNearest().transformed(by: self.tNesScreen)
        //} else {
        //    image = baseImage.transformed(by: self.tNesScreen)
        //}
        //
        //let renderDestination = CIRenderDestination(width: Int(self.drawableSize.width), height: Int(self.drawableSize.height), pixelFormat: self.colorPixelFormat, commandBuffer: safeCommandBuffer) {
        //    () -> MTLTexture in return safeCurrentDrawable.texture
        //}
        //
        //do {
        //    _ = try self.context.startTask(toRender: image, to: renderDestination)
        //} catch {
        //    os_log("%@", error.localizedDescription)
        //}
        //
        //safeCommandBuffer.present(safeCurrentDrawable)
        //safeCommandBuffer.commit()
        //
        //self.lastDrawableSize = self.drawableSizeview
        id<CAMetalDrawable> safeCurrentDrawable = view.currentDrawable;
        id<MTLCommandBuffer> safeCommandBuffer = [self.commandQueue commandBuffer];


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
        MAKESTRONG_RETURN_IF_NIL(self);
//#if DEBUG
//        glClearColor(1.0, 1.0, 1.0, 1.0);
//        glClear(GL_COLOR_BUFFER_BIT);
//#endif
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
            float finalResWidth = view.drawableSize.width;
            float finalResHeight = view.drawableSize.height;
            glUniform2f(strongself->crtUniform_FinalRes, finalResWidth, finalResHeight);
        }
        else
        {
            glUseProgram(strongself->blitShaderProgram);
            glUniform1i(strongself->blitUniform_EmulatedImage, 0);
        }

        glDisable(GL_DEPTH_TEST);
        glDisable(GL_CULL_FACE);

//        [self updateVBOWithScreenRect:screenRect andVideoBufferSize:videoBufferSize];

        glBindBuffer(GL_ARRAY_BUFFER, strongself->vertexVBO);

//        glEnableVertexAttribArray(GLKVertexAttribPosition);
//        glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(struct PVVertex), BUFFER_OFFSET(0));
//
//        glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
//        glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, sizeof(struct PVVertex), BUFFER_OFFSET(12));

        glBindBuffer(GL_ARRAY_BUFFER, 0);

        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, strongself->indexVBO);
        glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_SHORT, NULL);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);

//        glDisableVertexAttribArray(GLKVertexAttribTexCoord0);
//        glDisableVertexAttribArray(GLKVertexAttribPosition);

        glBindTexture(GL_TEXTURE_2D, 0);

        if ([strongself->_emulatorCore rendersToOpenGL])
        {
            glFlush();
            [strongself->_emulatorCore.frontBufferLock unlock];
        }
    };

    if ([self.emulatorCore rendersToOpenGL])
    {
        if ((!self.emulatorCore.isSpeedModified && !self.emulatorCore.isEmulationPaused) || self.emulatorCore.isFrontBufferReady)
        {
            [self.emulatorCore.frontBufferCondition lock];
            while (UNLIKELY(!self.emulatorCore.isFrontBufferReady) && LIKELY(!self.emulatorCore.isEmulationPaused))
            {
                [self.emulatorCore.frontBufferCondition wait];
            }
            BOOL isFrontBufferReady = self.emulatorCore.isFrontBufferReady;
            [self.emulatorCore.frontBufferCondition unlock];
            if (isFrontBufferReady)
            {
                fetchVideoBuffer();
                renderBlock();
                [_emulatorCore.frontBufferCondition lock];
                _emulatorCore.isFrontBufferReady = NO;
                [_emulatorCore.frontBufferCondition signal];
                [_emulatorCore.frontBufferCondition unlock];
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
            if (UNLIKELY(self.emulatorCore.isDoubleBuffered))
            {
                [self.emulatorCore.frontBufferCondition lock];
                while (UNLIKELY(!self.emulatorCore.isFrontBufferReady) && LIKELY(!self.emulatorCore.isEmulationPaused))
                {
                    [self.emulatorCore.frontBufferCondition wait];
                }
                _emulatorCore.isFrontBufferReady = NO;
                [_emulatorCore.frontBufferLock lock];
                fetchVideoBuffer();
                renderBlock();
                [_emulatorCore.frontBufferLock unlock];
                [_emulatorCore.frontBufferCondition unlock];
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


        [safeCommandBuffer presentDrawable:safeCurrentDrawable];
        [safeCommandBuffer commit];
}

//@objc private func appResignedActive() {
//self.queue.suspend()
//self.hasSuspended = true
//}
//
//@objc private func appBecameActive() {
//if self.hasSuspended {
//    self.queue.resume()
//    self.hasSuspended = false
//}
//}
#endif

#pragma mark - PVRenderDelegate protocol methods

#if USE_METAL //|| TARGET_OS_MACOS
- (void)startRenderingOnAlternateThread {

}
- (void)didRenderFrameOnAlternateThread {
    [self.emulatorCore.frontBufferLock lock];

 // TODO: Copy the back buffer
    [self.emulatorCore.frontBufferLock unlock];

    // Notify render thread that the front buffer is ready
    [self.emulatorCore.frontBufferCondition lock];
    [self.emulatorCore setIsFrontBufferReady:YES];
    [self.emulatorCore.frontBufferCondition signal];
    [self.emulatorCore.frontBufferCondition unlock];

    // Switch context back to emulator's
//    [EAGLContext setCurrentContext:self.alternateThreadGLContext];
//    glBindFramebuffer(GL_FRAMEBUFFER, alternateThreadFramebufferBack);
}

- (id) presentationFramebuffer {
    GLuint bufferID = self.emulatorCore.isDoubleBuffered ? alternateThreadFramebufferBack : alternateThreadFramebufferFront;
    return [NSNumber numberWithInt:bufferID];
}


#else

- (id) presentationFramebuffer {
    GLuint bufferID = self.emulatorCore.isDoubleBuffered ? alternateThreadFramebufferBack : alternateThreadFramebufferFront;
    return [NSNumber numberWithInt:bufferID];
}

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
#endif
@end
