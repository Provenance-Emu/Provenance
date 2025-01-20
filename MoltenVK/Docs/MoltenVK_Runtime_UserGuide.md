<a class="site-logo" href="https://github.com/KhronosGroup/MoltenVK" title="MoltenVK">
	<img src="images/MoltenVK-Logo-Banner.png" alt="MoltenVK" style="width:256px;height:auto">
</a>



MoltenVK Runtime User Guide
===========================

Copyright (c) 2015-2024 [The Brenwill Workshop Ltd.](http://www.brenwill.com)

[comment]: # "This document is written in Markdown (http://en.wikipedia.org/wiki/Markdown) format."
[comment]: # "For best results, use a Markdown reader."



Table of Contents
-----------------

- [About This Document](#about_this)
- [About **MoltenVK**](#about_moltenvk)
- [Installing **MoltenVK** in Your *Vulkan* Application](#install)
	- [Install *MoltenVK* as a Universal `XCFramework`](#install_xcfwk)
	- [Install *MoltenVK* as a Dynamic Library on _macOS_](#install_dylib)
	- [Optionally Link to Required System Libraries](#system_libs)
	- [Build and Runtime Requirements](#requirements)
- [Interacting with the **MoltenVK** Runtime](#interaction)
	- [MoltenVK Header Files](#moltenvk_headers)
	- [Configuring MoltenVK](#moltenvk_config)
- [Debugging Your **MoltenVK** Application using _Metal Frame Capture_](#gpu-capture)
- [*Metal Shading Language* Shaders](#shaders)
	- [Troubleshooting Shader Conversion](#spv_vs_msl)
- [Performance Considerations](#performance)
	- [Shader Loading Time](#shader_load_time)
	- [Swapchains](#swapchains)
	- [Timestamping](#timestamping)
	- [Xcode Configuration](#xcode_config)
	- [Metal System Trace Tool](#trace_tool)
- [Known **MoltenVK** Limitations](#limitations)



<a name="about_this"></a>
About This Document
-------------------

This document describes how to integrate the **MoltenVK** runtime distribution package into a game or
application, once **MoltenVK** has been built into a framework or library for *macOS*, *iOS*, or *tvOS*.

To learn how to use the **MoltenVK** open-source repository to build a **MoltenVK** runtime
distribution package, see the main [`README.md`](../README.md) document in the `MoltenVK` repository.



<a name="about_moltenvk"></a>
About **MoltenVK**
------------------

**MoltenVK** is a layered implementation of [*Vulkan 1.2*](https://www.khronos.org/vulkan)
graphics and compute functionality, that is built on Apple's [*Metal*](https://developer.apple.com/metal)
graphics and compute framework on *macOS*, *iOS*, and *tvOS*. **MoltenVK** allows you to use *Vulkan*
graphics and compute functionality to develop modern, cross-platform, high-performance graphical games
and applications, and to run them across many platforms, including *macOS*, *iOS*, *tvOS*, *Simulators*,
and *Mac Catalyst*.

*Metal* uses a different shading language, the *Metal Shading Language (MSL)*, than
*Vulkan*, which uses *SPIR-V*. **MoltenVK** automatically converts your *SPIR-V* shaders
to their *MSL* equivalents.

To provide *Vulkan* capability to the *macOS*, *iOS*, and *tvOS* platforms, **MoltenVK** uses
*Apple's* publicly available API's, including *Metal*. **MoltenVK** does **_not_** use any
private or undocumented API calls or features, so your app will be compatible with all
standard distribution channels, including *Apple's App Store*.


<a name="install"></a>
Installing **MoltenVK** in Your *Vulkan* Application
----------------------------------------------------

Installation of **MoltenVK** in your application is straightforward and easy!

Depending on your build and deployment needs, you can link **MoltenVK** to your application either
as either a static or dynamic universal `XCFramework`, or on _macOS_, as a *dynamic library* (`.dylib`).


<a name="install_xcfwk"></a>
### Install *MoltenVK* as a Universal `XCFramework`

> ***Note:*** *Xcode 14* introduced a new static linkage model that is not compatible with previous
versions of *Xcode*. If you link to a `MoltenVK.xcframework` that was built with *Xcode 14* or later,
also use *Xcode 14* or later to link it to your app or game.
>
> If you need to use *Xcode 13* or earlier to link `MoltenVK.xcframework` to your app or game,
first [build](../README.md#building) **MoltenVK** with *Xcode 13* or earlier.
>
> Or, if you want to use *Xcode 14* or later to [build](../README.md#building) **MoltenVK**, in order to be able
to use the latest *Metal* capabilities, but need to use *Xcode 13* or earlier to link `MoltenVK.xcframework`
to your app or game, first add the value `-fno-objc-msgsend-selector-stubs` to the `OTHER_CFLAGS` *Xcode* build
setting in the `MoltenVK.xcodeproj` and `MoltenVKShaderConverter.xcodeproj` *Xcode* projects, [build](../README.md#building)
**MoltenVK** with *Xcode 14* or later, and then link `MoltenVK.xcframework`to your app or game using *Xcode 13* or earlier.

To link **MoltenVK** to your application as either a static or dynamic `XCFramework`, follow these steps:

1. Open your application in *Xcode* and select your application's target in the *Project Navigator* panel.

2. Open the *Build Settings* tab.

	1. In the **Header Search Paths** (aka `HEADER_SEARCH_PATHS`) setting,
       add an entry that points to the `MoltenVK/include` folder.

	2. _(**Note:** This step is not required if linking to the static XCFramework)_ If linking to the _dynamic XCFramework_,
	in the **Runpath Search Paths** (aka `LD_RUNPATH_SEARCH_PATHS`) setting, add entries that match where the
	framework will be located in your runtime environment. If the dynamic library is to be embedded within your
	application, you would typically add one or both of the following entries for a _macOS_ platform target:

        ```
        @executable_path/../Frameworks
        @executable_path/../Frameworks/MoltenVK.framework
        ```

       or for a platform target other than _macOS_ add one or both of the following entries:

        ```
        @executable_path/Frameworks
        @executable_path/Frameworks/MoltenVK.framework
        ```

       `MoltenVK.framework` is internally configured to be located at `@rpath/MoltenVK.framework/MoltenVK`.

3. Open the *General* tab and drag either `Package/Latest/MoltenVK/static/MoltenVK.xcframework` or 
    `Package/Latest/MoltenVK/dynamic/MoltenVK.xcframework` to the *Embed Frameworks* (sometimes labeled 
    *Frameworks, Libraries, and Embedded Content*) list, and ensure the _Embed & Sign_ options is selected.


<a name="install_dylib"></a>
### Install *MoltenVK* as a Dynamic Library on _macOS_

To link **MoltenVK** to your _macOS_ application as a dynamic library (`.dylib`), follow these steps:

1. Open your application in *Xcode* and select your application's target in the
   *Project Navigator* panel.


2. Open the *Build Settings* tab.

    1. In the **Header Search Paths** (aka `HEADER_SEARCH_PATHS`) setting,
       add an entry that points to the `MoltenVK/include` folder.
      
    2. In the **Runpath Search Paths** (aka `LD_RUNPATH_SEARCH_PATHS`) setting,
       add an entry that matches where the dynamic library will be located in your runtime
       environment. If the dynamic library is to be embedded within your application,
       you would typically set this to `@executable_path/../Frameworks`.

       The `libMoltenVK.dylib` library in `MoltenVK.framework` is internally configured
       to be located at `@rpath/libMoltenVK.dylib`.

3. Open the *General* tab and drag `Package/Latest/MoltenVK/dynamic/dylib/macOS/libMoltenVK.dylib` 
   to the *Embed Frameworks* (sometimes labeled *Frameworks, Libraries, and Embedded Content*) list, 
   and ensure the _Embed & Sign_ options is selected.


<a name="system_libs"></a>
### Optionally Link to Required System Libraries

Open the *Build Phases* tab and open the *Link Binary With Libraries* list.

1. If your application does **_not_** use use `C++`, click the **+** button,
   and add `libc++.tbd` by selecting it from the list of system frameworks.
   This is needed because **MoltenVK** uses `C++` system libraries internally.
 
2. If you do **_not_** have the **Link Frameworks Automatically** (aka `CLANG_MODULES_AUTOLINK`) and
   **Enable Modules (C and Objective-C)** (aka `CLANG_ENABLE_MODULES`) settings enabled, click the
   **+** button, and add the following items by selecting them from the list of system frameworks:
   - `Metal.framework`
   - `Foundation.framework`.
   - `QuartzCore.framework`
   - `CoreGraphics.framework`
   - `IOSurface.framework`
   - `IOKit.framework` (*macOS*)
   - `AppKit.framework` (*macOS*)
   - `UIKit.framework` (*iOS* or *tvOS*)


<a name="requirements"></a>
### Build and Runtime Requirements

**MoltenVK** references the latest *Apple SDK* frameworks. To access these frameworks when building
your app, and to avoid build errors, be sure to use the latest publicly available version of *Xcode*.

Once built, your app integrating the **MoltenVK** libraries can be run on *macOS*, *iOS* or *tvOS*
devices that support *Metal*, or on the *Xcode* *iOS Simulator* or *tvOS Simulator*.

- At runtime, **MoltenVK** requires at least *macOS 10.15*, *iOS 13*, or *tvOS 13*.
- Information on *macOS* devices that are compatible with *Metal* can be found in
  [this article](http://www.idownloadblog.com/2015/06/22/how-to-find-mac-el-capitan-metal-compatible).
- Information on *iOS* devices that are compatible with *Metal* can be found in
  [this article](https://developer.apple.com/library/content/documentation/DeviceInformation/Reference/iOSDeviceCompatibility/HardwareGPUInformation/HardwareGPUInformation.html).

When a *Metal* app is running from *Xcode*, the default ***Scheme*** settings may reduce performance.
To improve performance and gain the benefits of *Metal*, perform the following in *Xcode*:

1. Open the ***Scheme Editor*** for building your main application. You can do
   this by selecting ***Edit Scheme...*** from the ***Scheme*** drop-down menu, or select
   ***Product -> Scheme -> Edit Scheme...*** from the main menu.
2. On the ***Info*** tab, set the ***Build Configuration*** to ***Release***, and disable the
   ***Debug executable*** check-box.
3. On the ***Options*** tab, disable both the ***Metal API Validation*** and ***GPU Frame Capture***
   options. For optimal performance, you may also consider disabling the other simulation
   and debugging options on this tab. For further information, see the
   [Xcode Scheme Settings and Performance](https://developer.apple.com/library/ios/documentation/Miscellaneous/Conceptual/MetalProgrammingGuide/Dev-Technique/Dev-Technique.html#//apple_ref/doc/uid/TP40014221-CH8-SW3)
   section of Apple's *Metal Programming Guide* documentation.



<a name="interaction"></a>
Interacting with the **MoltenVK** Runtime
-----------------------------------------

You programmatically configure and interact with the **MoltenVK** runtime through function
calls, enumeration values, and capabilities, in exactly the same way you do with other
*Vulkan* implementations. **MoltenVK** contains several header files that define access
to *Vulkan* and **MoltenVK** function calls.

In your application code, you access *Vulkan* features through the API defined in the standard
`vulkan.h` header file. This file is included in the **MoltenVK** framework, and can be included
in your source code files as follows:

	#include <vulkan/vulkan.h>

In addition to core *Vulkan* functionality, **MoltenVK**  also supports the following *Vulkan* extensions:

- `VK_KHR_16bit_storage`
- `VK_KHR_8bit_storage`
- `VK_KHR_bind_memory2`
- `VK_KHR_buffer_device_address`
  - *Requires GPU Tier 2 argument buffers support.*
- `VK_KHR_calibrated_timestamp`
  - *Requires Metal 2.2.*
- `VK_KHR_copy_commands2`
- `VK_KHR_create_renderpass2`
- `VK_KHR_dedicated_allocation`
- `VK_KHR_depth_stencil_resolve`
- `VK_KHR_descriptor_update_template`
- `VK_KHR_device_group`
- `VK_KHR_device_group_creation`
- `VK_KHR_driver_properties`
- `VK_KHR_dynamic_rendering`
- `VK_KHR_format_feature_flags2`
- `VK_KHR_fragment_shader_barycentric`
  - *Requires Metal 2.2 on Mac or Metal 2.3 on iOS.*
- `VK_KHR_get_memory_requirements2`
- `VK_KHR_get_physical_device_properties2`
- `VK_KHR_get_surface_capabilities2`
- `VK_KHR_imageless_framebuffer`
- `VK_KHR_image_format_list`
- `VK_KHR_incremental_present`
- `VK_KHR_maintenance1`
- `VK_KHR_maintenance2`
- `VK_KHR_maintenance3`
- `VK_KHR_map_memory2`
- `VK_KHR_multiview`
- `VK_KHR_portability_subset`
- `VK_KHR_push_descriptor`
- `VK_KHR_relaxed_block_layout`
- `VK_KHR_sampler_mirror_clamp_to_edge`
  - *Requires a Mac GPU or Apple family 7 GPU.*
- `VK_KHR_sampler_ycbcr_conversion`
- `VK_KHR_separate_depth_stencil_layouts`
- `VK_KHR_shader_draw_parameters`
- `VK_KHR_shader_float_controls`
- `VK_KHR_shader_float16_int8`
- `VK_KHR_shader_integer_dot_product`
- `VK_KHR_shader_non_semantic_info`
- `VK_KHR_shader_subgroup_extended_types`
  - *Requires Metal 2.1 on Mac or Metal 2.2 and Apple family 4 on iOS.*
- `VK_KHR_spirv_1_4`
- `VK_KHR_storage_buffer_storage_class`
- `VK_KHR_surface`
- `VK_KHR_swapchain`
- `VK_KHR_swapchain_mutable_format`
- `VK_KHR_synchronization2`
- `VK_KHR_timeline_semaphore`
- `VK_KHR_uniform_buffer_standard_layout`
- `VK_KHR_variable_pointers`
- `VK_KHR_vertex_attribute_divisor`
- `VK_EXT_4444_formats`
  - *Requires 16-bit formats and either native texture swizzling or manual swizzling to be enabled.*
- `VK_EXT_buffer_device_address`
  - *Requires GPU Tier 2 argument buffers support.*
- `VK_EXT_calibrated_timestamps`
  - *Requires Metal 2.2.*
- `VK_EXT_debug_marker`
- `VK_EXT_debug_report`
- `VK_EXT_debug_utils`
- `VK_EXT_descriptor_indexing`
  - *Initial release limited to Metal Tier 1: 96/128 textures,
    16 samplers, except macOS 11.0 (Big Sur) or later, or on older versions of macOS using
    an Intel GPU, and if Metal argument buffers enabled in config.*
- `VK_EXT_extended_dynamic_state`
  - *Requires Metal 3.1 for `VK_DYNAMIC_STATE_VERTEX_INPUT_BINDING_STRIDE`.*
- `VK_EXT_extended_dynamic_state2`
  - *Primitive restart is always enabled, as Metal does not support disabling it (`VK_DYNAMIC_STATE_PRIMITIVE_RESTART_ENABLE_EXT`).*
- `VK_EXT_extended_dynamic_state3`
  - *Metal does not support `VK_POLYGON_MODE_POINT`*
- `VK_EXT_external_memory_host`
- `VK_EXT_fragment_shader_interlock`
  - *Requires Metal 2.0 and Raster Order Groups.*
- `VK_EXT_hdr_metadata`
  - *macOS only.*
- `VK_EXT_headless_surface`
- `VK_EXT_host_image_copy`
- `VK_EXT_host_query_reset`
- `VK_EXT_image_robustness`
- `VK_EXT_inline_uniform_block`
- `VK_EXT_layer_settings`
- `VK_EXT_memory_budget`
  - *Requires Metal 2.0.*
- `VK_EXT_metal_objects`
- `VK_EXT_metal_surface`
- `VK_EXT_pipeline_creation_cache_control`
- `VK_EXT_pipeline_creation_feedback`
- `VK_EXT_post_depth_coverage`
  - *iOS and macOS, requires family 4 (A11) or better Apple GPU.*
- `VK_EXT_private_data `
- `VK_EXT_robustness2`
- `VK_EXT_sample_locations`
- `VK_EXT_scalar_block_layout`
- `VK_EXT_separate_stencil_usage`
- `VK_EXT_shader_atomic_float`
  - *Requires Metal 3.0.*
- `VK_EXT_shader_demote_to_helper_invocation`
  - *Requires Metal Shading Language 2.3.*
- `VK_EXT_shader_stencil_export`
  - *Requires Mac GPU family 2 or iOS GPU family 5.*
- `VK_EXT_shader_subgroup_ballot`
  - *Requires Mac GPU family 2 or Apple GPU family 4.*
- `VK_EXT_shader_subgroup_vote`
  - *Requires Mac GPU family 2 or Apple GPU family 4.*
- `VK_EXT_shader_viewport_index_layer`
- `VK_EXT_subgroup_size_control`
  - *Requires Metal 2.1 on Mac or Metal 2.2 and Apple family 4 on iOS.*
- `VK_EXT_surface_maintenance1`
- `VK_EXT_swapchain_colorspace`
- `VK_EXT_swapchain_maintenance1`
- `VK_EXT_vertex_attribute_divisor`
- `VK_EXT_texel_buffer_alignment`
  - *Requires Metal 2.0.*
- `VK_EXT_texture_compression_astc_hdr`
  - *iOS and macOS, requires family 6 (A13) or better Apple GPU.*
- `VK_MVK_ios_surface`
  - *Obsolete. Use `VK_EXT_metal_surface` instead.*
- `VK_MVK_macos_surface`
  - *Obsolete. Use `VK_EXT_metal_surface` instead.*
- `VK_AMD_gpu_shader_half_float`
- `VK_AMD_negative_viewport_height`
- `VK_AMD_shader_image_load_store_lod`
  - *Requires Apple GPU.*
- `VK_AMD_shader_trinary_minmax`
  - *Requires Metal 2.1.*
- `VK_IMG_format_pvrtc`
  - *Requires Apple GPU.*
- `VK_INTEL_shader_integer_functions2`
- `VK_NV_fragment_shader_barycentric`
  - *Requires Metal 2.2 on Mac or Metal 2.3 on iOS.*

In order to visibly display your content on *macOS*, *iOS*, or *tvOS*, you must enable the
`VK_EXT_metal_surface` extension, and use the function defined in that extension to create a
*Vulkan* rendering surface. You can enable the `VK_EXT_metal_surface` extension by defining
the `VK_USE_PLATFORM_METAL_EXT` guard macro in your compiler build settings. See the description
of the `mvk_vulkan.h` file below for  a convenient way to enable this extension automatically.

When creating a `CAMetalLayer` to underpin the *Vulkan* surface to render to, it is strongly
recommended that you ensure the `delegate` of the `CAMetalLayer` is the `NSView/UIView` in
which the layer is contained, to ensure correct and optimized *Vulkan* swapchain and refresh
timing behavior across multiple display screens that might have different properties.

The view will automatically be the `delegate` of the layer when the view creates the
`CAMetalLayer`, as per Apple's documentation:

>If the layer object was created by a view, the view typically assigns itself as the layer’s
delegate automatically, and you should not change that relationship. For layers you create
yourself, you can assign a delegate object and use that object to provide the contents of
the layer dynamically and perform other tasks.

But in the case where you create the `CAMetalLayer` yourself and assign it to the view,
you should also assign the view as the `delegate` of the layer.

Because **MoltenVK** supports the `VK_KHR_portability_subset` extension, when using the
*Vulkan Loader* from the *Vulkan SDK* to run **MoltenVK** on *macOS*, the *Vulkan Loader*
will only include **MoltenVK** `VkPhysicalDevices` in the list returned by
`vkEnumeratePhysicalDevices()` if the `VK_INSTANCE_CREATE_ENUMERATE_PORTABILITY_BIT_KHR`
flag is enabled in `vkCreateInstance()`. See the description of the `VK_KHR_portability_enumeration`
extension in the *Vulkan* specification for more information about the use of the
`VK_INSTANCE_CREATE_ENUMERATE_PORTABILITY_BIT_KHR` flag.


<a name="moltenvk_headers"></a>
### MoltenVK Header Files

**MoltenVK** provides additional functionality beyond standard *Vulkan* functionality,
to support configuration options and query behaviour that is specific to the **MoltenVK**
implementation of *Vulkan* functionality.

The following API header files are included in the **MoltenVK** package, each of which
can be included in your application source code as follows:

	#include <MoltenVK/HEADER_FILE>

where `HEADER_FILE` is one of the following:

- `mvk_vulkan.h` - This is a convenience header file that loads the `<vulkan/vulkan.h>` header file
  with platform settings to enable the appropriate _Vulkan_ WSI surface and portability extensions.

- `mvk_private_api.h` - Contains private structures and functions to query **MoltenVK** about
  **MoltenVK** version and configuration, runtime performance information, and available
  _Metal_ capabilities.
  > _**NOTE:**_ THE FUNCTIONS in `mvk_private_api.h` ARE NOT SUPPORTED BY THE _Vulkan Loader
  and Layers_, AND CAN ONLY BE USED WHEN **MoltenVK** IS LINKED DIRECTLY TO YOUR APPLICATION.

- `mvk_datatypes.h` - Contains helpful functions for converting between *Vulkan* and *Metal*
  data types. You do not need to use this functionality to use **MoltenVK**, as **MoltenVK**
  converts between *Vulkan* and *Metal* datatypes automatically (using the functions declared
  in this header). These functions are exposed in this header as a convienience for your own
  purposes such as interacting with *Metal* directly, or simply logging data values.


<a name="moltenvk_config"></a>
### Configuring MoltenVK

**MoltenVK** provides the ability to configure and optimize **MoltenVK** for your particular
application runtime requirements and development-time needs.

At runtime, configuration can be helpful in situtations where _Metal_ behavior is different
than _Vulkan_ behavior, and the results or performance you receive can depend on how **MoltenVK**
works around those differences, which, in turn, may depend on how you are using _Vulkan_.
Different apps might benefit differently in this handling.

Additional configuration parameters can be helpful at development time by providing you with
additional tracing, debugging, and performance measuring capabilities.

Each configuration parameter has a *name* and *value*, and can be passed to **MoltenVK**
via any of the following mechanisms:

- The standard _Vulkan_ `VK_EXT_layer_settings` extension.
- Application runtime environment variables.
- Build settings at **MoltenVK** build time.

Parameter values configured by build settings at **MoltenVK** build time can be overridden
by values set by environment variables, which, in turn, can be overridden during `VkInstance`
creation via the _Vulkan_ `VK_EXT_layer_settings` extension.

Using the `VK_EXT_layer_settings` extension is the preferred mechanism, as it is a standard
_Vulkan_ extension, and is supported by the _Vulkan_ loader and layers. When using the
`VK_EXT_layer_settings` extension, set `VkLayerSettingEXT::pLayerName` to the value of
`kMVKMoltenVKDriverLayerName` found in the `mvk_vulkan.h` header (or simply to `"MoltenVK"`).

Using environment variables can be a convinient mechanism to modify configuration parameters
during runtime debugging in the field (if the settings are *not* overridden during `VkInstance`
creation via the _Vulkan_ `VK_EXT_layer_settings` extension).

A description of each configuration parameter supported by **MoltenVK** can be found in the
[`MoltenVK_Configuration_Parameters.md`](MoltenVK_Configuration_Parameters.md) document in the `Docs` directory.



<a name="gpu-capture"></a>
Debugging Your MoltenVK Application using _Metal Frame Capture_
-----------------------------------------------------------------

Since **MoltenVK** translates _Vulkan API_ calls to _Metal_, you can use _Apple's_
[Metal Frame Capture](https://developer.apple.com/documentation/xcode/capturing-a-metal-workload-in-xcode)
to help debug your application. You can configure **MoltenVK** to automatically write to a GPU trace file,
without manual intervention, by using the following environment variables and configuration parameters:

1. `METAL_CAPTURE_ENABLED=1`, to enable Metal GPU capture. This must be set as an environment variable,
   or in _Xcode_ as an _Option_ in the _Scheme_ you use to launch your app from _Xcode_.
2. `MVK_CONFIG_AUTO_GPU_CAPTURE_SCOPE=n`, this defines the scope of the capture.
   You can set `n` to:
	- `0` to disable capturing,
	- `1` to capture all frames created between the creation of a `VkDevice` to its destruction, or
	- `2` to capture only the first frame.
3. `MVK_CONFIG_AUTO_GPU_CAPTURE_OUTPUT_FILE=filename.gputrace`, to set where the capture file
   should be saved to. Note that `filename.gputrace` must not already exist, otherwise the file
   will not be written, and an error will be logged.

Except for `METAL_CAPTURE_ENABLED=1`, the other parameters can be set as configuration parameters, as described
in the [Configuring MoltenVK](#moltenvk_config) section above (including as environment variables).

The created capture file can then be opened with _Xcode_ for investigation. You do not need to launch
your app from _Xcode_ to capture and generate the trace file.



<a name="shaders"></a>
*Metal Shading Language* Shaders
--------------------------------

*Metal* uses a different shader language than *Vulkan*. *Vulkan* uses the new
*SPIR-V Shading Language (SPIR-V)*, whereas *Metal* uses the *Metal Shading Language (MSL)*.
**MoltenVK** uses **Runtime Shader Conversion** to automatically convert your *SPIR-V* shaders
to their *MSL* equivalents, during loading your *SPIR-V* shaders, using the standard *Vulkan*
`vkCreateShaderModule()` function.



<a name="spv_vs_msl"></a>
### Troubleshooting Shader Conversion

The shader converter technology in **MoltenVK** is quite robust, and most *SPIR-V* shaders
can be converted to *MSL* without any problems. In the case where a conversion issue arises,
you can address the issue as follows:

- Errors encountered during **Runtime Shader Conversion** are logged to the console.

- To help understand conversion issues during **Runtime Shader Conversion**, you can enable logging
  the *SPIR-V* and *MSL* shader source code during shader conversion, by enabing the `MVK_CONFIG_DEBUG`
  configuration parameter. See the [*MoltenVK Configuration*](#moltenvk_config) description above.

  Enabling debug mode in **MoltenVK** includes shader conversion logging, which causes both
  the incoming *SPIR-V* code and the converted *MSL* source code to be logged to the console
  in human-readable form. This allows you to manually verify the conversions, and can help
  you diagnose issues that might occur during shader conversion.

- For some issues, you may be able to adjust your *SPIR-V* code so that it behaves the same
  under *Vulkan*, but is easier to automatically convert to *MSL*.

- You are also encouraged to report issues with shader conversion to the
  [*SPIRV-Cross*](https://github.com/KhronosGroup/SPIRV-Cross/issues) project. **MoltenVK** and
  **MoltenVKShaderConverter** make use of *SPIRV-Cross* to convert *SPIR-V* shaders to *MSL* shaders.



<a name="performance"></a>
Performance Considerations
--------------------------

This section discusses various options for improving performance when using **MoltenVK**.


<a name="shader_load_time"></a>
### Shader Loading Time

A number of steps is required to load and compile *SPIR-V* shaders into a form that *Metal* can use.
Although the overall process is fast, the slowest step involves converting shaders from *SPIR-V* to
*MSL* source code format.

If you have a lot of shaders, you can dramatically improve shader loading time by using the standard
*Vulkan pipeline cache* feature, to serialize shaders and store them in *MSL* form offline.
Loading *MSL* shaders via the pipeline cache serializing mechanism can be significantly faster than
converting from *SPIR-V* to *MSL* each time.

In *Vulkan*, pipeline cache serialization for offline storage is available through the
`vkGetPipelineCacheData()` and `vkCreatePipelineCache()` functions. Loading the pipeline cache
from offline storage at app start-up time can dramatically improve both shader loading performance,
and performance glitches and hiccups during runtime code if shader loading is performed then.

When using pipeline caching, nothing changes about how you load *SPIR-V* shader code. **MoltenVK**
automatically detects that the *SPIR-V* was previously converted to *MSL*, and stored offline via
the *Vulkan* pipeline cache serialization mechanism, and does not invoke the relatively expensive
step of converting the *SPIR-V* to *MSL* again.


<a name="swapchains"></a>
### Swapchains

*Metal* supports a very small number (3) of concurrent swapchain images. In addition, *Metal* can
sometimes hold onto these images during surface presentation.

**MoltenVK** supports using either 2 or 3 swapchain images. For best performance, it is recommended
that you use 3 swapchain images (triple-buffering), to ensure that at least one swapchain image will
be available when you need to render to it.

Using 3 swapchain images is particularly important when rendering to a full-screen surface, because
in that situation, *Metal* uses its *Direct to Display* feature, and avoids compositing the swapchain
image onto a separate composition surface before displaying it. Although *Direct to Display* can improve
performance throughput, it also means that *Metal* may hold onto each swapchain image a little longer
than when using an internal compositor, which increases the risk that a swapchain image will not be a
vailable when you request it, resulting in frame delays and visual stuttering.


<a name="timestamping"></a>
### Timestamping

On non-Apple GPUs (older Mac devices), the GPU can switch power and performance states as
required by usage. This affects the GPU timestamps retrievable through the Vulkan API.
As a result, the value of `VkPhysicalDeviceLimits::timestampPeriod` can vary over time.
Consider calling `vkGetPhysicalDeviceProperties()`, when needed, and retrieve the current
value of `VkPhysicalDeviceLimits::timestampPeriod`, to help you calibrate recent GPU
timestamps queried through the Vulkan API.

This is not needed on Apple Silicon devices, where all GPU timestamps are always returned
as nanoseconds, regardless of variations in power and performance states as the app runs.


<a name="xcode_config"></a>
### Xcode Configuration

When a *Metal* app is running from *Xcode*, the default ***Scheme*** settings reduce performance.
Be sure to follow the instructions for configuring your application's ***Scheme*** within *Xcode*,
found in the  in the [installation](#install) section above.


<a name="trace_tool"></a>
### Metal System Trace Tool

To help you get the best performance from your graphics app, the *Xcode Instruments* profiling tool
includes the *Metal System Trace* template. This template can be used to provide detailed tracing of the
CPU and GPU behaviour of your application, allowing you unprecedented performance measurement
and tuning capabilities for apps using *Metal*.



<a name="limitations"></a>
Known **MoltenVK** Limitations
------------------------------

This section documents the known limitations in this version of **MoltenVK**.

- See [above](#interaction) for known limitations for specific Vulkan extensions.

- On *macOS* versions prior to *macOS 10.15.6*, native host-coherent image device memory is not available.
  Because of this, changes made to `VkImage VK_MEMORY_PROPERTY_HOST_COHERENT_BIT` device memory by the CPU
  or GPU will not be available to the GPU or CPU, respectively, until the memory is flushed  or unmapped by
  the application. Applications using `vkMapMemory()` with `VkImage VK_MEMORY_PROPERTY_HOST_COHERENT_BIT`
  device memory on *macOS* versions prior to *macOS 10.15.6* must call either `vkUnmapMemory()`, or
  `vkFlushMappedMemoryRanges()` / `vkInvalidateMappedMemoryRanges()` to ensure memory changes are coherent
  between the CPU and GPU.  This limitation does **_not_** apply to `VKImage` device memory on *macOS*
  starting with *macOS 10.15.6*, does not apply to `VKImage` device memory on any version of *iOS* or *tvOS*,
  and does **_not_** apply to `VKBuffer` device memory on any platform.

- Image content in `PVRTC` compressed formats must be loaded directly into a `VkImage` using
  host-visible memory mapping. Loading via a staging buffer will result in malformed image content.

- Pipeline statistics query pool using `VK_QUERY_TYPE_PIPELINE_STATISTICS` is not supported.

- Application-controlled memory allocations using `VkAllocationCallbacks` are ignored.

- Since **MoltenVK** is an implementation of *Vulkan* functionality, it does not load
  *Vulkan Layers* on its own. In order to use *Vulkan Layers*, such as the validation layers,
  use the *Vulkan Loader and Layers* from the *[Vulkan SDK](https://vulkan.lunarg.com/sdk/home)*.
  Refer to the *Vulkan SDK [Getting Started](https://vulkan.lunarg.com/doc/sdk/latest/mac/getting_started.html)*
  document for more info.
