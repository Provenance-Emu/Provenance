<a class="site-logo" href="https://github.com/KhronosGroup/MoltenVK" title="MoltenVK">
	<img src="images/MoltenVK-Logo-Banner.png" alt="MoltenVK" style="width:256px;height:auto">
</a>



MoltenVK Configuration Parameters
=================================

Copyright (c) 2015-2024 [The Brenwill Workshop Ltd.](http://www.brenwill.com)

[comment]: # "This document is written in Markdown (http://en.wikipedia.org/wiki/Markdown) format."
[comment]: # "For best results, use a Markdown reader."



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


---------------------------------------
#### MVK_CONFIG_ACTIVITY_PERFORMANCE_LOGGING_STYLE

##### Type: Enumeration
- `0`: Log repeatedly every number of frames configured by the `MVK_CONFIG_PERFORMANCE_LOGGING_FRAME_COUNT` parameter.
- `1`: Log immediately after each performance measurement.
- `2`: Log at the end of the `VkDevice` lifetime. This is useful for one-shot apps such as testing frameworks.
- `3`: Log at the end of the `VkDevice` lifetime, but continue to accumulate across mulitiple `VkDevices`
  throughout the app process. This is useful for testing frameworks that create many `VkDevices` serially.

##### Default: `0`

If the `MVK_CONFIG_PERFORMANCE_TRACKING` parameter is enabled, this parameter controls
when **MoltenVK** should log activity performance events.


---------------------------------------
#### MVK_CONFIG_ADVERTISE_EXTENSIONS

##### Type: UInt32
##### Default: `1`

Controls which extensions **MoltenVK** should advertise it supports in `vkEnumerateInstanceExtensionProperties()`
and `vkEnumerateDeviceExtensionProperties()`. This can be useful when testing **MoltenVK** against specific
limited functionality. The value of this parameter is a `Bitwise-OR` of the following values:

- `1`: All supported extensions.
- `2`: WSI extensions supported on the platform.
- `4`: _Vulkan_ Portability Subset extensions.


Any prerequisite extensions are also advertised. If bit `1` is included, all supported
extensions will be advertised. A value of zero means no extensions will be advertised.


---------------------------------------
#### MVK_CONFIG_API_VERSION_TO_ADVERTISE

##### Type: UInt32
##### Default: `4202496`

Controls the _Vulkan_ API version that **MoltenVK** should advertise in `vkEnumerateInstanceVersion()`,
after **MoltenVK** adds the `VK_HEADER_VERSION` component.

Set this value to one of:

- `4202496` (decimal number for `VK_API_VERSION_1_2`)
- `4198400` (decimal number for `VK_API_VERSION_1_1`)
- `4194304` (decimal number for `VK_API_VERSION_1_0`)


---------------------------------------
#### MVK_CONFIG_AUTO_GPU_CAPTURE_OUTPUT_FILE

##### Type: String
##### Default: `""`

_(The default value is an empty string)._

If `MVK_CONFIG_AUTO_GPU_CAPTURE_SCOPE` is any value other than `0`, this is the path to a
file where the automatic GPU capture will be saved. If this parameter is an empty string
(the default), automatic GPU capture will be handled by the _Xcode_ user interface.

If this parameter is set to a valid file path, the _Xcode_ scheme need not have _Metal_ GPU capture
enabled, and in fact the app need not be run under _Xcode_'s control at all. This is useful in case
the app cannot be run under _Xcode_'s control. A path starting with '~' can be used to place it in
a user's home directory. This feature requires _Metal 2.2 (macOS 10.15+, iOS/tvOS 13+)_.


---------------------------------------
#### MVK_CONFIG_AUTO_GPU_CAPTURE_SCOPE

##### Type: Enumeration
- `0`: No automatic GPU capture.
- `1`: Automatically capture all GPU activity during the lifetime of a `VkDevice`.
- `2`: Automatically capture all GPU activity during the rendering and presentation of the first frame.
- `3`: Automatically capture all GPU activity while signaled on a temporary named pipe. Automatically 
  begins recording whenever the pipe is not empty, and records as many frames as the pipe contains bytes.

##### Default: `0`

Controls whether _Metal_ should run an automatic GPU capture without the user having to
trigger it manually via the _Xcode_ user interface, and controls the scope under which
that GPU capture will occur. This is useful when trying to capture a one-shot GPU trace,
such as when running a _Vulkan_ CTS test case, or for triggering the capture via an
IPC on a temporary named pipe. 

For values `2` and `3`, the queue for which the frames are captured is identifed by 
the values of the `MVK_CONFIG_DEFAULT_GPU_CAPTURE_SCOPE_QUEUE_FAMILY_INDEX` and 
`MVK_CONFIG_DEFAULT_GPU_CAPTURE_SCOPE_QUEUE_INDEX` configuration parameters.

For the automatic GPU capture to occur, the environment variable `MTL_CAPTURE_ENABLED` must be enabled,
or, if running the app from _Xcode_, the _GPU Frame Capture_ option can be set to _Metal_.

To manually trigger a GPU capture via the _Xcode_ user interface, leave this parameter at `0`.


---------------------------------------
#### MVK_CONFIG_DEBUG

##### Type: Boolean
##### Default: `0`

_(The default value is `1` if **MoltenVK** was built in Debug mode)._

If enabled, debugging capabilities will be enabled, including logging shader code during runtime shader conversion.


---------------------------------------
#### MVK_CONFIG_DEFAULT_GPU_CAPTURE_SCOPE_QUEUE_FAMILY_INDEX

##### Type: UInt32
##### Default: `0`

The index of the queue family whose presentation submissions will be
used as the default GPU Capture Scope, when GPU Capture is active.


---------------------------------------
#### MVK_CONFIG_DEFAULT_GPU_CAPTURE_SCOPE_QUEUE_INDEX

##### Type: UInt32
##### Default: `0`

The index of the queue, within the queue family identified by the
`MVK_CONFIG_DEFAULT_GPU_CAPTURE_SCOPE_QUEUE_FAMILY_INDEX` parameter, whose presentation
submissions will be used as the default GPU Capture Scope, when GPU Capture is active.


---------------------------------------
#### MVK_CONFIG_DISPLAY_WATERMARK

##### Type: Boolean
##### Default: `0`

If enabled, a **MoltenVK** logo watermark will be rendered on top of the scene.
This can be enabled for publicity during demos.


---------------------------------------
#### MVK_CONFIG_FAST_MATH_ENABLED

##### Type: Enumeration
- `0`: _Metal_ shaders will never be compiled with the fast math option.
- `1`: _Metal_ shaders will always be compiled with the fast math option.
- `2`: _Metal_ shaders will be compiled with the fast math option, unless the shader includes execution
  capabilities, such as `SignedZeroInfNanPreserve`, that require it to be compiled without fast math.

##### Default: `1`

Identifies when _Metal_ shaders will be compiled with the _Metal_ fast math option enabled.

Shaders compiled with the _Metal_ fast math option enabled perform floating point math significantly
faster, but may optimize floating point operations in ways that violate the IEEE 754 standard.

Enabling _Metal_ fast math can dramatically improve shader performance, and has little practical
effect on the numerical accuracy of most shaders. As such, disabling fast math should be done
carefully and deliberately. For most applications, always enabling fast math is the preferred choice.

Apps that have specific accuracy and handling needs for particular shaders, may elect to set
the value of this property to `2`, so that fast math will be disabled when compiling shaders
that request specific math accuracy and precision capabilities, such as `SignedZeroInfNanPreserve`.


---------------------------------------
#### MVK_CONFIG_FORCE_LOW_POWER_GPU

##### Type: Boolean
##### Default: `0`

Forces **MoltenVK** to only advertise the low-power GPUs, if availble on the device.


---------------------------------------
#### MVK_CONFIG_FULL_IMAGE_VIEW_SWIZZLE

##### Type: Boolean
##### Default: `0`

If _Metal_ supports native per-texture swizzling (_macOS 10.15+ with Mac 2 GPU_, _ios/tvOS 13+_),
this parameter is ignored.

When running on an older version of _Metal_ that does not support native per-texture swizzling,
if this parameter is enabled, `VkImageView` swizzling is automatically performed in the converted
_Metal_ shader code during all texture sampling and reading operations. This occurs regardless
of whether a swizzle is required for the `VkImageView` associated with the _Metal_ texture,
which may result in reduced performance.

If disabled, and native _Metal_ per-texture swizzling is not available on the platform, the
following very limited set of `VkImageView` component swizzles is supported via format substitutions:

```
Texture format			            Swizzle
--------------                  -------
VK_FORMAT_R8_UNORM              ZERO, ANY, ANY, RED
VK_FORMAT_A8_UNORM              ALPHA, ANY, ANY, ZERO
VK_FORMAT_R8G8B8A8_UNORM        BLUE, GREEN, RED, ALPHA
VK_FORMAT_R8G8B8A8_SRGB         BLUE, GREEN, RED, ALPHA
VK_FORMAT_B8G8R8A8_UNORM        BLUE, GREEN, RED, ALPHA
VK_FORMAT_B8G8R8A8_SRGB         BLUE, GREEN, RED, ALPHA
VK_FORMAT_D32_SFLOAT_S8_UINT    RED, ANY, ANY, ANY (stencil only)
VK_FORMAT_D24_UNORM_S8_UINT     RED, ANY, ANY, ANY (stencil only)
```

If native per-texture swizzling is not available, and this feature is not enabled,
an error is logged and returned in the following situations:

- `VkImageView` creation if that `VkImageView` requires full image view swizzling.
- A pipeline that was not compiled with full image view swizzling uses a `VkImageView` that is expecting a swizzle.
- `VkPhysicalDeviceImageFormatInfo2KHR` is passed in a call to `vkGetPhysicalDeviceImageFormatProperties2KHR()`
  to query for an `VkImageView` format that will require full swizzling.


---------------------------------------
#### MVK_CONFIG_LOG_LEVEL

##### Type: Enumeration
- `0`: No logging.
- `1`: Log errors only.
- `2`: Log errors and warning messages.
- `3`: Log errors, warnings and informational messages.
- `4`: Log errors, warnings, infos and debug messages.

##### Default: `3`

Controls the level of logging performed by **MoltenVK**.


---------------------------------------
#### MVK_CONFIG_MAX_ACTIVE_METAL_COMMAND_BUFFERS_PER_QUEUE

##### Type: UInt32
##### Default: `64`

The maximum number of _Metal_ command buffers that can be concurrently active per _Vulkan_ queue. The number
of active _Metal_ command buffers required depends on the `MVK_CONFIG_PREFILL_METAL_COMMAND_BUFFERS` parameter.
If `MVK_CONFIG_PREFILL_METAL_COMMAND_BUFFERS` is set to anything other than `0`, one _Metal_ command buffer
is required per _Vulkan_ command buffer, otherwise one _Metal_ command buffer is required per command buffer
queue submission, which will typically be significantly less than the number of _Vulkan_ command buffers.


---------------------------------------
#### MVK_CONFIG_METAL_COMPILE_TIMEOUT

##### Type: UInt64
##### Default: `INT64_MAX`

The maximum amount of time, in nanoseconds, to wait for a _Metal_ library, function, or
pipeline state object to be compiled and created by the _Metal_ compiler. An internal error
within the _Metal_ compiler may stall the thread for up to 30 seconds. Setting this value
limits that delay to a specified amount of time, allowing shader compilations to fail fast.


---------------------------------------
#### MVK_CONFIG_PERFORMANCE_LOGGING_FRAME_COUNT

##### Type: UInt32
##### Default: `0`

If the `MVK_CONFIG_PERFORMANCE_TRACKING` parameter is enabled, and this parameter is non-zero,
performance and frame-based statistics will be logged, on a repeating cycle, once per this many frames.
If this parameter is zero, or the `MVK_CONFIG_PERFORMANCE_TRACKING` parameter is disabled,
no frame-based performance statistics will be logged.


---------------------------------------
#### MVK_CONFIG_PERFORMANCE_TRACKING

##### Type: Boolean
##### Default: `0`

If enabled, performance statistics, as defined by the `MVKPerformanceStatistics` structure,
are collected, and can be retrieved via the private-API `vkGetPerformanceStatisticsMVK()` function.

You can also use the `MVK_CONFIG_ACTIVITY_PERFORMANCE_LOGGING_STYLE` and
`MVK_CONFIG_PERFORMANCE_LOGGING_FRAME_COUNT` parameters to configure when to log the performance statistics collected by this parameter.


---------------------------------------
#### MVK_CONFIG_PREALLOCATE_DESCRIPTORS

##### Type: Boolean
##### Default: `1`

Controls whether **MoltenVK** should preallocate memory in each `VkDescriptorPool` according
to the values of the `VkDescriptorPoolSize` parameters. Doing so may improve descriptor set
allocation performance and memory stability at a cost of preallocated application memory.
If this setting is disabled, the descriptors required for a descriptor set will be individually
dynamically allocated in application memory when the descriptor set itself is allocated.


---------------------------------------
#### MVK_CONFIG_PREFILL_METAL_COMMAND_BUFFERS

##### Type: Enumeration
- `0`: During _Vulkan_ command buffer filling, do not prefill a _Metal_ command buffer for each _Vulkan_
  command buffer. A single _Metal_ command buffer will be created and encoded for all the _Vulkan_ command
  buffers included when `vkQueueSubmit()` is called. **MoltenVK** automatically creates and drains
  a single _Metal_ object autorelease pool when `vkQueueSubmit()` is called. This is the fastest option,
  but potentially has the largest memory footprint.
- `1`: During _Vulkan_ command buffer filling, encode to the _Metal_ command buffer when `vkEndCommandBuffer()`
  is called. **MoltenVK** automatically creates and drains a single _Metal_ object autorelease pool when
  `vkEndCommandBuffer()` is called. This option has the fastest performance, and the largest memory footprint,
  of the prefilling options using autorelease pools.
- `2`: During _Vulkan_ command buffer filling, as each
  command is submitted to the _Vulkan_ command buffer, immediately encode it to the _Metal_ command buffer,
  and do not retain any command content in the _Vulkan_ command buffer. **MoltenVK** automatically creates
  and drains a _Metal_ object autorelease pool for each and every command added to the _Vulkan_ command buffer.
  This option has the smallest memory footprint,
  and the slowest performance, of the prefilling options using autorelease pools.
- `3`: During _Vulkan_ command buffer filling, as each
  command is submitted to the _Vulkan_ command buffer, immediately encode it to the _Metal_ command buffer,
  do not retain any command content in the _Vulkan_ command buffer, and assume the app will ensure that each
  thread that fills commands into a _Vulkan_ command buffer has a _Metal_ autorelease pool. **MoltenVK** will
  not create and drain any autorelease pools during encoding. This is the fastest prefilling option, and
  generally has a small memory footprint, depending on when the app-provided autorelease pool drains.

##### Default: `0`

For any value other than `0`, be aware of the following:

- One _Metal_ command buffer is required for each _Vulkan_ command buffer. Depending on the
  number of command buffers that you use, you may also need to change the value of the
  `MVK_CONFIG_MAX_ACTIVE_METAL_COMMAND_BUFFERS_PER_QUEUE` parameter.
- Prefilling of a _Metal_ command buffer will not occur during the filling of secondary command buffers
  (`VK_COMMAND_BUFFER_LEVEL_SECONDARY`), or for primary command buffers that are intended to be submitted
  to multiple queues concurrently (`VK_COMMAND_BUFFER_USAGE_SIMULTANEOUS_USE_BIT`).
- For primary command buffers that are intended to be reused (`VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT`
  is not set), prefilling will only apply to the first submission. Later submissions of the same command buffer
  will behave as if this configuration parameter is set to `0`.
- If you have recorded commands to a _Vulkan_ command buffer, and then choose to reset that command buffer
  instead of submitting it, the corresponding prefilled _Metal_ command buffer will still be submitted.
  This is because _Metal_ command buffers do not support the concept of being reset after being filled.
  Depending on when and how often you do this, it may cause unexpected visual artifacts and unnecessary GPU load.
- This configuration is incompatible with updating descriptors after binding. If any of the _UpdateAfterBind_
  feature flags of `VkPhysicalDeviceDescriptorIndexingFeatures` or `VkPhysicalDeviceInlineUniformBlockFeatures`
  have been enabled, the value of this parameter will be ignored and treated as if it is `0`.


---------------------------------------
#### MVK_CONFIG_RESUME_LOST_DEVICE

##### Type: Boolean
##### Default: `0`

Controls whether **MoltenVK** should treat a lost `VkDevice` as resumable, unless the corresponding
`VkPhysicalDevice` has also been lost. The `VK_ERROR_DEVICE_LOST` error has a broad definitional range,
and can mean anything from a GPU hiccup on the current command buffer submission, to a physically removed
GPU. In the case where this error does not impact the `VkPhysicalDevice`, _Vulkan_ requires that the app
destroy and re-create a new `VkDevice`. However, not all apps (including CTS) respect that requirement,
leading to what might be a transient command submission failure causing an unexpected catastrophic app failure.

If this parameter is enabled, in the case of a `VK_ERROR_DEVICE_LOST` error that does NOT impact
the `VkPhysicalDevice`, **MoltenVK** will log the error, but will not mark the `VkDevice` as lost,
allowing the `VkDevice` to continue to be used. If this parameter is disabled, **MoltenVK** will
mark the `VkDevice` as lost, and subsequent use of that `VkDevice` will be reduced or prohibited.


---------------------------------------
#### MVK_CONFIG_SHADER_COMPRESSION_ALGORITHM

##### Type: Enumeration
- `0`: No compression.
- `1`: `LZFSE`: Apple proprietary. Good balance of high performance and small compression size, particularly for larger data content.
- `2`: `ZLib`: Open cross-platform format. For smaller data content, has better performance and smaller size than `LZFSE`.
- `3`: `LZ4`: Fastest performance. Largest compression size.
- `4`: `LZMA`: Slowest performance. Smallest compression size, particular with larger content.

##### Default: `0`

Pipeline cache compression is available for _macOS 10.15+_, and _iOS/tvOS 13.0+_.

Controls the type of compression to use on the MSL source code that is stored in memory for use in a pipeline cache.
After being converted from SPIR-V, or loaded directly into a `VkShaderModule`, and then compiled into a `MTLLibrary`,
the MSL source code is no longer needed for operation, but it is retained so it can be written out as part of a
pipeline cache export. When a large number of shaders are loaded, this can consume significant memory. In such a case,
this parameter can be used to compress the MSL source code that is awaiting export as part of a pipeline cache.


---------------------------------------
#### MVK_CONFIG_SHADER_CONVERSION_FLIP_VERTEX_Y

##### Type: Boolean
##### Default: `1`

If enabled, MSL vertex shader code created during runtime shader conversion will
flip the Y-axis of each vertex, as the _Vulkan_ Y-axis is the inverse of *OpenGL*.

An alternate way to reverse the Y-axis is to employ a negative Y-axis value on
the viewport, in which case this parameter can be disabled.


---------------------------------------
#### MVK_CONFIG_SHOULD_MAXIMIZE_CONCURRENT_COMPILATION

##### Type: Boolean
##### Default: `0`

Maximize the concurrent executing compilation tasks.

To have effect, this parameter requires _macOS 13.3+_, and has no effect on _iOS_ or _tvOS_.


---------------------------------------
#### MVK_CONFIG_SPECIALIZED_QUEUE_FAMILIES

##### Type: Boolean
##### Default: `0`

_Metal_ does not distinguish functionality between queues, which would normally mean only a single
general-purpose queue family with multiple queues is needed. However, _Vulkan_ associates command
buffers with a queue family, whereas _Metal_ associates command buffers with a specific _Metal_ queue.
In order to allow a _Metal_ command buffer to be prefilled before it is formally submitted to a _Vulkan_ queue,
each _Vulkan_ queue family can support only a single _Metal_ queue. As a result, in order to provide parallel
queue operations, **MoltenVK** provides multiple queue families, each with a single queue.

If this parameter is disabled, all queue families will be advertised as having general-purpose
graphics + compute + transfer functionality, which is how the actual _Metal_ queues behave.

If this parameter is enabled, one queue family will be advertised as having general-purpose
graphics + compute + transfer functionality, and the remaining queue families will be advertised
as having specialized graphics *or* compute *or* transfer functionality, to make it easier for some
apps to select a queue family with the appropriate requirements.


---------------------------------------
#### MVK_CONFIG_SUPPORT_LARGE_QUERY_POOLS

##### Type: Boolean
##### Default: `1`

Depending on the GPU, _Metal_ allows 8,192 or 32,768 occlusion queries per `MTLBuffer`.
If enabled, **MoltenVK** allocates a `MTLBuffer` for each query pool, allowing each query
pool to support that permitted number of queries. This may slow performance or cause
unexpected behaviour if the query pool is not established prior to a _Metal_ renderpass,
or if the query pool is changed within a renderpass. If disabled, one `MTLBuffer` will
be shared by all query pools, which improves performance, but limits the total device
queries to the permitted number.


---------------------------------------
#### MVK_CONFIG_SWAPCHAIN_MIN_MAG_FILTER_USE_NEAREST

##### Type: Boolean
##### Default: `1`

If enabled, swapchain images will use simple _Nearest_ sampling when minifying or magnifying
the swapchain image to fit a physical display surface. If disabled, swapchain images will
use _Linear_ sampling when magnifying the swapchain image to fit a physical display surface.
Enabling this setting avoids smearing effects when swapchain images are simple interger
multiples of display pixels (eg- _macOS Retina_, and typical of graphics apps and games),
but may cause aliasing effects when using non-integer display scaling.


---------------------------------------
#### MVK_CONFIG_SWITCH_SYSTEM_GPU

##### Type: Boolean
##### Default: `1`

If enabled, when the app creates a `VkDevice` from a `VkPhysicalDevice` (GPU) that is neither
headless nor low-power, and is different than the GPU used by the windowing system, the
windowing system will be forced to switch to use the GPU selected by the _Vulkan_ app.
When the _Vulkan_ app is ended, the windowing system will automatically switch back to
using the previous GPU, depending on the usage requirements of other running apps.

If disabled, the _Vulkan_ app will render using its selected GPU, and if the windowing
system uses a different GPU, the windowing system compositor will automatically copy
framebuffer content from the app GPU to the windowing system GPU.

The value of this parmeter has no effect on systems with a single GPU, or when the
_Vulkan_ app creates a `VkDevice` from a low-power or headless `VkPhysicalDevice` (GPU).

Switching the windowing system GPU to match the _Vulkan_ app GPU maximizes app performance,
because it avoids the windowing system compositor from having to copy framebuffer content
between GPUs on each rendered frame. However, doing so forces the entire system to
potentially switch to using a GPU that may consume more power while the app is running.

Some _Vulkan_ apps may want to render using a high-power GPU, but leave it up to the
system window compositor to determine how best to blend content with the windowing
system, and as a result, may want to disable this parameter.


---------------------------------------
#### MVK_CONFIG_SYNCHRONOUS_QUEUE_SUBMITS

##### Type: Boolean
##### Default: `1`

_(The default value is `0` for OS versions prior to macOS 10.14+/iOS 12+)._

If enabled, queue command submissions `vkQueueSubmit()` and `vkQueuePresentKHR()`
will be processed on the thread that called the submission function. If disabled,
processing will be dispatched to a GCD `dispatch_queue` whose priority is determined
by `VkDeviceQueueCreateInfo::pQueuePriorities` during `vkCreateDevice()`.


---------------------------------------
#### MVK_CONFIG_TEXTURE_1D_AS_2D

##### Type: Boolean
##### Default: `1`

Controls whether **MoltenVK** should use a _Metal_ 2D texture with a height of 1 for a
_Vulkan_ 1D image, or use a native _Metal_ 1D texture. _Metal_ imposes significant restrictions
on native 1D textures, including not being renderable, clearable, or permitting mipmaps.
Using a _Metal_ 2D texture allows _Vulkan_ 1D textures to support this additional functionality.


---------------------------------------
#### MVK_CONFIG_TIMESTAMP_PERIOD_LOWPASS_ALPHA

##### Type: Float32
##### Default: `1.0`

This parameter is ignored on Apple Silicon (Apple GPU) devices.

Non-Apple GPUs can have a dynamic timestamp period, which varies over time according to GPU
workload. Depending on how often the app samples the `VkPhysicalDeviceLimits::timestampPeriod`
value using `vkGetPhysicalDeviceProperties()`, the app may want up-to-date, but potentially
volatile values, or it may find average values more useful.

The value of this parameter sets the alpha `(A)` value of a simple lowpass filter on the
`timestampPeriod` value, of the form:

    TPout = (1 - A)TPout + (A * TPin)

The alpha value can be set to a float between `0.0` and `1.0`. Values of alpha closer to `0.0`
cause the value of `timestampPeriod` to vary slowly over time and be less volatile, and values
of alpha closer to `1.0` cause the value of `timestampPeriod` to vary quickly and be more volatile.

Apps that query the `timestampPeriod` value infrequently will prefer low volatility, whereas
apps that query frequently may prefer higher volatility, to track more recent changes.


---------------------------------------
#### MVK_CONFIG_TRACE_VULKAN_CALLS

##### Type: Enumeration
- `0`: No _Vulkan_ call logging.
- `1`: Log the name of each _Vulkan_ call when the call is entered.
- `2`: Log the name and thread ID of each _Vulkan_ call when the call is entered.
- `3`: Log the name of each _Vulkan_ call when the call is entered and exited.
  This effectively brackets any other logging activity within the scope of the _Vulkan_ call.
- `4`: Log the name and thread ID of each _Vulkan_ call when the call is entered, and name when exited.
  This effectively brackets any other logging activity within the scope of the _Vulkan_ call.
- `5`: Same as `3`, plus logs the time spent inside the _Vulkan_ function.
- `6`: Same as `4`, plus logs the time spent inside the _Vulkan_ function.

##### Default: `0`

Controls the information **MoltenVK** logs for each _Vulkan_ call made by the application.


---------------------------------------
#### MVK_CONFIG_USE_COMMAND_POOLING

##### Type: Boolean
##### Default: `1`

Controls whether **MoltenVK** should use pools to manage memory used when adding commands to command buffers.
If this setting is enabled, **MoltenVK** will use a pool to hold command resources for reuse during command execution.
If this setting is disabled, command memory is allocated and destroyed each time a command is executed.
This is a classic time-space trade off. When command pooling is active, the memory in the pool can be
cleared via a call to the `vkTrimCommandPoolKHR()` command.


---------------------------------------
#### MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS

##### Type: Boolean
##### Default: `1`

Controls whether **MoltenVK** should use _Metal_ argument buffers for resources defined in descriptor sets,
if _Metal_ argument buffers are supported on the platform. Using _Metal_ argument buffers dramatically
increases the number of buffers, textures and samplers that can be bound to a pipeline shader, and in most
cases improves performance.


---------------------------------------
#### MVK_CONFIG_USE_MTLHEAP

##### Type: Boolean
##### Default: `0`

Controls whether **MoltenVK** should use `MTLHeaps` for allocating textures and buffers from device memory.
If this setting is enabled, and placement `MTLHeaps` are available on the platform, **MoltenVK** will allocate a
placement `MTLHeap` for each `VkDeviceMemory` instance, and allocate textures and buffers from that placement heap.
If this parameter is disabled, **MoltenVK** will allocate textures and buffers from general device memory.

Apple recommends that `MTLHeaps` should only be used for specific requirements such as aliasing or hazard tracking,
and **MoltenVK** testing has shown that allocating multiple textures of different types or usages from one `MTLHeap`
can occassionally cause corruption issues under certain circumstances.


---------------------------------------
#### MVK_CONFIG_VK_SEMAPHORE_SUPPORT_STYLE

##### Type: Enumeration
- `0`: Limit _Vulkan_ to a single queue, with no explicit semaphore synchronization, and use _Metal's_ implicit
  guarantees that all operations submitted to a queue will give the same result as if they had been run in submission order.
- `1`: Use _Metal_ events (`MTLEvent`) when available on the platform, and where safe. This will revert to the same as `0` on some
  _NVIDIA_ GPUs and _Rosetta2_, due to potential challenges with `MTLEvents` on those platforms, or in older environments where
  `MTLEvents` are not supported.
- `2`: Always use _Metal_ events (`MTLEvent`) when available on the platform. This will revert to the same as `0` in older
  environments where `MTLEvents` are not supported.
- `3`: Use CPU callbacks upon GPU submission completion. This is the slowest technique, but allows multiple queues, compared to `0`.

##### Default: `1`

Determines the style used to implement _Vulkan_ semaphore (`VkSemaphore`) functionality in _Metal_.


In the special case of `VK_SEMAPHORE_TYPE_TIMELINE` semaphores, **MoltenVK** will always use
`MTLSharedEvent` if it is available on the platform, regardless of the value of this parameter.


---------------------------------------
#### MVK_CONFIG_USE_METAL_PRIVATE_API

##### Type: Boolean
##### Default: Value of `MVK_USE_METAL_PRIVATE_API`

If enabled, **MoltenVK** will _use_ private interfaces exposed by _Metal_ to implement _Vulkan_
features that are difficult to support otherwise.

Unlike `MVK_USE_METAL_PRIVATE_API`, this setting may be overridden at run time.

This option is not available unless **MoltenVK** was built with `MVK_USE_METAL_PRIVATE_API` set to `1`.


---------------------------------------
#### MVK_CONFIG_SHADER_DUMP_DIR

##### Type: String
##### Default: `""`

_(The default value is an empty string)._

If not empty, **MoltenVK** will dump all SPIR-V shaders, compiled MSL shaders, and pipeline shader lists to the given directory.
The directory will be non-recursively created if it doesn't already exist.
