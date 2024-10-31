#include <Combiner.h>
#include "glsl_CombinerInputs.h"

using namespace glsl;

bool CombinerInputs::usesTile(u32 _t) const
{
	if (_t == 0)
		return (m_inputs & ((1 << G_GCI_TEXEL0) | (1 << G_GCI_TEXEL0_ALPHA))) != 0;
	return (m_inputs & ((1 << G_GCI_TEXEL1) | (1 << G_GCI_TEXEL1_ALPHA))) != 0;
}

bool CombinerInputs::usesTexture() const
{
	return (m_inputs & ((1 << G_GCI_TEXEL1) | (1 << G_GCI_TEXEL1_ALPHA) | (1 << G_GCI_TEXEL0) | (1 << G_GCI_TEXEL0_ALPHA))) != 0;
}

bool CombinerInputs::usesLOD() const
{
	return (m_inputs & (1 << G_GCI_LOD_FRACTION)) != 0;
}

bool CombinerInputs::usesNoise() const
{
	return (m_inputs & (1 << G_GCI_NOISE)) != 0;
}

bool CombinerInputs::usesShade() const
{
	return (m_inputs & ((1 << G_GCI_SHADE) | (1 << G_GCI_SHADE_ALPHA))) != 0;
}

bool CombinerInputs::usesShadeColor() const
{
	return (m_inputs & (1 << G_GCI_SHADE)) != 0;
}

bool CombinerInputs::usesHwLighting() const
{
	return (m_inputs & (1 << G_GCI_HW_LIGHT)) != 0;
}

void CombinerInputs::addInput(int _input)
{
	m_inputs |= 1 << _input;
}

void CombinerInputs::operator+=(const CombinerInputs & _other)
{
	m_inputs |= _other.m_inputs;
}
