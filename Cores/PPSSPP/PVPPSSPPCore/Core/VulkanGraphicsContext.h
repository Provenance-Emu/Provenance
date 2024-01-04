//
//  VulkanGraphicsContext.h
//  PVPPSSPP
//  Copyright (c) 2012- PPSSPP Project.
//

#import "PVPPSSPPCore.h"
#import "PVPPSSPPCore+Controls.h"
#import "PVPPSSPPCore+Audio.h"
#import "PVPPSSPPCore+Video.h"
#import <PVPPSSPP/PVPPSSPP-Swift.h>
#import <Foundation/Foundation.h>
#import <PVSupport/PVSupport.h>
#import <PVLogging/PVLogging.h>

/* PPSSPP Includes */
#include <vector>
#include <string>
#include <cstring>

#include "Common/System/Display.h"
#include "Common/System/NativeApp.h"
#include "Common/System/System.h"
#include "Common/GPU/Vulkan/VulkanContext.h"
#include "Common/GPU/Vulkan/VulkanDebug.h"
#include "Common/GPU/Vulkan/VulkanLoader.h"
#include "Common/GPU/Vulkan/VulkanRenderManager.h"
#include "Common/GPU/thin3d.h"
#include "Common/GPU/thin3d_create.h"
#include "Common/Data/Text/Parsers.h"
#include "Common/VR/PPSSPPVR.h"
#include "Common/Log.h"
#include "Core/Config.h"
#include "Core/ConfigValues.h"
#include "Core/System.h"
#if !PPSSPP_PLATFORM(WINDOWS) && !PPSSPP_PLATFORM(SWITCH)
#include <dlfcn.h>
#endif

#ifndef VulkanGraphicsContext_h
#define VulkanGraphicsContext_h

typedef void *VulkanLibraryHandle;
static VulkanLibraryHandle vulkanLibrary;
#define LOAD_GLOBAL_FUNC(x) x = (PFN_ ## x)dlsym(vulkanLibrary, #x); if (!x) { NSLog(@"Missing (global): %s", #x);}

class VulkanGraphicsContext : public GraphicsContext {
public:
	VulkanGraphicsContext() {
	}

	~VulkanGraphicsContext() {
        //delete g_Vulkan;
        g_Vulkan = nullptr;
	}

	VulkanGraphicsContext(CAMetalLayer* layer, const char* vulkan_path) {
		bool success = false;
		NSLog(@"VulkanGraphicsContext: Init");
		init_glslang();
		NSLog(@"VulkanGraphicsContext: Creating Vulkan context");
		Version gitVer(PPSSPP_GIT_VERSION);
		if (!this->VulkanLoad(vulkan_path)) {
			NSLog(@"VulkanGraphicsContext: Failed to load Vulkan driver library");
			return;
		}
		if (!g_Vulkan) {
			g_Vulkan = new VulkanContext();
		}
		VulkanContext::CreateInfo info{};
		info.app_name = "PPSSPP";
		info.app_ver = gitVer.ToInteger();
		info.flags = this->flags;
		VkResult res = g_Vulkan->CreateInstance(info);
		if (res != VK_SUCCESS) {
			NSLog(@"VulkanGraphicsContext: Failed to create vulkan context: %s", g_Vulkan->InitError().c_str());
			VulkanSetAvailable(false);
			delete g_Vulkan;
			g_Vulkan = nullptr;
			return;
		}
		int physicalDevice = g_Vulkan->GetBestPhysicalDevice();
		if (physicalDevice < 0) {
			NSLog(@"VulkanGraphicsContext: No usable Vulkan device found.");
			g_Vulkan->DestroyInstance();
			delete g_Vulkan;
			g_Vulkan = nullptr;
			return;
		}
		g_Vulkan->ChooseDevice(physicalDevice);
		NSLog(@"VulkanGraphicsContext: Creating Vulkan device");
		if (g_Vulkan->CreateDevice() != VK_SUCCESS) {
			NSLog(@"VulkanGraphicsContext: Failed to create vulkan device: %s", g_Vulkan->InitError().c_str());
			g_Vulkan->DestroyInstance();
			delete g_Vulkan;
			g_Vulkan = nullptr;
			return;
		}
		NSLog(@"VulkanGraphicsContext: Vulkan device created!");
		g_Config.iGPUBackend = (int)GPUBackend::VULKAN;
		SetGPUBackend(GPUBackend::VULKAN);
		if (!g_Vulkan) {
			NSLog(@"VulkanGraphicsContext: InitFromRenderThread: No Vulkan context");
			return;
		}
		res = g_Vulkan->InitSurface(WINDOWSYSTEM_METAL_EXT, (__bridge void *)layer, nullptr);
		if (res != VK_SUCCESS) {
			NSLog(@"VulkanGraphicsContext: g_Vulkan->InitSurface failed: '%s'", VulkanResultToString(res));
			return;
		}
		if (g_Vulkan->InitSwapchain()) {
			draw_ = Draw::T3DCreateVulkanContext(g_Vulkan);
			SetGPUBackend(GPUBackend::VULKAN);
			success = draw_->CreatePresets();  // Doesn't fail, we ship the compiler.
			_assert_msg_(success, "VulkanGraphicsContext: Failed to compile preset shaders");
			draw_->HandleEvent(Draw::Event::GOT_BACKBUFFER, g_Vulkan->GetBackbufferWidth(), g_Vulkan->GetBackbufferHeight());
			VulkanRenderManager *renderManager = (VulkanRenderManager *)draw_->GetNativeObject(Draw::NativeObject::RENDER_MANAGER);
			renderManager->SetInflightFrames(g_Config.iInflightFrames);
			success = renderManager->HasBackbuffers();
		} else {
			success = false;
		}
		NSLog(@"VulkanGraphicsContext: Vulkan Init completed, %s", success ? "successfully" : "but failed");
		if (!success) {
			g_Vulkan->DestroySwapchain();
			g_Vulkan->DestroySurface();
			g_Vulkan->DestroyDevice();
			g_Vulkan->DestroyInstance();
		}
	}

	Draw::DrawContext *GetDrawContext() override {
		return draw_;
	}

	void Shutdown() override {
        NSLog(@"VulkanGraphicsContext: Shutdown");
        draw_->HandleEvent(Draw::Event::LOST_BACKBUFFER, g_Vulkan->GetBackbufferWidth(), g_Vulkan->GetBackbufferHeight());
        delete draw_;
        draw_ = nullptr;
        g_Vulkan->WaitUntilQueueIdle();
        g_Vulkan->PerformPendingDeletes();
        g_Vulkan->DestroySwapchain();
        g_Vulkan->DestroySurface();
        NSLog(@"VulkanGraphicsContext: Done with ShutdownFromRenderThread");
		NSLog(@"VulkanGraphicsContext: Calling NativeShutdownGraphics");
		g_Vulkan->DestroyDevice();
		g_Vulkan->DestroyInstance();
		// We keep the g_Vulkan context around to avoid invalidating a ton of pointers around the app.
		finalize_glslang();
		NSLog(@"VulkanGraphicsContext: Shutdown completed");
	}

	void SwapBuffers() override {
	}

	void Resize() override {
		NSLog(@"VulkanGraphicsContext: Resize begin (oldsize: %dx%d)", g_Vulkan->GetBackbufferWidth(), g_Vulkan->GetBackbufferHeight());
		draw_->HandleEvent(Draw::Event::LOST_BACKBUFFER, g_Vulkan->GetBackbufferWidth(), g_Vulkan->GetBackbufferHeight());
		g_Vulkan->DestroySwapchain();
		g_Vulkan->DestroySurface();
		g_Vulkan->UpdateFlags(this->flags);
		g_Vulkan->ReinitSurface();
		g_Vulkan->InitSwapchain();
		draw_->HandleEvent(Draw::Event::GOT_BACKBUFFER, g_Vulkan->GetBackbufferWidth(), g_Vulkan->GetBackbufferHeight());
		NSLog(@"VulkanGraphicsContext: Resize end (final size: %dx%d)", g_Vulkan->GetBackbufferWidth(), g_Vulkan->GetBackbufferHeight());
	}

	void SwapInterval(int interval) override {
	}

	void *GetAPIContext() override {
		return g_Vulkan;
	}

	bool Initialized() {
		return draw_ != nullptr;
	}
    
    bool VulkanLoad(const char* path) {
        void *lib = dlopen(path, RTLD_NOW | RTLD_LOCAL);
        if (lib) {
            NSLog(@"VulkanGraphicsContext: %s: Library loaded\n", path);
        } else {
            NSLog(@"VulkanGraphicsContext: Failed path %s: Library not loaded\n", path);
        }
        vulkanLibrary = lib;
        LOAD_GLOBAL_FUNC(vkCreateInstance);
        LOAD_GLOBAL_FUNC(vkGetInstanceProcAddr);
        LOAD_GLOBAL_FUNC(vkGetDeviceProcAddr);
        LOAD_GLOBAL_FUNC(vkEnumerateInstanceVersion);
        LOAD_GLOBAL_FUNC(vkEnumerateInstanceExtensionProperties);
        LOAD_GLOBAL_FUNC(vkEnumerateInstanceLayerProperties);
        if (vkCreateInstance && vkGetInstanceProcAddr && vkGetDeviceProcAddr && vkEnumerateInstanceExtensionProperties && vkEnumerateInstanceLayerProperties) {
            NSLog(@"VulkanGraphicsContext: VulkanLoad: Base functions loaded.");
            return true;
        } else {
            NSLog(@"VulkanGraphicsContext: VulkanLoad: Failed to load Vulkan base functions.");
            return false;
        }
    }
private:
	VulkanContext *g_Vulkan = nullptr;
	Draw::DrawContext *draw_ = nullptr;
	uint32_t flags = VULKAN_FLAG_PRESENT_MAILBOX | VULKAN_FLAG_PRESENT_FIFO_RELAXED;
};
#endif /* VulkanGraphicsContext_h */
