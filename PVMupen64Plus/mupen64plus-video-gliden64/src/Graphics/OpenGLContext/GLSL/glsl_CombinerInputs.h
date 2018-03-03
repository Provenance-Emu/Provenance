#pragma once
#include <Types.h>

namespace glsl {

	class CombinerInputs
	{
	public:
		CombinerInputs() : m_inputs(0) {}
		explicit CombinerInputs(int _inputs) : m_inputs(_inputs) {}
		CombinerInputs(const CombinerInputs & _other) : m_inputs(_other.m_inputs) {}

		explicit operator int() { return m_inputs; }

		bool usesTile(u32 _t) const;

		bool usesTexture() const;

		bool usesLOD() const;

		bool usesNoise() const;

		bool usesShade() const;

		bool usesShadeColor() const;

		bool usesHwLighting() const;

		void addInput(int _input);

		void operator+=(const CombinerInputs & _other);

	private:
		int m_inputs;
	};

}
