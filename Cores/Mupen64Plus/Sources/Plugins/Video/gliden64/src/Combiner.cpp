#include <fstream>
#include <functional>
#include <cstring>
#include <stdio.h>
#include <osal_files.h>

#include "Combiner.h"
#include "DebugDump.h"
#include "gDP.h"
#include "Config.h"
#include "PluginAPI.h"
#include "RSP.h"
#include "Graphics/Context.h"

using namespace graphics;

static u32 saRGBExpanded[] =
{
	G_GCI_COMBINED,			G_GCI_TEXEL0,			G_GCI_TEXEL1,			G_GCI_PRIMITIVE,
	G_GCI_SHADE,			G_GCI_ENVIRONMENT,		G_GCI_ONE,				G_GCI_NOISE,
	G_GCI_ZERO,				G_GCI_ZERO,				G_GCI_ZERO,				G_GCI_ZERO,
	G_GCI_ZERO,				G_GCI_ZERO,				G_GCI_ZERO,				G_GCI_ZERO
};

static u32 sbRGBExpanded[] =
{
	G_GCI_COMBINED,			G_GCI_TEXEL0,			G_GCI_TEXEL1,			G_GCI_PRIMITIVE,
	G_GCI_SHADE,			G_GCI_ENVIRONMENT,		G_GCI_CENTER,			G_GCI_K4,
	G_GCI_ZERO,				G_GCI_ZERO,				G_GCI_ZERO,				G_GCI_ZERO,
	G_GCI_ZERO,				G_GCI_ZERO,				G_GCI_ZERO,				G_GCI_ZERO
};

static u32 mRGBExpanded[] =
{
	G_GCI_COMBINED,			G_GCI_TEXEL0,			G_GCI_TEXEL1,			G_GCI_PRIMITIVE,
	G_GCI_SHADE,			G_GCI_ENVIRONMENT,		G_GCI_SCALE,			G_GCI_COMBINED_ALPHA,
	G_GCI_TEXEL0_ALPHA,		G_GCI_TEXEL1_ALPHA,		G_GCI_PRIMITIVE_ALPHA,	G_GCI_SHADE_ALPHA,
	G_GCI_ENV_ALPHA,		G_GCI_LOD_FRACTION,		G_GCI_PRIM_LOD_FRAC,	G_GCI_K5,
	G_GCI_ZERO,				G_GCI_ZERO,				G_GCI_ZERO,				G_GCI_ZERO,
	G_GCI_ZERO,				G_GCI_ZERO,				G_GCI_ZERO,				G_GCI_ZERO,
	G_GCI_ZERO,				G_GCI_ZERO,				G_GCI_ZERO,				G_GCI_ZERO,
	G_GCI_ZERO,				G_GCI_ZERO,				G_GCI_ZERO,				G_GCI_ZERO
};

static u32 aRGBExpanded[] =
{
	G_GCI_COMBINED,			G_GCI_TEXEL0,			G_GCI_TEXEL1,			G_GCI_PRIMITIVE,
	G_GCI_SHADE,			G_GCI_ENVIRONMENT,		G_GCI_ONE,				G_GCI_ZERO
};

static u32 saAExpanded[] =
{
	G_GCI_COMBINED,			G_GCI_TEXEL0_ALPHA,		G_GCI_TEXEL1_ALPHA,		G_GCI_PRIMITIVE_ALPHA,
	G_GCI_SHADE_ALPHA,		G_GCI_ENV_ALPHA,		G_GCI_ONE,				G_GCI_ZERO
};

static u32 sbAExpanded[] =
{
	G_GCI_COMBINED,			G_GCI_TEXEL0_ALPHA,		G_GCI_TEXEL1_ALPHA,		G_GCI_PRIMITIVE_ALPHA,
	G_GCI_SHADE_ALPHA,		G_GCI_ENV_ALPHA,		G_GCI_ONE,				G_GCI_ZERO
};

static u32 mAExpanded[] =
{
	G_GCI_LOD_FRACTION,		G_GCI_TEXEL0_ALPHA,		G_GCI_TEXEL1_ALPHA,		G_GCI_PRIMITIVE_ALPHA,
	G_GCI_SHADE_ALPHA,		G_GCI_ENV_ALPHA,		G_GCI_PRIM_LOD_FRAC,	G_GCI_ZERO,
};

static u32 aAExpanded[] =
{
	G_GCI_COMBINED,			G_GCI_TEXEL0_ALPHA,		G_GCI_TEXEL1_ALPHA,		G_GCI_PRIMITIVE_ALPHA,
	G_GCI_SHADE_ALPHA,		G_GCI_ENV_ALPHA,		G_GCI_ONE,				G_GCI_ZERO
};

void Combiner_Init() {
	CombinerInfo & cmbInfo = CombinerInfo::get();
	cmbInfo.init();
	gDP.otherMode.cycleType = G_CYC_1CYCLE;
}

void Combiner_Destroy() {
	CombinerInfo::get().destroy();
}

/*---------------CombinerInfo-------------*/

CombinerInfo & CombinerInfo::get()
{
	static CombinerInfo info;
	return info;
}

void CombinerInfo::init()
{
	gfxContext.resetCombinerProgramBuilder();
	m_pCurrent = nullptr;

	m_shadersLoaded = 0;
	if (config.generalEmulation.enableShadersStorage != 0 && !_loadShadersStorage()) {
		for (auto cur = m_combiners.begin(); cur != m_combiners.end(); ++cur)
			delete cur->second;
		m_combiners.clear();
	}

	if (m_combiners.empty()) {
		setPolygonMode(DrawingState::TexRect);
		gDP.otherMode.cycleType = G_CYC_COPY;
		setCombine(EncodeCombineMode(0, 0, 0, TEXEL0, 0, 0, 0, TEXEL0, 0, 0, 0, TEXEL0, 0, 0, 0, TEXEL0));
		gDP.otherMode.cycleType = G_CYC_FILL;
		setCombine(EncodeCombineMode(0, 0, 0, SHADE, 0, 0, 0, SHADE, 0, 0, 0, SHADE, 0, 0, 0, SHADE));
	}

	m_shadowmapProgram.reset(gfxContext.createDepthFogShader());
	m_texrectCopyProgram.reset(gfxContext.createTexrectCopyShader());
}

void CombinerInfo::destroy()
{
	m_shadowmapProgram.reset();
	m_texrectCopyProgram.reset();

	m_pCurrent = nullptr;
	if (config.generalEmulation.enableShadersStorage != 0)
		_saveShadersStorage();
	m_shadersLoaded = 0;
	for (auto cur = m_combiners.begin(); cur != m_combiners.end(); ++cur)
		delete cur->second;
	m_combiners.clear();
}

static
void SimplifyCycle( CombineCycle *cc, CombinerStage *stage )
{
	// Load the first operand
	stage->op[0].op = LOAD;
	stage->op[0].param1 = cc->sa;
	stage->numOps = 1;

	// If we're just subtracting zero, skip it
	if (cc->sb != G_GCI_ZERO) {
		// Subtracting a number from itself is zero
		if (cc->sb == stage->op[0].param1)
			stage->op[0].param1 = G_GCI_ZERO;
		else {
			stage->op[1].op = SUB;
			stage->op[1].param1 = cc->sb;
			stage->numOps++;
		}
	}

	// If we either subtracted, or didn't load a zero
	if ((stage->numOps > 1) || (stage->op[0].param1 != G_GCI_ZERO)) {
		// Multiplying by zero is zero
		if (cc->m == G_GCI_ZERO) {
			stage->numOps = 1;
			stage->op[0].op = LOAD;
			stage->op[0].param1 = G_GCI_ZERO;
		} else {
			// Multiplying by one, so just do a load
			if ((stage->numOps == 1) && (stage->op[0].param1 == G_GCI_ONE))
				stage->op[0].param1 = cc->m;
			else {
				stage->op[stage->numOps].op = MUL;
				stage->op[stage->numOps].param1 = cc->m;
				stage->numOps++;
			}
		}
	}

	// Don't bother adding zero
	if (cc->a != G_GCI_ZERO) {
		// If all we have so far is zero, then load this instead
		if ((stage->numOps == 1) && (stage->op[0].param1 == G_GCI_ZERO))
			stage->op[0].param1 = cc->a;
		else {
			stage->op[stage->numOps].op = ADD;
			stage->op[stage->numOps].param1 = cc->a;
			stage->numOps++;
		}
	}

	// Handle interpolation
	if ((stage->numOps == 4) && (stage->op[1].param1 == stage->op[3].param1)) {
		stage->numOps = 1;
		stage->op[0].op = INTER;
		stage->op[0].param2 = stage->op[1].param1;
		stage->op[0].param3 = stage->op[2].param1;
	}
}

graphics::CombinerProgram * Combiner_Compile(CombinerKey key)
{
	gDPCombine combine;

	combine.mux = key.getMux();

	Combiner color, alpha;

	const u32 cycleType = key.getCycleType();
	const u32 numCycles = cycleType + 1;
	color.numStages = numCycles;
	alpha.numStages = numCycles;

	CombineCycle cc[2];
	CombineCycle ac[2];

	// Simplify each RDP combiner cycle into a combiner stage
	if (cycleType == G_CYC_1CYCLE) {
		// 1 cycle mode uses combiner equations from 2nd cycle
		u32 colorMux[4] = { saRGBExpanded[combine.saRGB1], sbRGBExpanded[combine.sbRGB1],
							mRGBExpanded[combine.mRGB1], aRGBExpanded[combine.aRGB1] };
		// Check for 'combined' mux
		for (u32 i = 0; i < 4; ++i) {
			if (colorMux[i] == G_GCI_COMBINED || colorMux[i] == G_GCI_COMBINED_ALPHA)
				colorMux[i] = G_GCI_ZERO;
		}
		cc[1].sa = colorMux[0];
		cc[1].sb = colorMux[1];
		cc[1].m = colorMux[2];
		cc[1].a = colorMux[3];
		SimplifyCycle(&cc[1], &color.stage[0]);

		u32 alphaMux[4] = { saAExpanded[combine.saA1], sbAExpanded[combine.sbA1],
			mAExpanded[combine.mA1], aAExpanded[combine.aA1] };
		// Check for 'combined' mux
		for (u32 i = 0; i < 4; ++i) {
			if (alphaMux[i] == G_GCI_COMBINED)
				alphaMux[i] = G_GCI_ZERO;
		}
		ac[1].sa = alphaMux[0];
		ac[1].sb = alphaMux[1];
		ac[1].m = alphaMux[2];
		ac[1].a = alphaMux[3];
		SimplifyCycle(&ac[1], &alpha.stage[0]);
	} else {
		// Decode and expand the combine mode into a more general form
		cc[1].sa = saRGBExpanded[combine.saRGB1];
		cc[1].sb = sbRGBExpanded[combine.sbRGB1];
		cc[1].m = mRGBExpanded[combine.mRGB1];
		cc[1].a = aRGBExpanded[combine.aRGB1];
		ac[1].sa = saAExpanded[combine.saA1];
		ac[1].sb = sbAExpanded[combine.sbA1];
		ac[1].m = mAExpanded[combine.mA1];
		ac[1].a = aAExpanded[combine.aA1];

		cc[0].sa = saRGBExpanded[combine.saRGB0];
		cc[0].sb = sbRGBExpanded[combine.sbRGB0];
		cc[0].m = mRGBExpanded[combine.mRGB0];
		cc[0].a = aRGBExpanded[combine.aRGB0];
		ac[0].sa = saAExpanded[combine.saA0];
		ac[0].sb = sbAExpanded[combine.sbA0];
		ac[0].m = mAExpanded[combine.mA0];
		ac[0].a = aAExpanded[combine.aA0];

		SimplifyCycle(&cc[0], &color.stage[0]);
		SimplifyCycle(&ac[0], &alpha.stage[0]);

		const bool equalStages = (memcmp(cc, cc + 1, sizeof(CombineCycle)) | memcmp(ac, ac + 1, sizeof(CombineCycle))) == 0;
		if (!equalStages) {
			SimplifyCycle(&cc[1], &color.stage[1]);
			SimplifyCycle(&ac[1], &alpha.stage[1]);
		} else {
			color.numStages = 1;
			alpha.numStages = 1;
		}
	}

	return gfxContext.createCombinerProgram(color, alpha, key);
}

void CombinerInfo::update()
{
	// TODO: find, why gDP.changed & CHANGED_COMBINE not always works (e.g. Mario Tennis).
//	if (gDP.changed & CHANGED_COMBINE) {
		if (gDP.otherMode.cycleType == G_CYC_COPY)
			setCombine(EncodeCombineMode(0, 0, 0, TEXEL0, 0, 0, 0, TEXEL0, 0, 0, 0, TEXEL0, 0, 0, 0, TEXEL0));
		else if (gDP.otherMode.cycleType == G_CYC_FILL)
			setCombine(EncodeCombineMode(0, 0, 0, SHADE, 0, 0, 0, SHADE, 0, 0, 0, SHADE, 0, 0, 0, SHADE));
		else
			setCombine(gDP.combine.mux);
		gDP.changed &= ~CHANGED_COMBINE;
//	}
}

void CombinerInfo::setCombine(u64 _mux )
{
	const CombinerKey key(_mux);
	if (m_pCurrent != nullptr && m_pCurrent->getKey() == key) {
		m_bChanged = false;
		return;
	}
	auto iter = m_combiners.find(key);
	if (iter != m_combiners.end()) {
		m_pCurrent = iter->second;
	} else {
		m_pCurrent = Combiner_Compile(key);
		m_pCurrent->update(true);
		m_combiners[m_pCurrent->getKey()] = m_pCurrent;
	}
	m_bChanged = true;
}

void CombinerInfo::updateParameters()
{
	m_pCurrent->update(false);
}

void CombinerInfo::setDepthFogCombiner()
{
	if (m_shadowmapProgram) {
		m_shadowmapProgram->activate();
		m_pCurrent = m_shadowmapProgram.get();
	}
}

ShaderProgram * CombinerInfo::getTexrectCopyProgram()
{
	return m_texrectCopyProgram.get();
}

bool CombinerInfo::isShaderCacheSupported() const
{
	return config.generalEmulation.enableShadersStorage != 0 && Context::ShaderProgramBinary;
}

void CombinerInfo::setPolygonMode(DrawingState _drawingState)
{
	switch (_drawingState) {
	case DrawingState::Rect:
	case DrawingState::TexRect:
		m_rectMode = true;
		break;
	default:
		m_rectMode = false;
		break;
	}
}

void CombinerInfo::_saveShadersStorage() const
{
	if (m_shadersLoaded >= m_combiners.size())
		return;

	gfxContext.saveShadersStorage(m_combiners);
}

bool CombinerInfo::_loadShadersStorage()
{
	if (gfxContext.loadShadersStorage(m_combiners)) {
		m_shadersLoaded = static_cast<u32>(m_combiners.size());
		return true;
	}

	return false;
}
