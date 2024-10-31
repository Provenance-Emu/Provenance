#pragma once

#include <stdint.h>

#include "libhardware.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * pixel format definitions
 */

enum {
	HAL_PIXEL_FORMAT_RGBA_8888          = 1,
	HAL_PIXEL_FORMAT_RGBX_8888          = 2,
	HAL_PIXEL_FORMAT_RGB_888            = 3,
	HAL_PIXEL_FORMAT_RGB_565            = 4,
	HAL_PIXEL_FORMAT_BGRA_8888          = 5,
	HAL_PIXEL_FORMAT_RGBA_5551          = 6,
	HAL_PIXEL_FORMAT_RGBA_4444          = 7,

	/* 0x8 - 0xFF range unavailable */

	/*
	 * 0x100 - 0x1FF
	 *
	 * This range is reserved for pixel formats that are specific to the HAL
	 * implementation.  Implementations can use any value in this range to
	 * communicate video pixel formats between their HAL modules.  These formats
	 * must not have an alpha channel.  Additionally, an EGLimage created from a
	 * gralloc buffer of one of these formats must be supported for use with the
	 * GL_OES_EGL_image_external OpenGL ES extension.
	 */

	/*
	 * Android YUV format:
	 *
	 * This format is exposed outside of the HAL to software
	 * decoders and applications.
	 * EGLImageKHR must support it in conjunction with the
	 * OES_EGL_image_external extension.
	 *
	 * YV12 is 4:2:0 YCrCb planar format comprised of a WxH Y plane followed
	 * by (W/2) x (H/2) Cr and Cb planes.
	 *
	 * This format assumes
	 * - an even width
	 * - an even height
	 * - a horizontal stride multiple of 16 pixels
	 * - a vertical stride equal to the height
	 *
	 *   y_size = stride * height
	 *   c_size = ALIGN(stride/2, 16) * height/2
	 *   size = y_size + c_size * 2
	 *   cr_offset = y_size
	 *   cb_offset = y_size + c_size
	 *
	 */
	HAL_PIXEL_FORMAT_YV12   = 0x32315659, // YCrCb 4:2:0 Planar



	/* Legacy formats (deprecated), used by ImageFormat.java */
	HAL_PIXEL_FORMAT_YCbCr_422_SP       = 0x10, // NV16
	HAL_PIXEL_FORMAT_YCrCb_420_SP       = 0x11, // NV21
	HAL_PIXEL_FORMAT_YCbCr_422_I        = 0x14, // YUY2
};

// hardware/gralloc.h

#define GRALLOC_HARDWARE_MODULE_ID "gralloc"

#define GRALLOC_HARDWARE_GPU0 "gpu0"

enum {
    /* buffer is never read in software */
    GRALLOC_USAGE_SW_READ_NEVER   = 0x00000000,
    /* buffer is rarely read in software */
    GRALLOC_USAGE_SW_READ_RARELY  = 0x00000002,
    /* buffer is often read in software */
    GRALLOC_USAGE_SW_READ_OFTEN   = 0x00000003,
    /* mask for the software read values */
    GRALLOC_USAGE_SW_READ_MASK    = 0x0000000F,

    /* buffer is never written in software */
    GRALLOC_USAGE_SW_WRITE_NEVER  = 0x00000000,
    /* buffer is never written in software */
    GRALLOC_USAGE_SW_WRITE_RARELY = 0x00000020,
    /* buffer is never written in software */
    GRALLOC_USAGE_SW_WRITE_OFTEN  = 0x00000030,
    /* mask for the software write values */
    GRALLOC_USAGE_SW_WRITE_MASK   = 0x000000F0,

    /* buffer will be used as an OpenGL ES texture */
    GRALLOC_USAGE_HW_TEXTURE      = 0x00000100,
    /* buffer will be used as an OpenGL ES render target */
    GRALLOC_USAGE_HW_RENDER       = 0x00000200,
    /* buffer will be used by the 2D hardware blitter */
    GRALLOC_USAGE_HW_2D           = 0x00000C00,
    /* buffer will be used with the framebuffer device */
    GRALLOC_USAGE_HW_FB           = 0x00001000,
    /* mask for the software usage bit-mask */
    GRALLOC_USAGE_HW_MASK         = 0x00001F00,
};


typedef const native_handle* buffer_handle_t;

/**
 * Every hardware module must have a data structure named HAL_MODULE_INFO_SYM
 * and the fields of this data structure must begin with hw_module_t
 * followed by module specific information.
 */
typedef struct gralloc_module_t {
    struct hw_module_t common;

    /*
     * (*registerBuffer)() must be called before a buffer_handle_t that has not
     * been created with (*alloc_device_t::alloc)() can be used.
     *
     * This is intended to be used with buffer_handle_t's that have been
     * received in this process through IPC.
     *
     * This function checks that the handle is indeed a valid one and prepares
     * it for use with (*lock)() and (*unlock)().
     *
     * It is not necessary to call (*registerBuffer)() on a handle created
     * with (*alloc_device_t::alloc)().
     *
     * returns an error if this buffer_handle_t is not valid.
     */
    int (*registerBuffer)(struct gralloc_module_t const* module,
            buffer_handle_t handle);

    /*
     * (*unregisterBuffer)() is called once this handle is no longer needed in
     * this process. After this call, it is an error to call (*lock)(),
     * (*unlock)(), or (*registerBuffer)().
     *
     * This function doesn't close or free the handle itself; this is done
     * by other means, usually through libcutils's native_handle_close() and
     * native_handle_free().
     *
     * It is an error to call (*unregisterBuffer)() on a buffer that wasn't
     * explicitly registered first.
     */
    int (*unregisterBuffer)(struct gralloc_module_t const* module,
            buffer_handle_t handle);

    /*
     * The (*lock)() method is called before a buffer is accessed for the
     * specified usage. This call may block, for instance if the h/w needs
     * to finish rendering or if CPU caches need to be synchronized.
     *
     * The caller promises to modify only pixels in the area specified
     * by (l,t,w,h).
     *
     * The content of the buffer outside of the specified area is NOT modified
     * by this call.
     *
     * If usage specifies GRALLOC_USAGE_SW_*, vaddr is filled with the address
     * of the buffer in virtual memory.
     *
     * THREADING CONSIDERATIONS:
     *
     * It is legal for several different threads to lock a buffer from
     * read access, none of the threads are blocked.
     *
     * However, locking a buffer simultaneously for write or read/write is
     * undefined, but:
     * - shall not result in termination of the process
     * - shall not block the caller
     * It is acceptable to return an error or to leave the buffer's content
     * into an indeterminate state.
     *
     * If the buffer was created with a usage mask incompatible with the
     * requested usage flags here, -EINVAL is returned.
     *
     */

    int (*lock)(struct gralloc_module_t const* module,
            buffer_handle_t handle, int usage,
            int l, int t, int w, int h,
            void** vaddr);


    /*
     * The (*unlock)() method must be called after all changes to the buffer
     * are completed.
     */

    int (*unlock)(struct gralloc_module_t const* module,
            buffer_handle_t handle);


    /* reserved for future use */
    int (*perform)(struct gralloc_module_t const* module,
            int operation, ... );

    /* reserved for future use */
    void* reserved_proc[7];
} gralloc_module_t;

/*****************************************************************************/

/**
 * Every device data structure must begin with hw_device_t
 * followed by module specific public methods and attributes.
 */

typedef struct alloc_device_t {
    struct hw_device_t common;

    /*
     * (*alloc)() Allocates a buffer in graphic memory with the requested
     * parameters and returns a buffer_handle_t and the stride in pixels to
     * allow the implementation to satisfy hardware constraints on the width
     * of a pixmap (eg: it may have to be multiple of 8 pixels).
     * The CALLER TAKES OWNERSHIP of the buffer_handle_t.
     *
     * Returns 0 on success or -errno on error.
     */

    int (*alloc)(struct alloc_device_t* dev,
            int w, int h, int format, int usage,
            buffer_handle_t* handle, int* stride);

    /*
     * (*free)() Frees a previously allocated buffer.
     * Behavior is undefined if the buffer is still mapped in any process,
     * but shall not result in termination of the program or security breaches
     * (allowing a process to get access to another process' buffers).
     * THIS FUNCTION TAKES OWNERSHIP of the buffer_handle_t which becomes
     * invalid after the call.
     *
     * Returns 0 on success or -errno on error.
     */
    int (*free)(struct alloc_device_t* dev,
            buffer_handle_t handle);

    /* This hook is OPTIONAL.
     *
     * If non NULL it will be caused by SurfaceFlinger on dumpsys
     */
    void (*dump)(struct alloc_device_t *dev, char *buff, int buff_len);

    void* reserved_proc[7];
} alloc_device_t;


/** convenience API for opening and closing a supported device */

static inline int gralloc_open(const struct hw_module_t* module,
        struct alloc_device_t** device) {
    return module->methods->open(module,
            GRALLOC_HARDWARE_GPU0, (struct hw_device_t**)device);
}

static inline int gralloc_close(struct alloc_device_t* device) {
    return device->common.close(&device->common);
}

// ui/egl/android_natives.h

#define ANDROID_NATIVE_MAKE_CONSTANT(a,b,c,d) \
    (((unsigned)(a)<<24)|((unsigned)(b)<<16)|((unsigned)(c)<<8)|(unsigned)(d))

#define ANDROID_NATIVE_BUFFER_MAGIC \
    ANDROID_NATIVE_MAKE_CONSTANT('_','b','f','r')


typedef struct android_native_base_t
{
	/* a magic value defined by the actual EGL native type */
	int magic;

	/* the sizeof() of the actual EGL native type */
	int version;

	void* reserved[4];

	/* reference-counting interface */
	void (*incRef)(struct android_native_base_t* base);
	void (*decRef)(struct android_native_base_t* base);
} android_native_base_t;

// ui/android_native_buffer.h

struct android_native_buffer_t
{
#ifdef __cplusplus
	constexpr android_native_buffer_t() :
		common{ANDROID_NATIVE_BUFFER_MAGIC, sizeof(android_native_buffer_t)},
		width{0}, height{0}, stride{0}, format{0}, usage{0}, reserved{}, handle{}, reserved_proc{}
	{}
#endif

	struct android_native_base_t common;

	int width;
	int height;
	int stride;
	int format;
	int usage;

	void* reserved[2];

	buffer_handle_t handle;

  void* reserved_proc[8];
};

// include/pixelflinger/format.h

enum GGLPixelFormat {
	// these constants need to match those
	// in graphics/PixelFormat.java, ui/PixelFormat.h, BlitHardware.h
	GGL_PIXEL_FORMAT_UNKNOWN    =   0,
	GGL_PIXEL_FORMAT_NONE       =   0,

	GGL_PIXEL_FORMAT_RGBA_8888   =   1,  // 4x8-bit ARGB
	GGL_PIXEL_FORMAT_RGBX_8888   =   2,  // 3x8-bit RGB stored in 32-bit chunks
	GGL_PIXEL_FORMAT_RGB_888     =   3,  // 3x8-bit RGB
	GGL_PIXEL_FORMAT_RGB_565     =   4,  // 16-bit RGB
	GGL_PIXEL_FORMAT_BGRA_8888   =   5,  // 4x8-bit BGRA
	GGL_PIXEL_FORMAT_RGBA_5551   =   6,  // 16-bit RGBA
	GGL_PIXEL_FORMAT_RGBA_4444   =   7,  // 16-bit RGBA

	GGL_PIXEL_FORMAT_A_8         =   8,  // 8-bit A
	GGL_PIXEL_FORMAT_L_8         =   9,  // 8-bit L (R=G=B = L)
	GGL_PIXEL_FORMAT_LA_88       = 0xA,  // 16-bit LA
	GGL_PIXEL_FORMAT_RGB_332     = 0xB,  // 8-bit RGB (non paletted)

	// reserved range. don't use.
	GGL_PIXEL_FORMAT_RESERVED_10 = 0x10,
	GGL_PIXEL_FORMAT_RESERVED_11 = 0x11,
	GGL_PIXEL_FORMAT_RESERVED_12 = 0x12,
	GGL_PIXEL_FORMAT_RESERVED_13 = 0x13,
	GGL_PIXEL_FORMAT_RESERVED_14 = 0x14,
	GGL_PIXEL_FORMAT_RESERVED_15 = 0x15,
	GGL_PIXEL_FORMAT_RESERVED_16 = 0x16,
	GGL_PIXEL_FORMAT_RESERVED_17 = 0x17,

	// reserved/special formats
	GGL_PIXEL_FORMAT_Z_16       =  0x18,
	GGL_PIXEL_FORMAT_S_8        =  0x19,
	GGL_PIXEL_FORMAT_SZ_24      =  0x1A,
	GGL_PIXEL_FORMAT_SZ_8       =  0x1B,

	// reserved range. don't use.
	GGL_PIXEL_FORMAT_RESERVED_20 = 0x20,
	GGL_PIXEL_FORMAT_RESERVED_21 = 0x21,
};

#ifdef __cplusplus
}
#endif
