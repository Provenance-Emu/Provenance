#ifndef TEXTUREFILTERHANDLER_H
#define TEXTUREFILTERHANDLER_H

#include "Types.h"

class TextureFilterHandler
{
public:
	TextureFilterHandler() : m_inited(0), m_options(0) {}
	// It's not safe to call shutdown() in destructor, because texture filter has its own static objects, which can be destroyed first.
	~TextureFilterHandler() { shutdown(); }
	void init();
	void shutdown();
	void dumpcache();
	bool isInited() const { return m_inited != 0; }
	bool optionsChanged() const { return _getConfigOptions() != m_options; }
private:
	u32 _getConfigOptions() const;
	u32 m_inited;
	u32 m_options;
};

extern TextureFilterHandler TFH;

#endif // TEXTUREFILTERHANDLER_H
