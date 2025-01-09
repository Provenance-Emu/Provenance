#import <cassert>
#import "CGSH_VulkaniOS.h"
#import "vulkan/Loader.h"
#import <QuartzCore/QuartzCore.h>
#import "GSH_VulkanPlatformDefs.h"

CGSH_VulkaniOS::CGSH_VulkaniOS(CAMetalLayer* layer)
    : m_layer(layer)
{
}

CGSHandler::FactoryFunction CGSH_VulkaniOS::GetFactoryFunction(CAMetalLayer* layer)
{
	return [layer]() { return new CGSH_VulkaniOS(layer); };
}

void CGSH_VulkaniOS::InitializeImpl()
{
	m_instance = CreateInstance(true);

	VkIOSSurfaceCreateInfoMVK surfaceCreateInfo = {};
	surfaceCreateInfo.pView = (__bridge void*)m_layer;
	auto result = m_instance.vkCreateIOSSurfaceMVK(m_instance, &surfaceCreateInfo, nullptr, &m_context->surface);
	CHECKVULKANERROR(result);

	CGSH_Vulkan::InitializeImpl();

	{
		CGSize drawableSize = m_layer.drawableSize;

		PRESENTATION_PARAMS presentationParams;
		presentationParams.mode = PRESENTATION_MODE_FILL;
		presentationParams.windowWidth = drawableSize.width;
		presentationParams.windowHeight = drawableSize.height;

		SetPresentationParams(presentationParams);
	}
}

void MakeCurrentThreadRealTime();
void CGSH_VulkaniOS::PresentBackbuffer()
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        MakeCurrentThreadRealTime();
        [[NSThread currentThread] setName:@"Play.Vulkan"];
        [[NSThread currentThread] setQualityOfService:NSQualityOfServiceUserInteractive];
    });
}
