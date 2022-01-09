//
//  PVGLViewController.m
//  Provenance
//
//  Created by James Addyman on 08/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import "PVGLViewController.h"
@import PVSupport;
#import "Provenance-Swift.h"
#import <QuartzCore/QuartzCore.h>

#if !TARGET_OS_MACCATALYST
#import <OpenGLES/gltypes.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>
#import <OpenGLES/EAGL.h>
#else
@import OpenGL;
@import AppKit;
@import GLUT;
#endif

// Add SPI https://developer.apple.com/documentation/opengles/eaglcontext/2890259-teximageiosurface?language=objc
@interface EAGLContext()
- (BOOL)texImageIOSurface:(IOSurfaceRef)ioSurface target:(NSUInteger)target internalFormat:(NSUInteger)internalFormat width:(uint32_t)width height:(uint32_t)height format:(NSUInteger)format type:(NSUInteger)type plane:(uint32_t)plane;
@end

#define USE_METAL 1//TARGET_OS_MACCATALYST
#define BUFFER_COUNT 3

#if USE_METAL
@import Metal;
@import MetalKit;

struct float2{ float x; float y; };
struct float4 { float x; float y; float z; float w; };

struct CRT_Data
{
    struct float4 DisplayRect;
    struct float2 EmulatedImageSize;
    struct float2 FinalRes;
};
#endif

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

#if USE_METAL
@interface PVGLViewController () <PVRenderDelegate, MTKViewDelegate>
#else
@interface PVGLViewController () <PVRenderDelegate>
#endif
{
    GLuint alternateThreadFramebufferBack;
    GLuint alternateThreadColorTextureBack;
    GLuint alternateThreadDepthRenderbuffer;
    
#if USE_METAL
    IOSurfaceRef backingIOSurface;      // for OpenGL core support
    id<MTLTexture> backingMTLTexture;   // for OpenGL core support

    id<MTLBuffer> _uploadBuffer[BUFFER_COUNT];
    uint _frameCount;
#else
    
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
#endif
    
    struct RenderSettings renderSettings;
}

#if USE_METAL
@property (nonatomic, strong) MTKView *mtlview;
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLRenderPipelineState> blitPipeline;
@property (nonatomic, strong) id<MTLRenderPipelineState> crtFilterPipeline;
@property (nonatomic, strong) id<MTLSamplerState> pointSampler;
@property (nonatomic, strong) id<MTLSamplerState> linearSampler;
@property (nonatomic, strong) id<MTLTexture> inputTexture;
@property (nonatomic, strong) id<MTLCommandBuffer> previousCommandBuffer; // used for scheduling with OpenGL context
#endif
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
    if (alternateThreadColorTextureBack > 0)
    {
        glDeleteTextures(1, &alternateThreadColorTextureBack);
    }
    if (alternateThreadFramebufferBack > 0)
    {
        glDeleteFramebuffers(1, &alternateThreadFramebufferBack);
    }

#if USE_METAL
    backingMTLTexture = nil;
    if (backingIOSurface)
        CFRelease(backingIOSurface);
#else
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
#endif
    
    [[PVSettingsModel shared] removeObserver:self forKeyPath:@"crtFilterEnabled"];
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
        renderSettings.smoothingEnabled = [[PVSettingsModel shared] imageSmoothing];
        
        [[PVSettingsModel shared] addObserver:self forKeyPath:@"crtFilterEnabled" options:NSKeyValueObservingOptionNew context:nil];
        [[PVSettingsModel shared] addObserver:self forKeyPath:@"imageSmoothing" options:NSKeyValueObservingOptionNew context:nil];
	}

	return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"crtFilterEnabled"]) {
        renderSettings.crtFilterEnabled = [[PVSettingsModel shared] crtFilterEnabled];
    } else if ([keyPath isEqualToString:@"imageSmoothing"]) {
        renderSettings.smoothingEnabled = [[PVSettingsModel shared] imageSmoothing];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)viewDidLoad
{
	[super viewDidLoad];

    [self updatePreferredFPS];


    self.glContext = [self bestContext];

#if !USE_METAL
    if (self.glContext == nil) {
        // TODO: Alert NO gl here
        return;
    }
#endif

    ILOG(@"Initiated GLES version %lu", (unsigned long)self.glContext.API);

        // TODO: Need to benchmark this

    self.glContext.multiThreaded = PVSettingsModel.shared.debugOptions.multiThreadedGL;

	[EAGLContext setCurrentContext:self.glContext];

#if !USE_METAL
	GLKView *view = (GLKView *)self.view;
#else
    _frameCount = 0;
    self.device = MTLCreateSystemDefaultDevice();

    MTKView *view = [[MTKView alloc] initWithFrame:self.view.bounds device:self.device];
    self.mtlview = view;
    [self.view addSubview:self.mtlview];
    view.device = self.device;
    view.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0);
    view.depthStencilPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    view.sampleCount = 1;
    view.delegate = self;
    view.autoResizeDrawable = YES;
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

    GLenum depthFormat = self.emulatorCore.depthFormat;
    switch (depthFormat) {
        case GL_DEPTH_COMPONENT16:
#if USE_METAL
            if (@available(macOS 10.12, iOS 13.0, *))
            {
                view.depthStencilPixelFormat = MTLPixelFormatDepth16Unorm;
            }
            else
            {
                view.depthStencilPixelFormat = MTLPixelFormatDepth32Float;
            }
#else
            view.drawableDepthFormat = GLKViewDrawableDepthFormat16;
#endif
            break;
        case GL_DEPTH_COMPONENT24:
#if USE_METAL
            view.depthStencilPixelFormat = MTLPixelFormatX32_Stencil8; // fallback to D32 if D24 isn't supported
    #if !TARGET_OS_IPHONE
            if (_device.isDepth24Stencil8PixelFormatSupported)
                view.depthStencilPixelFormat = MTLPixelFormatX24_Stencil8;
    #endif
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
        if(PVSettingsModel.shared.debugOptions.multiSampling) {
#if USE_METAL
            //[view setSampleCount:4]; // Having the view multi-sampled doesn't make sense to me. We need to resolve the MSAA before presenting it
#else
            view.drawableMultisample = GLKViewDrawableMultisample4X;
#endif
        }
    }

    [self setupTexture];
#if !USE_METAL
    defaultVertexShader = [self compileShaderResource:@"shaders/default/default_vertex" ofType:GL_VERTEX_SHADER];
    [self setupVBOs];
#endif
    
    [self setupBlitShader];
    [self setupCRTShader];

    alternateThreadFramebufferBack = 0;
    alternateThreadColorTextureBack = 0;
    alternateThreadDepthRenderbuffer = 0;
#if !USE_METAL
    alternateThreadFramebufferFront = 0;
    alternateThreadColorTextureFront = 0;
#endif
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

- (void) updatePreferredFPS {
    float preferredFPS = self.emulatorCore.frameInterval;
    WLOG(@"updatePreferredFPS (%f)", preferredFPS);
    if (preferredFPS  < 10) {
        WLOG(@"Cores frame interval (%f) too low. Setting to 60", preferredFPS);
        preferredFPS = 60;
    }
#if !USE_METAL
    [self setPreferredFramesPerSecond:preferredFPS];
    WLOG(@"Actual FPS: %f", self.framesPerSecond);
#endif
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    UIEdgeInsets parentSafeAreaInsets = UIEdgeInsetsZero;
    if (@available(iOS 11.0, tvOS 11.0, macOS 11.0, macCatalyst 11.0, *)) {
        parentSafeAreaInsets = self.parentViewController.view.safeAreaInsets;
    }
    
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
#if USE_METAL
        [self.mtlview setFrame:CGRectMake(0, 0, width, height)];
#endif
    }

    [self updatePreferredFPS];
}

- (void)setupTexture
{
#if USE_METAL
    {
        CGRect screenRect = self.emulatorCore.screenRect;
        
        if (!self.emulatorCore.rendersToOpenGL)
        {
            uint formatByteWidth = [self getByteWidthForPixelFormat:[self.emulatorCore pixelFormat] type:[self.emulatorCore pixelType]];
            
            for (int i = 0; i < BUFFER_COUNT; ++i)
            {
                _uploadBuffer[i] = [_device newBufferWithLength:self.emulatorCore.bufferSize.width * self.emulatorCore.bufferSize.height * formatByteWidth options:MTLResourceStorageModeShared];
            }
        }
        
        MTLTextureDescriptor* desc = [MTLTextureDescriptor new];
        desc.textureType = MTLTextureType2D;
        desc.pixelFormat = [self getMTLPixelFormatFromGLPixelFormat:[self.emulatorCore pixelFormat] type:[self.emulatorCore pixelType]];
        desc.width = self.emulatorCore.rendersToOpenGL ? screenRect.size.width : self.emulatorCore.bufferSize.width;
        desc.height = self.emulatorCore.rendersToOpenGL ? screenRect.size.height : self.emulatorCore.bufferSize.height;
        desc.storageMode = MTLStorageModePrivate;
        desc.usage = MTLTextureUsageShaderRead;
        #if DEBUG
            desc.usage |= MTLTextureUsageRenderTarget; // needed for debug clear
        #endif
        
        _inputTexture = [_device newTextureWithDescriptor:desc];
    }
    
    {
        MTLSamplerDescriptor* desc = [MTLSamplerDescriptor new];
        desc.minFilter = MTLSamplerMinMagFilterNearest;
        desc.magFilter = MTLSamplerMinMagFilterNearest;
        desc.mipFilter = MTLSamplerMipFilterNearest;
        desc.sAddressMode = MTLSamplerAddressModeClampToEdge;
        desc.tAddressMode = MTLSamplerAddressModeClampToEdge;
        desc.rAddressMode = MTLSamplerAddressModeClampToEdge;
        
        _pointSampler = [_device newSamplerStateWithDescriptor:desc];
    }
    
    {
        MTLSamplerDescriptor* desc = [MTLSamplerDescriptor new];
        desc.minFilter = MTLSamplerMinMagFilterLinear;
        desc.magFilter = MTLSamplerMinMagFilterLinear;
        desc.mipFilter = MTLSamplerMipFilterNearest;
        desc.sAddressMode = MTLSamplerAddressModeClampToEdge;
        desc.tAddressMode = MTLSamplerAddressModeClampToEdge;
        desc.rAddressMode = MTLSamplerAddressModeClampToEdge;
        
        _linearSampler = [_device newSamplerStateWithDescriptor:desc];
    }
#else
    
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
#endif
}


#if !USE_METAL
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

- (void)createShadersDirs {
    // TODO: This is a hack, dir should come from arg
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error;
    NSString *docsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true).firstObject;
    
    [fm createDirectoryAtPath:[docsPath stringByAppendingPathComponent:@"shaders/default/"] withIntermediateDirectories:true attributes:nil error:&error];
    if (error) {
        ELOG(@"%@", error.localizedDescription);
    }
    [fm createDirectoryAtPath:[docsPath stringByAppendingPathComponent:@"shaders/blit/"] withIntermediateDirectories:true attributes:nil error:&error];
    if (error) {
        ELOG(@"%@", error.localizedDescription);
    }
    [fm createDirectoryAtPath:[docsPath stringByAppendingPathComponent:@"shaders/crt/"] withIntermediateDirectories:true attributes:nil error:&error];
    if (error) {
        ELOG(@"%@", error.localizedDescription);
    }
}

- (GLuint)compileShaderResource:(NSString*)shaderResourceName ofType:(GLenum)shaderType
{
    // TODO: check shaderType == GL_VERTEX_SHADER
    NSString *fileName = [shaderResourceName stringByAppendingPathExtension:@"glsl"];

    NSString *docsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true).firstObject stringByAppendingPathComponent:fileName];
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSString* shaderPath;
    NSString* bundleShaderPath = [[NSBundle mainBundle] pathForResource:shaderResourceName
                                                                 ofType:@"glsl"];
    
    if(![fm fileExistsAtPath:docsPath]) {
        [self createShadersDirs];
        NSError *error;

        [fm copyItemAtPath:bundleShaderPath
                    toPath:docsPath
                     error:&error];
        if (error) {
            ELOG(@"%@", error.localizedDescription);
        }
    }
    
    if([fm fileExistsAtPath:docsPath]) {
        shaderPath = docsPath;
    } else {
        shaderPath = bundleShaderPath;
    }
    if ( shaderPath == NULL )
    {
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
        return 0;
    }
    
    const char* shaderSourceCString = [shaderSource cStringUsingEncoding:NSASCIIStringEncoding];
    if ( shaderSourceCString == NULL )
    {
        ELOG(@"Nil shaderSourceCString");
        return 0;
    }
    
    GLuint shader = glCreateShader( shaderType );
    if ( shader == 0 )
    {
        ELOG(@"Nil shader");
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
        MAKESTRONG_RETURN_IF_NIL(self);
#if DEBUG
        glClearColor(1.0, 1.0, 1.0, 1.0);
        glClear(GL_COLOR_BUFFER_BIT);
#endif
        const BOOL rendersToOpenGL = strongself->_emulatorCore.rendersToOpenGL;
        const BOOL crtEnabled = strongself->renderSettings.crtFilterEnabled;

        GLuint frontBufferTex;
        if (UNLIKELY(rendersToOpenGL))
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

// these helper functions getByteWidthForPixelFormat and getMTLPixelFormatFromGLPixelFormat are not great
// ideally we'd take in API agnostic data rather than remapping GL to MTL but this will work for now even though it's a bit fragile
- (uint)getByteWidthForPixelFormat:(GLenum)pixelFormat type:(GLenum)pixelType
{
    uint typeWidth = 0;
    switch (pixelType)
    {
        case GL_BYTE:
        case GL_UNSIGNED_BYTE:
            typeWidth = 1;
            break;
        case GL_SHORT:
        case GL_UNSIGNED_SHORT:
        case GL_UNSIGNED_SHORT_5_6_5:
            typeWidth = 2;
            break;
        case GL_INT:
        case GL_UNSIGNED_INT:
        case GL_FLOAT:
        case 0x8367: // GL_UNSIGNED_INT_8_8_8_8_REV:
            typeWidth = 4;
            break;
        default:
            assert(!"Unknown GL pixelType. Add me");
    }
    
    switch (pixelFormat)
    {
        case GL_BGRA:
        case GL_RGBA:
            return 4 * typeWidth;
            
        case GL_RGB:
            if (pixelType == GL_UNSIGNED_SHORT_5_6_5)
                return typeWidth;
            break;
        default:
            break;
    }
    
    assert(!"Unknown GL pixelFormat. Add me");
    return 1;
}

- (MTLPixelFormat)getMTLPixelFormatFromGLPixelFormat:(GLenum)pixelFormat type:(GLenum)pixelType
{
    if (pixelFormat == GL_BGRA && (pixelType == GL_UNSIGNED_BYTE || pixelType == 0x8367 /* GL_UNSIGNED_INT_8_8_8_8_REV */))
    {
        return MTLPixelFormatBGRA8Unorm;
    }
    else if (pixelFormat == GL_RGBA && pixelType == GL_UNSIGNED_BYTE)
    {
        return MTLPixelFormatRGBA8Unorm;
    }
    else if (pixelFormat == GL_RGBA && pixelType == GL_BYTE)
    {
        return MTLPixelFormatRGBA8Snorm;
    }
    else if (pixelFormat == GL_RGB && pixelType == GL_UNSIGNED_SHORT_5_6_5)
    {
        return MTLPixelFormatB5G6R5Unorm;
    }
    
    assert(!"Unknown GL pixelFormat. Add me");
    return MTLPixelFormatInvalid;
}

- (void)setupBlitShader
{
    NSError* error;
    
    MTLFunctionConstantValues* constants = [MTLFunctionConstantValues new];
    bool FlipY = self.emulatorCore.rendersToOpenGL;
    [constants setConstantValue:&FlipY type:MTLDataTypeBool withName:@"FlipY"];
    
    id<MTLLibrary> lib = [_device newDefaultLibrary];
    
    MTLRenderPipelineDescriptor* desc = [MTLRenderPipelineDescriptor new];
    desc.vertexFunction = [lib newFunctionWithName:@"fullscreen_vs" constantValues:constants error:&error];
    desc.fragmentFunction = [lib newFunctionWithName:@"blit_ps"];
    desc.colorAttachments[0].pixelFormat = [self getMTLPixelFormatFromGLPixelFormat:[self.emulatorCore pixelFormat] type:[self.emulatorCore pixelType]];
    
    _blitPipeline = [_device newRenderPipelineStateWithDescriptor:desc error:&error];
}

- (void)setupCRTShader
{
    NSError* error;
    
    MTLFunctionConstantValues* constants = [MTLFunctionConstantValues new];
    bool FlipY = self.emulatorCore.rendersToOpenGL;
    [constants setConstantValue:&FlipY type:MTLDataTypeBool withName:@"FlipY"];
    
    id<MTLLibrary> lib = [_device newDefaultLibrary];
    
    MTLRenderPipelineDescriptor* desc = [MTLRenderPipelineDescriptor new];
    desc.vertexFunction = [lib newFunctionWithName:@"fullscreen_vs" constantValues:constants error:&error];
    desc.fragmentFunction = [lib newFunctionWithName:@"crt_filter_ps"];
    desc.colorAttachments[0].pixelFormat = [self getMTLPixelFormatFromGLPixelFormat:[self.emulatorCore pixelFormat] type:[self.emulatorCore pixelType]];
    
    _crtFilterPipeline = [_device newRenderPipelineStateWithDescriptor:desc error:&error];
}

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

    MAKEWEAK(self);

    void (^renderBlock)(void) = ^()
    {
        MAKESTRONG_RETURN_IF_NIL(self);
        
        if (self.emulatorCore.rendersToOpenGL)
        {
            [self.emulatorCore.frontBufferLock lock];
        }
        
        id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBufferWithUnretainedReferences];
        self.previousCommandBuffer = commandBuffer;
        
        CGRect screenRect = [self.emulatorCore screenRect];
        
        if (!self.emulatorCore.rendersToOpenGL)
        {
            const void* videoBuffer = [self.emulatorCore videoBuffer];
            CGSize videoBufferSize = [self.emulatorCore bufferSize];
            uint formatByteWidth = [self getByteWidthForPixelFormat:[self.emulatorCore pixelFormat] type:[self.emulatorCore pixelType]];
            
            id<MTLBuffer> uploadBuffer = self->_uploadBuffer[++self->_frameCount % BUFFER_COUNT];
            memcpy(uploadBuffer.contents, videoBuffer, videoBufferSize.width * videoBufferSize.height * formatByteWidth);
            
            id<MTLBlitCommandEncoder> encoder = [commandBuffer blitCommandEncoder];
            
            [encoder copyFromBuffer:uploadBuffer
                       sourceOffset:0
                  sourceBytesPerRow:videoBufferSize.width * formatByteWidth
                sourceBytesPerImage:0
                         sourceSize:MTLSizeMake(videoBufferSize.width, videoBufferSize.height, 1)
                           toTexture:self.inputTexture
                   destinationSlice:0
                   destinationLevel:0
                  destinationOrigin:MTLOriginMake(0, 0, 0)];
            
            [encoder endEncoding];
        }

        id<MTLTexture> outputTex = view.currentDrawable.texture;
        
        if (outputTex == nil)
        {
            // MTKView is set up wrong. Skip a frame and hope things fix themselves
            if (self.emulatorCore.rendersToOpenGL)
            {
                [strongself->_emulatorCore.frontBufferLock unlock];
                return;
            }
        }
        
        MTLRenderPassDescriptor* desc = [MTLRenderPassDescriptor new];
        desc.colorAttachments[0].texture = outputTex;
        desc.colorAttachments[0].loadAction = MTLLoadActionClear;
        desc.colorAttachments[0].storeAction = MTLStoreActionStore;
        desc.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0);
        desc.colorAttachments[0].level = 0;
        desc.colorAttachments[0].slice = 0;
        
        id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:desc];
        
        if (strongself->renderSettings.crtFilterEnabled)
        {
            struct CRT_Data cbData;
            cbData.DisplayRect.x = screenRect.origin.x;
            cbData.DisplayRect.y = screenRect.origin.y;
            cbData.DisplayRect.z = screenRect.size.width;
            cbData.DisplayRect.w = screenRect.size.height;
            
            cbData.EmulatedImageSize.x = self.inputTexture.width;
            cbData.EmulatedImageSize.y = self.inputTexture.height;
            
            cbData.FinalRes.x = view.drawableSize.width;
            cbData.FinalRes.y = view.drawableSize.height;
            
            [encoder setFragmentBytes:&cbData length:sizeof(cbData) atIndex:0];
            
            [encoder setRenderPipelineState:self.crtFilterPipeline];
        }
        else
        {
            [encoder setRenderPipelineState:self.blitPipeline];
        }
        
        [encoder setFragmentTexture:self.inputTexture atIndex:0];
        [encoder setFragmentSamplerState:strongself->renderSettings.smoothingEnabled ? self.linearSampler : self.pointSampler atIndex:0];
        [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
        [encoder endEncoding];
        [commandBuffer presentDrawable:view.currentDrawable];
        [commandBuffer commit];

        if ([strongself->_emulatorCore rendersToOpenGL])
        {
#if !USE_METAL
            glFlush();
#endif
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
                renderBlock();
                [_emulatorCore.frontBufferLock unlock];
                [_emulatorCore.frontBufferCondition unlock];
            }
            else
            {
                @synchronized(self.emulatorCore)
                {
                    renderBlock();
                }
            }
        }
    }
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

- (void)startRenderingOnAlternateThread
{
    self.emulatorCore.glesVersion = self.glesVersion;
    self.alternateThreadBufferCopyGLContext = [[EAGLContext alloc] initWithAPI:[self.glContext API] sharegroup:[self.glContext sharegroup]];
    
#if !USE_METAL
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
#endif
    
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
#if USE_METAL
        CGFloat width = self.emulatorCore.bufferSize.width;
        CGFloat height = self.emulatorCore.bufferSize.height;
        
        {
            NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:
                                  [NSNumber numberWithInt:width], kIOSurfaceWidth,
                                  [NSNumber numberWithInt:height], kIOSurfaceHeight,
                                  [NSNumber numberWithInt:4], kIOSurfaceBytesPerElement,
                                  nil];

            backingIOSurface = IOSurfaceCreate((CFDictionaryRef)dict);
        }
        IOSurfaceLock(backingIOSurface, 0, NULL);
        
        glGenTextures(1, &alternateThreadColorTextureBack);
        glBindTexture(GL_TEXTURE_2D, alternateThreadColorTextureBack);
        // use CGLTexImageIOSurface2D instead of texImageIOSurface for macOS
        [[EAGLContext currentContext] texImageIOSurface:backingIOSurface
                                   target:GL_TEXTURE_2D
                           internalFormat:GL_RGBA
                                    width:width
                                   height:height
                                   format:GL_RGBA
                                     type:GL_UNSIGNED_BYTE
                                    plane:0];
        glBindTexture(GL_TEXTURE_2D, 0);
        

        IOSurfaceUnlock(backingIOSurface, 0, NULL);
        
        MTLTextureDescriptor* mtlDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:width height:height mipmapped:NO];
        backingMTLTexture = [_device newTextureWithDescriptor:mtlDesc iosurface:backingIOSurface plane:0];

#else
        glGenTextures(1, &alternateThreadColorTextureBack);
        glBindTexture(GL_TEXTURE_2D, alternateThreadColorTextureBack);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        NSAssert( !((unsigned int)self.emulatorCore.bufferSize.width & ((unsigned int)self.emulatorCore.bufferSize.width - 1)), @"Emulator buffer width is not a power of two!" );
        NSAssert( !((unsigned int)self.emulatorCore.bufferSize.height & ((unsigned int)self.emulatorCore.bufferSize.height - 1)), @"Emulator buffer height is not a power of two!" );
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, self.emulatorCore.bufferSize.width, self.emulatorCore.bufferSize.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
        glBindTexture(GL_TEXTURE_2D, 0);
#endif

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
#if !USE_METAL
    // Release back buffer
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
#endif
    glFlush();
    
    // Blit back buffer to front buffer
    [self.emulatorCore.frontBufferLock lock];
    
#if USE_METAL
    // glFlush + waitUntilScheduled is how we coordinate texture access between OpenGL and Metal
    // There might be a more performant solution using MTLFences or MTLEvents but this is an ok first impl
    [self.previousCommandBuffer waitUntilScheduled];
    
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBufferWithUnretainedReferences];
    id<MTLBlitCommandEncoder> encoder = [commandBuffer blitCommandEncoder];
    
    CGRect screenRect = self.emulatorCore.screenRect;
    
    [encoder copyFromTexture:backingMTLTexture
                 sourceSlice:0
                 sourceLevel:0
                sourceOrigin:MTLOriginMake(0, 0, 0)
                  sourceSize:MTLSizeMake(screenRect.size.width, screenRect.size.height, 1)
                   toTexture:_inputTexture
            destinationSlice:0
            destinationLevel:0
           destinationOrigin:MTLOriginMake(0, 0, 0)];
    
    [encoder endEncoding];
    [commandBuffer commit];
#else
    
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
#endif
    
    [self.emulatorCore.frontBufferLock unlock];
    
    // Notify render thread that the front buffer is ready
    [self.emulatorCore.frontBufferCondition lock];
    [self.emulatorCore setIsFrontBufferReady:YES];
    [self.emulatorCore.frontBufferCondition signal];
    [self.emulatorCore.frontBufferCondition unlock];
    
#if !USE_METAL
    // Switch context back to emulator's
    [EAGLContext setCurrentContext:self.alternateThreadGLContext];
    glBindFramebuffer(GL_FRAMEBUFFER, alternateThreadFramebufferBack);
#endif
}
@end
