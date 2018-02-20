#include <Config.h>
#include "glsl_CombinerProgramUniformFactory.h"
#include <Graphics/Parameters.h>

#include <Textures.h>
#include <NoiseTexture.h>
#include <FrameBuffer.h>
#include <DisplayWindow.h>
#include <GBI.h>
#include <RSP.h>
#include <gSP.h>
#include <gDP.h>
#include <VI.h>

namespace glsl {

/*---------------Uniform-------------*/

struct iUniform	{
	GLint loc = -1;
	int val = -999;
	void set(int _val, bool _force) {
		if (loc >= 0 && (_force || val != _val)) {
			val = _val;
			glUniform1i(loc, _val);
		}
	}
};

struct fUniform {
	GLint loc = -1;
	float val = -9999.9f;
	void set(float _val, bool _force) {
		if (loc >= 0 && (_force || val != _val)) {
			val = _val;
			glUniform1f(loc, _val);
		}
	}
};

struct fv2Uniform {
	GLint loc = -1;
	float val1 = -9999.9f, val2 = -9999.9f;
	void set(float _val1, float _val2, bool _force) {
		if (loc >= 0 && (_force || val1 != _val1 || val2 != _val2)) {
			val1 = _val1;
			val2 = _val2;
			glUniform2f(loc, _val1, _val2);
		}
	}
};

struct fv3Uniform {
	GLint loc = -1;
	float val[3];
	void set(float * _pVal, bool _force) {
		const size_t szData = sizeof(float)* 3;
		if (loc >= 0 && (_force || memcmp(val, _pVal, szData) != 0)) {
			memcpy(val, _pVal, szData);
			glUniform3fv(loc, 1, _pVal);
		}
	}
};

struct fv4Uniform {
	GLint loc = -1;
	float val[4];
	void set(float * _pVal, bool _force) {
		const size_t szData = sizeof(float)* 4;
		if (loc >= 0 && (_force || memcmp(val, _pVal, szData) != 0)) {
			memcpy(val, _pVal, szData);
			glUniform4fv(loc, 1, _pVal);
		}
	}
};

struct iv2Uniform {
	GLint loc = -1;
	int val1 = -999, val2 = -999;
	void set(int _val1, int _val2, bool _force) {
		if (loc >= 0 && (_force || val1 != _val1 || val2 != _val2)) {
			val1 = _val1;
			val2 = _val2;
			glUniform2i(loc, _val1, _val2);
		}
	}
};

struct i4Uniform {
	GLint loc = -1;
	int val0 = -999, val1 = -999, val2 = -999, val3 = -999;
	void set(int _val0, int _val1, int _val2, int _val3, bool _force) {
		if (loc < 0)
			return;
		if (_force || _val0 != val0 || _val1 != val1 || _val2 != val2 || _val3 != val3) {
			val0 = _val0;
			val1 = _val1;
			val2 = _val2;
			val3 = _val3;
			glUniform4i(loc, val0, val1, val2, val3);
		}
	}
};


/*---------------UniformGroup-------------*/

#define LocateUniform(A) \
	A.loc = glGetUniformLocation(_program, #A);

class UNoiseTex : public UniformGroup
{
public:
	UNoiseTex(GLuint _program) {
		LocateUniform(uTexNoise);
	}

	void update(bool _force) override
	{
		uTexNoise.set(int(graphics::textureIndices::NoiseTex), _force);
	}

private:
	iUniform uTexNoise;
};

class UDepthTex : public UniformGroup
{
public:
	UDepthTex(GLuint _program) {
		LocateUniform(uDepthTex);
	}

	void update(bool _force) override
	{
		uDepthTex.set(int(graphics::textureIndices::DepthTex), _force);
	}

private:
	iUniform uDepthTex;
};

class UTextures : public UniformGroup
{
public:
	UTextures(GLuint _program) {
		LocateUniform(uTex0);
		LocateUniform(uTex1);
	}

	void update(bool _force) override
	{
		uTex0.set(0, _force);
		uTex1.set(1, _force);
	}

private:
	iUniform uTex0;
	iUniform uTex1;
};

class UMSAATextures : public UniformGroup
{
public:
	UMSAATextures(GLuint _program) {
		LocateUniform(uMSTex0);
		LocateUniform(uMSTex1);
		LocateUniform(uMSAASamples);
	}

	void update(bool _force) override
	{
		uMSTex0.set(int(graphics::textureIndices::MSTex[0]), _force);
		uMSTex1.set(int(graphics::textureIndices::MSTex[1]), _force);
		uMSAASamples.set(config.video.multisampling, _force);
	}

private:
	iUniform uMSTex0;
	iUniform uMSTex1;
	iUniform uMSAASamples;
};

class UFrameBufferInfo : public UniformGroup
{
public:
	UFrameBufferInfo(GLuint _program) {
		LocateUniform(uFbMonochrome);
		LocateUniform(uFbFixedAlpha);
		LocateUniform(uMSTexEnabled);
	}

	void update(bool _force) override
	{
		int nFbMonochromeMode0 = 0, nFbMonochromeMode1 = 0;
		int nFbFixedAlpha0 = 0, nFbFixedAlpha1 = 0;
		int nMSTex0Enabled = 0, nMSTex1Enabled = 0;
		TextureCache & cache = textureCache();
		if (cache.current[0] != nullptr && cache.current[0]->frameBufferTexture != CachedTexture::fbNone) {
			if (cache.current[0]->size == G_IM_SIZ_8b) {
				nFbMonochromeMode0 = 1;
				if (gDP.otherMode.imageRead == 0)
					nFbFixedAlpha0 = 1;
			} else if (gSP.textureTile[0]->size == G_IM_SIZ_16b && gSP.textureTile[0]->format == G_IM_FMT_IA) {
				nFbMonochromeMode0 = 2;
			} else if ((config.generalEmulation.hacks & hack_ZeldaMonochrome) != 0 &&
					   cache.current[0]->size == G_IM_SIZ_16b &&
					   gSP.textureTile[0]->size == G_IM_SIZ_8b &&
					   gSP.textureTile[0]->format == G_IM_FMT_CI) {
				// Zelda monochrome effect
				nFbMonochromeMode0 = 3;
				nFbMonochromeMode1 = 3;
			}

			nMSTex0Enabled = cache.current[0]->frameBufferTexture == CachedTexture::fbMultiSample ? 1 : 0;
		}
		if (cache.current[1] != nullptr && cache.current[1]->frameBufferTexture != CachedTexture::fbNone) {
			if (cache.current[1]->size == G_IM_SIZ_8b) {
				nFbMonochromeMode1 = 1;
				if (gDP.otherMode.imageRead == 0)
					nFbFixedAlpha1 = 1;
			}
			else if (gSP.textureTile[1]->size == G_IM_SIZ_16b && gSP.textureTile[1]->format == G_IM_FMT_IA)
				nFbMonochromeMode1 = 2;
			nMSTex1Enabled = cache.current[1]->frameBufferTexture == CachedTexture::fbMultiSample ? 1 : 0;
		}
		uFbMonochrome.set(nFbMonochromeMode0, nFbMonochromeMode1, _force);
		uFbFixedAlpha.set(nFbFixedAlpha0, nFbFixedAlpha1, _force);
		uMSTexEnabled.set(nMSTex0Enabled, nMSTex1Enabled, _force);
		gDP.changed &= ~CHANGED_FB_TEXTURE;
	}

private:
	iv2Uniform uFbMonochrome;
	iv2Uniform uFbFixedAlpha;
	iv2Uniform uMSTexEnabled;
};


class UFog : public UniformGroup
{
public:
	UFog(GLuint _program) {
		LocateUniform(uFogUsage);
		LocateUniform(uFogScale);
	}

	void update(bool _force) override
	{
		if (RSP.LLE) {
			uFogUsage.set(0, _force);
			return;
		}

		int nFogUsage = ((gSP.geometryMode & G_FOG) != 0) ? 1 : 0;
		if (GBI.getMicrocodeType() == F3DAM) {
			const s16 fogMode = ((gSP.geometryMode >> 13) & 9) + 0xFFF8;
			if (fogMode == 0)
				nFogUsage = 1;
			else if (fogMode > 0)
				nFogUsage = 2;
		}
		uFogUsage.set(nFogUsage, _force);
		uFogScale.set(gSP.fog.multiplierf, gSP.fog.offsetf, _force);
	}

private:
	iUniform uFogUsage;
	fv2Uniform uFogScale;
};

class UBlendMode1Cycle : public UniformGroup
{
public:
	UBlendMode1Cycle(GLuint _program) {
		LocateUniform(uBlendMux1);
		LocateUniform(uForceBlendCycle1);
	}

	void update(bool _force) override
	{
		uBlendMux1.set(gDP.otherMode.c1_m1a,
			gDP.otherMode.c1_m1b,
			gDP.otherMode.c1_m2a,
			gDP.otherMode.c1_m2b,
			_force);

		const int forceBlend1 = (int)gDP.otherMode.forceBlender;
		uForceBlendCycle1.set(forceBlend1, _force);
	}

private:
	i4Uniform uBlendMux1;
	iUniform uForceBlendCycle1;
};

class UBlendMode2Cycle : public UniformGroup
{
public:
	UBlendMode2Cycle(GLuint _program) {
		LocateUniform(uBlendMux1);
		LocateUniform(uBlendMux2);
		LocateUniform(uForceBlendCycle1);
		LocateUniform(uForceBlendCycle2);
	}

	void update(bool _force) override
	{
		if ((gDP.otherMode.l & 0xFFFF0000) == 0x01500000) {
			uForceBlendCycle1.set(0, _force);
			uForceBlendCycle2.set(0, _force);
			return;
		}

		uBlendMux1.set(gDP.otherMode.c1_m1a,
			gDP.otherMode.c1_m1b,
			gDP.otherMode.c1_m2a,
			gDP.otherMode.c1_m2b,
			_force);

		uBlendMux2.set(gDP.otherMode.c2_m1a,
			gDP.otherMode.c2_m1b,
			gDP.otherMode.c2_m2a,
			gDP.otherMode.c2_m2b,
			_force);

		const int forceBlend1 = 1;
		uForceBlendCycle1.set(forceBlend1, _force);
		const int forceBlend2 = gDP.otherMode.forceBlender;
		uForceBlendCycle2.set(forceBlend2, _force);
	}

private:
	i4Uniform uBlendMux1;
	i4Uniform uBlendMux2;
	iUniform uForceBlendCycle1;
	iUniform uForceBlendCycle2;
};

class UDitherMode : public UniformGroup
{
public:
	UDitherMode(GLuint _program, bool _usesNoise)
	: m_usesNoise(_usesNoise)
	{
		LocateUniform(uAlphaCompareMode);
		LocateUniform(uAlphaDitherMode);
		LocateUniform(uColorDitherMode);
	}

	void update(bool _force) override
	{
		if (gDP.otherMode.cycleType < G_CYC_COPY) {
			uAlphaCompareMode.set(gDP.otherMode.alphaCompare, _force);
			uAlphaDitherMode.set(gDP.otherMode.alphaDither, _force);
			uColorDitherMode.set(gDP.otherMode.colorDither, _force);
		}
		else {
			uAlphaCompareMode.set(0, _force);
			uAlphaDitherMode.set(0, _force);
			uColorDitherMode.set(0, _force);
		}

		bool updateNoiseTex = m_usesNoise;
		updateNoiseTex |= (gDP.otherMode.cycleType < G_CYC_COPY) && (gDP.otherMode.colorDither == G_CD_NOISE || gDP.otherMode.alphaDither == G_AD_NOISE || gDP.otherMode.alphaCompare == G_AC_DITHER);
		if (updateNoiseTex)
			g_noiseTexture.update();
	}

private:
	iUniform uAlphaCompareMode;
	iUniform uAlphaDitherMode;
	iUniform uColorDitherMode;
	bool m_usesNoise;
};

class UScreenScale : public UniformGroup
{
public:
	UScreenScale(GLuint _program) {
		LocateUniform(uScreenScale);
	}

	void update(bool _force) override
	{
		FrameBuffer * pBuffer = frameBufferList().getCurrent();
		if (pBuffer == nullptr)
			uScreenScale.set(dwnd().getScaleX(), dwnd().getScaleY(), _force);
		else
			uScreenScale.set(pBuffer->m_scale, pBuffer->m_scale, _force);
	}

private:
	fv2Uniform uScreenScale;
};

class UMipmap1 : public UniformGroup
{
public:
	UMipmap1(GLuint _program) {
		LocateUniform(uMinLod);
		LocateUniform(uMaxTile);
	}

	void update(bool _force) override
	{
		uMinLod.set(gDP.primColor.m, _force);
		uMaxTile.set(gSP.texture.level, _force);
	}

private:
	fUniform uMinLod;
	iUniform uMaxTile;
};

class UMipmap2 : public UniformGroup
{
public:
	UMipmap2(GLuint _program) {
		LocateUniform(uEnableLod);
		LocateUniform(uTextureDetail);
	}

	void update(bool _force) override
	{
		const int uCalcLOD = (gDP.otherMode.textureLOD == G_TL_LOD) ? 1 : 0;
		uEnableLod.set(uCalcLOD, _force);
		uTextureDetail.set(gDP.otherMode.textureDetail, _force);
	}

private:
	iUniform uEnableLod;
	iUniform uTextureDetail;
};

class UTexturePersp : public UniformGroup
{
public:
	UTexturePersp(GLuint _program) {
		LocateUniform(uTexturePersp);
	}

	void update(bool _force) override
	{
		const u32 texturePersp = (RSP.LLE || GBI.isTexturePersp()) ? gDP.otherMode.texturePersp : 1U;
		uTexturePersp.set(texturePersp, _force);
	}

private:
	iUniform uTexturePersp;
};

class UTextureFetchMode : public UniformGroup
{
public:
	UTextureFetchMode(GLuint _program) {
		LocateUniform(uTextureFilterMode);
		LocateUniform(uTextureFormat);
		LocateUniform(uTextureConvert);
		LocateUniform(uConvertParams);
	}

	void update(bool _force) override
	{
		int textureFilter = gDP.otherMode.textureFilter;
		if ((gSP.objRendermode&G_OBJRM_BILERP) != 0)
			textureFilter |= 2;
		uTextureFilterMode.set(textureFilter, _force);
		uTextureFormat.set(gSP.textureTile[0]->format, gSP.textureTile[1]->format, _force);
		uTextureConvert.set(gDP.otherMode.convert_one, _force);
		if (gDP.otherMode.bi_lerp0 == 0 || gDP.otherMode.bi_lerp1 == 0)
			uConvertParams.set(gDP.convert.k0, gDP.convert.k1, gDP.convert.k2, gDP.convert.k3, _force);
	}

private:
	iUniform uTextureFilterMode;
	iv2Uniform uTextureFormat;
	iUniform uTextureConvert;
	i4Uniform uConvertParams;
};

class UAlphaTestInfo : public UniformGroup
{
public:
	UAlphaTestInfo(GLuint _program) {
		LocateUniform(uEnableAlphaTest);
		LocateUniform(uAlphaCvgSel);
		LocateUniform(uCvgXAlpha);
		LocateUniform(uAlphaTestValue);
	}

	void update(bool _force) override
	{
		if (gDP.otherMode.cycleType == G_CYC_FILL) {
			uEnableAlphaTest.set(0, _force);
		}
		else if (gDP.otherMode.cycleType == G_CYC_COPY) {
			if (gDP.otherMode.alphaCompare & G_AC_THRESHOLD) {
				uEnableAlphaTest.set(1, _force);
				uAlphaCvgSel.set(0, _force);
				uAlphaTestValue.set(0.5f, _force);
			}
			else {
				uEnableAlphaTest.set(0, _force);
			}
		}
		else if ((gDP.otherMode.alphaCompare & G_AC_THRESHOLD) != 0) {
			uEnableAlphaTest.set(1, _force);
			uAlphaTestValue.set(gDP.blendColor.a, _force);
			uAlphaCvgSel.set(gDP.otherMode.alphaCvgSel, _force);
		}
		else {
			uEnableAlphaTest.set(0, _force);
		}

		uCvgXAlpha.set(gDP.otherMode.cvgXAlpha, _force);
	}

private:
	iUniform uEnableAlphaTest;
	iUniform uAlphaCvgSel;
	iUniform uCvgXAlpha;
	fUniform uAlphaTestValue;
};

class UDepthScale : public UniformGroup
{
public:
	UDepthScale(GLuint _program) {
		LocateUniform(uDepthScale);
	}

	void update(bool _force) override
	{
		if (RSP.LLE)
			uDepthScale.set(0.5f, 0.5f, _force);
		else
			uDepthScale.set(gSP.viewport.vscale[2], gSP.viewport.vtrans[2], _force);
	}

private:
	fv2Uniform uDepthScale;
};

class UDepthInfo : public UniformGroup
{
public:
	UDepthInfo(GLuint _program) {
		LocateUniform(uEnableDepth);
		LocateUniform(uEnableDepthCompare);
		LocateUniform(uEnableDepthUpdate);
		LocateUniform(uDepthMode);
		LocateUniform(uDepthSource);
		LocateUniform(uPrimDepth);
		LocateUniform(uDeltaZ);
	}

	void update(bool _force) override
	{
		FrameBuffer * pBuffer = frameBufferList().getCurrent();
		if (pBuffer == nullptr || pBuffer->m_pDepthBuffer == nullptr)
			return;

		const int nDepthEnabled = (gSP.geometryMode & G_ZBUFFER) > 0 ? 1 : 0;
		uEnableDepth.set(nDepthEnabled, _force);
		if (nDepthEnabled == 0) {
			uEnableDepthCompare.set(0, _force);
			uEnableDepthUpdate.set(0, _force);
		}
		else {
			uEnableDepthCompare.set(gDP.otherMode.depthCompare, _force);
			uEnableDepthUpdate.set(gDP.otherMode.depthUpdate, _force);
		}
		uDepthMode.set(gDP.otherMode.depthMode, _force);
		uDepthSource.set(gDP.otherMode.depthSource, _force);
		if (gDP.otherMode.depthSource == G_ZS_PRIM) {
			uDeltaZ.set(gDP.primDepth.deltaZ, _force);
			uPrimDepth.set(gDP.primDepth.z, _force);
		}
	}

private:
	iUniform uEnableDepth;
	iUniform uEnableDepthCompare;
	iUniform uEnableDepthUpdate;
	iUniform uDepthMode;
	iUniform uDepthSource;
	fUniform uPrimDepth;
	fUniform uDeltaZ;
};

class UDepthSource : public UniformGroup
{
public:
	UDepthSource(GLuint _program) {
		LocateUniform(uDepthSource);
		LocateUniform(uPrimDepth);
	}

	void update(bool _force) override
	{
		uDepthSource.set(gDP.otherMode.depthSource, _force);
		if (gDP.otherMode.depthSource == G_ZS_PRIM)
			uPrimDepth.set(gDP.primDepth.z, _force);
	}

private:
	iUniform uDepthSource;
	fUniform uPrimDepth;
};

class URenderTarget : public UniformGroup
{
public:
	URenderTarget(GLuint _program) {
		LocateUniform(uRenderTarget);
	}

	void update(bool _force) override
	{
		int renderTarget = 0;
		if (gDP.colorImage.address == gDP.depthImageAddress ) {
			renderTarget = gDP.otherMode.depthCompare + 1;
		}
		uRenderTarget.set(renderTarget, _force);
	}

private:
	iUniform uRenderTarget;
};

class UScreenCoordsScale : public UniformGroup
{
public:
	UScreenCoordsScale(GLuint _program) {
		LocateUniform(uScreenCoordsScale);
	}

	void update(bool _force) override
	{
		f32 scaleX, scaleY;
		calcCoordsScales(frameBufferList().getCurrent(), scaleX, scaleY);
		uScreenCoordsScale.set(2.0f*scaleX, -2.0f*scaleY, _force);
	}

private:
	fv2Uniform uScreenCoordsScale;
};

class UColors : public UniformGroup
{
public:
	UColors(GLuint _program) {
		LocateUniform(uFogColor);
		LocateUniform(uCenterColor);
		LocateUniform(uScaleColor);
		LocateUniform(uBlendColor);
		LocateUniform(uEnvColor);
		LocateUniform(uPrimColor);
		LocateUniform(uPrimLod);
		LocateUniform(uK4);
		LocateUniform(uK5);
	}

	void update(bool _force) override
	{
		uFogColor.set(&gDP.fogColor.r, _force);
		uCenterColor.set(&gDP.key.center.r, _force);
		uScaleColor.set(&gDP.key.scale.r, _force);
		uBlendColor.set(&gDP.blendColor.r, _force);
		uEnvColor.set(&gDP.envColor.r, _force);
		uPrimColor.set(&gDP.primColor.r, _force);
		uPrimLod.set(gDP.primColor.l, _force);
		uK4.set(gDP.convert.k4*0.0039215689f, _force);
		uK5.set(gDP.convert.k5*0.0039215689f, _force);
	}

private:
	fv4Uniform uFogColor;
	fv4Uniform uCenterColor;
	fv4Uniform uScaleColor;
	fv4Uniform uBlendColor;
	fv4Uniform uEnvColor;
	fv4Uniform uPrimColor;
	fUniform uPrimLod;
	fUniform uK4;
	fUniform uK5;
};

class URectColor : public UniformGroup
{
public:
	URectColor(GLuint _program) {
		LocateUniform(uRectColor);
	}

	void update(bool _force) override
	{
		uRectColor.set(&gDP.rectColor.r, _force);
	}

private:
	fv4Uniform uRectColor;
};

class UTextureSize : public UniformGroup
{
public:
	UTextureSize(GLuint _program, bool _useT0, bool _useT1)
	: m_useT0(_useT0)
	, m_useT1(_useT1)
	{
		LocateUniform(uTextureSize[0]);
		LocateUniform(uTextureSize[1]);
	}

	void update(bool _force) override
	{
		TextureCache & cache = textureCache();
		if (m_useT0 && cache.current[0] != NULL)
			uTextureSize[0].set((float)cache.current[0]->realWidth, (float)cache.current[0]->realHeight, _force);
		if (m_useT1 && cache.current[1] != NULL)
			uTextureSize[1].set((float)cache.current[1]->realWidth, (float)cache.current[1]->realHeight, _force);
	}

private:
	fv2Uniform uTextureSize[2];
	bool m_useT0;
	bool m_useT1;
};

class UTextureParams : public UniformGroup
{
public:
	UTextureParams(GLuint _program, bool _useT0, bool _useT1)
	{
		m_useTile[0] = _useT0;
		m_useTile[1] = _useT1;
		LocateUniform(uTexOffset[0]);
		LocateUniform(uTexOffset[1]);
		LocateUniform(uCacheShiftScale[0]);
		LocateUniform(uCacheShiftScale[1]);
		LocateUniform(uCacheScale[0]);
		LocateUniform(uCacheScale[1]);
		LocateUniform(uCacheOffset[0]);
		LocateUniform(uCacheOffset[1]);
		LocateUniform(uTexScale);
		LocateUniform(uCacheFrameBuffer);
	}

	void update(bool _force) override
	{
		int nFB[2] = { 0, 0 };
		TextureCache & cache = textureCache();
		for (u32 t = 0; t < 2; ++t) {
			if (!m_useTile[t])
				continue;

			if (gSP.textureTile[t] != nullptr) {
				if (gSP.textureTile[t]->textureMode == TEXTUREMODE_BGIMAGE || gSP.textureTile[t]->textureMode == TEXTUREMODE_FRAMEBUFFER_BG)
					uTexOffset[t].set(0.0f, 0.0f, _force);
				else {
					float fuls = gSP.textureTile[t]->fuls;
					float fult = gSP.textureTile[t]->fult;
					if (gSP.textureTile[t]->frameBufferAddress > 0) {
						FrameBuffer * pBuffer = frameBufferList().getBuffer(gSP.textureTile[t]->frameBufferAddress);
						if (pBuffer != nullptr) {
							if (gSP.textureTile[t]->masks > 0 && gSP.textureTile[t]->clamps == 0)
								fuls = float(gSP.textureTile[t]->uls % (1 << gSP.textureTile[t]->masks));
							if (gSP.textureTile[t]->maskt > 0 && gSP.textureTile[t]->clampt == 0)
								fult = float(gSP.textureTile[t]->ult % (1 << gSP.textureTile[t]->maskt));
						} else {
							gSP.textureTile[t]->frameBufferAddress = 0;
						}
					}
					uTexOffset[t].set(fuls, fult, _force);
				}
			}

			if (cache.current[t] != nullptr) {
				f32 shiftScaleS = 1.0f;
				f32 shiftScaleT = 1.0f;
				getTextureShiftScale(t, cache, shiftScaleS, shiftScaleT);
				uCacheShiftScale[t].set(shiftScaleS, shiftScaleT, _force);
				uCacheScale[t].set(cache.current[t]->scaleS, cache.current[t]->scaleT, _force);
				uCacheOffset[t].set(cache.current[t]->offsetS, cache.current[t]->offsetT, _force);
				nFB[t] = cache.current[t]->frameBufferTexture;
			}
		}

		uCacheFrameBuffer.set(nFB[0], nFB[1], _force);
		uTexScale.set(gSP.texture.scales, gSP.texture.scalet, _force);
	}

private:
	bool m_useTile[2];
	fv2Uniform uTexOffset[2];
	fv2Uniform uCacheShiftScale[2];
	fv2Uniform uCacheScale[2];
	fv2Uniform uCacheOffset[2];
	fv2Uniform uTexScale;
	iv2Uniform uCacheFrameBuffer;
};


class ULights : public UniformGroup
{
public:
	ULights(GLuint _program)
	{
		char buf[32];
		for (s32 i = 0; i < 8; ++i) {
			sprintf(buf, "uLightDirection[%d]", i);
			uLightDirection[i].loc = glGetUniformLocation(_program, buf);
			sprintf(buf, "uLightColor[%d]", i);
			uLightColor[i].loc = glGetUniformLocation(_program, buf);
		}
	}

	void update(bool _force) override
	{
		for (u32 i = 0; i <= gSP.numLights; ++i) {
			uLightDirection[i].set(gSP.lights.xyz[i], _force);
			uLightColor[i].set(gSP.lights.rgb[i], _force);
		}
	}

private:
	fv3Uniform uLightDirection[8];
	fv3Uniform uLightColor[8];
};


/*---------------CombinerProgramUniformFactory-------------*/

void CombinerProgramUniformFactory::buildUniforms(GLuint _program,
												  const CombinerInputs & _inputs,
												  const CombinerKey & _key,
												  UniformGroups & _uniforms)
{
	if (config.generalEmulation.enableNoise != 0)
		_uniforms.emplace_back(new UNoiseTex(_program));

	if (!m_glInfo.isGLES2) {
		_uniforms.emplace_back(new UDepthTex(_program));
		_uniforms.emplace_back(new UDepthScale(_program));
	}

	if (_inputs.usesTexture()) {
		_uniforms.emplace_back(new UTextures(_program));

		if (config.video.multisampling != 0)
			_uniforms.emplace_back(new UMSAATextures(_program));

		_uniforms.emplace_back(new UFrameBufferInfo(_program));

		if (_inputs.usesLOD()) {
			_uniforms.emplace_back(new UMipmap1(_program));
			if (config.generalEmulation.enableLOD != 0)
				_uniforms.emplace_back(new UMipmap2(_program));
		} else if (_key.getCycleType() < G_CYC_COPY) {
			_uniforms.emplace_back(new UTextureFetchMode(_program));
		}

		_uniforms.emplace_back(new UTexturePersp(_program));

		if (m_glInfo.isGLES2)
			_uniforms.emplace_back(new UTextureSize(_program, _inputs.usesTile(0), _inputs.usesTile(1)));

		if (!_key.isRectKey())
			_uniforms.emplace_back(new UTextureParams(_program, _inputs.usesTile(0), _inputs.usesTile(1)));
	}

	_uniforms.emplace_back(new UFog(_program));

	if (config.generalEmulation.enableLegacyBlending == 0) {
		switch (_key.getCycleType()) {
		case G_CYC_1CYCLE:
			_uniforms.emplace_back(new UBlendMode1Cycle(_program));
			break;
		case G_CYC_2CYCLE:
			_uniforms.emplace_back(new UBlendMode2Cycle(_program));
			break;
		}
	}

	_uniforms.emplace_back(new UDitherMode(_program, _inputs.usesNoise()));

	_uniforms.emplace_back(new UScreenScale(_program));

	_uniforms.emplace_back(new UAlphaTestInfo(_program));

	if (config.frameBufferEmulation.N64DepthCompare != 0)
		_uniforms.emplace_back(new UDepthInfo(_program));
	else
		_uniforms.emplace_back(new UDepthSource(_program));

	if (config.generalEmulation.enableFragmentDepthWrite != 0 ||
		config.frameBufferEmulation.N64DepthCompare != 0)
		_uniforms.emplace_back(new URenderTarget(_program));

	_uniforms.emplace_back(new UScreenCoordsScale(_program));

	_uniforms.emplace_back(new UColors(_program));

	if (_key.isRectKey())
		_uniforms.emplace_back(new URectColor(_program));

	if (_inputs.usesHwLighting())
		_uniforms.emplace_back(new ULights(_program));
}

CombinerProgramUniformFactory::CombinerProgramUniformFactory(const opengl::GLInfo & _glInfo)
: m_glInfo(_glInfo)
{
}

}
