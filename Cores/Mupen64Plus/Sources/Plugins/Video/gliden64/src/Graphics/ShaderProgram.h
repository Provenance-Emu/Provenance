#pragma once
#include <Types.h>
#include "CombinerProgram.h"

namespace graphics {

	class ShaderProgram : public CombinerProgram
	{
	public:
		virtual ~ShaderProgram() {}

		void update(bool _force) override {}
		const CombinerKey & getKey() const override { return CombinerKey::getEmpty(); }
		bool usesTexture() const override {return true;}
		virtual bool usesTile(u32 _t) const override {return _t == 0 ? true : false;}
		virtual bool usesShade() const override {return false;}
		virtual bool usesLOD() const override {return false;}
		virtual bool usesHwLighting() const override {return false;}
		virtual bool getBinaryForm(std::vector<char> & _buffer) override {return false;}
	};

	class TexrectDrawerShaderProgram : public ShaderProgram
	{
	public:
		virtual void setTextureSize(u32 _width, u32 _height) = 0;
		virtual void setEnableAlphaTest(int _enable) = 0;
	};

	class TextDrawerShaderProgram : public ShaderProgram
	{
	public:
		virtual void setTextColor(float * _color) = 0;
	};
}
