/*
 Copyright (c) 2013, OpenEmu Team

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
     * Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.
     * Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in the
       documentation and/or other materials provided with the distribution.
     * Neither the name of the OpenEmu Team nor the
       names of its contributors may be used to endorse or promote products
       derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
 EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include "base/logging.h"
#include "base/NativeApp.h"

#include "Common/LogManager.h"

#include "Core/Core.h"
#include "Core/CoreTiming.h"
#include "Core/Host.h"
#include "Core/System.h"
#include "Core/HLE/__sceAudio.h"

#include "file/vfs.h"
#include "file/zip_read.h"

#include "gfx/gl_lost_manager.h"

#include "Common/GraphicsContext.h"
#include "gfx/GLStateCache.h"
#include "GPU/GPUState.h"

#include "input/input_state.h"

#include "UI/OnScreenDisplay.h"

KeyInput input_state;
OnScreenMessages osm;

// Here's where we store the OpenEmu framebuffer to bind for final rendering
extern int framebuffer;

class AndroidLogger : public LogListener
{
public:
    void Log(const LogMessage &msg) override{};

	void Log(LogTypes::LOG_LEVELS level, const char *msg)
	{
		switch (level)
		{
            case LogTypes::LVERBOSE:
            case LogTypes::LDEBUG:
            case LogTypes::LINFO:
                ILOG("%s", msg);
                break;
            case LogTypes::LERROR:
                ELOG("%s", msg);
                break;
            case LogTypes::LWARNING:
                WLOG("%s", msg);
                break;
            case LogTypes::LNOTICE:
            default:
                ILOG("%s", msg);
                break;
		}
	}
};

static AndroidLogger *logger = 0;

class NativeHost : public Host {
public:
    NativeHost() {
    }

    void UpdateUI() override {}

    void UpdateMemView() override {}
    void UpdateDisassembly() override {}

    void SetDebugMode(bool mode) override { }

    bool InitGraphics(std::string *error_string, GraphicsContext **ctx)override { return true; }
    void ShutdownGraphics() override {}

    void InitSound() override {}
    void UpdateSound() override {}
    void ShutdownSound() override {}

    // this is sent from EMU thread! Make sure that Host handles it properly!
    void BootDone() override {}

    bool IsDebuggingEnabled() override {return false;}
    bool AttemptLoadSymbolMap() override {return false;}
    void SetWindowTitle(const char *message) override {}
};

int NativeMix(short *audio, int num_samples)
{
    int sample_rate = System_GetPropertyInt(SYSPROP_AUDIO_SAMPLE_RATE);
    num_samples = __AudioMix(audio, num_samples, sample_rate > 0 ? sample_rate : 44100);

	return num_samples;
}

void NativeInit(int argc, const char *argv[], const char *savegame_directory, const char *external_directory, const char *installID, bool fs)
{
    host = new NativeHost();

    logger = new AndroidLogger();

	LogManager *logman = LogManager::GetInstance();
	ILOG("Logman: %p", logman);

    LogTypes::LOG_LEVELS logLevel = LogTypes::LINFO;
	for(int i = 0; i < LogTypes::NUMBER_OF_LOGS; i++)
	{
		LogTypes::LOG_TYPE type = (LogTypes::LOG_TYPE)i;
        logman->SetLogLevel(type, logLevel);
    }

    VFSRegister("", new DirectoryAssetReader(external_directory));
}

void NativeInitGraphics(GraphicsContext *graphicsContext)
{
    // Save framebuffer to later be bound again
    glGetIntegerv(GL_FRAMEBUFFER_BINDING_EXT, &framebuffer);

    Core_SetGraphicsContext(graphicsContext);

    gl_lost_manager_init();
}

void NativeResized(){}

void NativeRender(GraphicsContext *graphicsContext)
{
	glstate.Restore();

    PSP_BeginHostFrame();

    s64 blockTicks = usToCycles(1000000 / 10);
    while(coreState == CORE_RUNNING)
    {
		PSP_RunLoopFor((int)blockTicks);
	}

	// Hopefully coreState is now CORE_NEXTFRAME
	if(coreState == CORE_NEXTFRAME)
    {
		// set back to running for the next frame
		coreState = CORE_RUNNING;
    }

    PSP_EndHostFrame();
}

void NativeUpdate() {}

void NativeShutdownGraphics()
{
    gl_lost_manager_shutdown();
}

void NativeShutdown()
{
    delete host;
    host = 0;

    LogManager::Shutdown();
}

void OnScreenMessages::Show(const std::string &text, float duration_s, uint32_t color, int icon, bool checkUnique, const char *id) {}

std::string System_GetProperty(SystemProperty prop) {
	switch (prop) {
        case SYSPROP_NAME:
            return "OpenEmu:";
        case SYSPROP_LANGREGION:
            return "en_US";
        default:
            return "";
	}
}

int System_GetPropertyInt(SystemProperty prop) {
    switch (prop) {
        case SYSPROP_AUDIO_SAMPLE_RATE:
            return 44100;
        case SYSPROP_DISPLAY_REFRESH_RATE:
            return 60000;
        default:
            return -1;
    }
}

void NativeMessageReceived(const char *message, const char *value) {}


