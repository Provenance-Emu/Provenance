//
//  CameraInterface.mm
//  Cytrus
//
//  Created by Jarrod Norwell on 27/8/2024.
//  Copyright © 2024 Jarrod Norwell. All rights reserved.
//

#import "CameraInterface.h"

#import <AVFoundation/AVFoundation.h>
#import <CoreImage/CoreImage.h>
#import <CoreVideo/CoreVideo.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

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
} // namespace YuvTable

CVPixelBufferRef scaledPixelBuffer(CVPixelBufferRef pixelBuffer, CGSize size) {
    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
    CIContext *context = [CIContext contextWithOptions:NULL];
    
    CGSize inputSize = ciImage.extent.size;
    
    CGFloat widthScale = size.width / inputSize.width;
    CGFloat heightScale = size.height / inputSize.height;
    CGFloat scaleFactor = MIN(widthScale, heightScale);
    
    CGSize scaledSize = CGSizeMake(inputSize.width * scaleFactor, inputSize.height * scaleFactor);
    
    NSDictionary *pixelBufferAttributes = @{
        (NSString *)kCVPixelBufferCGImageCompatibilityKey: @YES,
        (NSString *)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES
    };
    
    CVPixelBufferRef scaledPixelBuffer;
    CVPixelBufferCreate(kCFAllocatorDefault, size.width, size.height, kCVPixelFormatType_32BGRA, (__bridge CFDictionaryRef)pixelBufferAttributes, &scaledPixelBuffer);
    
    CVPixelBufferLockBaseAddress(scaledPixelBuffer, kCVPixelBufferLock_ReadOnly);
    
    CGAffineTransform scaleTransform = CGAffineTransformMakeScale(scaleFactor, scaleFactor);
    CIImage *scaledImage = [ciImage imageByApplyingTransform:scaleTransform];
    
    CGFloat offsetX = (size.width - scaledSize.width) / 2.0;
    CGFloat offsetY = (size.height - scaledSize.height) / 2.0;
    CGAffineTransform translateTransform = CGAffineTransformMakeTranslation(offsetX, offsetY);
    CIImage *centeredImage = [scaledImage imageByApplyingTransform:translateTransform];
    
    [context render:centeredImage toCVPixelBuffer:scaledPixelBuffer];
    
    CVPixelBufferUnlockBaseAddress(scaledPixelBuffer, kCVPixelBufferLock_ReadOnly);
    
    return scaledPixelBuffer;
}



@interface ObjCRearCamera : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate> {
    AVCaptureDevice *device;
    AVCaptureSession *session;
    AVCaptureDeviceInput *input;
    AVCaptureVideoDataOutput *output;
    
    BOOL isRGB565;
    
    std::vector<uint16_t> framebuffer;
    
    int64_t minFramesPerSecond, maxFramesPerSecond;
    CGFloat _width, _height;
}

+(ObjCRearCamera *) sharedInstance;

-(void) stop;
-(void) start;

-(void) framesPerSecond:(Service::CAM::FrameRate)arg1;
-(void) resolution:(Service::CAM::Resolution)arg1;
-(void) format:(Service::CAM::OutputFormat)arg1;

-(std::vector<uint16_t>) frame;
-(CGFloat) width;
-(CGFloat) height;
@end

@interface ObjCFrontCamera : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate> {
    AVCaptureDevice *device;
    AVCaptureSession *session;
    AVCaptureDeviceInput *input;
    AVCaptureVideoDataOutput *output;
    
    BOOL isRGB565;
    
    std::vector<uint16_t> framebuffer;
    
    int64_t minFramesPerSecond, maxFramesPerSecond;
    CGFloat _width, _height;
}

+(ObjCFrontCamera *) sharedInstance;

-(void) stop;
-(void) start;

-(void) framesPerSecond:(Service::CAM::FrameRate)arg1;
-(void) resolution:(Service::CAM::Resolution)arg1;
-(void) format:(Service::CAM::OutputFormat)arg1;

-(std::vector<uint16_t>) frame;
-(CGFloat) width;
-(CGFloat) height;
@end

@implementation ObjCRearCamera
-(ObjCRearCamera *) init {
    if (self = [super init]) {
        session = [[AVCaptureSession alloc] init];
        [session setSessionPreset:AVCaptureSessionPresetHigh];
        
        NSArray<AVCaptureDevice *> *devices = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[
            AVCaptureDeviceTypeBuiltInWideAngleCamera
        ] mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionUnspecified].devices;
        
        [devices enumerateObjectsUsingBlock:^(AVCaptureDevice *obj, NSUInteger idx, BOOL *stop) {
            if ([obj position] == AVCaptureDevicePositionBack) {
                device = obj;
                *stop = TRUE;
            }
        }];
    } return self;
}

+(ObjCRearCamera *) sharedInstance {
    static ObjCRearCamera *sharedInstance = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

-(void) stop {
    if ([session isRunning])
        [session stopRunning];
    
    [session removeInput:input];
    [session removeOutput:output];
}

-(void) start {
    [device lockForConfiguration:NULL];
    // configure
    [device setActiveVideoMinFrameDuration:CMTimeMake(1, minFramesPerSecond)];
    [device setActiveVideoMaxFrameDuration:CMTimeMake(1, maxFramesPerSecond)];
    [device unlockForConfiguration];
    
    input = [AVCaptureDeviceInput deviceInputWithDevice:device error:NULL];
    
    if ([session canAddInput:input])
        [session addInput:input];
    
    output = [[AVCaptureVideoDataOutput alloc] init];
    
    NSDictionary *settings = @{
        (NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA)
    };
    
    [output setVideoSettings:settings];
    [output setAlwaysDiscardsLateVideoFrames:YES];
    [output setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    
    if ([session canAddOutput:output])
        [session addOutput:output];
    
    if (![session isRunning])
        [session startRunning];
}

-(void) framesPerSecond:(Service::CAM::FrameRate)arg1 {
    switch (arg1) {
        case Service::CAM::FrameRate::Rate_15:
            minFramesPerSecond = maxFramesPerSecond = 15;
            break;
        case Service::CAM::FrameRate::Rate_15_To_5:
            minFramesPerSecond = 5;
            maxFramesPerSecond = 15;
            break;
        case Service::CAM::FrameRate::Rate_15_To_2:
            minFramesPerSecond = 2;
            maxFramesPerSecond = 15;
            break;
        case Service::CAM::FrameRate::Rate_10:
            minFramesPerSecond = maxFramesPerSecond = 15;
            break;
        case Service::CAM::FrameRate::Rate_8_5:
            minFramesPerSecond = maxFramesPerSecond = 8.5;
            break;
        case Service::CAM::FrameRate::Rate_5:
            minFramesPerSecond = maxFramesPerSecond = 5;
            break;
        case Service::CAM::FrameRate::Rate_20:
            minFramesPerSecond = maxFramesPerSecond = 20;
            break;
        case Service::CAM::FrameRate::Rate_20_To_5:
            minFramesPerSecond = 5;
            maxFramesPerSecond = 20;
            break;
        case Service::CAM::FrameRate::Rate_30:
            minFramesPerSecond = maxFramesPerSecond = 30;
            break;
        case Service::CAM::FrameRate::Rate_30_To_5:
            minFramesPerSecond = 5;
            maxFramesPerSecond = 30;
            break;
        case Service::CAM::FrameRate::Rate_15_To_10:
            minFramesPerSecond = 10;
            maxFramesPerSecond = 15;
            break;
        case Service::CAM::FrameRate::Rate_20_To_10:
            minFramesPerSecond = 10;
            maxFramesPerSecond = 20;
            break;
        case Service::CAM::FrameRate::Rate_30_To_10:
            minFramesPerSecond = 10;
            maxFramesPerSecond = 30;
            break;
    }
}

-(void) resolution:(Service::CAM::Resolution)arg1 {
    _width = arg1.width;
    _height = arg1.height;
    framebuffer.resize(_height * _width);
}

-(void) format:(Service::CAM::OutputFormat)arg1 {
    isRGB565 = arg1 == Service::CAM::OutputFormat::RGB565;
}

-(std::vector<uint16_t>) frame {
    return framebuffer;
}

-(CGFloat) width {
    return _width;
}

-(CGFloat) height {
    return _height;
}

-(void) captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
    if (!UIDeviceOrientationIsFlat(orientation))
        [connection setVideoOrientation:(AVCaptureVideoOrientation)orientation];
    else
        [connection setVideoOrientation:AVCaptureVideoOrientationPortrait];
    
    CVPixelBufferRef ref = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferRef pixelBuffer = scaledPixelBuffer(ref, {_width, _height});
    
    CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    
    uint8_t *bgraData = (uint8_t *)CVPixelBufferGetBaseAddress(pixelBuffer);
    size_t bgraStride = CVPixelBufferGetBytesPerRow(pixelBuffer);
    size_t width = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    
    if (isRGB565) {
        std::vector<uint16_t> rgb565Buffer(width * height);
        
        for (size_t y = 0; y < height; ++y) {
            for (size_t x = 0; x < width; ++x) {
                size_t bgraOffset = y * bgraStride + x * 4;
                
                uint8_t b = bgraData[bgraOffset];
                uint8_t g = bgraData[bgraOffset + 1];
                uint8_t r = bgraData[bgraOffset + 2];
                
                rgb565Buffer[y * width + x] = ((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3);
            }
        }
        
        memcpy(framebuffer.data(), rgb565Buffer.data(), width * height * sizeof(uint16_t));
    } else {
        std::vector<uint16_t> yuv422Buffer(width * height);
        auto dest = yuv422Buffer.begin();
        
        bool write = false;
        int py = 0, pu = 0, pv = 0;
        for (int j = 0; j < height; ++j) {
            for (int i = 0; i < width; ++i) {
                uint32_t bgra = *reinterpret_cast<uint32_t*>(&bgraData[(j * width + i) * 4]);
                
                uint8_t b  = (bgra & 0x000000FF);        // Extract Blue
                uint8_t g = (bgra & 0x0000FF00) >> 8;   // Extract Green
                uint8_t r   = (bgra & 0x00FF0000) >> 16;  // Extract Red
                uint8_t a = (bgra & 0xFF000000) >> 24;  // Extract Alpha
                
                // The following transformation is a reverse of the one in Y2R using ITU_Rec601
                int y = YuvTable::Y(r, g, b);
                int u = YuvTable::U(r, g, b);
                int v = YuvTable::V(r, g, b);
                
                if (write) {
                    pu = (pu + u) / 2;
                    pv = (pv + v) / 2;
                    *(dest++) =
                    static_cast<u16>(std::clamp(py, 0, 0xFF) | (std::clamp(pu, 0, 0xFF) << 8));
                    *(dest++) =
                    static_cast<u16>(std::clamp(y, 0, 0xFF) | (std::clamp(pv, 0, 0xFF) << 8));
                } else {
                    py = y;
                    pu = u;
                    pv = v;
                }
                write = !write;
            }
        }
        
        memcpy(framebuffer.data(), yuv422Buffer.data(), width * height * sizeof(uint16_t));
    }
}
@end

@implementation ObjCFrontCamera
-(ObjCFrontCamera *) init {
    if (self = [super init]) {
        session = [[AVCaptureSession alloc] init];
        [session setSessionPreset:AVCaptureSessionPresetHigh];
        
        NSArray<AVCaptureDevice *> *devices = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[
            AVCaptureDeviceTypeBuiltInWideAngleCamera
        ] mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionUnspecified].devices;
        
        [devices enumerateObjectsUsingBlock:^(AVCaptureDevice *obj, NSUInteger idx, BOOL *stop) {
            if ([obj position] == AVCaptureDevicePositionFront) {
                device = obj;
                *stop = TRUE;
            }
        }];
    } return self;
}

+(ObjCFrontCamera *) sharedInstance {
    static ObjCFrontCamera *sharedInstance = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

-(void) stop {
    if ([session isRunning])
        [session stopRunning];
    
    [session removeInput:input];
    [session removeOutput:output];
}

-(void) start {
    [device lockForConfiguration:NULL];
    // configure
    [device setActiveVideoMinFrameDuration:CMTimeMake(1, minFramesPerSecond)];
    [device setActiveVideoMaxFrameDuration:CMTimeMake(1, maxFramesPerSecond)];
    [device unlockForConfiguration];
    
    input = [AVCaptureDeviceInput deviceInputWithDevice:device error:NULL];
    
    if ([session canAddInput:input])
        [session addInput:input];
    
    output = [[AVCaptureVideoDataOutput alloc] init];
    
    NSDictionary *settings = @{
        (NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA)
    };
    
    [output setVideoSettings:settings];
    [output setAlwaysDiscardsLateVideoFrames:YES];
    [output setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    
    if ([session canAddOutput:output])
        [session addOutput:output];
    
    if (![session isRunning])
        [session startRunning];
}

-(void) framesPerSecond:(Service::CAM::FrameRate)arg1 {
    switch (arg1) {
        case Service::CAM::FrameRate::Rate_15:
            minFramesPerSecond = maxFramesPerSecond = 15;
            break;
        case Service::CAM::FrameRate::Rate_15_To_5:
            minFramesPerSecond = 5;
            maxFramesPerSecond = 15;
            break;
        case Service::CAM::FrameRate::Rate_15_To_2:
            minFramesPerSecond = 2;
            maxFramesPerSecond = 15;
            break;
        case Service::CAM::FrameRate::Rate_10:
            minFramesPerSecond = maxFramesPerSecond = 15;
            break;
        case Service::CAM::FrameRate::Rate_8_5:
            minFramesPerSecond = maxFramesPerSecond = 8.5;
            break;
        case Service::CAM::FrameRate::Rate_5:
            minFramesPerSecond = maxFramesPerSecond = 5;
            break;
        case Service::CAM::FrameRate::Rate_20:
            minFramesPerSecond = maxFramesPerSecond = 20;
            break;
        case Service::CAM::FrameRate::Rate_20_To_5:
            minFramesPerSecond = 5;
            maxFramesPerSecond = 20;
            break;
        case Service::CAM::FrameRate::Rate_30:
            minFramesPerSecond = maxFramesPerSecond = 30;
            break;
        case Service::CAM::FrameRate::Rate_30_To_5:
            minFramesPerSecond = 5;
            maxFramesPerSecond = 30;
            break;
        case Service::CAM::FrameRate::Rate_15_To_10:
            minFramesPerSecond = 10;
            maxFramesPerSecond = 15;
            break;
        case Service::CAM::FrameRate::Rate_20_To_10:
            minFramesPerSecond = 10;
            maxFramesPerSecond = 20;
            break;
        case Service::CAM::FrameRate::Rate_30_To_10:
            minFramesPerSecond = 10;
            maxFramesPerSecond = 30;
            break;
    }
}

-(void) resolution:(Service::CAM::Resolution)arg1 {
    _width = arg1.width;
    _height = arg1.height;
    framebuffer.resize(_height * _width);
}

-(void) format:(Service::CAM::OutputFormat)arg1 {
    isRGB565 = arg1 == Service::CAM::OutputFormat::RGB565;
}

-(std::vector<uint16_t>) frame {
    return framebuffer;
}

-(CGFloat) width {
    return _width;
}

-(CGFloat) height {
    return _height;
}

-(void) captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
    if (!UIDeviceOrientationIsFlat(orientation))
        [connection setVideoOrientation:(AVCaptureVideoOrientation)orientation];
    else
        [connection setVideoOrientation:AVCaptureVideoOrientationPortrait];
    
    [connection setVideoMirrored:TRUE];
    
    CVPixelBufferRef ref = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferRef pixelBuffer = scaledPixelBuffer(ref, {_width, _height});
    
    CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    
    uint8_t *bgraData = (uint8_t *)CVPixelBufferGetBaseAddress(pixelBuffer);
    size_t bgraStride = CVPixelBufferGetBytesPerRow(pixelBuffer);
    size_t width = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    
    if (isRGB565) {
        std::vector<uint16_t> rgb565Buffer(width * height);
        
        for (size_t y = 0; y < height; ++y) {
            for (size_t x = 0; x < width; ++x) {
                size_t bgraOffset = y * bgraStride + x * 4;
                
                uint8_t b = bgraData[bgraOffset];
                uint8_t g = bgraData[bgraOffset + 1];
                uint8_t r = bgraData[bgraOffset + 2];
                
                rgb565Buffer[y * width + x] = ((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3);
            }
        }
        
        memcpy(framebuffer.data(), rgb565Buffer.data(), width * height * sizeof(uint16_t));
    } else {
        std::vector<uint16_t> yuv422Buffer(width * height);
        auto dest = yuv422Buffer.begin();
        
        bool write = false;
        int py = 0, pu = 0, pv = 0;
        for (int j = 0; j < height; ++j) {
            for (int i = 0; i < width; ++i) {
                uint32_t bgra = *reinterpret_cast<uint32_t*>(&bgraData[(j * width + i) * 4]);
                
                uint8_t b  = (bgra & 0x000000FF);        // Extract Blue
                uint8_t g = (bgra & 0x0000FF00) >> 8;   // Extract Green
                uint8_t r   = (bgra & 0x00FF0000) >> 16;  // Extract Red
                uint8_t a = (bgra & 0xFF000000) >> 24;  // Extract Alpha
                
                // The following transformation is a reverse of the one in Y2R using ITU_Rec601
                int y = YuvTable::Y(r, g, b);
                int u = YuvTable::U(r, g, b);
                int v = YuvTable::V(r, g, b);
                
                if (write) {
                    pu = (pu + u) / 2;
                    pv = (pv + v) / 2;
                    *(dest++) =
                    static_cast<u16>(std::clamp(py, 0, 0xFF) | (std::clamp(pu, 0, 0xFF) << 8));
                    *(dest++) =
                    static_cast<u16>(std::clamp(y, 0, 0xFF) | (std::clamp(pv, 0, 0xFF) << 8));
                } else {
                    py = y;
                    pu = u;
                    pv = v;
                }
                write = !write;
            }
        }
        
        memcpy(framebuffer.data(), yuv422Buffer.data(), width * height * sizeof(uint16_t));
    }
}
@end





namespace Camera {
iOSRearCameraInterface::~iOSRearCameraInterface() {}

void iOSRearCameraInterface::StartCapture() {
    NSLog(@"%s", __FUNCTION__);
    [[ObjCRearCamera sharedInstance] start];
};

void iOSRearCameraInterface::StopCapture() {
    NSLog(@"%s", __FUNCTION__);
    [[ObjCRearCamera sharedInstance] stop];
};

void iOSRearCameraInterface::SetResolution(const Service::CAM::Resolution& resolution) {
    NSLog(@"%s, %hu, %hu", __FUNCTION__, resolution.width, resolution.height);
    [[ObjCRearCamera sharedInstance] resolution:resolution];
};

void iOSRearCameraInterface::SetFlip(Service::CAM::Flip flip) {
    NSLog(@"%s", __FUNCTION__);
};

void iOSRearCameraInterface::SetEffect(Service::CAM::Effect effect) {
    NSLog(@"%s", __FUNCTION__);
};

void iOSRearCameraInterface::SetFormat(Service::CAM::OutputFormat format) {
    NSLog(@"%s, %hhu", __FUNCTION__, format);
    [[ObjCRearCamera sharedInstance] format:format];
};

void iOSRearCameraInterface::SetFrameRate(Service::CAM::FrameRate frame_rate) {
    NSLog(@"%s", __FUNCTION__);
    [[ObjCRearCamera sharedInstance] framesPerSecond:frame_rate];
};

std::vector<u16> iOSRearCameraInterface::ReceiveFrame() {
    NSLog(@"%s", __FUNCTION__);
    return [[ObjCRearCamera sharedInstance] frame];
};

bool iOSRearCameraInterface::IsPreviewAvailable() {
    NSLog(@"%s", __FUNCTION__);
    return true;
};

iOSFrontCameraInterface::~iOSFrontCameraInterface() {}

void iOSFrontCameraInterface::StartCapture() {
    NSLog(@"%s", __FUNCTION__);
    [[ObjCFrontCamera sharedInstance] start];
};

void iOSFrontCameraInterface::StopCapture() {
    NSLog(@"%s", __FUNCTION__);
    [[ObjCFrontCamera sharedInstance] stop];
};

void iOSFrontCameraInterface::SetResolution(const Service::CAM::Resolution& resolution) {
    NSLog(@"%s, %hu, %hu", __FUNCTION__, resolution.width, resolution.height);
    [[ObjCFrontCamera sharedInstance] resolution:resolution];
};

void iOSFrontCameraInterface::SetFlip(Service::CAM::Flip flip) {
    NSLog(@"%s", __FUNCTION__);
};

void iOSFrontCameraInterface::SetEffect(Service::CAM::Effect effect) {
    NSLog(@"%s", __FUNCTION__);
};

void iOSFrontCameraInterface::SetFormat(Service::CAM::OutputFormat format) {
    NSLog(@"%s, %hhu", __FUNCTION__, format);
    [[ObjCFrontCamera sharedInstance] format:format];
};

void iOSFrontCameraInterface::SetFrameRate(Service::CAM::FrameRate frame_rate) {
    NSLog(@"%s", __FUNCTION__);
    [[ObjCFrontCamera sharedInstance] framesPerSecond:frame_rate];
};

std::vector<u16> iOSFrontCameraInterface::ReceiveFrame() {
    NSLog(@"%s", __FUNCTION__);
    return [[ObjCFrontCamera sharedInstance] frame];
};

bool iOSFrontCameraInterface::IsPreviewAvailable() {
    NSLog(@"%s", __FUNCTION__);
    return true;
};
}
