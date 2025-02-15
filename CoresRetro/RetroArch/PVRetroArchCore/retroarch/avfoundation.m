/*  RetroArch - A frontend for libretro.
 *  Copyright (C) 2025      - Joseph Mattiello
 *
 *  RetroArch is free software: you can redistribute it and/or modify it under the terms
 *  of the GNU General Public License as published by the Free Software Found-
 *  ation, either version 3 of the License, or (at your option) any later version.
 *
 *  RetroArch is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
 *  without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
 *  PURPOSE.  See the GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along with RetroArch.
 *  If not, see <http://www.gnu.org/licenses/>.
 */

#import <AVFoundation/AVFoundation.h>

#include "../../retroarch.h"
#include "../../camera/camera_driver.h"

@interface AVCameraManager : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>
@property (strong, nonatomic) AVCaptureSession *session;
@property (strong, nonatomic) AVCaptureDeviceInput *input;
@property (strong, nonatomic) AVCaptureVideoDataOutput *output;
@property (assign) uint32_t *frameBuffer;
@property (assign) size_t frameBufferSize;
@property (assign) bool authorized;
@property (assign) bool running;
@end

@implementation AVCameraManager

+ (instancetype)sharedInstance {
    static AVCameraManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[AVCameraManager alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _session = [[AVCaptureSession alloc] init];
        _session.sessionPreset = AVCaptureSessionPreset640x480;
        _authorized = false;
        _running = false;
    }
    return self;
}

- (void)requestAuthorization {
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
        self.authorized = granted;
    }];
}

- (void)captureOutput:(AVCaptureOutput *)output
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {
    if (!self.frameBuffer)
        return;

    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer, 0);

    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);

    // Convert YUV to RGB (simplified example)
    for (size_t y = 0; y < height; y++) {
        for (size_t x = 0; x < width; x++) {
            size_t index = y * width + x;
            self.frameBuffer[index] = 0xFF000000 | (baseAddress[index] << 16) |
                                    (baseAddress[index] << 8) | baseAddress[index];
        }
    }

    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
}

@end

typedef struct avfoundation {
    AVCameraManager *manager;
    unsigned width;
    unsigned height;
} avfoundation_t;

static void *avfoundation_init(const char *device, uint64_t caps, unsigned width, unsigned height) {
    avfoundation_t *avf = (avfoundation_t*)calloc(1, sizeof(avfoundation_t));
    if (!avf)
        return NULL;

    avf->manager = [AVCameraManager sharedInstance];
    avf->width = width;
    avf->height = height;

    [avf->manager requestAuthorization];

    // Configure capture session
    AVCaptureDevice *camera = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (!camera) {
        free(avf);
        return NULL;
    }

    NSError *error = nil;
    avf->manager.input = [AVCaptureDeviceInput deviceInputWithDevice:camera error:&error];
    if (!avf->manager.input || error) {
        free(avf);
        return NULL;
    }

    [avf->manager.session beginConfiguration];
    [avf->manager.session addInput:avf->manager.input];

    avf->manager.output = [[AVCaptureVideoDataOutput alloc] init];
    if (!avf->manager.output) {
        free(avf);
        return NULL;
    }

    [avf->manager.output setSampleBufferDelegate:avf->manager queue:dispatch_get_main_queue()];
    [avf->manager.session addOutput:avf->manager.output];
    [avf->manager.session commitConfiguration];

    // Allocate frame buffer
    avf->manager.frameBufferSize = width * height * sizeof(uint32_t);
    avf->manager.frameBuffer = (uint32_t*)malloc(avf->manager.frameBufferSize);
    if (!avf->manager.frameBuffer) {
        free(avf);
        return NULL;
    }

    return avf;
}

static void avfoundation_free(void *data) {
    avfoundation_t *avf = (avfoundation_t*)data;
    if (!avf)
        return;

    [avf->manager.session stopRunning];
    if (avf->manager.frameBuffer)
        free(avf->manager.frameBuffer);

    free(avf);
}

static bool avfoundation_start(void *data) {
    avfoundation_t *avf = (avfoundation_t*)data;
    if (!avf || !avf->manager.authorized)
        return false;

    [avf->manager.session startRunning];
    avf->manager.running = true;
    return true;
}

static void avfoundation_stop(void *data) {
    avfoundation_t *avf = (avfoundation_t*)data;
    if (!avf)
        return;

    [avf->manager.session stopRunning];
    avf->manager.running = false;
}

static bool avfoundation_poll(void *data,
                            retro_camera_frame_raw_framebuffer_t frame_raw_cb,
                            retro_camera_frame_opengl_texture_t frame_gl_cb) {
    avfoundation_t *avf = (avfoundation_t*)data;
    if (!avf || !avf->manager.running)
        return false;

    if (frame_raw_cb && avf->manager.frameBuffer) {
        frame_raw_cb(avf->manager.frameBuffer, avf->width, avf->height, avf->width * 4);
        return true;
    }

    return false;
}

camera_driver_t camera_avfoundation = {
    avfoundation_init,
    avfoundation_free,
    avfoundation_start,
    avfoundation_stop,
    avfoundation_poll,
    "avfoundation",
};
