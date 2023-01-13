//
//  PVGCVRViewController.m
//  VirtualBoyVR-iOS
//
//  Created by Tom Kidd on 9/3/18.
//  Copyright © 2018 Tom Kidd. All rights reserved.
//

#import "PVGCVRViewController.h"
#import <PVSupport/PVEmulatorCore.h>
#import "PVSettingsModel.h"
#import <QuartzCore/QuartzCore.h>
#import <PVMednafen/MednafenGameCore.h>

@interface PVGCVRViewController ()
{
    GLKVector3 vertices[8];
    GLKVector2 textureCoordinates[8];
    GLKVector3 triangleVertices[6];
    GLKVector2 triangleTexCoords[6];
    
    GLuint texture;
    
    CGRect screenRect;
    const void* videoBuffer;
    GLenum videoBufferPixelFormat;
    GLenum videoBufferPixelType;
    CGSize videoBufferSize;
    
    CGFloat xOffset;
    CGFloat yOffset;
    
    CGFloat scale;
    CGFloat sbs;
}

@property (nonatomic, strong) EAGLContext *glContext;
@property (nonatomic, strong) GLKBaseEffect *effect;
@property (nonatomic, strong) GVRCardboardView *cardboardView;
@property (nonatomic, strong) CADisplayLink *displayLink;

@end

@implementation PVGCVRViewController

- (instancetype)initWithEmulatorCore:(PVEmulatorCore *)emulatorCore
{
    if ((self = [super init]))
    {
        self.emulatorCore = emulatorCore;
    }
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
//        self.cardboardView = [[GVRCardboardView alloc] initWithFrame:CGRectMake(0, 0, 768, 224)];
    self.cardboardView = [[GVRCardboardView alloc] initWithFrame:CGRectZero];
    self.cardboardView.delegate = self;
    self.cardboardView.vrModeEnabled = true;
    self.view = self.cardboardView;
    
    self.glContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
    [EAGLContext setCurrentContext:self.glContext];

    self.cardboardView.context = self.glContext;
    
    self.displayLink = [CADisplayLink displayLinkWithTarget: self selector: @selector(render)];
    [self.displayLink addToRunLoop: [NSRunLoop currentRunLoop] forMode: NSDefaultRunLoopMode];

    self.effect = [[GLKBaseEffect alloc] init];
    
    sbs = (CGFloat)[[NSUserDefaults standardUserDefaults] integerForKey:@"sbs"];
    scale = (CGFloat)[[NSUserDefaults standardUserDefaults] floatForKey:@"scale"];
    
    [self setupTexture];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (void)setupTexture
{
    glGenTextures(1, &texture);
    glBindTexture(GL_TEXTURE_2D, texture);
    glTexImage2D(GL_TEXTURE_2D, 0, [self.emulatorCore internalPixelFormat], self.emulatorCore.bufferSize.width, self.emulatorCore.bufferSize.height, 0, [self.emulatorCore pixelFormat], [self.emulatorCore pixelType], self.emulatorCore.videoBuffer);
    if ([[PVSettingsModel sharedInstance] imageSmoothing])
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

- (void)cardboardView:(GVRCardboardView *)cardboardView willStartDrawing:(GVRHeadTransform *)headTransform {

}

- (void)cardboardView:(GVRCardboardView *)cardboardView prepareDrawFrame:(GVRHeadTransform *)headTransform {
    
//    printf("viewport kGVRCenterEye (%f, %f) %fx%f \n", [headTransform viewportForEye:kGVRCenterEye].origin.x, [headTransform viewportForEye:kGVRCenterEye].origin.y, [headTransform viewportForEye:kGVRCenterEye].size.width, [headTransform viewportForEye:kGVRCenterEye].size.height);
//    printf("viewport kGVRLeftEye (%f, %f) %fx%f \n", [headTransform viewportForEye:kGVRLeftEye].origin.x, [headTransform viewportForEye:kGVRLeftEye].origin.y, [headTransform viewportForEye:kGVRLeftEye].size.width, [headTransform viewportForEye:kGVRLeftEye].size.height);
//    printf("viewport kGVRRightEye (%f, %f) %fx%f \n", [headTransform viewportForEye:kGVRRightEye].origin.x, [headTransform viewportForEye:kGVRRightEye].origin.y, [headTransform viewportForEye:kGVRRightEye].size.width, [headTransform viewportForEye:kGVRRightEye].size.height);
    
    CGFloat Vw = [headTransform viewportForEye:kGVRLeftEye].size.width + [headTransform viewportForEye:kGVRRightEye].size.width;
    CGFloat Vh = [headTransform viewportForEye:kGVRLeftEye].size.height;
    
    // ASSUMPTION: Each side of the Virtual Boy's screen (each eye) is 384 x 224
    // https://en.wikipedia.org/wiki/Virtual_Boy_hardware#Specifications
    CGFloat Fw = (768.0 + sbs) * scale;
    CGFloat Fh = 224.0 * scale;
    
    xOffset = (Vw - Fw) / 2;
    yOffset = (Vh - Fh) / 2;
    
    if (self.emulatorCore.isSpeedModified)
    {
        [self fetchVideoBuffer];
        [self renderBlock];
    }
    else
    {
        if (self.emulatorCore.isDoubleBuffered)
        {
            [self.emulatorCore.frontBufferCondition lock];
            while (!self.emulatorCore.isFrontBufferReady) [self.emulatorCore.frontBufferCondition wait];
            [self.emulatorCore setIsFrontBufferReady:NO];
            [self.emulatorCore.frontBufferLock lock];
            [self fetchVideoBuffer];
            [self renderBlock];
            [self.emulatorCore.frontBufferLock unlock];
            [self.emulatorCore.frontBufferCondition unlock];
        }
        else
        {
            @synchronized(self.emulatorCore)
            {
                [self fetchVideoBuffer];
                [self renderBlock];
            }
        }
    }
}

- (void)cardboardView:(GVRCardboardView *)cardboardView drawEye:(GVREye)eye withHeadTransform:(GVRHeadTransform *)headTransform {

//    printf("eye: %li viewport (%f, %f) %fx%f \n", (long)eye, [headTransform viewportForEye:eye].origin.x, [headTransform viewportForEye:eye].origin.y, [headTransform viewportForEye:eye].size.width, [headTransform viewportForEye:eye].size.height);
    
    // per-eye frame thing goes here
    
}

- (void)encodeWithCoder:(nonnull NSCoder *)aCoder {
    
}

- (void)cardboardView:(GVRCardboardView *)cardboardView didFireEvent:(GVRUserEvent)event {
    switch (event) {
        case kGVRUserEventBackButton:
            [[self navigationController] popToRootViewControllerAnimated:true];
            break;
            
        default:
            break;
    }
}

- (void)traitCollectionDidChange:(nullable UITraitCollection *)previousTraitCollection {
    
}

- (void)preferredContentSizeDidChangeForChildContentContainer:(nonnull id<UIContentContainer>)container {
    
}

//- (CGSize)sizeForChildContentContainer:(nonnull id<UIContentContainer>)container withParentContainerSize:(CGSize)parentSize {
//
//}

- (void)systemLayoutFittingSizeDidChangeForChildContentContainer:(nonnull id<UIContentContainer>)container {
    
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(nonnull id<UIViewControllerTransitionCoordinator>)coordinator {
    
}

- (void)willTransitionToTraitCollection:(nonnull UITraitCollection *)newCollection withTransitionCoordinator:(nonnull id<UIViewControllerTransitionCoordinator>)coordinator {
    
}

- (void)didUpdateFocusInContext:(nonnull UIFocusUpdateContext *)context withAnimationCoordinator:(nonnull UIFocusAnimationCoordinator *)coordinator {
    
}

- (void)setNeedsFocusUpdate {
    
}

//- (BOOL)shouldUpdateFocusInContext:(nonnull UIFocusUpdateContext *)context {
//
//}

- (void)updateFocusIfNeeded {
    
}

- (void)render {
    [self.cardboardView render];
}

- (void)fetchVideoBuffer {
    screenRect = [self.emulatorCore screenRect];
    videoBufferPixelFormat = [self.emulatorCore pixelFormat];
    videoBufferPixelType = [self.emulatorCore pixelType];
    videoBufferSize = [self.emulatorCore bufferSize];
    videoBuffer = [self.emulatorCore videoBuffer];
}

- (void)renderBlock {
    
    GLsizei gl_screenwidth = videoBufferSize.width * scale;
    GLsizei gl_screenheight = videoBufferSize.height * scale;
    
    glViewport(xOffset, yOffset, gl_screenwidth, gl_screenheight);

//    glViewport(0, 0, 3500, 3000);

//    glClearColor(0.0, 1.0, 0.0, 1.0); // green
    glClearColor(0.0, 0.0, 0.0, 1.0); // black
    glClear(GL_COLOR_BUFFER_BIT);
    
//    printf("*****\n");
//    printf("screenRect.origin.x: %f\n", screenRect.origin.x);
//    printf("screenRect.origin.y: %f\n", screenRect.origin.y);
//    printf("screenRect.size.width: %f\n", screenRect.size.width);
//    printf("screenRect.size.height: %f\n", screenRect.size.height);
//    printf("videoBufferSize.width: %f\n", videoBufferSize.width);
//    printf("videoBufferSize.height: %f\n", videoBufferSize.height);
//
//    printf("gl_screenwidth: %d\n", gl_screenwidth);
//    printf("gl_screenheight: %d\n", gl_screenheight);
//
//    printf("xOffset: %f\n", xOffset);
//    printf("yOffset: %f\n", yOffset);

    
    CGFloat texLeft = screenRect.origin.x / videoBufferSize.width;
    CGFloat texTop = screenRect.origin.y / videoBufferSize.height;
    CGFloat texRight = ( screenRect.origin.x + screenRect.size.width ) / videoBufferSize.width;
    CGFloat texBottom = ( screenRect.origin.y + screenRect.size.height ) / videoBufferSize.height;
    
    vertices[0] = GLKVector3Make(-1.0, -1.0,  1.0); // Left  bottom
    vertices[1] = GLKVector3Make( 1.0, -1.0,  1.0); // Right bottom
    vertices[2] = GLKVector3Make( 1.0,  1.0,  1.0); // Right top
    vertices[3] = GLKVector3Make(-1.0,  1.0,  1.0); // Left  top
    
    textureCoordinates[0] = GLKVector2Make(texLeft, texBottom); // Left bottom
    textureCoordinates[1] = GLKVector2Make(texRight, texBottom); // Right bottom
    textureCoordinates[2] = GLKVector2Make(texRight, texTop); // Right top
    textureCoordinates[3] = GLKVector2Make(texLeft, texTop); // Left top
    
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
    glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, videoBufferSize.width, videoBufferSize.height, videoBufferPixelFormat, videoBufferPixelType, videoBuffer);
    
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

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
}

@end
