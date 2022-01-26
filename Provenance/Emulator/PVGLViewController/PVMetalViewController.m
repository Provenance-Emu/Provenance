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

@property (nonatomic, strong) MTKView *mtlview;
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLRenderPipelineState> blitPipeline;
@property (nonatomic, strong) id<MTLRenderPipelineState> crtFilterPipeline;
@property (nonatomic, strong) id<MTLSamplerState> pointSampler;
@property (nonatomic, strong) id<MTLSamplerState> linearSampler;
@property (nonatomic, strong) id<MTLTexture> inputTexture;
@property (nonatomic, strong) id<MTLCommandBuffer> previousCommandBuffer; // used for scheduling with OpenGL context

@property (nonatomic, strong) EAGLContext *glContext;
@property (nonatomic, strong) EAGLContext *alternateThreadGLContext;
@property (nonatomic, strong) EAGLContext *alternateThreadBufferCopyGLContext;

@property (nonatomic, assign) GLESVersion glesVersion;

@end

PV_OBJC_DIRECT_MEMBERS
@implementation PVMetalViewController

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

    if (self.emulatorCore.rendersToOpenGL)
    {
        self.glContext = [self bestContext];

        ILOG(@"Initiated GLES version %lu", (unsigned long)self.glContext.API);

        // TODO: Need to benchmark this

        self.glContext.multiThreaded = PVSettingsModel.shared.debugOptions.multiThreadedGL;

        [EAGLContext setCurrentContext:self.glContext];
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
//     CVDisplayLinkCreateWithActiveCGDisplays(&displayLink);
//     CVDisplayLinkSetOutputCallback(displayLink, &MyDisplayLinkCallback, (__bridge void*)self);
//     CVDisplayLinkStart(displayLink);

    view.opaque = YES;
    view.layer.opaque = YES;

    view.userInteractionEnabled = NO;

    GLenum depthFormat = self.emulatorCore.depthFormat;
    switch (depthFormat) {
        case GL_DEPTH_COMPONENT16:
            if (@available(macOS 10.12, iOS 13.0, *))
            {
                view.depthStencilPixelFormat = MTLPixelFormatDepth16Unorm;
            }
            else
            {
                view.depthStencilPixelFormat = MTLPixelFormatDepth32Float;
            }
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
        if(PVSettingsModel.shared.debugOptions.multiSampling) {
            //[view setSampleCount:4]; // Having the view multi-sampled doesn't make sense to me. We need to resolve the MSAA before presenting it
        }
    }

    [self setupTexture];
    
    [self setupBlitShader];
    [self setupCRTShader];

    alternateThreadFramebufferBack = 0;
    alternateThreadColorTextureBack = 0;
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

- (void) updatePreferredFPS {
    float preferredFPS = self.emulatorCore.frameInterval;
    WLOG(@"updatePreferredFPS (%f)", preferredFPS);
    if (preferredFPS  < 10) {
        WLOG(@"Cores frame interval (%f) too low. Setting to 60", preferredFPS);
        preferredFPS = 60;
    }
    self.mtlview.preferredFramesPerSecond = preferredFPS;
    [self setPreferredFramesPerSecond:preferredFPS];
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
        [self.mtlview setFrame:CGRectMake(0, 0, width, height)];
    }

    [self updatePreferredFPS];
}

- (void)updateInputTexture
{
    CGRect screenRect = self.emulatorCore.screenRect;
    MTLPixelFormat pixelFormat = [self getMTLPixelFormatFromGLPixelFormat:self.emulatorCore.pixelFormat type:self.emulatorCore.pixelType];
    
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
    desc.colorAttachments[0].pixelFormat = self.mtlview.currentDrawable.layer.pixelFormat;
    
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
    desc.colorAttachments[0].pixelFormat = self.mtlview.currentDrawable.layer.pixelFormat;
    
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
        self.previousCommandBuffer = commandBuffer;
        
        CGRect screenRect = strongself.emulatorCore.screenRect;
        
        [self updateInputTexture];
        
        if (!strongself.emulatorCore.rendersToOpenGL)
        {
            const void* videoBuffer = strongself.emulatorCore.videoBuffer;
            CGSize videoBufferSize = strongself.emulatorCore.bufferSize;
            uint formatByteWidth = [strongself getByteWidthForPixelFormat:strongself.emulatorCore.pixelFormat type:strongself.emulatorCore.pixelType];
            
            id<MTLBuffer> uploadBuffer = strongself->_uploadBuffer[++strongself->_frameCount % BUFFER_COUNT];
            
            memcpy(uploadBuffer.contents, videoBuffer, videoBufferSize.width * screenRect.size.height * formatByteWidth);
            
            id<MTLBlitCommandEncoder> encoder = [commandBuffer blitCommandEncoder];
            
            [encoder copyFromBuffer:uploadBuffer
                       sourceOffset:0
                  sourceBytesPerRow:videoBufferSize.width * formatByteWidth
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
        
        if (strongself->renderSettings.crtFilterEnabled)
        {
            struct CRT_Data cbData;
            cbData.DisplayRect.x = screenRect.origin.x;
            cbData.DisplayRect.y = screenRect.origin.y;
            cbData.DisplayRect.z = screenRect.size.width;
            cbData.DisplayRect.w = screenRect.size.height;
            
            cbData.EmulatedImageSize.x = strongself.inputTexture.width;
            cbData.EmulatedImageSize.y = strongself.inputTexture.height;
            
            cbData.FinalRes.x = view.drawableSize.width;
            cbData.FinalRes.y = view.drawableSize.height;
            
            [encoder setFragmentBytes:&cbData length:sizeof(cbData) atIndex:0];
            
            [encoder setRenderPipelineState:strongself.crtFilterPipeline];
        }
        else
        {
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

        if ([strongself->_emulatorCore rendersToOpenGL])
        {
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

#pragma mark - PVRenderDelegate protocol methods

- (void)startRenderingOnAlternateThread
{
    self.emulatorCore.glesVersion = self.glesVersion;
    self.alternateThreadBufferCopyGLContext = [[EAGLContext alloc] initWithAPI:[self.glContext API] sharegroup:[self.glContext sharegroup]];
        
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
                sourceOrigin:MTLOriginMake(0, 0, 0)
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
