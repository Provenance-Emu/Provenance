// Copyright 2016 Dolphin Emulator Project
// Licensed under GPLv2+
// Refer to the license.txt file included.

#include <atomic>
#include <cstdarg>
#include <cstdlib>
#include <cstdint>
#include <iostream> // For std::cout

#include "Common/CommonFuncs.h"
#include "Common/DynamicLibrary.h"
#include "Common/FileUtil.h"
#include "Common/Logging/Log.h"
#include "Common/StringUtil.h"

#include "VideoBackends/Vulkan/VulkanLoader.h"

#define VULKAN_MODULE_ENTRY_POINT(name, required) PFN_##name name;
#define VULKAN_INSTANCE_ENTRY_POINT(name, required) PFN_##name name;
#define VULKAN_DEVICE_ENTRY_POINT(name, required) PFN_##name name;
#include "VideoBackends/Vulkan/VulkanEntryPoints.inl"
#undef VULKAN_DEVICE_ENTRY_POINT
#undef VULKAN_INSTANCE_ENTRY_POINT
#undef VULKAN_MODULE_ENTRY_POINT

namespace Vulkan
{
static void ResetVulkanLibraryFunctionPointers()
{
#define VULKAN_MODULE_ENTRY_POINT(name, required) name = nullptr;
#define VULKAN_INSTANCE_ENTRY_POINT(name, required) name = nullptr;
#define VULKAN_DEVICE_ENTRY_POINT(name, required) name = nullptr;
#include "VideoBackends/Vulkan/VulkanEntryPoints.inl"
#undef VULKAN_DEVICE_ENTRY_POINT
#undef VULKAN_INSTANCE_ENTRY_POINT
#undef VULKAN_MODULE_ENTRY_POINT
}

static Common::DynamicLibrary s_vulkan_module;

static bool OpenVulkanLibrary()
{
#ifdef __APPLE__
  // Check if a path to a specific Vulkan library has been specified.
  char* libvulkan_env = getenv("LIBVULKAN_PATH");
  if (libvulkan_env && s_vulkan_module.Open(libvulkan_env))
    return true;

  // Use the libvulkan.dylib from the application bundle.
    const std::vector<std::string> vulkanPaths = {
        File::GetBundleDirectory() + "/Frameworks/libMoltenVK_Dolphin.dylib",
        File::GetBundleDirectory() + "/Frameworks/libMoltenVK.dylib",
        File::GetBundleDirectory() + "/Frameworks/MoltenVK-1.2.8.framework/MoltenVK",
        File::GetBundleDirectory() + "/Frameworks/MoltenVK-1.2.8.framework/MoltenVK-1.2.8",
        File::GetBundleDirectory() + "/Frameworks/MoltenVK.framework/MoltenVK",
        "@executable_path/Frameworks/MoltenVK-1.2.8.framework/MoltenVK",
        "@executable_path/Frameworks/MoltenVK-1.2.8.framework/MoltenVK-1.2.8",
        "@executable_path/Frameworks/MoltenVK.framework/MoltenVK"
    };

    for (const auto& path : vulkanPaths)
    {
        std::cout << "Attempting to load Vulkan library from: " << path << std::endl;
        GENERIC_LOG_FMT(Common::Log::LogType::VIDEO, Common::Log::LogLevel::LINFO, "{}", "Attempting to load Vulkan library from: " + path);

        if (s_vulkan_module.Open(path.c_str()))
        {
            std::cout << "Successfully loaded Vulkan library from: " << path << std::endl;
            GENERIC_LOG_FMT(Common::Log::LogType::VIDEO, Common::Log::LogLevel::LINFO, "{}", "Successfully loaded Vulkan library from: from: " + path);

            return true;
        }
        else
        {
            std::cout << "Failed to load Vulkan library from: " << path << std::endl;
            GENERIC_LOG_FMT(Common::Log::LogType::VIDEO, Common::Log::LogLevel::LINFO, "{}", "Failed to load Vulkan library from: from: " + path);
        }
    }

    std::cout << "Failed to load Vulkan library from any of the specified paths." << std::endl;
    return false;
#else
  std::string filename = Common::DynamicLibrary::GetVersionedFilename("vulkan", 1);
  if (s_vulkan_module.Open(filename.c_str()))
    return true;

  // Android devices may not have libvulkan.so.1, only libvulkan.so.
  filename = Common::DynamicLibrary::GetVersionedFilename("vulkan");
  return s_vulkan_module.Open(filename.c_str());
#endif
}

bool LoadVulkanLibrary()
{
  if (!s_vulkan_module.IsOpen() && !OpenVulkanLibrary())
    return false;

#define VULKAN_MODULE_ENTRY_POINT(name, required)                                                  \
  if (!s_vulkan_module.GetSymbol(#name, &name) && required)                                        \
  {                                                                                                \
    ERROR_LOG_FMT(VIDEO, "Vulkan: Failed to load required module function {}", #name);             \
    ResetVulkanLibraryFunctionPointers();                                                          \
    s_vulkan_module.Close();                                                                       \
    return false;                                                                                  \
  }
#include "VideoBackends/Vulkan/VulkanEntryPoints.inl"
#undef VULKAN_MODULE_ENTRY_POINT

  return true;
}

void UnloadVulkanLibrary()
{
  s_vulkan_module.Close();
  if (!s_vulkan_module.IsOpen())
    ResetVulkanLibraryFunctionPointers();
}

bool LoadVulkanInstanceFunctions(VkInstance instance)
{
  bool required_functions_missing = false;
  auto LoadFunction = [&](PFN_vkVoidFunction* func_ptr, const char* name, bool is_required) {
    *func_ptr = vkGetInstanceProcAddr(instance, name);
    if (!(*func_ptr) && is_required)
    {
      ERROR_LOG_FMT(VIDEO, "Vulkan: Failed to load required instance function {}", name);
      required_functions_missing = true;
    }
  };

#define VULKAN_INSTANCE_ENTRY_POINT(name, required)                                                \
  LoadFunction(reinterpret_cast<PFN_vkVoidFunction*>(&name), #name, required);
#include "VideoBackends/Vulkan/VulkanEntryPoints.inl"
#undef VULKAN_INSTANCE_ENTRY_POINT

  return !required_functions_missing;
}

bool LoadVulkanDeviceFunctions(VkDevice device)
{
  bool required_functions_missing = false;
  auto LoadFunction = [&](PFN_vkVoidFunction* func_ptr, const char* name, bool is_required) {
    *func_ptr = vkGetDeviceProcAddr(device, name);
    if (!(*func_ptr) && is_required)
    {
      ERROR_LOG_FMT(VIDEO, "Vulkan: Failed to load required device function {}", name);
      required_functions_missing = true;
    }
  };

#define VULKAN_DEVICE_ENTRY_POINT(name, required)                                                  \
  LoadFunction(reinterpret_cast<PFN_vkVoidFunction*>(&name), #name, required);
#include "VideoBackends/Vulkan/VulkanEntryPoints.inl"
#undef VULKAN_DEVICE_ENTRY_POINT

  return !required_functions_missing;
}

const char* VkResultToString(VkResult res)
{
  switch (res)
  {
  case VK_SUCCESS:
    return "VK_SUCCESS";

  case VK_NOT_READY:
    return "VK_NOT_READY";

  case VK_TIMEOUT:
    return "VK_TIMEOUT";

  case VK_EVENT_SET:
    return "VK_EVENT_SET";

  case VK_EVENT_RESET:
    return "VK_EVENT_RESET";

  case VK_INCOMPLETE:
    return "VK_INCOMPLETE";

  case VK_ERROR_OUT_OF_HOST_MEMORY:
    return "VK_ERROR_OUT_OF_HOST_MEMORY";

  case VK_ERROR_OUT_OF_DEVICE_MEMORY:
    return "VK_ERROR_OUT_OF_DEVICE_MEMORY";

  case VK_ERROR_INITIALIZATION_FAILED:
    return "VK_ERROR_INITIALIZATION_FAILED";

  case VK_ERROR_DEVICE_LOST:
    return "VK_ERROR_DEVICE_LOST";

  case VK_ERROR_MEMORY_MAP_FAILED:
    return "VK_ERROR_MEMORY_MAP_FAILED";

  case VK_ERROR_LAYER_NOT_PRESENT:
    return "VK_ERROR_LAYER_NOT_PRESENT";

  case VK_ERROR_EXTENSION_NOT_PRESENT:
    return "VK_ERROR_EXTENSION_NOT_PRESENT";

  case VK_ERROR_FEATURE_NOT_PRESENT:
    return "VK_ERROR_FEATURE_NOT_PRESENT";

  case VK_ERROR_INCOMPATIBLE_DRIVER:
    return "VK_ERROR_INCOMPATIBLE_DRIVER";

  case VK_ERROR_TOO_MANY_OBJECTS:
    return "VK_ERROR_TOO_MANY_OBJECTS";

  case VK_ERROR_FORMAT_NOT_SUPPORTED:
    return "VK_ERROR_FORMAT_NOT_SUPPORTED";

  case VK_ERROR_SURFACE_LOST_KHR:
    return "VK_ERROR_SURFACE_LOST_KHR";

  case VK_ERROR_NATIVE_WINDOW_IN_USE_KHR:
    return "VK_ERROR_NATIVE_WINDOW_IN_USE_KHR";

  case VK_SUBOPTIMAL_KHR:
    return "VK_SUBOPTIMAL_KHR";

  case VK_ERROR_OUT_OF_DATE_KHR:
    return "VK_ERROR_OUT_OF_DATE_KHR";

  case VK_ERROR_INCOMPATIBLE_DISPLAY_KHR:
    return "VK_ERROR_INCOMPATIBLE_DISPLAY_KHR";

  case VK_ERROR_VALIDATION_FAILED_EXT:
    return "VK_ERROR_VALIDATION_FAILED_EXT";

  case VK_ERROR_INVALID_SHADER_NV:
    return "VK_ERROR_INVALID_SHADER_NV";

  default:
    return "UNKNOWN_VK_RESULT";
  }
}

void LogVulkanResult(int level, const char* func_name, VkResult res, const char* msg, ...)
{
  std::va_list ap;
  va_start(ap, msg);
  std::string real_msg = StringFromFormatV(msg, ap);
  va_end(ap);

  real_msg = fmt::format("({}) {} ({}: {})", func_name, real_msg, static_cast<int>(res),
                         VkResultToString(res));

  GENERIC_LOG_FMT(Common::Log::LogType::VIDEO, static_cast<Common::Log::LogLevel>(level), "{}", real_msg);
}

}  // namespace Vulkan
