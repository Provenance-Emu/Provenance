// Copyright 2012 Dolphin Emulator Project
// Licensed under GPLv2+
// Refer to the license.txt file included.
#include "DolphinGameCore.h"
#include "Core/ConfigManager.h"
#include <OpenGL/gl3.h>

#include "Common/GL/GLInterface/AGL.h"
#include "Common/Logging/Log.h"

static bool UpdateCachedDimensions(NSView* view, u32* width, u32* height)
{
    return true;
}

static bool AttachContextToView(NSOpenGLContext* context, NSView* view, u32* width, u32* height)
{
    return true;
}

GLContextAGL::~GLContextAGL()
{
}

bool GLContextAGL::IsHeadless() const
{
    return false;
}

void GLContextAGL::Swap()
{
    [_current.renderDelegate didRenderFrameOnAlternateThread];
}

// Create rendering window.
// Call browser: Core.cpp:EmuThread() > main.cpp:Video_Initialize()
bool GLContextAGL::Initialize(const WindowSystemInfo& wsi, bool stereo, bool core)
{
    MakeCurrent();
        // Control window size and picture scaling
        if(SConfig::GetInstance().bWii) {
            m_backbuffer_width = 854;
            m_backbuffer_height = 480;
        } else {
            m_backbuffer_width = 640;
            m_backbuffer_height = 480;
        }
        return true;
   
}

std::unique_ptr<GLContext> GLContextAGL::CreateSharedContext()
{
    return nullptr;
}

bool GLContextAGL::MakeCurrent()
{
    [_current.renderDelegate willRenderFrameOnAlternateThread];
    
    // Set the background color of the context to black
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    Swap();

    return true;
}

bool GLContextAGL::ClearCurrent()
{
    return true;
}

void GLContextAGL::Update()
{
    if(SConfig::GetInstance().bWii) {
        m_backbuffer_width = 854;
        m_backbuffer_height = 480;
    } else {
        m_backbuffer_width = 640;
        m_backbuffer_height = 480;
    }
    return;
}

void GLContextAGL::SwapInterval(int interval)
{
}
