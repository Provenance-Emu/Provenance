# README.md

_Notes by Joe_

This has two ways to compile the GPU

1. Neon mode
2. GLES Mode

> These are currently using `gpulib` which can link either of the either two static libs.
> In thoery, these could be dynamic but I'm just testing at the moment.

Status:

1. GLES - Crashes on init
2. Neon - Crashes on init
    `DEFINE GPU_NEON`
3. Unai - Crashes on init! (what even is this? Non-neon arm/cpp?) UNiversAlInterpertor?
    `DEFINE GPU_UNAI`

How to switch modes:

1. Change the static linking (if still using that) in `gpulib` to either `gpulib-neon` or `gpulib-gles`.
    I theory, I could use the `GPU_NEON` to control a `#include "../gpu/whatever-plugin.c"` right in the core code.
2. Change compiler flags in `BuildFlags.xcconfig`
    `GPU_NEON` controls the subclass and `rendersToOpenGL` var.
    Which other ones? 
    I don't recall. `USE_GPULIB` maybe?
    I didn't need `USE_GPULIB` when using my GLES version linked right into GPULIB, not sure what it does.
    TODO: Look at what `USE_GPULIB` #ifdef does
    
## GLES IS SPECIAL?

It seems it can compile in two ways,
1. Standaline, with `gpulib_if.m`
2. As a plugin, linked with `gpulib` without `gpulib_if`.

Which one works? I'm testing...
    
About my hacks:

1. gpu-gles/gpuPlugin.m,gpuFps.m :

> At some point, I don't remember what I was doing, but I made the `EAGL` code work with `EGL`.
> This is probably a stupid hack just to make things compile and would exlain why it doesn't work and crashes when trying to draw a frame.

