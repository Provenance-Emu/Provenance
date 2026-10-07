// Adapted from Cytrus (Jarrod Norwell), GPL-2.0-or-later
// Source: folium-app/Cytrus System/camera.mm @ 81a12f0e. The three duplicated Objective-C camera
// classes are folded into one parameterised by capture position; capture runs on a private queue
// and frames are handed to the emu thread under a mutex.
#import <TargetConditionals.h>
#include "AzaharCamera.h"

#if !TARGET_OS_TV

#import <Foundation/Foundation.h>
#import <PVLogging/PVLoggingObjC.h>
#import <AVFoundation/AVFoundation.h>   // before the azahar headers, whose include paths shadow Network/Network.h
#import <CoreImage/CoreImage.h>
#import <CoreVideo/CoreVideo.h>

#include <algorithm>
#include <array>
#include <memory>
#include <mutex>
#include <vector>

#include "core/frontend/camera/factory.h"
#include "core/frontend/camera/interface.h"
#include "core/hle/service/cam/cam.h"

namespace YuvTable {

constexpr std::array<int, 256> Y_R = {
    53,  53,  53,  54,  54,  54,  55,  55,  55,  56,  56,  56,  56,  57,  57,  57,  58,  58,  58,
    59,  59,  59,  59,  60,  60,  60,  61,  61,  61,  62,  62,  62,  62,  63,  63,  63,  64,  64,
    64,  65,  65,  65,  65,  66,  66,  66,  67,  67,  67,  67,  68,  68,  68,  69,  69,  69,  70,
    70,  70,  70,  71,  71,  71,  72,  72,  72,  73,  73,  73,  73,  74,  74,  74,  75,  75,  75,
    76,  76,  76,  76,  77,  77,  77,  78,  78,  78,  79,  79,  79,  79,  80,  80,  80,  81,  81,
    81,  82,  82,  82,  82,  83,  83,  83,  84,  84,  84,  85,  85,  85,  85,  86,  86,  86,  87,
    87,  87,  87,  88,  88,  88,  89,  89,  89,  90,  90,  90,  90,  91,  91,  91,  92,  92,  92,
    93,  93,  93,  93,  94,  94,  94,  95,  95,  95,  96,  96,  96,  96,  97,  97,  97,  98,  98,
    98,  99,  99,  99,  99,  100, 100, 100, 101, 101, 101, 102, 102, 102, 102, 103, 103, 103, 104,
    104, 104, 105, 105, 105, 105, 106, 106, 106, 107, 107, 107, 108, 108, 108, 108, 109, 109, 109,
    110, 110, 110, 110, 111, 111, 111, 112, 112, 112, 113, 113, 113, 113, 114, 114, 114, 115, 115,
    115, 116, 116, 116, 116, 117, 117, 117, 118, 118, 118, 119, 119, 119, 119, 120, 120, 120, 121,
    121, 121, 122, 122, 122, 122, 123, 123, 123, 124, 124, 124, 125, 125, 125, 125, 126, 126, 126,
    127, 127, 127, 128, 128, 128, 128, 129, 129,
};

constexpr std::array<int, 256> Y_G = {
    -79, -79, -78, -78, -77, -77, -76, -75, -75, -74, -74, -73, -72, -72, -71, -71, -70, -70, -69,
    -68, -68, -67, -67, -66, -65, -65, -64, -64, -63, -62, -62, -61, -61, -60, -60, -59, -58, -58,
    -57, -57, -56, -55, -55, -54, -54, -53, -52, -52, -51, -51, -50, -50, -49, -48, -48, -47, -47,
    -46, -45, -45, -44, -44, -43, -42, -42, -41, -41, -40, -40, -39, -38, -38, -37, -37, -36, -35,
    -35, -34, -34, -33, -33, -32, -31, -31, -30, -30, -29, -28, -28, -27, -27, -26, -25, -25, -24,
    -24, -23, -23, -22, -21, -21, -20, -20, -19, -18, -18, -17, -17, -16, -15, -15, -14, -14, -13,
    -13, -12, -11, -11, -10, -10, -9,  -8,  -8,  -7,  -7,  -6,  -5,  -5,  -4,  -4,  -3,  -3,  -2,
    -1,  -1,  0,   0,   0,   1,   1,   2,   2,   3,   4,   4,   5,   5,   6,   6,   7,   8,   8,
    9,   9,   10,  11,  11,  12,  12,  13,  13,  14,  15,  15,  16,  16,  17,  18,  18,  19,  19,
    20,  21,  21,  22,  22,  23,  23,  24,  25,  25,  26,  26,  27,  28,  28,  29,  29,  30,  31,
    31,  32,  32,  33,  33,  34,  35,  35,  36,  36,  37,  38,  38,  39,  39,  40,  41,  41,  42,
    42,  43,  43,  44,  45,  45,  46,  46,  47,  48,  48,  49,  49,  50,  50,  51,  52,  52,  53,
    53,  54,  55,  55,  56,  56,  57,  58,  58,  59,  59,  60,  60,  61,  62,  62,  63,  63,  64,
    65,  65,  66,  66,  67,  68,  68,  69,  69,
};

constexpr std::array<int, 256> Y_B = {
    25, 25, 26, 26, 26, 26, 26, 26, 26, 26, 26, 27, 27, 27, 27, 27, 27, 27, 27, 27, 28, 28, 28, 28,
    28, 28, 28, 28, 28, 29, 29, 29, 29, 29, 29, 29, 29, 30, 30, 30, 30, 30, 30, 30, 30, 30, 31, 31,
    31, 31, 31, 31, 31, 31, 31, 32, 32, 32, 32, 32, 32, 32, 32, 32, 33, 33, 33, 33, 33, 33, 33, 33,
    34, 34, 34, 34, 34, 34, 34, 34, 34, 35, 35, 35, 35, 35, 35, 35, 35, 35, 36, 36, 36, 36, 36, 36,
    36, 36, 36, 37, 37, 37, 37, 37, 37, 37, 37, 38, 38, 38, 38, 38, 38, 38, 38, 38, 39, 39, 39, 39,
    39, 39, 39, 39, 39, 40, 40, 40, 40, 40, 40, 40, 40, 40, 41, 41, 41, 41, 41, 41, 41, 41, 41, 42,
    42, 42, 42, 42, 42, 42, 42, 43, 43, 43, 43, 43, 43, 43, 43, 43, 44, 44, 44, 44, 44, 44, 44, 44,
    44, 45, 45, 45, 45, 45, 45, 45, 45, 45, 46, 46, 46, 46, 46, 46, 46, 46, 47, 47, 47, 47, 47, 47,
    47, 47, 47, 48, 48, 48, 48, 48, 48, 48, 48, 48, 49, 49, 49, 49, 49, 49, 49, 49, 49, 50, 50, 50,
    50, 50, 50, 50, 50, 51, 51, 51, 51, 51, 51, 51, 51, 51, 52, 52, 52, 52, 52, 52, 52, 52, 52, 53,
    53, 53, 53, 53, 53, 53, 53, 53, 54, 54, 54, 54, 54, 54, 54, 54,
};

static constexpr int Y(int r, int g, int b) {
    return Y_R[r] + Y_G[g] + Y_B[b];
}

constexpr std::array<int, 256> U_R = {
    30, 30, 30, 30, 30, 30, 31, 31, 31, 31, 31, 32, 32, 32, 32, 32, 32, 33, 33, 33, 33, 33, 33, 34,
    34, 34, 34, 34, 34, 35, 35, 35, 35, 35, 35, 36, 36, 36, 36, 36, 36, 37, 37, 37, 37, 37, 37, 38,
    38, 38, 38, 38, 38, 39, 39, 39, 39, 39, 39, 40, 40, 40, 40, 40, 40, 41, 41, 41, 41, 41, 41, 42,
    42, 42, 42, 42, 42, 43, 43, 43, 43, 43, 43, 44, 44, 44, 44, 44, 45, 45, 45, 45, 45, 45, 46, 46,
    46, 46, 46, 46, 47, 47, 47, 47, 47, 47, 48, 48, 48, 48, 48, 48, 49, 49, 49, 49, 49, 49, 50, 50,
    50, 50, 50, 50, 51, 51, 51, 51, 51, 51, 52, 52, 52, 52, 52, 52, 53, 53, 53, 53, 53, 53, 54, 54,
    54, 54, 54, 54, 55, 55, 55, 55, 55, 55, 56, 56, 56, 56, 56, 56, 57, 57, 57, 57, 57, 57, 58, 58,
    58, 58, 58, 59, 59, 59, 59, 59, 59, 60, 60, 60, 60, 60, 60, 61, 61, 61, 61, 61, 61, 62, 62, 62,
    62, 62, 62, 63, 63, 63, 63, 63, 63, 64, 64, 64, 64, 64, 64, 65, 65, 65, 65, 65, 65, 66, 66, 66,
    66, 66, 66, 67, 67, 67, 67, 67, 67, 68, 68, 68, 68, 68, 68, 69, 69, 69, 69, 69, 69, 70, 70, 70,
    70, 70, 70, 71, 71, 71, 71, 71, 72, 72, 72, 72, 72, 72, 73, 73,
};

constexpr std::array<int, 256> U_G = {
    -45, -44, -44, -44, -43, -43, -43, -42, -42, -42, -41, -41, -41, -40, -40, -40, -39, -39, -39,
    -38, -38, -38, -37, -37, -37, -36, -36, -36, -35, -35, -35, -34, -34, -34, -33, -33, -33, -32,
    -32, -32, -31, -31, -31, -30, -30, -30, -29, -29, -29, -28, -28, -28, -27, -27, -27, -26, -26,
    -26, -25, -25, -25, -24, -24, -24, -23, -23, -23, -22, -22, -22, -21, -21, -21, -20, -20, -20,
    -19, -19, -19, -18, -18, -18, -17, -17, -17, -16, -16, -16, -15, -15, -15, -14, -14, -14, -14,
    -13, -13, -13, -12, -12, -12, -11, -11, -11, -10, -10, -10, -9,  -9,  -9,  -8,  -8,  -8,  -7,
    -7,  -7,  -6,  -6,  -6,  -5,  -5,  -5,  -4,  -4,  -4,  -3,  -3,  -3,  -2,  -2,  -2,  -1,  -1,
    -1,  0,   0,   0,   0,   0,   0,   1,   1,   1,   2,   2,   2,   3,   3,   3,   4,   4,   4,
    5,   5,   5,   6,   6,   6,   7,   7,   7,   8,   8,   8,   9,   9,   9,   10,  10,  10,  11,
    11,  11,  12,  12,  12,  13,  13,  13,  14,  14,  14,  15,  15,  15,  16,  16,  16,  17,  17,
    17,  18,  18,  18,  19,  19,  19,  20,  20,  20,  21,  21,  21,  22,  22,  22,  23,  23,  23,
    24,  24,  24,  25,  25,  25,  26,  26,  26,  27,  27,  27,  28,  28,  28,  29,  29,  29,  30,
    30,  30,  31,  31,  31,  32,  32,  32,  33,  33,  33,  34,  34,  34,  35,  35,  35,  36,  36,
    36,  37,  37,  37,  38,  38,  38,  39,  39,
};

constexpr std::array<int, 256> U_B = {
    113, 113, 114, 114, 115, 115, 116, 116, 117, 117, 118, 118, 119, 119, 120, 120, 121, 121, 122,
    122, 123, 123, 124, 124, 125, 125, 126, 126, 127, 127, 128, 128, 129, 129, 130, 130, 131, 131,
    132, 132, 133, 133, 134, 134, 135, 135, 136, 136, 137, 137, 138, 138, 139, 139, 140, 140, 141,
    141, 142, 142, 143, 143, 144, 144, 145, 145, 146, 146, 147, 147, 148, 148, 149, 149, 150, 150,
    151, 151, 152, 152, 153, 153, 154, 154, 155, 155, 156, 156, 157, 157, 158, 158, 159, 159, 160,
    160, 161, 161, 162, 162, 163, 163, 164, 164, 165, 165, 166, 166, 167, 167, 168, 168, 169, 169,
    170, 170, 171, 171, 172, 172, 173, 173, 174, 174, 175, 175, 176, 176, 177, 177, 178, 178, 179,
    179, 180, 180, 181, 181, 182, 182, 183, 183, 184, 184, 185, 185, 186, 186, 187, 187, 188, 188,
    189, 189, 190, 190, 191, 191, 192, 192, 193, 193, 194, 194, 195, 195, 196, 196, 197, 197, 198,
    198, 199, 199, 200, 200, 201, 201, 202, 202, 203, 203, 204, 204, 205, 205, 206, 206, 207, 207,
    208, 208, 209, 209, 210, 210, 211, 211, 212, 212, 213, 213, 214, 214, 215, 215, 216, 216, 217,
    217, 218, 218, 219, 219, 220, 220, 221, 221, 222, 222, 223, 223, 224, 224, 225, 225, 226, 226,
    227, 227, 228, 228, 229, 229, 230, 230, 231, 231, 232, 232, 233, 233, 234, 234, 235, 235, 236,
    236, 237, 237, 238, 238, 239, 239, 240, 240,
};

static constexpr int U(int r, int g, int b) {
    return -U_R[r] - U_G[g] + U_B[b];
}

constexpr std::array<int, 256> V_R = {
    89,  90,  90,  91,  91,  92,  92,  93,  93,  94,  94,  95,  95,  96,  96,  97,  97,  98,  98,
    99,  99,  100, 100, 101, 101, 102, 102, 103, 103, 104, 104, 105, 105, 106, 106, 107, 107, 108,
    108, 109, 109, 110, 110, 111, 111, 112, 112, 113, 113, 114, 114, 115, 115, 116, 116, 117, 117,
    118, 118, 119, 119, 120, 120, 121, 121, 122, 122, 123, 123, 124, 124, 125, 125, 126, 126, 127,
    127, 128, 128, 129, 129, 130, 130, 131, 131, 132, 132, 133, 133, 134, 134, 135, 135, 136, 136,
    137, 137, 138, 138, 139, 139, 140, 140, 141, 141, 142, 142, 143, 143, 144, 144, 145, 145, 146,
    146, 147, 147, 148, 148, 149, 149, 150, 150, 151, 151, 152, 152, 153, 153, 154, 154, 155, 155,
    156, 156, 157, 157, 158, 158, 159, 159, 160, 160, 161, 161, 162, 162, 163, 163, 164, 164, 165,
    165, 166, 166, 167, 167, 168, 168, 169, 169, 170, 170, 171, 171, 172, 172, 173, 173, 174, 174,
    175, 175, 176, 176, 177, 177, 178, 178, 179, 179, 180, 180, 181, 181, 182, 182, 183, 183, 184,
    184, 185, 185, 186, 186, 187, 187, 188, 188, 189, 189, 190, 190, 191, 191, 192, 192, 193, 193,
    194, 194, 195, 195, 196, 196, 197, 197, 198, 198, 199, 199, 200, 200, 201, 201, 202, 202, 203,
    203, 204, 205, 205, 206, 206, 207, 207, 208, 208, 209, 209, 210, 210, 211, 211, 212, 212, 213,
    213, 214, 214, 215, 215, 216, 216, 217, 217,
};

constexpr std::array<int, 256> V_G = {
    -57, -56, -56, -55, -55, -55, -54, -54, -53, -53, -52, -52, -52, -51, -51, -50, -50, -50, -49,
    -49, -48, -48, -47, -47, -47, -46, -46, -45, -45, -45, -44, -44, -43, -43, -42, -42, -42, -41,
    -41, -40, -40, -39, -39, -39, -38, -38, -37, -37, -37, -36, -36, -35, -35, -34, -34, -34, -33,
    -33, -32, -32, -31, -31, -31, -30, -30, -29, -29, -29, -28, -28, -27, -27, -26, -26, -26, -25,
    -25, -24, -24, -24, -23, -23, -22, -22, -21, -21, -21, -20, -20, -19, -19, -18, -18, -18, -17,
    -17, -16, -16, -16, -15, -15, -14, -14, -13, -13, -13, -12, -12, -11, -11, -10, -10, -10, -9,
    -9,  -8,  -8,  -8,  -7,  -7,  -6,  -6,  -5,  -5,  -5,  -4,  -4,  -3,  -3,  -3,  -2,  -2,  -1,
    -1,  0,   0,   0,   0,   0,   1,   1,   2,   2,   2,   3,   3,   4,   4,   4,   5,   5,   6,
    6,   7,   7,   7,   8,   8,   9,   9,   10,  10,  10,  11,  11,  12,  12,  12,  13,  13,  14,
    14,  15,  15,  15,  16,  16,  17,  17,  17,  18,  18,  19,  19,  20,  20,  20,  21,  21,  22,
    22,  23,  23,  23,  24,  24,  25,  25,  25,  26,  26,  27,  27,  28,  28,  28,  29,  29,  30,
    30,  31,  31,  31,  32,  32,  33,  33,  33,  34,  34,  35,  35,  36,  36,  36,  37,  37,  38,
    38,  38,  39,  39,  40,  40,  41,  41,  41,  42,  42,  43,  43,  44,  44,  44,  45,  45,  46,
    46,  46,  47,  47,  48,  48,  49,  49,  49,
};

constexpr std::array<int, 256> V_B = {
    18, 18, 18, 18, 18, 18, 18, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 20, 20, 20, 20,
    20, 20, 20, 20, 20, 20, 20, 20, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 22, 22, 22, 22,
    22, 22, 22, 22, 22, 22, 22, 22, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 24, 24, 24,
    24, 24, 24, 24, 24, 24, 24, 24, 24, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 26, 26, 26,
    26, 26, 26, 26, 26, 26, 26, 26, 26, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 28, 28,
    28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 30, 30,
    30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 32,
    32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 33, 33, 33, 33, 33, 33, 33, 33, 33, 33, 33, 33, 34,
    34, 34, 34, 34, 34, 34, 34, 34, 34, 34, 34, 35, 35, 35, 35, 35, 35, 35, 35, 35, 35, 35, 35, 35,
    36, 36, 36, 36, 36, 36, 36, 36, 36, 36, 36, 36, 37, 37, 37, 37, 37, 37, 37, 37, 37, 37, 37, 37,
    38, 38, 38, 38, 38, 38, 38, 38, 38, 38, 38, 38, 39, 39, 39, 39,
};

static constexpr int V(int r, int g, int b) {
    return V_R[r] - V_G[g] - V_B[b];
}

}

static CVPixelBufferRef TransformSampleBuffer(CMSampleBufferRef sampleBuffer, int targetWidth, int targetHeight) {
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (!imageBuffer) { return nullptr; }
    CIImage *input = [CIImage imageWithCVPixelBuffer:imageBuffer];
    if (!input) { return nullptr; }

    // Scale to fill, then center-crop to the requested size.
    const CGRect extent = input.extent;
    const CGFloat scale = std::max((CGFloat)targetWidth / extent.size.width, (CGFloat)targetHeight / extent.size.height);
    CIImage *scaled = [input imageByApplyingTransform:CGAffineTransformMakeScale(scale, scale)];
    const CGRect se = scaled.extent;
    const CGFloat cropX = se.origin.x + (se.size.width - targetWidth) / 2.0;
    const CGFloat cropY = se.origin.y + (se.size.height - targetHeight) / 2.0;
    CIImage *cropped = [scaled imageByApplyingTransform:CGAffineTransformMakeTranslation(-cropX, -cropY)];

    NSDictionary *attrs = @{
        (NSString *)kCVPixelBufferCGImageCompatibilityKey: @YES,
        (NSString *)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES,
    };
    CVPixelBufferRef output = nullptr;
    CVPixelBufferCreate(kCFAllocatorDefault, targetWidth, targetHeight, kCVPixelFormatType_32BGRA,
                        (__bridge CFDictionaryRef)attrs, &output);
    if (!output) { return nullptr; }

    static CIContext *context = [CIContext contextWithOptions:nil];
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    [context render:cropped toCVPixelBuffer:output bounds:CGRectMake(0, 0, targetWidth, targetHeight) colorSpace:colorSpace];
    CGColorSpaceRelease(colorSpace);
    return output;
}

/// BGRA frame -> 3DS pixel format (RGB565 or YUV422), `width * height` u16 words.
static std::vector<u16> ConvertSampleBuffer(CMSampleBufferRef sampleBuffer, int width, int height, bool rgb565) {
    CVPixelBufferRef buffer = TransformSampleBuffer(sampleBuffer, width, height);
    if (!buffer) { return {}; }
    CVPixelBufferLockBaseAddress(buffer, kCVPixelBufferLock_ReadOnly);
    const size_t w = CVPixelBufferGetWidth(buffer), h = CVPixelBufferGetHeight(buffer);
    const size_t bytesPerRow = CVPixelBufferGetBytesPerRow(buffer);
    const uint8_t *base = static_cast<const uint8_t *>(CVPixelBufferGetBaseAddress(buffer));
    std::vector<u16> out(w * h);

    if (rgb565) {
        for (size_t y = 0; y < h; ++y) {
            const uint8_t *row = base + y * bytesPerRow;
            for (size_t x = 0; x < w; ++x) {
                const uint8_t b = row[x * 4 + 0], g = row[x * 4 + 1], r = row[x * 4 + 2];
                out[y * w + x] = static_cast<u16>(((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3));
            }
        }
    } else {
        bool write = false;
        int py = 0, pu = 0, pv = 0;
        auto dest = out.begin();
        for (size_t j = 0; j < h; ++j) {
            const uint8_t *row = base + j * bytesPerRow;
            for (size_t i = 0; i < w; ++i) {
                const uint8_t b = row[i * 4 + 0], g = row[i * 4 + 1], r = row[i * 4 + 2];
                const int y = YuvTable::Y(r, g, b), u = YuvTable::U(r, g, b), v = YuvTable::V(r, g, b);
                if (write) {
                    pu = (pu + u) / 2;
                    pv = (pv + v) / 2;
                    *(dest++) = static_cast<u16>(std::clamp(py, 0, 0xFF) | (std::clamp(pu, 0, 0xFF) << 8));
                    *(dest++) = static_cast<u16>(std::clamp(y, 0, 0xFF) | (std::clamp(pv, 0, 0xFF) << 8));
                } else {
                    py = y; pu = u; pv = v;
                }
                write = !write;
            }
        }
    }
    CVPixelBufferUnlockBaseAddress(buffer, kCVPixelBufferLock_ReadOnly);
    CVPixelBufferRelease(buffer);
    return out;
}

/// One AVFoundation capture pipeline. `frame` is safe to call from the emu thread.
@interface AzaharCaptureCamera : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>
- (instancetype)initWithPosition:(AVCaptureDevicePosition)position;
- (void)start;
- (void)stop;
- (void)setFrameRate:(Service::CAM::FrameRate)rate;
- (void)setResolution:(Service::CAM::Resolution)resolution;
- (void)setRGB565:(BOOL)rgb565;
- (std::vector<u16>)frame;
- (BOOL)isAvailable;
@end

@implementation AzaharCaptureCamera {
    AVCaptureDevicePosition _position;
    AVCaptureSession *_session;       // only touched on _queue
    dispatch_queue_t _queue;
    std::mutex _mutex;                 // guards everything below, shared with the capture queue
    std::vector<u16> _framebuffer;
    int _width, _height;
    BOOL _rgb565;
    int _minFps, _maxFps;
    BOOL _wantRunning;
}

- (instancetype)initWithPosition:(AVCaptureDevicePosition)position {
    if ((self = [super init])) {
        _position = position;
        _queue = dispatch_queue_create("org.provenance-emu.azahar.camera", DISPATCH_QUEUE_SERIAL);
        _width = 640; _height = 480; _minFps = _maxFps = 30;
    }
    return self;
}

/// All session work runs serially on `_queue`, in call order, so a stop can never be overtaken by the
/// start before it. `_wantRunning` lets queued starts (and the permission callback) bail after a stop.
- (void)start {
    { std::lock_guard lock(_mutex); _wantRunning = true; }
    dispatch_async(_queue, ^{ [self startOnQueue]; });
}

- (void)stop {
    { std::lock_guard lock(_mutex); _wantRunning = false; }
    dispatch_async(_queue, ^{ [self stopOnQueue]; });
}

- (BOOL)wantsRunning {
    std::lock_guard lock(_mutex);
    return _wantRunning;
}

- (void)startOnQueue {
    if (![self wantsRunning]) { return; }
    switch ([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo]) {
    case AVAuthorizationStatusAuthorized: {
        [self startAuthorized];
        break;
    }
    case AVAuthorizationStatusNotDetermined: {
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            if (granted) { dispatch_async(self->_queue, ^{ if ([self wantsRunning]) { [self startAuthorized]; } }); }
        }];
        break;
    }
    default:
        break;   // denied or restricted: the game keeps receiving blank frames
    }
}

- (void)stopOnQueue {
    [_session stopRunning];
    _session = nil;
}

/// On `_queue`.
- (void)startAuthorized {
    [self stopOnQueue];   // never leave a running session behind when replacing it
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera
                                                                 mediaType:AVMediaTypeVideo position:_position];
    if (!device) { return; }
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:nil];
    if (!input) { return; }
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    session.sessionPreset = AVCaptureSessionPreset640x480;
    AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
    output.videoSettings = @{(NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)};
    output.alwaysDiscardsLateVideoFrames = YES;
    [output setSampleBufferDelegate:self queue:_queue];
    if ([session canAddInput:input]) { [session addInput:input]; }
    if ([session canAddOutput:output]) { [session addOutput:output]; }
    [self applyFrameRateTo:device];   // after the preset: applying a preset resets the durations
    if (![self wantsRunning]) { return; }
    _session = session;
    [session startRunning];
    if (![self wantsRunning]) { [self stopOnQueue]; }
}

/// Frame durations outside the active format's supported ranges raise an exception, so clamp first.
- (void)applyFrameRateTo:(AVCaptureDevice *)device {
    int minFps, maxFps;
    { std::lock_guard lock(_mutex); minFps = _minFps; maxFps = _maxFps; }
    Float64 lowest = 1.0, highest = 120.0;
    if (device.activeFormat.videoSupportedFrameRateRanges.count > 0) {
        lowest = 1e9; highest = 0;
        for (AVFrameRateRange *range in device.activeFormat.videoSupportedFrameRateRanges) {
            lowest = std::min(lowest, range.minFrameRate);
            highest = std::max(highest, range.maxFrameRate);
        }
    }
    const Float64 hi = std::clamp((Float64)maxFps, lowest, highest);
    const Float64 lo = std::clamp((Float64)minFps, lowest, hi);
    if (![device lockForConfiguration:nil]) { return; }
    @try {
        device.activeVideoMinFrameDuration = CMTimeMake(1, (int32_t)hi);   // shortest frame = fastest rate
        device.activeVideoMaxFrameDuration = CMTimeMake(1, (int32_t)lo);
    } @catch (NSException *exception) {
        WLOG(@"[PVAzahar] camera frame rate rejected: %@", exception.reason);
    }
    [device unlockForConfiguration];
}

- (BOOL)isAvailable {
    return [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera
                                              mediaType:AVMediaTypeVideo position:_position] != nil;
}

- (void)setFrameRate:(Service::CAM::FrameRate)rate {
    using R = Service::CAM::FrameRate;
    int lo = 15, hi = 15;
    switch (rate) {
    case R::Rate_15: lo = hi = 15; break;
    case R::Rate_15_To_5: lo = 5; hi = 15; break;
    case R::Rate_15_To_2: lo = 2; hi = 15; break;
    case R::Rate_10: lo = hi = 10; break;
    case R::Rate_8_5: lo = hi = 8; break;
    case R::Rate_5: lo = hi = 5; break;
    case R::Rate_20: lo = hi = 20; break;
    case R::Rate_20_To_5: lo = 5; hi = 20; break;
    case R::Rate_30: lo = hi = 30; break;
    case R::Rate_30_To_5: lo = 5; hi = 30; break;
    case R::Rate_15_To_10: lo = 10; hi = 15; break;
    case R::Rate_20_To_10: lo = 10; hi = 20; break;
    case R::Rate_30_To_10: lo = 10; hi = 30; break;
    }
    std::lock_guard lock(_mutex);
    _minFps = lo; _maxFps = hi;
}

- (void)setResolution:(Service::CAM::Resolution)resolution {
    std::lock_guard lock(_mutex);
    _width = resolution.width; _height = resolution.height;
    _framebuffer.assign(static_cast<size_t>(_width) * _height, 0);
}

- (void)setRGB565:(BOOL)rgb565 {
    std::lock_guard lock(_mutex);
    _rgb565 = rgb565;
}

- (std::vector<u16>)frame {
    std::lock_guard lock(_mutex);
    return _framebuffer;
}

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {
    @autoreleasepool {
        int w, h; BOOL rgb565;
        { std::lock_guard lock(_mutex); w = _width; h = _height; rgb565 = _rgb565; }
        std::vector<u16> converted = ConvertSampleBuffer(sampleBuffer, w, h, rgb565);
        std::lock_guard lock(_mutex);
        if (_width == w && _height == h && converted.size() == _framebuffer.size()) { _framebuffer = std::move(converted); }
    }
}
@end

namespace Camera {
namespace {
class AVCameraInterface final : public CameraInterface {
public:
    explicit AVCameraInterface(AVCaptureDevicePosition position)
        : camera([[AzaharCaptureCamera alloc] initWithPosition:position]) {}
    ~AVCameraInterface() override { [camera stop]; }
    void StartCapture() override { [camera start]; }
    void StopCapture() override { [camera stop]; }
    void SetResolution(const Service::CAM::Resolution& resolution) override { [camera setResolution:resolution]; }
    void SetFlip(Service::CAM::Flip) override {}
    void SetEffect(Service::CAM::Effect) override {}
    void SetFormat(Service::CAM::OutputFormat format) override {
        [camera setRGB565:format == Service::CAM::OutputFormat::RGB565];
    }
    void SetFrameRate(Service::CAM::FrameRate frameRate) override { [camera setFrameRate:frameRate]; }
    std::vector<u16> ReceiveFrame() override { return [camera frame]; }
    bool IsPreviewAvailable() override { return [camera isAvailable]; }

private:
    AzaharCaptureCamera *camera;
};

class AVCameraFactory final : public CameraFactory {
public:
    explicit AVCameraFactory(AVCaptureDevicePosition position) : position(position) {}
    std::unique_ptr<CameraInterface> Create(const std::string&, const Service::CAM::Flip&) override {
        return std::make_unique<AVCameraInterface>(position);
    }
private:
    AVCaptureDevicePosition position;
};
} // namespace
} // namespace Camera

namespace AzaharCamera {
void RegisterFactories() {
    Camera::RegisterFactory(kFrontCamera, std::make_unique<Camera::AVCameraFactory>(AVCaptureDevicePositionFront));
    Camera::RegisterFactory(kRearLeftCamera, std::make_unique<Camera::AVCameraFactory>(AVCaptureDevicePositionBack));
    Camera::RegisterFactory(kRearRightCamera, std::make_unique<Camera::AVCameraFactory>(AVCaptureDevicePositionBack));
}
}

#else // tvOS: azahar's blank camera is the default

namespace AzaharCamera {
void RegisterFactories() {}
}

#endif
