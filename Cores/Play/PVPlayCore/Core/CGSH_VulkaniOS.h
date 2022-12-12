#import <QuartzCore/QuartzCore.h>
#import "../gs/GSH_Vulkan/GSH_Vulkan.h"

class CGSH_VulkaniOS : public CGSH_Vulkan
{
public:
	CGSH_VulkaniOS(CAMetalLayer*);
	virtual ~CGSH_VulkaniOS() = default;

	static FactoryFunction GetFactoryFunction(CAMetalLayer*);

	void InitializeImpl() override;
	void PresentBackbuffer() override;

private:
	CAMetalLayer* m_layer = nullptr;
	void CreateFramebuffer();
};
