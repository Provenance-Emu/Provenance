
#include "hw/pvr/Renderer_if.h"
#include "oslib/oslib.h"

void rend_set_fb_scale(float x,float y) { }
void rend_text_invl(vram_block* bl) { }

struct norend : Renderer
{
	bool Init()
	{
		return true;
	}

	void Resize(int w, int h) { }
	void Term() { }


        bool Process(TA_context* ctx) { return true; }

        void DrawOSD() {  }

	bool Render()
	{
		return true;//!pvrrc.isRTT;
	}

	void Present() { }
};


Renderer* rend_norend() { return new norend(); }

u32 GetTexture(TSP tsp,TCW tcw) { return 0; }
