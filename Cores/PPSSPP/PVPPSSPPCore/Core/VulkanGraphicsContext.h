//
//  VulkanGraphicsContext.h
//  PVPPSSPP
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

#ifndef VulkanGraphicsContext_h
#define VulkanGraphicsContext_h

class VulkanGraphicsContext : public GraphicsContext {
public:
	VulkanGraphicsContext() {
		CheckGLExtensions();
		draw_ = Draw::T3DCreateGLContext();
		renderManager_ = (GLRenderManager *)draw_->GetNativeObject(Draw::NativeObject::RENDER_MANAGER);
		renderManager_->SetInflightFrames(g_Config.iInflightFrames);
		SetGPUBackend(GPUBackend::OPENGL);
		g_Config.iGPUBackend = (int)GPUBackend::OPENGL;
		bool success = draw_->CreatePresets();
		_assert_msg_(success, "Failed to compile preset shaders");
	}
	~VulkanGraphicsContext() {
		delete draw_;
	}
	Draw::DrawContext *GetDrawContext() override {
		return draw_;
	}

	void SwapInterval(int interval) override {}
	void SwapBuffers() override {}
	void Resize() override {}
	void Shutdown() override {}

	void ThreadStart() override {
		renderManager_->ThreadStart(draw_);
	}

	bool ThreadFrame() override {
		return renderManager_->ThreadFrame();
	}

	void ThreadEnd() override {
		renderManager_->ThreadEnd();
	}

	void StopThread() override {
		renderManager_->WaitUntilQueueIdle();
		renderManager_->StopThread();
	}

private:
	Draw::DrawContext *draw_;
	GLRenderManager *renderManager_;
};
#endif /* VulkanGraphicsContext_h */
