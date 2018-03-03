#include <vector>
#include "CombinerProgram.h"
#include <Config.h>

namespace graphics {

	u32 CombinerProgram::getShaderCombinerOptionsBits()
	{
		// WARNING: Shader Storage format version must be increased after any change in this function.
		std::vector<u32> vecOptions;
		vecOptions.push_back(config.video.multisampling > 0 ? 1 : 0);
		vecOptions.push_back(config.texture.bilinearMode);
		vecOptions.push_back(config.generalEmulation.enableHWLighting);
		vecOptions.push_back(config.generalEmulation.enableNoise);
		vecOptions.push_back(config.generalEmulation.enableLOD);
		vecOptions.push_back(config.frameBufferEmulation.N64DepthCompare);
		vecOptions.push_back(config.generalEmulation.enableLegacyBlending);
		vecOptions.push_back(config.generalEmulation.enableFragmentDepthWrite);
		u32 optionsSet = 0;
		for (u32 i = 0; i < vecOptions.size(); ++i)
			optionsSet |= vecOptions[i] << i;
		return optionsSet;
	}

}
