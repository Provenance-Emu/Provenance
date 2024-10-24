#pragma once
#include <istream>
#include "gDP.h"

class CombinerKey {
public:
	CombinerKey() {
		m_key.mux = 0;
	}
	explicit CombinerKey(u64 _mux, bool _setModeBits = true);
	CombinerKey(const CombinerKey & _other);

	void operator=(u64 _mux);
	void operator=(const CombinerKey & _other);

	bool operator==(const CombinerKey & _other) const;
	bool operator<(const CombinerKey & _other) const;

	bool isRectKey() const;

	u32 getCycleType() const;

	u32 getBilerp() const;

	u64 getMux() const { return m_key.mux; }

	void read(std::istream & _is);

	static const CombinerKey & getEmpty();

private:
	gDPCombine m_key;
};
