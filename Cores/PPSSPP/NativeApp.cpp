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

#include <atomic>
#include <thread>
#include "Thread/ThreadUtil.h"

#include "Math/fast/fast_math.h"

#include "Common/LogManager.h"
#include "Common/CPUDetect.h"

#include "Core/Core.h"
#include "Core/CoreTiming.h"
#include "Core/Host.h"
#include "Core/System.h"
#include "Core/HLE/__sceAudio.h"
#include "Core/ThreadPools.h"

#include "File/VFS/VFS.h"
#include "File/VFS/AssetReader.h"

//#include "Common/GPU/OpenGL/OpenEmuGLContext.h"
#include "Common/GPU/OpenGL/GLCommon.h"
//#include "DataFormat.h"

#include "Common/GraphicsContext.h"
#include "GPU/GPUState.h"

#include "GPU/GPUState.h"
#include "GPU/GPUInterface.h"

//#include "DataFormatGL.h"

#include "Common/Input/InputState.h"
#include "Common/System/System.h"

#include "UI/OnScreenDisplay.h"

#include <stdio.h>

inline const char *removePath(const char *str) {
    const char *slash = strrchr(str, '/');
    return slash ? (slash + 1) : str;
}

#ifdef _DEBUG
#define DLOG(...) {printf("D: %s:%i: ", removePath(__FILE__), __LINE__); printf("D: " __VA_ARGS__); printf("\n");}
#else
#define DLOG(...)
#endif
#define ILOG(...) {printf("I: %s:%i: ", removePath(__FILE__), __LINE__); printf(__VA_ARGS__); printf("\n");}
#define WLOG(...) {printf("W: %s:%i: ", removePath(__FILE__), __LINE__); printf(__VA_ARGS__); printf("\n");}
#define ELOG(...) {printf("E: %s:%i: ", removePath(__FILE__), __LINE__); printf(__VA_ARGS__); printf("\n");}
#define FLOG(...) {printf("F: %s:%i: ", removePath(__FILE__), __LINE__); printf(__VA_ARGS__); printf("\n"); Crash();}

KeyInput input_state;
OnScreenMessages osm;

//namespace OpenEmuCoreThread {
//    OpenEmuGLContext *ctx;
//
//    enum class EmuThreadState {
//        DISABLED,
//        START_REQUESTED,
//        RUNNING,
//        PAUSE_REQUESTED,
//        PAUSED,
//        QUIT_REQUESTED,
//        STOPPED,
//    };
//
//    static std::thread emuThread;
//    static bool threadStarted = false;
//    static std::atomic<EmuThreadState> emuThreadState(EmuThreadState::DISABLED);
//
//    static void EmuFrame() {
//        ctx->SetRenderTarget();
//
//        if (ctx->GetDrawContext()) {
//            ctx->GetDrawContext()->BeginFrame();
//        }
//
//        gpu->BeginHostFrame();
//
//        coreState = CORE_RUNNING;
//        PSP_RunLoopUntil(UINT64_MAX);
//
//        gpu->EndHostFrame();
//
//        if (ctx->GetDrawContext()) {
//            ctx->GetDrawContext()->EndFrame();
//        }
//    }
//
//    static void EmuThreadFunc() {
//        SetCurrentThreadName("Emu");
//
//        while (true) {
//            switch ((EmuThreadState)emuThreadState) {
//                case EmuThreadState::START_REQUESTED:
//                    threadStarted = true;
//                    emuThreadState = EmuThreadState::RUNNING;
//                    /* fallthrough */
//                case EmuThreadState::RUNNING:
//                    EmuFrame();
//                    break;
//                case EmuThreadState::PAUSE_REQUESTED:
//                    emuThreadState = EmuThreadState::PAUSED;
//                    /* fallthrough */
//                case EmuThreadState::PAUSED:
//                    usleep(1000);
//                    break;
//                default:
//                case EmuThreadState::QUIT_REQUESTED:
//                    emuThreadState = EmuThreadState::STOPPED;
//                    ctx->StopThread();
//                    return;
//            }
//        }
//    }
//
//    void EmuThreadStart() {
//        bool wasPaused = emuThreadState == EmuThreadState::PAUSED;
//        emuThreadState = EmuThreadState::START_REQUESTED;
//
//        if (!wasPaused) {
//            ctx->ThreadStart();
//            emuThread = std::thread(&EmuThreadFunc);
//        }
//    }
//
//    void EmuThreadStop() {
//        if (emuThreadState != EmuThreadState::RUNNING) {
//            return;
//        }
//
//        emuThreadState = EmuThreadState::QUIT_REQUESTED;
//
//        while (ctx->ThreadFrame()) {
//            // Need to keep eating frames to allow the EmuThread to exit correctly.
//            continue;
//        }
//        emuThread.join();
//        emuThread = std::thread();
//        ctx->ThreadEnd();
//    }
//
//    void EmuThreadPause() {
//        if (emuThreadState != EmuThreadState::RUNNING) {
//            return;
//        }
//        emuThreadState = EmuThreadState::PAUSE_REQUESTED;
//
//        while (emuThreadState != EmuThreadState::PAUSED) {
//            //We need to process frames until the thread Pauses give 10 ms between loops
//            ctx->ThreadFrame();
//            emuThreadState = EmuThreadState::PAUSE_REQUESTED;
//            usleep(10000);
//        }
//    }
//
//    static void EmuThreadJoin() {
//        emuThread.join();
//        emuThread = std::thread();
//    }
//}  // namespace OpenEmuCoreThread


// Here's where we store the OpenEmu framebuffer to bind for final rendering
int framebuffer = 0;

//class AndroidLogger : public LogListener
//{
//public:
//    void Log(const LogMessage &msg) override{};
//
//    void Log(LogTypes::LOG_LEVELS level, const char *msg)
//    {
//        switch (level)
//        {
//            case LogTypes::LVERBOSE:
//            case LogTypes::LDEBUG:
//            case LogTypes::LINFO:
//                ILOG("%s", msg);
//                break;
//            case LogTypes::LERROR:
//                ELOG("%s", msg);
//                break;
//            case LogTypes::LWARNING:
//                WLOG("%s", msg);
//                break;
//            case LogTypes::LNOTICE:
//            default:
//                ILOG("%s", msg);
//                break;
//        }
//    }
//};
//
//static AndroidLogger *logger = 0;

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

void NativeInit(int argc, const char *argv[], const char *savegame_directory, const char *external_directory, const char *cache_directory)
{
    VFSRegister("", new DirectoryAssetReader(Path("assets/")));
    VFSRegister("", new DirectoryAssetReader(Path(external_directory)));
    
    g_threadManager.Init(cpu_info.num_cores, cpu_info.logical_cpu_count);

    if (host == nullptr) {
        host = new NativeHost();
    }
    
//    logger = new AndroidLogger();

    LogManager *logman = LogManager::GetInstance();
    ILOG("Logman: %p", logman);

    LogTypes::LOG_LEVELS logLevel = LogTypes::LINFO;
    for(int i = 0; i < LogTypes::NUMBER_OF_LOGS; i++)
    {
        LogTypes::LOG_TYPE type = (LogTypes::LOG_TYPE)i;
        logman->SetLogLevel(type, logLevel);
    }
}

//void NativeSetThreadState(OpenEmuCoreThread::EmuThreadState threadState)  {
//    if(threadState == OpenEmuCoreThread::EmuThreadState::PAUSE_REQUESTED && OpenEmuCoreThread::threadStarted)
//        OpenEmuCoreThread::EmuThreadPause();
//    else if(threadState == OpenEmuCoreThread::EmuThreadState::START_REQUESTED && !OpenEmuCoreThread::threadStarted)
//        OpenEmuCoreThread::EmuThreadStart();
//    else
//        OpenEmuCoreThread::emuThreadState = threadState;
//}

bool NativeInitGraphics(GraphicsContext *graphicsContext)
{
    //Set the Core Thread graphics Context
//    OpenEmuCoreThread::ctx = static_cast<OpenEmuGLContext*>(graphicsContext);
    
    // Save framebuffer and set ppsspp default graphics framebuffer object
//    glGetIntegerv(GL_FRAMEBUFFER_BINDING_EXT, &framebuffer);
//    OpenEmuCoreThread::ctx->SetRenderFBO(framebuffer);
//
//    Core_SetGraphicsContext(OpenEmuCoreThread::ctx);
    
    if (gpu)
        gpu->DeviceRestore();
    
    return true;
}

void NativeResized(){}

void NativeRender(GraphicsContext *ctx)
{
//    if(OpenEmuCoreThread::emuThreadState == OpenEmuCoreThread::EmuThreadState::PAUSED)
//        return;
//
//    OpenEmuCoreThread::ctx->ThreadFrame();
//    OpenEmuCoreThread::ctx->SwapBuffers();
}

void NativeUpdate() {}

void NativeShutdownGraphics()
{
}

void NativeShutdown()
{
    delete host;
    host = 0;

    LogManager::Shutdown();
}

bool NativeTouch(const TouchInput &touch) {
//    if (screenManager) {
//        // Brute force prevent NaNs from getting into the UI system
//        if (my_isnan(touch.x) || my_isnan(touch.y)) {
//            return false;
//        }
//        screenManager->touch(touch);
//        return true;
//    } else {
        return false;
//    }
}

bool NativeKey(const KeyInput &key) {
//    // INFO_LOG(SYSTEM, "Key code: %i flags: %i", key.keyCode, key.flags);
//#if !defined(MOBILE_DEVICE)
//    if (g_Config.bPauseExitsEmulator) {
//        static std::vector<int> pspKeys;
//        pspKeys.clear();
//        if (KeyMap::KeyToPspButton(key.deviceId, key.keyCode, &pspKeys)) {
//            if (std::find(pspKeys.begin(), pspKeys.end(), VIRTKEY_PAUSE) != pspKeys.end()) {
//                System_SendMessage("finish", "");
//                return true;
//            }
//        }
//    }
//#endif
    bool retval = false;
//    if (screenManager)
//        retval = screenManager->key(key);
    return retval;
}

bool NativeAxis(const AxisInput &axis) {
    return false;
}

void OnScreenMessages::Show(const std::string &text, float duration_s, uint32_t color, int icon, bool checkUnique, const char *id) {}

std::string System_GetProperty(SystemProperty prop) {
    switch (prop) {
        case SYSPROP_NAME:
            return "OpenEmu:";
         case SYSPROP_LANGREGION: {
               // Get user-preferred locale from OS
               setlocale(LC_ALL, "");
               std::string locale(setlocale(LC_ALL, NULL));
               // Set c and c++ strings back to POSIX
               std::locale::global(std::locale("POSIX"));
               if (!locale.empty()) {
                   if (locale.find("_", 0) != std::string::npos) {
                       if (locale.find(".", 0) != std::string::npos) {
                           return locale.substr(0, locale.find(".",0));
                       } else {
                           return locale;
                       }
                   }
               }
               return "en_US";
           }
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

float System_GetPropertyFloat(SystemProperty prop) {
    switch (prop) {
    case SYSPROP_DISPLAY_REFRESH_RATE:
            return 59.94f;
    case SYSPROP_DISPLAY_SAFE_INSET_LEFT:
    case SYSPROP_DISPLAY_SAFE_INSET_RIGHT:
    case SYSPROP_DISPLAY_SAFE_INSET_TOP:
    case SYSPROP_DISPLAY_SAFE_INSET_BOTTOM:
        return 0.0f;
    default:
        return -1;
    }
}

bool System_GetPropertyBool(SystemProperty prop) {
    switch (prop) {
    case SYSPROP_HAS_BACK_BUTTON:
        return true;
    case SYSPROP_APP_GOLD:
#ifdef GOLD
        return true;
#else
        return false;
#endif
    default:
        return false;
    }
}

void System_SendMessage(const char *command, const char *parameter) {
    return;
}
