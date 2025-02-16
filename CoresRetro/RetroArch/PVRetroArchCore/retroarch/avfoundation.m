#include <TargetConditionals.h>
#include <Foundation/Foundation.h>
#include <AVFoundation/AVFoundation.h>
#include "../../libretro.h"
#include "../camera/camera_driver.h"
#include "../verbosity.h"
#import <Accelerate/Accelerate.h>

@interface AVCameraManager : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>
@property (strong, nonatomic) AVCaptureSession *session;
@property (strong, nonatomic) AVCaptureDeviceInput *input;
@property (strong, nonatomic) AVCaptureVideoDataOutput *output;
@property (assign) uint32_t *frameBuffer;
@property (assign) size_t width;
@property (assign) size_t height;

- (bool)setupCameraSession;
@end

@implementation AVCameraManager

+ (AVCameraManager *)sharedInstance {
    static AVCameraManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[AVCameraManager alloc] init];
    });
    return instance;
}

- (void)requestCameraAuthorizationWithCompletion:(void (^)(BOOL granted))completion {
    RARCH_LOG("[Camera]: Checking camera authorization status\n");

    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];

    switch (status) {
        case AVAuthorizationStatusAuthorized: {
            RARCH_LOG("[Camera]: Camera access already authorized\n");
            completion(YES);
            break;
        }

        case AVAuthorizationStatusNotDetermined: {

            RARCH_LOG("[Camera]: Requesting camera authorization...\n");
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo
                                     completionHandler:^(BOOL granted) {
                RARCH_LOG("[Camera]: Authorization %s\n", granted ? "granted" : "denied");
                completion(granted);
            }];
            break;
        }

        case AVAuthorizationStatusDenied: {
            RARCH_ERR("[Camera]: Camera access denied by user\n");
            completion(NO);
            break;
        }

        case AVAuthorizationStatusRestricted: {
            RARCH_ERR("[Camera]: Camera access restricted (parental controls?)\n");
            completion(NO);
            break;
        }

        default: {
            RARCH_ERR("[Camera]: Unknown authorization status\n");
            completion(NO);
            break;
        }
    }
}

- (void)captureOutput:(AVCaptureOutput *)output
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {
    if (!self.frameBuffer)
        return;

    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer, 0);

    size_t sourceWidth = CVPixelBufferGetWidth(imageBuffer);
    size_t sourceHeight = CVPixelBufferGetHeight(imageBuffer);
    OSType pixelFormat = CVPixelBufferGetPixelFormatType(imageBuffer);

    RARCH_LOG("[Camera]: Processing frame %zux%zu format: %u\n", sourceWidth, sourceHeight, (unsigned int)pixelFormat);

    // Setup vImage buffers
    vImage_Buffer srcBuffer = {}, dstBuffer = {};
    vImage_Error err = kvImageNoError;

    // Setup destination buffer (our frameBuffer)
    dstBuffer.data = self.frameBuffer;
    dstBuffer.width = self.width;
    dstBuffer.height = self.height;
    dstBuffer.rowBytes = self.width * 4;

    // Calculate aspect fill scaling
    float sourceAspect = (float)sourceWidth / sourceHeight;
    float targetAspect = (float)self.width / self.height;
    float scale;
    size_t scaledWidth, scaledHeight;

    if (sourceAspect > targetAspect) {
        // Source is wider - scale to match height
        scale = (float)self.height / sourceHeight;
        scaledWidth = sourceWidth * scale;
        scaledHeight = self.height;
    } else {
        // Source is taller - scale to match width
        scale = (float)self.width / sourceWidth;
        scaledWidth = self.width;
        scaledHeight = sourceHeight * scale;
    }

    // Calculate centering offsets
    size_t xOffset = (scaledWidth - self.width) / 2;
    size_t yOffset = (scaledHeight - self.height) / 2;

    RARCH_LOG("[Camera]: Scaling from %zux%zu to %zux%zu (offset: %zu,%zu)\n",
              sourceWidth, sourceHeight, scaledWidth, scaledHeight, xOffset, yOffset);

    switch (pixelFormat) {
        case kCVPixelFormatType_32BGRA: {
            // Direct BGRA conversion
            srcBuffer.data = CVPixelBufferGetBaseAddress(imageBuffer);
            srcBuffer.width = sourceWidth;
            srcBuffer.height = sourceHeight;
            srcBuffer.rowBytes = CVPixelBufferGetBytesPerRow(imageBuffer);

            // Convert BGRA to RGBA
            uint8_t permuteMap[4] = {2, 1, 0, 3}; // BGRA -> RGBA
            err = vImagePermuteChannels_ARGB8888(&srcBuffer, &dstBuffer, permuteMap, kvImageNoFlags);
            break;
        }

        case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange: {
            // YUV to RGB conversion
            vImage_Buffer srcY = {}, srcCbCr = {};

            srcY.data = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
            srcY.width = sourceWidth;
            srcY.height = sourceHeight;
            srcY.rowBytes = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 0);

            srcCbCr.data = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 1);
            srcCbCr.width = sourceWidth / 2;
            srcCbCr.height = sourceHeight / 2;
            srcCbCr.rowBytes = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 1);

            vImage_YpCbCrToARGB info;
            vImage_YpCbCrPixelRange pixelRange =
                (pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange) ?
                    (vImage_YpCbCrPixelRange){16, 128, 235, 240} :  // Video range
                    (vImage_YpCbCrPixelRange){0, 128, 255, 255};    // Full range

            err = vImageConvert_YpCbCrToARGB_GenerateConversion(kvImage_YpCbCrToARGBMatrix_ITU_R_601_4,
                                                               &pixelRange,
                                                               &info,
                                                               kvImage420Yp8_CbCr8,
                                                               kvImageARGB8888,
                                                               kvImageNoFlags);

            if (err == kvImageNoError) {
                err = vImageConvert_420Yp8_CbCr8ToARGB8888(&srcY,
                                                          &srcCbCr,
                                                          &dstBuffer,
                                                          &info,
                                                          NULL,
                                                          255,
                                                          kvImageNoFlags);
            }
            break;
        }

        default:
            RARCH_ERR("[Camera]: Unsupported pixel format: %u\n", (unsigned int)pixelFormat);
            err = kvImageUnknownFlagsBit;
            break;
    }

    if (err != kvImageNoError) {
        RARCH_ERR("[Camera]: Error processing frame: %ld\n", err);
    }

    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
}

- (bool)setupCameraSession {
    // Initialize capture session
    self.session = [[AVCaptureSession alloc] init];

    // Get camera device
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (!device) {
        RARCH_ERR("[Camera]: No camera device found\n");
        return false;
    }

    // Create device input
    NSError *error = nil;
    self.input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    if (error) {
        RARCH_ERR("[Camera]: Failed to create device input: %s\n",
                  [error.localizedDescription UTF8String]);
        return false;
    }

    if ([self.session canAddInput:self.input]) {
        [self.session addInput:self.input];
        RARCH_LOG("[Camera]: Added camera input to session\n");
    }

    // Create and configure video output
    self.output = [[AVCaptureVideoDataOutput alloc] init];
    self.output.videoSettings = @{
        (NSString*)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)
    };
    [self.output setSampleBufferDelegate:self queue:dispatch_get_main_queue()];

    if ([self.session canAddOutput:self.output]) {
        [self.session addOutput:self.output];
        RARCH_LOG("[Camera]: Added video output to session\n");
    }

    return true;
}

@end

typedef struct
{
    AVCameraManager *manager;
    unsigned width;
    unsigned height;
} avfoundation_t;

static void generateColorBars(uint32_t *buffer, size_t width, size_t height) {
    const uint32_t colors[] = {
        0xFFFFFFFF,  // White
        0xFFFFFF00,  // Yellow
        0xFF00FFFF,  // Cyan
        0xFF00FF00,  // Green
        0xFFFF00FF,  // Magenta
        0xFFFF0000,  // Red
        0xFF0000FF,  // Blue
        0xFF000000   // Black
    };

    size_t barWidth = width / 8;
    for (size_t y = 0; y < height; y++) {
        for (size_t x = 0; x < width; x++) {
            size_t colorIndex = x / barWidth;
            buffer[y * width + x] = colors[colorIndex];
        }
    }
}

static void *avfoundation_init(const char *device, uint64_t caps,
                             unsigned width, unsigned height)
{
    RARCH_LOG("[Camera]: Initializing AVFoundation camera %ux%u\n", width, height);

    avfoundation_t *avf = (avfoundation_t*)calloc(1, sizeof(avfoundation_t));
    if (!avf) {
        RARCH_ERR("[Camera]: Failed to allocate avfoundation_t\n");
        return NULL;
    }

    avf->manager = [AVCameraManager sharedInstance];
    avf->width = width;
    avf->height = height;
    avf->manager.width = width;
    avf->manager.height = height;

    // Check if we're on the main thread
    if ([NSThread isMainThread]) {
        RARCH_LOG("[Camera]: Initializing on main thread\n");
        // Direct initialization on main thread
        AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
        if (status != AVAuthorizationStatusAuthorized) {
            RARCH_ERR("[Camera]: Camera access not authorized (status: %d)\n", (int)status);
            free(avf);
            return NULL;
        }
    } else {
        RARCH_LOG("[Camera]: Initializing on background thread\n");
        // Use dispatch_sync to run authorization check on main thread
        __block AVAuthorizationStatus status;
        dispatch_sync(dispatch_get_main_queue(), ^{
            status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
        });

        if (status != AVAuthorizationStatusAuthorized) {
            RARCH_ERR("[Camera]: Camera access not authorized (status: %d)\n", (int)status);
            free(avf);
            return NULL;
        }
    }

    // Allocate frame buffer
    avf->manager.frameBuffer = (uint32_t*)calloc(width * height, sizeof(uint32_t));
    if (!avf->manager.frameBuffer) {
        RARCH_ERR("[Camera]: Failed to allocate frame buffer\n");
        free(avf);
        return NULL;
    }

    // Initialize capture session on main thread
    __block bool setupSuccess = false;

    if ([NSThread isMainThread]) {
        @autoreleasepool {
            setupSuccess = [avf->manager setupCameraSession];
            if (setupSuccess) {
                [avf->manager.session startRunning];
                RARCH_LOG("[Camera]: Started camera session\n");
            }
        }
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            @autoreleasepool {
                setupSuccess = [avf->manager setupCameraSession];
                if (setupSuccess) {
                    [avf->manager.session startRunning];
                    RARCH_LOG("[Camera]: Started camera session\n");
                }
            }
        });
    }

    if (!setupSuccess) {
        RARCH_ERR("[Camera]: Failed to setup camera\n");
        free(avf->manager.frameBuffer);
        free(avf);
        return NULL;
    }

    // Add a check to verify the session is actually running
    if (!avf->manager.session.isRunning) {
        RARCH_ERR("[Camera]: Failed to start camera session\n");
        free(avf->manager.frameBuffer);
        free(avf);
        return NULL;
    }

    RARCH_LOG("[Camera]: AVFoundation camera initialized and started successfully\n");
    return avf;
}

static void avfoundation_free(void *data)
{
    avfoundation_t *avf = (avfoundation_t*)data;
    if (!avf)
        return;

    RARCH_LOG("[Camera]: Freeing AVFoundation camera\n");

    if (avf->manager.session) {
        [avf->manager.session stopRunning];
    }

    if (avf->manager.frameBuffer) {
        free(avf->manager.frameBuffer);
        avf->manager.frameBuffer = NULL;
    }

    free(avf);
    RARCH_LOG("[Camera]: AVFoundation camera freed\n");
}

static bool avfoundation_start(void *data)
{
    avfoundation_t *avf = (avfoundation_t*)data;
    if (!avf || !avf->manager.session) {
        RARCH_ERR("[Camera]: Cannot start - invalid data\n");
        return false;
    }

    RARCH_LOG("[Camera]: Starting AVFoundation camera\n");

    if ([NSThread isMainThread]) {
        [avf->manager.session startRunning];
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [avf->manager.session startRunning];
        });
    }

    // Verify the session actually started
    bool isRunning = avf->manager.session.isRunning;
    RARCH_LOG("[Camera]: Camera session running: %s\n", isRunning ? "YES" : "NO");
    return isRunning;
}

static void avfoundation_stop(void *data)
{
    avfoundation_t *avf = (avfoundation_t*)data;
    if (!avf || !avf->manager.session)
        return;

    RARCH_LOG("[Camera]: Stopping AVFoundation camera\n");
    [avf->manager.session stopRunning];
}

static bool avfoundation_poll(void *data,
      retro_camera_frame_raw_framebuffer_t frame_raw_cb,
      retro_camera_frame_opengl_texture_t frame_gl_cb)
{
    avfoundation_t *avf = (avfoundation_t*)data;
    if (!avf || !frame_raw_cb) {
        RARCH_ERR("[Camera]: Cannot poll - invalid data or callback\n");
        return false;
    }

    if (!avf->manager.session.isRunning) {
        RARCH_LOG("[Camera]: Camera not running, generating color bars\n");
        uint32_t *tempBuffer = (uint32_t*)calloc(avf->width * avf->height, sizeof(uint32_t));
        if (tempBuffer) {
            generateColorBars(tempBuffer, avf->width, avf->height);
            frame_raw_cb(tempBuffer, avf->width, avf->height, avf->width * 4);
            free(tempBuffer);
            return true;
        }
        return false;
    }

    RARCH_LOG("[Camera]: Delivering camera frame\n");
    frame_raw_cb(avf->manager.frameBuffer, avf->width, avf->height, avf->width * 4);
    return true;
}

camera_driver_t camera_avfoundation = {
   avfoundation_init,
   avfoundation_free,
   avfoundation_start,
   avfoundation_stop,
   avfoundation_poll,
   "avfoundation"
};
