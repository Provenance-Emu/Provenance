#ifdef _WIN32
#include <Windows.h>
#include <tchar.h>
#else
#include <vector>
#include <dlfcn.h>
#endif
#include <stdexcept>
#include <cassert>
#include "vulkan/Loader.h"
#include "string_format.h"

using namespace Framework::Vulkan;

CLoader::CLoader()
{
	LoadLibrary();
}

void* CLoader::GetLibraryProcAddr(const char* procName)
{
#ifdef _WIN32
	return nullptr;
#else
	return dlsym(m_vulkanDl, procName);
#endif
}

void CLoader::LoadLibrary()
{
#ifdef _WIN32
	assert(m_vulkanModule == NULL);

	m_vulkanModule = ::LoadLibrary(_T("vulkan-1.dll"));
	if(m_vulkanModule == NULL)
	{
		throw std::runtime_error("Failed to load Vulkan library.");
	}

	vkCreateInstance      = reinterpret_cast<PFN_vkCreateInstance>(GetProcAddress(m_vulkanModule, "vkCreateInstance"));
	vkGetInstanceProcAddr = reinterpret_cast<PFN_vkGetInstanceProcAddr>(GetProcAddress(m_vulkanModule, "vkGetInstanceProcAddr"));
#else
	assert(m_vulkanDl == nullptr);
	
	std::vector<const char*> libPaths;
#ifdef __APPLE__
    libPaths.push_back("@executable_path/Frameworks/libMoltenVK_Play.dylib");
#else
	libPaths.push_back("libvulkan.so");
	libPaths.push_back("libvulkan.so.1");
#endif
	
	for(const auto& libPath : libPaths)
	{
		m_vulkanDl = dlopen(libPath, RTLD_NOW | RTLD_LOCAL);
		if(m_vulkanDl)
		{
			break;
		}
		printf("Warning: Failed attempt to load Vulkan library from '%s': %s.\n", libPath, dlerror());
	}

	if(!m_vulkanDl)
	{
		throw std::runtime_error("Failed to find an appropriate Vulkan library to load.");
	}
	
	vkCreateInstance      = reinterpret_cast<PFN_vkCreateInstance>(dlsym(m_vulkanDl, "vkCreateInstance"));
	vkGetInstanceProcAddr = reinterpret_cast<PFN_vkGetInstanceProcAddr>(dlsym(m_vulkanDl, "vkGetInstanceProcAddr"));
#endif
}
