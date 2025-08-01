// Copyright 2023 Citra Emulator Project
// Licensed under GPLv2 or any later version
// Refer to the license.txt file included.

// Include the vulkan platform specific header

// Local Changes: Local Vulkan name

#if defined(ANDROID) || defined(__ANDROID__)
#define VK_USE_PLATFORM_ANDROID_KHR
#elif defined(_WIN32)
#define VK_USE_PLATFORM_WIN32_KHR
#elif defined(__APPLE__)
#define VK_USE_PLATFORM_METAL_EXT
#else
#define VK_USE_PLATFORM_WAYLAND_KHR
#define VK_USE_PLATFORM_XLIB_KHR
#endif

#define VULKAN_HPP_NO_CONSTRUCTORS
#include <memory>
#include <vector>
#include <boost/container/static_vector.hpp>
#include <fmt/format.h>

#include "common/assert.h"
#include "common/logging/log.h"
#include "common/settings.h"
#include "core/frontend/emu_window.h"
#include "video_core/renderer_vulkan/vk_platform.h"

namespace Vulkan {

vk::DynamicLoader& GetVulkanLoader() {
    static vk::DynamicLoader dl("@executable_path/Frameworks/MoltenVK.framework/MoltenVK");
    return dl;
}

std::shared_ptr<Common::DynamicLibrary> OpenLibrary(
    [[maybe_unused]] Frontend::GraphicsContext* context) {
#ifdef ANDROID
    // Android may override the Vulkan driver from the frontend.
    if (auto library = context->GetDriverLibrary(); library) {
        return library;
    }
#endif
    auto library = std::make_shared<Common::DynamicLibrary>();
#ifdef __APPLE__
    const std::string filename = Common::DynamicLibrary::GetLibraryName("vulkan");
    if (!library->Load(filename)) {
        // Fall back to directly loading bundled MoltenVK library.
        const std::string mvk_filename = "@rpath/MoltenVK.framework/MoltenVK";
        void(library->Load(mvk_filename));
    }
#else
    std::string filename = Common::DynamicLibrary::GetLibraryName("vulkan", 1);
    LOG_DEBUG(Render_Vulkan, "Trying Vulkan library: {}", filename);
    if (!library->Load(filename)) {
        // Android devices may not have libvulkan.so.1, only libvulkan.so.
        filename = Common::DynamicLibrary::GetLibraryName("vulkan");
        LOG_DEBUG(Render_Vulkan, "Trying Vulkan library (second attempt): {}", filename);
        void(library->Load(filename));
    }
#endif
    return library;
}

vk::SurfaceKHR CreateSurface(vk::Instance instance, const Frontend::EmuWindow& emu_window) {
    const auto& window_info = emu_window.GetWindowInfo();
    vk::SurfaceKHR surface{};

    const vk::MetalSurfaceCreateInfoEXT macos_ci = {
        .pLayer = static_cast<const CAMetalLayer*>(window_info.render_surface)};

    if (instance.createMetalSurfaceEXT(&macos_ci, nullptr, &surface) != vk::Result::eSuccess) {
        LOG_CRITICAL(Render_Vulkan, "Failed to initialize MacOS surface");
        UNREACHABLE();
    }

    if (!surface) {
        LOG_CRITICAL(Render_Vulkan, "Presentation not supported on this platform");
        UNREACHABLE();
    }

    return surface;
}

std::vector<const char*> GetInstanceExtensions(Frontend::WindowSystemType window_type,
                                               bool enable_debug_utils) {
    const auto properties = vk::enumerateInstanceExtensionProperties();
    if (properties.empty()) {
        LOG_ERROR(Render_Vulkan, "Failed to query extension properties");
        return std::vector<const char*>{};
    }

    // Add the windowing system specific extension
    std::vector<const char*> extensions;
    extensions.reserve(6);

#if defined(__APPLE__)
    extensions.push_back(VK_KHR_PORTABILITY_ENUMERATION_EXTENSION_NAME);
    // For configuring MoltenVK.
    // FIXME: @JoeMatt this isn't working yet
//    extensions.push_back(VK_EXT_LAYER_SETTINGS_EXTENSION_NAME);
#endif

    switch (window_type) {
    case Frontend::WindowSystemType::Headless:
        break;
#if defined(VK_USE_PLATFORM_WIN32_KHR)
    case Frontend::WindowSystemType::Windows:
        extensions.push_back(VK_KHR_WIN32_SURFACE_EXTENSION_NAME);
        break;
#elif defined(VK_USE_PLATFORM_XLIB_KHR) || defined(VK_USE_PLATFORM_WAYLAND_KHR)
    case Frontend::WindowSystemType::X11:
        extensions.push_back(VK_KHR_XLIB_SURFACE_EXTENSION_NAME);
        break;
    case Frontend::WindowSystemType::Wayland:
        extensions.push_back(VK_KHR_WAYLAND_SURFACE_EXTENSION_NAME);
        break;
#elif defined(VK_USE_PLATFORM_METAL_EXT)
    case Frontend::WindowSystemType::MacOS:
        extensions.push_back(VK_EXT_METAL_SURFACE_EXTENSION_NAME);
        break;
#elif defined(VK_USE_PLATFORM_ANDROID_KHR)
    case Frontend::WindowSystemType::Android:
        extensions.push_back(VK_KHR_ANDROID_SURFACE_EXTENSION_NAME);
        break;
#endif
    default:
        LOG_ERROR(Render_Vulkan, "Presentation not supported on this platform");
        break;
    }

    if (window_type != Frontend::WindowSystemType::Headless) {
        extensions.push_back(VK_KHR_SURFACE_EXTENSION_NAME);
    }

    if (enable_debug_utils) {
        extensions.push_back(VK_EXT_DEBUG_UTILS_EXTENSION_NAME);
        extensions.push_back(VK_EXT_DEBUG_REPORT_EXTENSION_NAME);
    }

    // Sanitize extension list
    std::erase_if(extensions, [&](const char* extension) -> bool {
        const auto it =
            std::find_if(properties.begin(), properties.end(), [extension](const auto& prop) {
                return std::strcmp(extension, prop.extensionName) == 0;
            });

        if (it == properties.end()) {
            LOG_INFO(Render_Vulkan, "Candidate instance extension {} is not available", extension);
            return true;
        }
        return false;
    });

    return extensions;
}

void LoadInstanceFunctions(vk::Instance instance) {
    // Perform instance function loading here, to also load window system functions
    VULKAN_HPP_DEFAULT_DISPATCHER.init(instance);
}

vk::InstanceCreateFlags GetInstanceFlags() {
#if defined(__APPLE__)
    return vk::InstanceCreateFlagBits::eEnumeratePortabilityKHR;
#else
    return static_cast<vk::InstanceCreateFlags>(0);
#endif
}
//
vk::UniqueInstance CreateInstance(const Common::DynamicLibrary& library,
                                  Frontend::WindowSystemType window_type, bool enable_validation,
                                  bool dump_command_buffers) {
    if (!library.IsLoaded()) {
        throw std::runtime_error("Failed to load Vulkan driver library");
    }

    const auto vkGetInstanceProcAddr =
        library.GetSymbol<PFN_vkGetInstanceProcAddr>("vkGetInstanceProcAddr");
    if (!vkGetInstanceProcAddr) {
        throw std::runtime_error("Failed GetSymbol vkGetInstanceProcAddr");
    }
    VULKAN_HPP_DEFAULT_DISPATCHER.init(vkGetInstanceProcAddr);

    const u32 available_version = VULKAN_HPP_DEFAULT_DISPATCHER.vkEnumerateInstanceVersion
                                      ? vk::enumerateInstanceVersion()
                                      : VK_API_VERSION_1_0;
    if (available_version < TargetVulkanApiVersion) {
        throw std::runtime_error(fmt::format(
            "Vulkan {}.{} is required, but only {}.{} is supported by instance!",
            VK_VERSION_MAJOR(TargetVulkanApiVersion), VK_VERSION_MINOR(TargetVulkanApiVersion),
            VK_VERSION_MAJOR(available_version), VK_VERSION_MINOR(available_version)));
    }

    const auto extensions = GetInstanceExtensions(window_type, enable_validation);

    const vk::ApplicationInfo application_info = {
        .pApplicationName = "Citra",
        .applicationVersion = VK_MAKE_VERSION(1, 0, 0),
        .pEngineName = "Citra Vulkan",
        .engineVersion = VK_MAKE_VERSION(1, 0, 0),
        .apiVersion = TargetVulkanApiVersion,
    };

    boost::container::static_vector<const char*, 2> layers;
    if (enable_validation) {
        layers.push_back("VK_LAYER_KHRONOS_validation");
    }
    if (dump_command_buffers) {
        layers.push_back("VK_LAYER_LUNARG_api_dump");
    }

    vk::InstanceCreateInfo instance_ci = {
        .flags = GetInstanceFlags(),
        .pApplicationInfo = &application_info,
        .enabledLayerCount = static_cast<u32>(layers.size()),
        .ppEnabledLayerNames = layers.data(),
        .enabledExtensionCount = static_cast<u32>(extensions.size()),
        .ppEnabledExtensionNames = extensions.data(),
    };

    // Configure MoltenVK using environment variables for proper iOS operation
#ifdef __APPLE__
    LOG_INFO(Render_Vulkan, "Configuring MoltenVK for iOS/ARM optimization");
    
    // Enable synchronous queue submits for better presentation timing
    setenv("MVK_CONFIG_SYNCHRONOUS_QUEUE_SUBMITS", "1", 1);
    
    // Enable device recovery for better stability
    setenv("MVK_CONFIG_RESUME_LOST_DEVICE", "1", 1);
    
    // Enable concurrent shader compilation for better performance
    setenv("MVK_CONFIG_SHOULD_MAXIMIZE_CONCURRENT_COMPILATION", "1", 1);
    
    // Additional MoltenVK 1.2.11 specific optimizations
    setenv("MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS", "1", 1);
    setenv("MVK_CONFIG_FORCE_LOW_POWER_GPU", "0", 1);  // Use high-performance GPU
    setenv("MVK_CONFIG_FULL_IMAGE_VIEW_SWIZZLE", "1", 1);
    
    // Disable Metal validation to work around descriptor set binding issues
    // This addresses the "missing buffer binding at index 0" Metal validation error
    setenv("MVK_CONFIG_API_VERSION_TO_ADVERTISE", "1.1.0", 1);
    setenv("MVK_CONFIG_DEBUG", "0", 1);
    
    LOG_INFO(Render_Vulkan, "MoltenVK configuration applied for iOS/ARM optimization");
#endif

    auto instance = vk::createInstanceUnique(instance_ci);

    VULKAN_HPP_DEFAULT_DISPATCHER.init(*instance);

    return instance;
}

vk::UniqueDebugUtilsMessengerEXT CreateDebugMessenger(vk::Instance instance) {
    vk::DebugUtilsMessengerCreateInfoEXT msg_ci = {
        .messageSeverity = vk::DebugUtilsMessageSeverityFlagBitsEXT::eInfo |
                           vk::DebugUtilsMessageSeverityFlagBitsEXT::eError |
                           vk::DebugUtilsMessageSeverityFlagBitsEXT::eWarning |
                           vk::DebugUtilsMessageSeverityFlagBitsEXT::eVerbose,
        .messageType = vk::DebugUtilsMessageTypeFlagBitsEXT::eGeneral |
                       vk::DebugUtilsMessageTypeFlagBitsEXT::eValidation |
                       vk::DebugUtilsMessageTypeFlagBitsEXT::eDeviceAddressBinding |
                       vk::DebugUtilsMessageTypeFlagBitsEXT::ePerformance,
        .pfnUserCallback = [](VkDebugUtilsMessageSeverityFlagBitsEXT severity,
                              VkDebugUtilsMessageTypeFlagsEXT type,
                              const VkDebugUtilsMessengerCallbackDataEXT* data,
                              void* user_data) {
            const char* message{data->pMessage};
            
            // Add more context for MoltenVK-specific issues
            std::string type_str = "";
            if (type & VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT) type_str += "[GENERAL] ";
            if (type & VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT) type_str += "[VALIDATION] ";
            if (type & VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT) type_str += "[PERFORMANCE] ";
            
            if (severity & VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT) {
                LOG_CRITICAL(Render_Vulkan, "{}{}", type_str, message);
            } else if (severity & VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT) {
                LOG_WARNING(Render_Vulkan, "{}{}", type_str, message);
            } else if (severity & VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT) {
                LOG_INFO(Render_Vulkan, "{}{}", type_str, message);
            } else if (severity & VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT) {
                LOG_DEBUG(Render_Vulkan, "{}{}", type_str, message);
            }
            return VK_FALSE;
        },
    };
    return instance.createDebugUtilsMessengerEXTUnique(msg_ci);
}

vk::UniqueDebugReportCallbackEXT CreateDebugReportCallback(vk::Instance instance) {
    const vk::DebugReportCallbackCreateInfoEXT callback_ci = {
        .flags = vk::DebugReportFlagBitsEXT::eDebug | vk::DebugReportFlagBitsEXT::eInformation |
                 vk::DebugReportFlagBitsEXT::eError |
                 vk::DebugReportFlagBitsEXT::ePerformanceWarning |
                 vk::DebugReportFlagBitsEXT::eWarning
    };
    return instance.createDebugReportCallbackEXTUnique(callback_ci);
}

DebugCallback CreateDebugCallback(vk::Instance instance, bool& debug_utils_supported) {
    if (!Settings::values.renderer_debug) {
        return {};
    }
    const auto properties = vk::enumerateInstanceExtensionProperties();
    if (properties.empty()) {
        LOG_ERROR(Render_Vulkan, "Failed to query extension properties");
        return {};
    }
    const auto it = std::find_if(properties.begin(), properties.end(), [](const auto& prop) {
        return std::strcmp(VK_EXT_DEBUG_UTILS_EXTENSION_NAME, prop.extensionName) == 0;
    });
    // Prefer debug util messenger if available.
    debug_utils_supported = it != properties.end();
    if (debug_utils_supported) {
        return CreateDebugMessenger(instance);
    }
    // Otherwise fallback to debug report callback.
    return CreateDebugReportCallback(instance);
}

} // namespace Vulkan
