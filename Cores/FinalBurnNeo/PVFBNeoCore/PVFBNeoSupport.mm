//
//  PVFBNeoSupport.m
//  PVFBNeo
//
//  Created by Joseph Mattiello on 1/13/23.
//  Copyright © 2023 Provenance Emu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "burner.h"
#import "interface.h"
#import <CoreGraphics/CoreGraphics.h>
#import <UIKit/UIKit.h>

//#import "FBVideo.h"
//#import "FBInput.h"
//#import "FBAudio.h"
//#import "FBMainThread.h"

#pragma mark - FinalBurn callbacks

static unsigned char *screenBuffer = NULL;
static int bufferWidth = 0;
static int bufferHeight = 0;
static int bufferBytesPerPixel = 0;

static int MacOSVideoInit()
{
    int gameWidth;
    int gameHeight;
    int rotationMode = 0;
    int flags = BurnDrvGetFlags();

    BurnDrvGetVisibleSize(&gameWidth, &gameHeight);

    if (flags & BDF_ORIENTATION_VERTICAL) {
        rotationMode |= 1;
    }

    if (flags & BDF_ORIENTATION_FLIPPED) {
        rotationMode ^= 2;
    }

    nVidImageWidth = gameWidth;
    nVidImageHeight = gameHeight;
    nVidImageDepth = 16;
    nVidImageBPP = nVidImageDepth / 8;
    if (!rotationMode) {
        nVidImagePitch = nVidImageWidth * nVidImageBPP;
    } else {
        nVidImagePitch = nVidImageHeight * nVidImageBPP;
    }

    SetBurnHighCol(nVidImageDepth);

    bufferBytesPerPixel = nVidImageBPP;
    bufferWidth = gameWidth;
    bufferHeight = gameHeight;

    int bufSize = bufferWidth * bufferHeight * nVidImageBPP;
    free(screenBuffer);
    screenBuffer = (unsigned char *) malloc(bufSize);

    if (screenBuffer == NULL)
        return 1;

    nBurnBpp = nVidImageBPP;
    nBurnPitch = nVidImagePitch;
    pVidImage = screenBuffer;

    memset(screenBuffer, 0, bufSize);

    int textureWidth;
    int textureHeight;
    BOOL isRotated = rotationMode & 1;

    if (!isRotated) {
        textureWidth = bufferWidth;
        textureHeight = bufferHeight;
    } else {
        textureWidth = bufferHeight;
        textureHeight = bufferWidth;
    }

    CGSize screenSize = CGSizeMake((CGFloat)bufferWidth,
                                   (CGFloat)bufferHeight);

#warning "TODO"
#if 0
    [AppDelegate.sharedInstance.video notifyTextureReadyOfWidth:textureWidth
                                                         height:textureHeight
                                                      isRotated:isRotated
                                                      isFlipped:flags & BDF_ORIENTATION_FLIPPED
                                                  bytesPerPixel:bufferBytesPerPixel
                                                     screenSize:screenSize];
#endif
    return 0;
}
static int MacOSVideoExit()
{
    free(screenBuffer);
    screenBuffer = NULL;

    return 0;
}

static int MacOSVideoFrame(bool redraw)
{
    if (pVidImage == NULL || bRunPause)
        return 0;

    VidFrameCallback(redraw);

    return 0;
}

static int MacOSVideoPaint(int validate)
{
#warning "TODO"
#if 0
    return [AppDelegate.sharedInstance.video renderToSurface:screenBuffer] ? 0 : 1;
#endif
}

static int MacOSVideoScale(RECT*, int, int)
{
    return 0;
}

static int MacOSVideoGetSettings(InterfaceInfo *info)
{
    return 0;
}

struct VidOut VidOutMacOS = {
    MacOSVideoInit,
    MacOSVideoExit,
    MacOSVideoFrame,
    MacOSVideoPaint,
    MacOSVideoScale,
    MacOSVideoGetSettings,
    _T("MacOS Video"),
};
