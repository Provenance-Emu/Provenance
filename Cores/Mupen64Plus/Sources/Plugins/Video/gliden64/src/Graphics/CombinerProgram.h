#pragma once
#include <map>
#include <vector>
#include "CombinerKey.h"

namespace graphics {

	class CombinerProgram
	{
	public:
		virtual ~CombinerProgram() {}
		virtual void activate() = 0;
		virtual void update(bool _force) = 0;

		virtual const CombinerKey & getKey() const = 0;

		virtual bool usesTexture() const = 0;
		virtual bool usesTile(u32 _t) const = 0;
		virtual bool usesShade() const = 0;
		virtual bool usesLOD() const = 0;
		virtual bool usesHwLighting() const = 0;

		virtual bool getBinaryForm(std::vector<char> & _buffer) = 0;

		static u32 getShaderCombinerOptionsBits();
	};

	typedef std::map<CombinerKey, graphics::CombinerProgram *> Combiners;
}
