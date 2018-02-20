#include "GLideN64.h"
#include <math.h>
#include "Types.h"
#include "VI.h"
#include "N64.h"
#include "gSP.h"
#include "gDP.h"
#include "RSP.h"
#include "FrameBuffer.h"
#include "DepthBuffer.h"
#include "FrameBufferInfo.h"
#include "Config.h"
#include "Performance.h"
#include "Debugger.h"
#include "DebugDump.h"
#include "Keys.h"
#include "DisplayWindow.h"
#include <Graphics/Context.h>

using namespace std;

VIInfo VI;

u16 VI_GetMaxBufferHeight(u16 _width)
{
	if (_width > 320 || VI.interlaced)
		return VI.PAL ? 580 : 480;

	return VI.PAL ? 290 : 240;
}

void VI_UpdateSize()
{
	const f32 xScale = _FIXED2FLOAT( _SHIFTR( *REG.VI_X_SCALE, 0, 12 ), 10 );
//	f32 xOffset = _FIXED2FLOAT( _SHIFTR( *REG.VI_X_SCALE, 16, 12 ), 10 );

	const u32 vScale = _SHIFTR(*REG.VI_Y_SCALE, 0, 12);
//	f32 yOffset = _FIXED2FLOAT( _SHIFTR( *REG.VI_Y_SCALE, 16, 12 ), 10 );

//	const u32 hEnd = _SHIFTR( *REG.VI_H_START, 0, 10 );
//	const u32 hStart = _SHIFTR( *REG.VI_H_START, 16, 10 );

	// These are in half-lines, so shift an extra bit
	const u32 vEnd = _SHIFTR( *REG.VI_V_START, 0, 10 );
	const u32 vStart = _SHIFTR( *REG.VI_V_START, 16, 10 );
	const bool interlacedPrev = VI.interlaced;
	if (VI.width > 0)
		VI.widthPrev = VI.width;

	VI.real_height = vEnd > vStart ? (((vEnd - vStart) >> 1) * vScale) >> 10 : 0;
	VI.width = *REG.VI_WIDTH;
	VI.interlaced = (*REG.VI_STATUS & 0x40) != 0;

	if (VI.interlaced) {
		f32 fullWidth = 640.0f;
		if ((*REG.VI_X_SCALE) % 512 == 0)
			fullWidth *= xScale;
		if (*REG.VI_WIDTH > fullWidth) {
			const u32 scale = (u32)floorf(*REG.VI_WIDTH / fullWidth + 0.5f);
			VI.width /= scale;
			VI.real_height *= scale;
		}
		if (VI.real_height % 2 == 1)
			--VI.real_height;
	} //else if (hEnd != 0 && *REG.VI_WIDTH != 0)
		//VI.width = min((u32)floorf((hEnd - hStart)*xScale + 0.5f), *REG.VI_WIDTH);

	VI.PAL = (*REG.VI_V_SYNC & 0x3ff) > 550;
	if (VI.PAL && (vEnd - vStart) > 478) {
		VI.height = (u32)(VI.real_height*1.0041841f);
		if (VI.height > 576)
			VI.height = VI.real_height = 576;
	}
	else {
		VI.height = (u32)(VI.real_height*1.0126582f);
		if (VI.height > 480)
			VI.height = VI.real_height = 480;
	}
	if (VI.height % 2 == 1)
		--VI.height;

//	const int fsaa = ((*REG.VI_STATUS) >> 8) & 3;
//	const int divot = ((*REG.VI_STATUS) >> 4) & 1;
	FrameBufferList & fbList = frameBufferList();
	FrameBuffer * pBuffer = fbList.findBuffer(VI.lastOrigin);
	DepthBuffer * pDepthBuffer = pBuffer != nullptr ? pBuffer->m_pDepthBuffer : nullptr;
	if (config.frameBufferEmulation.enable &&
		((interlacedPrev != VI.interlaced) ||
		(VI.width > 0 && VI.width != VI.widthPrev) ||
		(!VI.interlaced && pDepthBuffer != nullptr && pDepthBuffer->m_width != VI.width))) {
		fbList.removeBuffers(VI.widthPrev);
		fbList.removeBuffers(VI.width);
		depthBufferList().destroy();
		depthBufferList().init();
	}

	VI.rwidth = VI.width != 0 ? 1.0f / VI.width : 0.0f;
	VI.rheight = VI.height != 0 ? 1.0f / VI.height : 0.0f;
}

void VI_UpdateScreen()
{
	if (VI.lastOrigin == -1) // Workaround for Mupen64Plus issue with initialization
		gfxContext.isError();

	if (ConfigOpen)
		return;

	perf.increaseVICount();
	DisplayWindow & wnd = dwnd();
	if (wnd.changeWindow())
		return;
	if (wnd.resizeWindow())
		return;
	wnd.saveScreenshot();
	g_debugger.checkDebugState();

	if (isKeyPressed(G64_VK_G, 0x0001)) {
		SwitchDump(config.debug.dumpMode);
	}

	bool bVIUpdated = false;
	if (*REG.VI_ORIGIN != VI.lastOrigin) {
		VI_UpdateSize();
		bVIUpdated = true;
		wnd.updateScale();
		perf.increaseFramesCount();
	}

	if (config.frameBufferEmulation.enable) {

		FrameBuffer * pBuffer = frameBufferList().findBuffer(*REG.VI_ORIGIN);
		if (pBuffer == nullptr) {
			gDP.changed |= CHANGED_CPU_FB_WRITE;
		} else if (!FBInfo::fbInfo.isSupported() &&
				 (config.generalEmulation.hacks & hack_RE2) == 0 &&
				 !pBuffer->isValid(true)) {
			gDP.changed |= CHANGED_CPU_FB_WRITE;
			if (config.frameBufferEmulation.copyToRDRAM == 0 && (config.generalEmulation.hacks & hack_subscreen) == 0)
				pBuffer->copyRdram();
		}

		const bool bCFB = (gDP.changed&CHANGED_CPU_FB_WRITE) == CHANGED_CPU_FB_WRITE;
		bool bNeedSwap = false;
		switch (config.frameBufferEmulation.bufferSwapMode) {
		case Config::bsOnVerticalInterrupt:
			bNeedSwap = true;
			break;
		case Config::bsOnVIOriginChange:
			bNeedSwap = bCFB ? true : (*REG.VI_ORIGIN != VI.lastOrigin);
			break;
		case Config::bsOnColorImageChange:
			bNeedSwap = bCFB ? true : (gDP.colorImage.changed != 0);
			break;
		}

		if (bNeedSwap) {
			if (bCFB) {
				if (pBuffer == nullptr || pBuffer->m_width != VI.width) {
					if (!bVIUpdated) {
						VI_UpdateSize();
						wnd.updateScale();
						bVIUpdated = true;
					}
					const u32 size = *REG.VI_STATUS & 3;
					if (VI.height > 0 && size > G_IM_SIZ_8b  && VI.width > 0)
						frameBufferList().saveBuffer(*REG.VI_ORIGIN, G_IM_FMT_RGBA, size, VI.width, true);
				}
			}
//			if ((((*REG.VI_STATUS) & 3) > 0) && (gDP.colorImage.changed || bCFB)) { // Does not work in release build!!!
			if (((*REG.VI_STATUS) & 3) > 0) {
				if (!bVIUpdated) {
					VI_UpdateSize();
					bVIUpdated = true;
				}
				FrameBuffer_CopyFromRDRAM(*REG.VI_ORIGIN, bCFB);
			}
			frameBufferList().renderBuffer();
			frameBufferList().clearBuffersChanged();
			VI.lastOrigin = *REG.VI_ORIGIN;
		} 
	} else {
		if (gDP.changed & CHANGED_COLORBUFFER) {
			frameBufferList().renderBuffer();
			gDP.changed &= ~CHANGED_COLORBUFFER;
			VI.lastOrigin = *REG.VI_ORIGIN;
		}
	}

	if (VI.lastOrigin == -1) { // Workaround for Mupen64Plus issue with initialization
		gfxContext.clearColorBuffer(0.0f, 0.0f, 0.0f, 0.0f);
	}
}
