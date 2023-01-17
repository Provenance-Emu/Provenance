//
//  PVMetalViewController.m
//  Provenance
//
//  Created by James Addyman on 08/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import "PVMetalViewController.h"
@import PVSupport;
#import "Provenance-Swift.h"
#import <QuartzCore/QuartzCore.h>

#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
#import <OpenGLES/gltypes.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>
#import <OpenGLES/EAGL.h>
#else
@import OpenGL;
@import AppKit;
@import GLUT;
@import CoreImage;
@import OpenGL.IOSurface;
@import OpenGL.GL3;
//#import <OpenGL/CGLIOSurface.h>
@import OpenGL.OpenGLAvailability;
@import OpenGL.GL;
@import CoreVideo;
#endif

// Add SPI https://developer.apple.com/documentation/opengles/eaglcontext/2890259-teximageiosurface?language=objc
#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
@interface EAGLContext()
- (BOOL)texImageIOSurface:(IOSurfaceRef)ioSurface target:(NSUInteger)target internalFormat:(NSUInteger)internalFormat width:(uint32_t)width height:(uint32_t)height format:(NSUInteger)format type:(NSUInteger)type plane:(uint32_t)plane;
@end
#endif

#define BUFFER_COUNT 3

@import Metal;
@import MetalKit;

@interface PVMetalViewController () <PVRenderDelegate, MTKViewDelegate>
{
    GLuint alternateThreadFramebufferBack;
    GLuint alternateThreadColorTextureBack;
    GLuint alternateThreadDepthRenderbuffer;
    
    IOSurfaceRef backingIOSurface;      // for OpenGL core support
    id<MTLTexture> backingMTLTexture;   // for OpenGL core support

    id<MTLBuffer> _uploadBuffer[BUFFER_COUNT];
    uint _frameCount;
    
    struct RenderSettings renderSettings;
    
    
}

@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLRenderPipelineState> blitPipeline;
@property (nonatomic, strong) id<MTLRenderPipelineState> effectFilterPipeline;
@property (nonatomic, strong) id<MTLSamplerState> pointSampler;
@property (nonatomic, strong) id<MTLSamplerState> linearSampler;
@property (nonatomic, strong) id<MTLTexture> inputTexture;
@property (nonatomic, strong) id<MTLCommandBuffer> previousCommandBuffer; // used for scheduling with OpenGL context

#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
@property (nonatomic, strong) EAGLContext *glContext;
@property (nonatomic, strong) EAGLContext *alternateThreadGLContext;
@property (nonatomic, strong) EAGLContext *alternateThreadBufferCopyGLContext;
#else
//@property (nonatomic, strong) NSOpenGLContext *glContext;
//@property (nonatomic, strong) NSOpenGLContext *alternateThreadGLContext;
//@property (nonatomic, strong) NSOpenGLContext *alternateThreadBufferCopyGLContext;
//@property (nonatomic, strong) CADisplayLink *caDisplayLink;
#endif

@property (nonatomic, assign) GLESVersion glesVersion;

@property (nonatomic, strong, nullable) Shader* effectFilterShader;
@end

PV_OBJC_DIRECT_MEMBERS
@implementation PVMetalViewController
{
    GLuint resolution_uniform;
    GLuint texture_uniform;
    GLuint previous_texture_uniform;
    GLuint frame_blending_mode_uniform;

    GLuint position_attribute;
    GLuint texture;
    GLuint previous_texture;
    GLuint program;
}

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

    backingMTLTexture = nil;
    if (backingIOSurface)
        CFRelease(backingIOSurface);
    
    [[PVSettingsModel shared] removeObserver:self forKeyPath:@"metalFilter"];
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
        
//        renderSettings.crtFilterEnabled = [[PVSettingsModel shared] crtFilterEnabled];
        renderSettings.crtFilterEnabled = [self filterShaderEnabled];

        renderSettings.smoothingEnabled = [[PVSettingsModel shared] imageSmoothing];
        
        [[PVSettingsModel shared] addObserver:self forKeyPath:@"metalFilter" options:NSKeyValueObservingOptionNew context:nil];
        [[PVSettingsModel shared] addObserver:self forKeyPath:@"imageSmoothing" options:NSKeyValueObservingOptionNew context:nil];
	}

	return self;
}

- (BOOL)filterShaderEnabled {
    NSString *value = PVSettingsModel.shared.metalFilter.lowercaseString;
    BOOL enabled = !([value isEqualToString:@""] || [value isEqualToString:@"off"]);
    return enabled;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"metalFilter"]) {
        renderSettings.crtFilterEnabled = [self filterShaderEnabled];
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

    if (self.emulatorCore.rendersToOpenGL)
    {
#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
        self.glContext = [self bestContext];

        ILOG(@"Initiated GLES version %lu", (unsigned long)self.glContext.API);

        // TODO: Need to benchmark this

        self.glContext.multiThreaded = PVSettingsModel.shared.videoOptions.multiThreadedGL;

        [EAGLContext setCurrentContext:self.glContext];
#else
#endif
    }

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
//    self.caDisplayLink = [UIScreen.mainScreen displayLinkWithTarget:self selector::@selector(displayLinkCalled:)];
//    _caDisplayLink.preferredFramesPerSecond = 120;
//
//     CVDisplayLinkCreateWithActiveCGDisplays(&_caDisplayLink);
//     CVDisplayLinkSetOutputCallback(_caDisplayLink, &MyDisplayLinkCallback, (__bridge void*)self);
//     CVDisplayLinkStart(_caDisplayLink);

    view.opaque = YES;
    view.layer.opaque = YES;

    view.userInteractionEnabled = NO;

    GLenum depthFormat = self.emulatorCore.depthFormat;
    switch (depthFormat) {
        case GL_DEPTH_COMPONENT16:
            view.depthStencilPixelFormat = MTLPixelFormatDepth16Unorm;
            break;
        case GL_DEPTH_COMPONENT24:
            view.depthStencilPixelFormat = MTLPixelFormatX32_Stencil8; // fallback to D32 if D24 isn't supported
    #if !TARGET_OS_IPHONE
            if (_device.isDepth24Stencil8PixelFormatSupported)
                view.depthStencilPixelFormat = MTLPixelFormatX24_Stencil8;
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
            //[view setSampleCount:4]; // Having the view multi-sampled doesn't make sense to me. We need to resolve the MSAA before presenting it
        }
    }

    [self setupTexture];
    
    [self setupBlitShader];
    
    NSString *metalFilter = PVSettingsModel.shared.metalFilter;
    Shader *filterShader = [MetalShaderManager.sharedInstance filterShaderForName:metalFilter];
    if(filterShader) {
        [self setupEffectFilterShader:filterShader];
    }

    alternateThreadFramebufferBack = 0;
    alternateThreadColorTextureBack = 0;
    alternateThreadDepthRenderbuffer = 0;
}

#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
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
    WLOG(@"updatePreferredFPS (%f)", preferredFPS);
    if (preferredFPS  < 10) {
        WLOG(@"Cores frame interval (%f) too low. Setting to 60", preferredFPS);
        preferredFPS = 60;
    }
    self.mtlview.preferredFramesPerSecond = preferredFPS;
    
#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
    [self setPreferredFramesPerSecond:preferredFPS];
#else
    [self setFramesPerSecond:preferredFPS];
#endif
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    if (self.emulatorCore.skipLayout)
        return;
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
        [self.mtlview setFrame:CGRectMake(0, 0, width, height)];
    }

    [self updatePreferredFPS];
}

- (void)updateInputTexture
{
    CGRect screenRect = self.emulatorCore.screenRect;
    MTLPixelFormat pixelFormat = [self getMTLPixelFormatFromGLPixelFormat:self.emulatorCore.pixelFormat type:self.emulatorCore.pixelType];
    
    if (self.emulatorCore.rendersToOpenGL) {
        pixelFormat = MTLPixelFormatRGBA8Unorm;
    }    
    if (self.inputTexture == nil ||
        self.inputTexture.width != screenRect.size.width ||
        self.inputTexture.height != screenRect.size.height ||
        self.inputTexture.pixelFormat != pixelFormat)
    {
        MTLTextureDescriptor* desc = [MTLTextureDescriptor new];
        desc.textureType = MTLTextureType2D;
        desc.pixelFormat = pixelFormat;
        desc.width = screenRect.size.width;
        desc.height = screenRect.size.height;
        desc.storageMode = MTLStorageModePrivate;
        desc.usage = MTLTextureUsageShaderRead;
        
        self.inputTexture = [self.device newTextureWithDescriptor:desc];
    }
}

- (void)setupTexture
{
    [self updateInputTexture];
    
    if (!self.emulatorCore.rendersToOpenGL)
    {
        uint formatByteWidth = [self getByteWidthForPixelFormat:self.emulatorCore.pixelFormat type:self.emulatorCore.pixelType];
        
        for (int i = 0; i < BUFFER_COUNT; ++i)
        {
            _uploadBuffer[i] = [_device newBufferWithLength:self.emulatorCore.bufferSize.width * self.emulatorCore.bufferSize.height * formatByteWidth options:MTLResourceStorageModeShared];
        }
    }
    
    {
        MTLSamplerDescriptor* desc = [MTLSamplerDescriptor new];
        desc.minFilter = MTLSamplerMinMagFilterNearest;
        desc.magFilter = MTLSamplerMinMagFilterNearest;
        desc.mipFilter = MTLSamplerMipFilterNearest;
        desc.sAddressMode = MTLSamplerAddressModeClampToZero;
        desc.tAddressMode = MTLSamplerAddressModeClampToZero;
        desc.rAddressMode = MTLSamplerAddressModeClampToZero;
        
        _pointSampler = [_device newSamplerStateWithDescriptor:desc];
    }
    
    {
        MTLSamplerDescriptor* desc = [MTLSamplerDescriptor new];
        desc.minFilter = MTLSamplerMinMagFilterLinear;
        desc.magFilter = MTLSamplerMinMagFilterLinear;
        desc.mipFilter = MTLSamplerMipFilterNearest;
        desc.sAddressMode = MTLSamplerAddressModeClampToZero;
        desc.tAddressMode = MTLSamplerAddressModeClampToZero;
        desc.rAddressMode = MTLSamplerAddressModeClampToZero;
        
        _linearSampler = [_device newSamplerStateWithDescriptor:desc];
    }
}

// these helper functions getByteWidthForPixelFormat and getMTLPixelFormatFromGLPixelFormat are not great
// ideally we'd take in API agnostic data rather than remapping GL to MTL but this will work for now even though it's a bit fragile
- (uint)getByteWidthForPixelFormat:(GLenum)pixelFormat type:(GLenum)pixelType
{
    uint typeWidth = 0;
    switch (pixelType)
    {
        case GL_BYTE:
        case GL_UNSIGNED_BYTE:
            typeWidth = 2;
            break;
        case GL_UNSIGNED_SHORT_5_5_5_1:
        case GL_SHORT:
        case GL_UNSIGNED_SHORT:
        case GL_UNSIGNED_SHORT_5_6_5:
            typeWidth = 2;
            break;
        case GL_INT:
        case GL_UNSIGNED_INT:
        case GL_FLOAT:
        case GL_FLOAT_32_UNSIGNED_INT_24_8_REV:
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
            switch (pixelType) {
                case GL_UNSIGNED_BYTE:
                case GL_UNSIGNED_SHORT_4_4_4_4:
                case GL_UNSIGNED_SHORT_5_5_5_1:
                case GL_UNSIGNED_SHORT_5_6_5:
                    return 2 * typeWidth;
                default:
                    return 4 * typeWidth;
            }
#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
        case GL_RGB565:
#else
        case GL_UNSIGNED_SHORT_5_6_5:
#endif
        case GL_RGB:
            switch (pixelType) {
                case GL_UNSIGNED_BYTE:
                case GL_UNSIGNED_SHORT_4_4_4_4:
                case GL_UNSIGNED_SHORT_5_5_5_1:
                case GL_UNSIGNED_SHORT_5_6_5:
                    return typeWidth;
                default:
                    return 4 * typeWidth;
            }
        case GL_RGB5_A1:
            return 4 * typeWidth;
        case GL_RGB8:
        case GL_RGBA8:
            return 8 * typeWidth;
        default:
            break;
    }
    
    NSAssert(false, @"Unknown GL pixelFormat %x. Add me", pixelFormat);
    return 1;
}

- (MTLPixelFormat)getMTLPixelFormatFromGLPixelFormat:(GLenum)pixelFormat type:(GLenum)pixelType
{
    if (pixelFormat == GL_BGRA && (pixelType == GL_UNSIGNED_BYTE || pixelType == 0x8367 /* GL_UNSIGNED_INT_8_8_8_8_REV */))
    {
        return MTLPixelFormatBGRA8Unorm; // MTLPixelFormatBGRA8Unorm_sRGB
    }
    else if (pixelFormat == GL_BGRA && (pixelType == GL_UNSIGNED_INT | pixelType == GL_UNSIGNED_BYTE))
    {
        return MTLPixelFormatBGRA8Unorm;
//        return MTLPixelFormatBGRA10_XR;
//        return MTLPixelFormatBGRA8Unorm_sRGB;
    }
    else if (pixelFormat == GL_BGRA && (pixelType == GL_FLOAT_32_UNSIGNED_INT_24_8_REV))
    {
        return MTLPixelFormatBGRA8Unorm_sRGB;
//        return MTLPixelFormatBGRA10_XR;
//        return MTLPixelFormatBGRA8Unorm_sRGB;
    }
    else if (pixelFormat == GL_RGB && pixelType == GL_UNSIGNED_BYTE)
    {
        return MTLPixelFormatRGBA8Unorm;
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
        if (@available(iOS 8, tvOS 8, macOS 11, macCatalyst 14, *))
        {
           return MTLPixelFormatB5G6R5Unorm;
        }
        return MTLPixelFormatRGBA16Unorm;
    }
    else if (pixelType == GL_UNSIGNED_SHORT_8_8_APPLE)
    {
        return MTLPixelFormatRGBA16Unorm;
    }
    else if (pixelType == GL_UNSIGNED_SHORT_5_5_5_1)
    {
        if (@available(iOS 8, tvOS 8, macOS 11, macCatalyst 14, *))
        {
            return MTLPixelFormatA1BGR5Unorm;
        }
        return MTLPixelFormatRGBA16Unorm;
    }
    else if (pixelType == GL_UNSIGNED_SHORT_4_4_4_4)
    {
        if (@available(iOS 8, tvOS 8, macOS 11, macCatalyst 14, *))
        {
            return MTLPixelFormatABGR4Unorm;
        }
        return MTLPixelFormatRGBA16Unorm;
    }
    else if (pixelFormat == GL_RGBA8)
    {
        if (pixelType == GL_UNSIGNED_BYTE) { // 8bit
            return MTLPixelFormatRGBA8Unorm;
        } else if (pixelType == GL_UNSIGNED_SHORT) { // 16bit
//            MTLPixelFormatRGB10A2Unorm = 90,
//            MTLPixelFormatRGB10A2Uint  = 91,
//
//            MTLPixelFormatRG11B10Float = 92,
//            MTLPixelFormatRGB9E5Float = 93,
            return MTLPixelFormatRGBA32Uint;
        }
    }
#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
    else if (pixelFormat == GL_RGB565)
#else
    else if (pixelFormat == GL_UNSIGNED_SHORT_5_6_5)
#endif
    {
        return MTLPixelFormatRGBA16Unorm;
    }
    
    ELOG(@"Unknown GL pixelFormat. Add pixelFormat: %0x pixelType: %0x", pixelFormat, pixelType);

    assert(!"Unknown GL pixelFormat. Add it");
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
    Shader* fillScreenShader = MetalShaderManager.sharedInstance.vertexShaders.firstObject;
    desc.vertexFunction = [lib newFunctionWithName:fillScreenShader.function constantValues:constants error:&error];
    
    if(error) {
        ELOG(@"%@", error);
    }
    
    Shader* blitterShader = MetalShaderManager.sharedInstance.blitterShaders.firstObject;
    desc.fragmentFunction = [lib newFunctionWithName:blitterShader.function];
    desc.colorAttachments[0].pixelFormat = self.mtlview.currentDrawable.layer.pixelFormat;
    
    _blitPipeline = [_device newRenderPipelineStateWithDescriptor:desc error:&error];
    if(error) {
        ELOG(@"%@", error);
    }
}

- (void)setupEffectFilterShader:(Shader*)filterShader {
    self.effectFilterShader = filterShader;
    NSError* error;
    
    MTLFunctionConstantValues* constants = [MTLFunctionConstantValues new];
    bool FlipY = self.emulatorCore.rendersToOpenGL;
    [constants setConstantValue:&FlipY type:MTLDataTypeBool withName:@"FlipY"];
    
    id<MTLLibrary> lib = [_device newDefaultLibrary];
    
    // Fill screen shader
    MTLRenderPipelineDescriptor* desc = [MTLRenderPipelineDescriptor new];
    Shader* fillScreenShader = MetalShaderManager.sharedInstance.vertexShaders.firstObject;
    desc.vertexFunction = [lib newFunctionWithName:fillScreenShader.function constantValues:constants error:&error];
    if(error) {
        ELOG(@"%@", error);
    }
        
    // Filter shader
    desc.fragmentFunction = [lib newFunctionWithName:filterShader.function];
    desc.colorAttachments[0].pixelFormat = self.mtlview.currentDrawable.layer.pixelFormat;
    
    _effectFilterPipeline = [_device newRenderPipelineStateWithDescriptor:desc error:&error];
    if(error) {
        ELOG(@"%@", error);
    }
}

// MARK: - fsh Shaders
+ (GLuint)shaderWithContents:(NSString*)contents type:(GLenum)type
{

    const GLchar *source = [contents UTF8String];
    // Create the shader object
    GLuint shader = glCreateShader(type);
    // Load the shader source
    glShaderSource(shader, 1, &source, 0);
    // Compile the shader
    glCompileShader(shader);
    // Check for errors
    GLint status = 0;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &status);
    if (status == GL_FALSE) {
        GLchar messages[1024];
        glGetShaderInfoLog(shader, sizeof(messages), 0, &messages[0]);
        NSLog(@"%@:- GLSL Shader Error: %s", self, messages);
    }
    return shader;
}

+ (GLuint)programWithVertexShader:(NSString*)vsh fragmentShader:(NSString*)fsh
{
    // Build shaders
    GLuint vertex_shader = [self shaderWithContents:vsh type:GL_VERTEX_SHADER];
    GLuint fragment_shader = [self shaderWithContents:fsh type:GL_FRAGMENT_SHADER];
    // Create program
    GLuint program = glCreateProgram();
    // Attach shaders
    glAttachShader(program, vertex_shader);
    glAttachShader(program, fragment_shader);
    // Link program
    glLinkProgram(program);
    // Check for errors
    GLint status;
    glGetProgramiv(program, GL_LINK_STATUS, &status);
    if (status == GL_FALSE) {
        GLchar messages[1024];
        glGetProgramInfoLog(program, sizeof(messages), 0, &messages[0]);
        NSLog(@"%@:- GLSL Program Error: %s", self, messages);
    }
    // Delete shaders
    glDeleteShader(vertex_shader);
    glDeleteShader(fragment_shader);

    return program;
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
    if (self.emulatorCore.skipEmulationLoop)
        return;
    MAKEWEAK(self);

    void (^renderBlock)(void) = ^()
    {
        MAKESTRONG_RETURN_IF_NIL(self);
//        PVMetalViewController *self = strongself;
        
        id<MTLTexture> outputTex = view.currentDrawable.texture;
        
        if (outputTex == nil)
        {
            // MTKView is set up wrong. Skip a frame and hope things fix themselves
            return;
        }
        
        if (strongself.emulatorCore.rendersToOpenGL)
        {
            [strongself.emulatorCore.frontBufferLock lock];
        }
        
        id<MTLCommandBuffer> commandBuffer = [strongself.commandQueue commandBuffer];
        strongself.previousCommandBuffer = commandBuffer;
        
        CGRect screenRect = strongself.emulatorCore.screenRect;
        
        [strongself updateInputTexture];
        
        if (!strongself.emulatorCore.rendersToOpenGL)
        {
            const uint8_t* videoBuffer = strongself.emulatorCore.videoBuffer;
            CGSize videoBufferSize = strongself.emulatorCore.bufferSize;
            uint formatByteWidth = [strongself getByteWidthForPixelFormat:strongself.emulatorCore.pixelFormat type:strongself.emulatorCore.pixelType];
            uint inputBytesPerRow = videoBufferSize.width * formatByteWidth;
            
            id<MTLBuffer> uploadBuffer = strongself->_uploadBuffer[++strongself->_frameCount % BUFFER_COUNT];
            uint8_t* uploadAddress = uploadBuffer.contents;
            

            uint outputBytesPerRow;
            if (screenRect.origin.x == 0 && (screenRect.size.width * 2 >= videoBufferSize.width)) // fast path if x is aligned to edge and excess width isn't too crazy
            {
                outputBytesPerRow = inputBytesPerRow;
                const uint8_t* inputAddress = &videoBuffer[(uint)screenRect.origin.y * inputBytesPerRow];
                uint8_t* outputAddress = uploadAddress;
                memcpy(outputAddress, inputAddress, screenRect.size.height * inputBytesPerRow);
            }
            else
            {
                outputBytesPerRow = screenRect.size.width * formatByteWidth;
                for (uint i = 0; i < (uint)screenRect.size.height; ++i)
                {
                    uint inputRow = screenRect.origin.y + i;
                    const uint8_t* inputAddress = &videoBuffer[(inputRow * inputBytesPerRow) + ((uint)screenRect.origin.x * formatByteWidth)];
                    uint8_t* outputAddress = &uploadAddress[i * outputBytesPerRow];
                    memcpy(outputAddress, inputAddress, outputBytesPerRow);
                }
            }
            
            id<MTLBlitCommandEncoder> encoder = [commandBuffer blitCommandEncoder];
            
            [encoder copyFromBuffer:uploadBuffer
                       sourceOffset:0
                  sourceBytesPerRow:outputBytesPerRow
                sourceBytesPerImage:0
                         sourceSize:MTLSizeMake(screenRect.size.width, screenRect.size.height, 1)
                           toTexture:strongself.inputTexture
                   destinationSlice:0
                   destinationLevel:0
                  destinationOrigin:MTLOriginMake(0, 0, 0)];
            
            [encoder endEncoding];
        }
        
        MTLRenderPassDescriptor* desc = [MTLRenderPassDescriptor new];
        desc.colorAttachments[0].texture = outputTex;
        desc.colorAttachments[0].loadAction = MTLLoadActionClear;
        desc.colorAttachments[0].storeAction = MTLStoreActionStore;
        desc.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0);
        desc.colorAttachments[0].level = 0;
        desc.colorAttachments[0].slice = 0;
        
        id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:desc];
        
        if (strongself->renderSettings.lcdFilterEnabled && [strongself->_emulatorCore.screenType.lowercaseString containsString:@"lcd"] ) {
            
        }
        else if (strongself->renderSettings.crtFilterEnabled && [strongself->_emulatorCore.screenType.lowercaseString containsString:@"crt"] ) {
            if ( [strongself->_effectFilterShader.name isEqualToString:@"CRT"]) {
                struct CRT_Data cbData;
                cbData.DisplayRect.x = 0;
                cbData.DisplayRect.y = 0;
                cbData.DisplayRect.z = screenRect.size.width;
                cbData.DisplayRect.w = screenRect.size.height;
                
                cbData.EmulatedImageSize.x = strongself.inputTexture.width;
                cbData.EmulatedImageSize.y = strongself.inputTexture.height;
                
                cbData.FinalRes.x = view.drawableSize.width;
                cbData.FinalRes.y = view.drawableSize.height;
                
                [encoder setFragmentBytes:&cbData length:sizeof(cbData) atIndex:0];
                
                [encoder setRenderPipelineState:strongself.effectFilterPipeline];
            } else if ( [strongself->_effectFilterShader.name isEqualToString:@"Simple CRT"]) {
                struct SimpleCrtUniforms cbData;
                
                cbData.mame_screen_src_rect.x = 0;
                cbData.mame_screen_src_rect.y = 0;
                cbData.mame_screen_src_rect.z = screenRect.size.width;
                cbData.mame_screen_src_rect.w = screenRect.size.height;
                
                cbData.mame_screen_dst_rect.x = strongself.inputTexture.width;
                cbData.mame_screen_dst_rect.y = strongself.inputTexture.height;
                cbData.mame_screen_dst_rect.z = view.drawableSize.width;
                cbData.mame_screen_dst_rect.w = view.drawableSize.height;
                
                cbData.curv_vert = 5.0;
                cbData.curv_horiz = 4.0;
                cbData.curv_strength = 0.25;
                cbData.light_boost = 1.3;
                cbData.vign_strength = 0.05;
                cbData.zoom_out = 1.1;
                cbData.brightness = 1.0;
                
                [encoder setFragmentBytes:&cbData length:sizeof(cbData) atIndex:0];
                [encoder setRenderPipelineState:strongself.effectFilterPipeline];
            } else if ( [strongself->_effectFilterShader.name containsString:@".fsh"] ) {
                
                static NSString * const vertex_shader = @"\n\
                #version 150 \n\
                in vec4 aPosition;\n\
                void main(void) {\n\
                    gl_Position = aPosition;\n\
                }\n\
                ";
                
                NSString* (^shaderSourceForName)(NSString*, NSError **) = ^NSString* (NSString* name, NSError** error) {
                    NSString *file = [[NSBundle mainBundle] pathForResource:name
                                                                     ofType:@"fsh"
                                                                inDirectory:@"Shaders"];
                    return [NSString stringWithContentsOfFile:file
                                                     encoding:NSUTF8StringEncoding
                                                        error:error];
                };
                
                NSString* shaderName = [strongself->_effectFilterShader.name stringByDeletingPathExtension];
                
                NSError *err;
                
                // Program
                NSString *fragment_shader = shaderSourceForName(@"MasterShader", &err);
                if (err) {
                    ELOG(@"%@", err.localizedDescription);
                    err = NULL;
                }
                fragment_shader = [fragment_shader stringByReplacingOccurrencesOfString:@"{filter}"
                                                                             withString:shaderSourceForName(shaderName, &err)];
                strongself->program = [PVMetalViewController programWithVertexShader:vertex_shader fragmentShader:fragment_shader];
                if (err) {
                    ELOG(@"%@", err.localizedDescription);
                    err = NULL;
                }
                // Attributes
                strongself->position_attribute = glGetAttribLocation(strongself->program, "aPosition");
                // Uniforms
                strongself->resolution_uniform = glGetUniformLocation(strongself->program, "output_resolution");
                
                glGenTextures(1, &strongself->texture);
                glBindTexture(GL_TEXTURE_2D, strongself->texture);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
                glBindTexture(GL_TEXTURE_2D, 0);
                strongself->texture_uniform = glGetUniformLocation(strongself->program, "image");
                
                glGenTextures(1, &strongself->previous_texture);
                glBindTexture(GL_TEXTURE_2D, strongself->previous_texture);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
                glBindTexture(GL_TEXTURE_2D, 0);
                strongself->previous_texture_uniform = glGetUniformLocation(strongself->program, "previous_image");
                
                strongself->frame_blending_mode_uniform = glGetUniformLocation(strongself->program, "frame_blending_mode");
                
                // Program
                
                glUseProgram(strongself->program);
                
                GLuint vao;
//#if !TARGET_OS_OSX
                glGenVertexArrays(1, &vao);
                glBindVertexArray(vao);
//#else  //Not needed because of @import OpenGL.GL3 ?
//                glGenVertexArraysAPPLE(1, &vao);
//                glBindVertexArrayAPPLE(vao);
//#endif
                
                GLuint vbo;
                glGenBuffers(1, &vbo);
                
                // Attributes
                
                static GLfloat const quad[16] = {
                    -1.f, -1.f, 0, 1,
                    -1.f, +1.f, 0, 1,
                    +1.f, -1.f, 0, 1,
                    +1.f, +1.f, 0, 1,
                };
                
                glBindBuffer(GL_ARRAY_BUFFER, vbo);
                glBufferData(GL_ARRAY_BUFFER, sizeof(quad), quad, GL_STATIC_DRAW);
                glEnableVertexAttribArray(strongself->position_attribute);
                glVertexAttribPointer(strongself->position_attribute, 4, GL_FLOAT, GL_FALSE, 0, 0);
            }
        } else {
                [encoder setRenderPipelineState:strongself.blitPipeline];
        }
        
        [encoder setFragmentTexture:strongself.inputTexture atIndex:0];
        [encoder setFragmentSamplerState:strongself->renderSettings.smoothingEnabled ? strongself.linearSampler : strongself.pointSampler atIndex:0];
        [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
        [encoder endEncoding];

		[commandBuffer presentDrawable:view.currentDrawable];
		// This should exist, but fails on some xcode's?! -jm
//        [commandBuffer presentDrawable:view.currentDrawable afterMinimumDuration:1.0/view.preferredFramesPerSecond];
        [commandBuffer commit];

        if ([strongself->_emulatorCore rendersToOpenGL]) {
            [strongself->_emulatorCore.frontBufferLock unlock];
        }
    };

    if ([self.emulatorCore rendersToOpenGL]) {
        if ((!self.emulatorCore.isSpeedModified && !self.emulatorCore.isEmulationPaused) || self.emulatorCore.isFrontBufferReady) {
            [self.emulatorCore.frontBufferCondition lock];
            while (UNLIKELY(!self.emulatorCore.isFrontBufferReady) && LIKELY(!self.emulatorCore.isEmulationPaused))
            {
                [self.emulatorCore.frontBufferCondition wait];
            }
            BOOL isFrontBufferReady = self.emulatorCore.isFrontBufferReady;
            [self.emulatorCore.frontBufferCondition unlock];
            if (isFrontBufferReady) {
                renderBlock();
                [self->_emulatorCore.frontBufferCondition lock];
                self->_emulatorCore.isFrontBufferReady = NO;
                [self->_emulatorCore.frontBufferCondition signal];
                [self->_emulatorCore.frontBufferCondition unlock];
            }
        }
    } else {
        if (self.emulatorCore.isSpeedModified) {
            renderBlock();
        } else {
            if (UNLIKELY(self.emulatorCore.isDoubleBuffered))
            {
                [self.emulatorCore.frontBufferCondition lock];
                while (UNLIKELY(!self.emulatorCore.isFrontBufferReady) && LIKELY(!self.emulatorCore.isEmulationPaused))
                {
                    [self.emulatorCore.frontBufferCondition wait];
                }
                self->_emulatorCore.isFrontBufferReady = NO;
                [self->_emulatorCore.frontBufferLock lock];
                renderBlock();
                [self->_emulatorCore.frontBufferLock unlock];
                [self->_emulatorCore.frontBufferCondition unlock];
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

#pragma mark - PVRenderDelegate protocol methods

- (void)startRenderingOnAlternateThread
{
    self.emulatorCore.glesVersion = self.glesVersion;

//#if TARGET_OS_MACCATALYST || TARGET_OS_OSX
//    return;
//#endif

#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
    self.alternateThreadBufferCopyGLContext = [[EAGLContext alloc] initWithAPI:[self.glContext API] sharegroup:[self.glContext sharegroup]];
        
    self.alternateThreadGLContext = [[EAGLContext alloc] initWithAPI:[self.glContext API] sharegroup:[self.glContext sharegroup]];
    [EAGLContext setCurrentContext:self.alternateThreadGLContext];
#endif
    
    // Setup framebuffer
    if (alternateThreadFramebufferBack == 0)
    {
        glGenFramebuffers(1, &alternateThreadFramebufferBack);
    }
    glBindFramebuffer(GL_FRAMEBUFFER, alternateThreadFramebufferBack);
    
    // Setup color textures to render into
    if (alternateThreadColorTextureBack == 0)
    {
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
#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
        [[EAGLContext currentContext] texImageIOSurface:backingIOSurface
                                   target:GL_TEXTURE_2D
                           internalFormat:GL_RGBA
                                    width:width
                                   height:height
                                   format:GL_RGBA
                                     type:GL_UNSIGNED_BYTE
                                    plane:0];
#else
        // TODO: This?
//        [CAOpenGLLayer layer];
//        CGLPixelFormatObj *pf;
//        CGLTexImageIOSurface2D(self.mEAGLContext, GL_TEXTURE_2D, GL_RGBA, width, height, GL_RGBA, GL_UNSIGNED_BYTE, backingIOSurface, 0);
#endif
        glBindTexture(GL_TEXTURE_2D, 0);
        

        IOSurfaceUnlock(backingIOSurface, 0, NULL);

        MTLTextureDescriptor* mtlDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
																						   width:width
																						  height:height
																					   mipmapped:NO];
        backingMTLTexture = [_device newTextureWithDescriptor:mtlDesc
													iosurface:backingIOSurface
														plane:0];
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
    glFlush();
    
    // Blit back buffer to front buffer
    [self.emulatorCore.frontBufferLock lock];
    
    // glFlush + waitUntilScheduled is how we coordinate texture access between OpenGL and Metal
    // There might be a more performant solution using MTLFences or MTLEvents but this is an ok first impl
    [self.previousCommandBuffer waitUntilScheduled];
    
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    id<MTLBlitCommandEncoder> encoder = [commandBuffer blitCommandEncoder];
    
    CGRect screenRect = self.emulatorCore.screenRect;
    
    [encoder copyFromTexture:backingMTLTexture
                 sourceSlice:0
                 sourceLevel:0
                sourceOrigin:MTLOriginMake(screenRect.origin.x, screenRect.origin.y, 0)
                  sourceSize:MTLSizeMake(screenRect.size.width, screenRect.size.height, 1)
                   toTexture:_inputTexture
            destinationSlice:0
            destinationLevel:0
           destinationOrigin:MTLOriginMake(0, 0, 0)];
    
    [encoder endEncoding];
    [commandBuffer commit];
    
    [self.emulatorCore.frontBufferLock unlock];
    
    // Notify render thread that the front buffer is ready
    [self.emulatorCore.frontBufferCondition lock];
    [self.emulatorCore setIsFrontBufferReady:YES];
    [self.emulatorCore.frontBufferCondition signal];
    [self.emulatorCore.frontBufferCondition unlock];
}
@end
