//
// Copyright 2018 Sepehr Taghdisian (septag@github). All rights reserved.
// License: https://github.com/septag/dds-ktx#license-bsd-2-clause
//
// Many parts of this code is taken from bimg library: 
// https://github.com/bkaradzic/bimg 
//
// Copyright 2011-2019 Branimir Karadzic. All rights reserved.
// License: https://github.com/bkaradzic/bimg#license-bsd-2-clause
//
// dds-ktx.h - v1.1.0 - Reader/Writer for DDS/KTX formats
//      Parses DDS and KTX files from a memory blob, written in C99
//      
//      Supported formats:
//          For supported formats, see ddsktx_format enum. 
//          Both KTX/DDS parser supports all formats defined in ddsktx_format
//
//      Overriable macros:
//          DDSKTX_API     Define any function specifier for public functions (default: extern)
//          ddsktx_memcpy  default: memcpy(dst, src, size)
//          ddsktx_memset  default: memset(dst, v, size)
//          ddsktx_assert  default: assert(a)
//          ddsktx_strcpy  default: strcpy(dst, src)
//          ddsktx_memcmp  default: memcmp(ptr1, ptr2, size)
//          
//      API:
//          bool ddsktx_parse(ddsktx_texture_info* tc, const void* file_data, int size, ddsktx_error* err);
//              Parses texture file and fills the ddsktx_texture_info struct
//              Returns true if successfully parsed, false if failed with an error message inside ddsktx_error parameter (optional)
//              After format is parsed, you can read the contents of ddsktx_format and create your GPU texture
//              To get pointer to mips and slices see ddsktx_get_sub function
//          
//          void ddsktx_get_sub(const ddsktx_texture_info* tex, ddsktx_sub_data* buff, 
//                           const void* file_data, int size,
//                           int array_idx, int slice_face_idx, int mip_idx);
//              Gets sub-image data, form a parsed texture file
//              user must provided the container object and the original file data which was passed to ddsktx_parse
//              array_idx: array index (0..num_layers)
//              slice_face_idx: depth-slice or cube-face index. 
//                              if 'flags' have DDSKTX_TEXTURE_FLAG_CUBEMAP bit, then this value represents cube-face-index (0..DDSKTX_CUBE_FACE_COUNT)
//                              else it represents depth slice index (0..depth)
//              mip_idx: mip index (0..num_mips-1 in ddsktx_texture_info)
//          
//          const char* ddsktx_format_str(ddsktx_format format);
//              Converts a format enumeration to string
//
//          bool ddsktx_format_compressed(ddsktx_format format);
//              Returns true if format is compressed
//
//      Example (for 2D textures only): 
//          int size;
//          void* dds_data = load_file("test.dds", &size);
//          assert(dds_data);
//          ddsktx_texture_info tc = {0};
//          if (ddsktx_parse(&tc, dds_data, size, NULL)) {
//              assert(tc.depth == 1);
//              assert(!(tc.flags & DDSKTX_TEXTURE_FLAG_CUBEMAP));
//              assert(tc.num_layers == 1);
//              // Create GPU texture from tc data
//              for (int mip = 0; mip < tc->num_mips; mip++) {
//                  ddsktx_sub_data sub_data;
//                  ddsktx_get_sub(&tc, &sub_data, dds_data, size, 0, 0, mip);
//                  // Fill/Set texture sub resource data (mips in this case)
//              }
//          }
//          free(dds_data);     // memory must be valid during stc_ calls
//
// Version history:
//      0.9.0       Initial release, ktx is incomplete
//      1.0.0       Api change: ddsktx_sub_data
//                  Added KTX support
//      1.0.1       Fixed major bugs in KTX parsing
//      1.1.0       Fixed bugs in get_sub routine, refactored some parts, image-viewer example
//
// TODO
//      Write KTX/DDS
//      Read KTX metadata. currently it just stores the offset/size to the metadata block
//

 #pragma once

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#ifndef DDSKTX_API
#   ifdef __cplusplus
#       define DDSKTX_API extern "C" 
#   else
#       define DDSKTX_API  
#   endif
#endif

typedef struct ddsktx_sub_data
{
    const void* buff;
    int         width;
    int         height;
    int         size_bytes;
    int         row_pitch_bytes;
} ddsktx_sub_data;

typedef enum ddsktx_format
{
    DDSKTX_FORMAT_BC1,         // DXT1
    DDSKTX_FORMAT_BC2,         // DXT3
    DDSKTX_FORMAT_BC3,         // DXT5
    DDSKTX_FORMAT_BC4,         // ATI1
    DDSKTX_FORMAT_BC5,         // ATI2
    DDSKTX_FORMAT_BC6H,        // BC6H
    DDSKTX_FORMAT_BC7,         // BC7
    DDSKTX_FORMAT_ETC1,        // ETC1 RGB8
    DDSKTX_FORMAT_ETC2,        // ETC2 RGB8
    DDSKTX_FORMAT_ETC2A,       // ETC2 RGBA8
    DDSKTX_FORMAT_ETC2A1,      // ETC2 RGBA8A1
    DDSKTX_FORMAT_PTC12,       // PVRTC1 RGB 2bpp
    DDSKTX_FORMAT_PTC14,       // PVRTC1 RGB 4bpp
    DDSKTX_FORMAT_PTC12A,      // PVRTC1 RGBA 2bpp
    DDSKTX_FORMAT_PTC14A,      // PVRTC1 RGBA 4bpp
    DDSKTX_FORMAT_PTC22,       // PVRTC2 RGBA 2bpp
    DDSKTX_FORMAT_PTC24,       // PVRTC2 RGBA 4bpp
    DDSKTX_FORMAT_ATC,         // ATC RGB 4BPP
    DDSKTX_FORMAT_ATCE,        // ATCE RGBA 8 BPP explicit alpha
    DDSKTX_FORMAT_ATCI,        // ATCI RGBA 8 BPP interpolated alpha
    DDSKTX_FORMAT_ASTC4x4,     // ASTC 4x4 8.0 BPP
    DDSKTX_FORMAT_ASTC5x5,     // ASTC 5x5 5.12 BPP
    DDSKTX_FORMAT_ASTC6x6,     // ASTC 6x6 3.56 BPP
    DDSKTX_FORMAT_ASTC8x5,     // ASTC 8x5 3.20 BPP
    DDSKTX_FORMAT_ASTC8x6,     // ASTC 8x6 2.67 BPP
    DDSKTX_FORMAT_ASTC10x5,    // ASTC 10x5 2.56 BPP
    _DDSKTX_FORMAT_COMPRESSED,
    DDSKTX_FORMAT_A8,
    DDSKTX_FORMAT_R8,
    DDSKTX_FORMAT_RGBA8,
    DDSKTX_FORMAT_RGBA8S,
    DDSKTX_FORMAT_RG16,
    DDSKTX_FORMAT_RGB8,
    DDSKTX_FORMAT_R16,
    DDSKTX_FORMAT_R32F,
    DDSKTX_FORMAT_R16F,
    DDSKTX_FORMAT_RG16F,
    DDSKTX_FORMAT_RG16S,
    DDSKTX_FORMAT_RGBA16F,
    DDSKTX_FORMAT_RGBA16,
    DDSKTX_FORMAT_BGRA8,
    DDSKTX_FORMAT_RGB10A2,
    DDSKTX_FORMAT_RG11B10F,
    DDSKTX_FORMAT_RG8,
    DDSKTX_FORMAT_RG8S,
    _DDSKTX_FORMAT_COUNT
} ddsktx_format;

typedef enum ddsktx_texture_flags
{
    DDSKTX_TEXTURE_FLAG_CUBEMAP = 0x01,       
    DDSKTX_TEXTURE_FLAG_SRGB    = 0x02,        
    DDSKTX_TEXTURE_FLAG_ALPHA   = 0x04,       // Has alpha channel
    DDSKTX_TEXTURE_FLAG_DDS     = 0x08,       // container was DDS file
    DDSKTX_TEXTURE_FLAG_KTX     = 0x10,       // container was KTX file
    DDSKTX_TEXTURE_FLAG_VOLUME  = 0x20,       // 3D volume
} ddsktx_texture_flags;

typedef struct ddsktx_texture_info
{
    int                 data_offset;   // start offset of pixel data
    int                 size_bytes;
    ddsktx_format       format;
    unsigned int        flags;         // ddsktx_texture_flags
    int                 width;
    int                 height;
    int                 depth;
    int                 num_layers;
    int                 num_mips;
    int                 bpp;
    int                 metadata_offset; // ktx only
    int                 metadata_size;   // ktx only
} ddsktx_texture_info;

typedef enum ddsktx_cube_face
{
    DDSKTX_CUBE_FACE_X_POSITIVE = 0,
    DDSKTX_CUBE_FACE_X_NEGATIVE,
    DDSKTX_CUBE_FACE_Y_POSITIVE,
    DDSKTX_CUBE_FACE_Y_NEGATIVE,
    DDSKTX_CUBE_FACE_Z_POSITIVE,
    DDSKTX_CUBE_FACE_Z_NEGATIVE,
    DDSKTX_CUBE_FACE_COUNT
} ddsktx_cube_face;

typedef struct ddsktx_error
{
    char msg[256];
} ddsktx_error;

#ifdef __cplusplus
#   define ddsktx_default(_v) =_v
#else
#   define ddsktx_default(_v)
#endif

DDSKTX_API bool ddsktx_parse(ddsktx_texture_info* tc, const void* file_data, int size, ddsktx_error* err ddsktx_default(NULL));
DDSKTX_API void ddsktx_get_sub(const ddsktx_texture_info* tex, ddsktx_sub_data* buff, 
                         const void* file_data, int size,
                         int array_idx, int slice_face_idx, int mip_idx);
DDSKTX_API const char* ddsktx_format_str(ddsktx_format format);
DDSKTX_API bool        ddsktx_format_compressed(ddsktx_format format);

////////////////////////////////////////////////////////////////////////////////////////////////////
// Implementation
#ifdef DDSKTX_IMPLEMENT

#define stc__makefourcc(_a, _b, _c, _d) ( ( (uint32_t)(_a) | ( (uint32_t)(_b) << 8) | \
                                        ( (uint32_t)(_c) << 16) | ( (uint32_t)(_d) << 24) ) )

// DDS: https://docs.microsoft.com/en-us/windows/desktop/direct3ddds/dx-graphics-dds-pguide
#define DDSKTX__DDS_HEADER_SIZE 124
#define DDSKTX__DDS_MAGIC       stc__makefourcc('D', 'D', 'S', ' ')
#define DDSKTX__DDS_DXT1        stc__makefourcc('D', 'X', 'T', '1')
#define DDSKTX__DDS_DXT2        stc__makefourcc('D', 'X', 'T', '2')
#define DDSKTX__DDS_DXT3        stc__makefourcc('D', 'X', 'T', '3')
#define DDSKTX__DDS_DXT4        stc__makefourcc('D', 'X', 'T', '4')
#define DDSKTX__DDS_DXT5        stc__makefourcc('D', 'X', 'T', '5')
#define DDSKTX__DDS_ATI1        stc__makefourcc('A', 'T', 'I', '1')
#define DDSKTX__DDS_BC4U        stc__makefourcc('B', 'C', '4', 'U')
#define DDSKTX__DDS_ATI2        stc__makefourcc('A', 'T', 'I', '2')
#define DDSKTX__DDS_BC5U        stc__makefourcc('B', 'C', '5', 'U')
#define DDSKTX__DDS_DX10        stc__makefourcc('D', 'X', '1', '0')

#define DDSKTX__DDS_ETC1        stc__makefourcc('E', 'T', 'C', '1')
#define DDSKTX__DDS_ETC2        stc__makefourcc('E', 'T', 'C', '2')
#define DDSKTX__DDS_ET2A        stc__makefourcc('E', 'T', '2', 'A')
#define DDSKTX__DDS_PTC2        stc__makefourcc('P', 'T', 'C', '2')
#define DDSKTX__DDS_PTC4        stc__makefourcc('P', 'T', 'C', '4')
#define DDSKTX__DDS_ATC         stc__makefourcc('A', 'T', 'C', ' ')
#define DDSKTX__DDS_ATCE        stc__makefourcc('A', 'T', 'C', 'E')
#define DDSKTX__DDS_ATCI        stc__makefourcc('A', 'T', 'C', 'I')
#define DDSKTX__DDS_ASTC4x4     stc__makefourcc('A', 'S', '4', '4')
#define DDSKTX__DDS_ASTC5x5     stc__makefourcc('A', 'S', '5', '5')
#define DDSKTX__DDS_ASTC6x6     stc__makefourcc('A', 'S', '6', '6')
#define DDSKTX__DDS_ASTC8x5     stc__makefourcc('A', 'S', '8', '5')
#define DDSKTX__DDS_ASTC8x6     stc__makefourcc('A', 'S', '8', '6')
#define DDSKTX__DDS_ASTC10x5    stc__makefourcc('A', 'S', ':', '5')

#define DDSKTX__DDS_R8G8B8         20
#define DDSKTX__DDS_A8R8G8B8       21
#define DDSKTX__DDS_R5G6B5         23
#define DDSKTX__DDS_A1R5G5B5       25
#define DDSKTX__DDS_A4R4G4B4       26
#define DDSKTX__DDS_A2B10G10R10    31
#define DDSKTX__DDS_G16R16         34
#define DDSKTX__DDS_A2R10G10B10    35
#define DDSKTX__DDS_A16B16G16R16   36
#define DDSKTX__DDS_A8L8           51
#define DDSKTX__DDS_R16F           111
#define DDSKTX__DDS_G16R16F        112
#define DDSKTX__DDS_A16B16G16R16F  113
#define DDSKTX__DDS_R32F           114
#define DDSKTX__DDS_G32R32F        115
#define DDSKTX__DDS_A32B32G32R32F  116

#define DDSKTX__DDS_FORMAT_R32G32B32A32_FLOAT  2
#define DDSKTX__DDS_FORMAT_R32G32B32A32_UINT   3
#define DDSKTX__DDS_FORMAT_R16G16B16A16_FLOAT  10
#define DDSKTX__DDS_FORMAT_R16G16B16A16_UNORM  11
#define DDSKTX__DDS_FORMAT_R16G16B16A16_UINT   12
#define DDSKTX__DDS_FORMAT_R32G32_FLOAT        16
#define DDSKTX__DDS_FORMAT_R32G32_UINT         17
#define DDSKTX__DDS_FORMAT_R10G10B10A2_UNORM   24
#define DDSKTX__DDS_FORMAT_R11G11B10_FLOAT     26
#define DDSKTX__DDS_FORMAT_R8G8B8A8_UNORM      28
#define DDSKTX__DDS_FORMAT_R8G8B8A8_UNORM_SRGB 29
#define DDSKTX__DDS_FORMAT_R16G16_FLOAT        34
#define DDSKTX__DDS_FORMAT_R16G16_UNORM        35
#define DDSKTX__DDS_FORMAT_R32_FLOAT           41
#define DDSKTX__DDS_FORMAT_R32_UINT            42
#define DDSKTX__DDS_FORMAT_R8G8_UNORM          49
#define DDSKTX__DDS_FORMAT_R16_FLOAT           54
#define DDSKTX__DDS_FORMAT_R16_UNORM           56
#define DDSKTX__DDS_FORMAT_R8_UNORM            61
#define DDSKTX__DDS_FORMAT_R1_UNORM            66
#define DDSKTX__DDS_FORMAT_BC1_UNORM           71
#define DDSKTX__DDS_FORMAT_BC1_UNORM_SRGB      72
#define DDSKTX__DDS_FORMAT_BC2_UNORM           74
#define DDSKTX__DDS_FORMAT_BC2_UNORM_SRGB      75
#define DDSKTX__DDS_FORMAT_BC3_UNORM           77
#define DDSKTX__DDS_FORMAT_BC3_UNORM_SRGB      78
#define DDSKTX__DDS_FORMAT_BC4_UNORM           80
#define DDSKTX__DDS_FORMAT_BC5_UNORM           83
#define DDSKTX__DDS_FORMAT_B5G6R5_UNORM        85
#define DDSKTX__DDS_FORMAT_B5G5R5A1_UNORM      86
#define DDSKTX__DDS_FORMAT_B8G8R8A8_UNORM      87
#define DDSKTX__DDS_FORMAT_B8G8R8A8_UNORM_SRGB 91
#define DDSKTX__DDS_FORMAT_BC6H_SF16           96
#define DDSKTX__DDS_FORMAT_BC7_UNORM           98
#define DDSKTX__DDS_FORMAT_BC7_UNORM_SRGB      99
#define DDSKTX__DDS_FORMAT_B4G4R4A4_UNORM      115

#define DDSKTX__DDS_DX10_DIMENSION_TEXTURE2D 3
#define DDSKTX__DDS_DX10_DIMENSION_TEXTURE3D 4
#define DDSKTX__DDS_DX10_MISC_TEXTURECUBE    4

#define DDSKTX__DDSD_CAPS                  0x00000001
#define DDSKTX__DDSD_HEIGHT                0x00000002
#define DDSKTX__DDSD_WIDTH                 0x00000004
#define DDSKTX__DDSD_PITCH                 0x00000008
#define DDSKTX__DDSD_PIXELFORMAT           0x00001000
#define DDSKTX__DDSD_MIPMAPCOUNT           0x00020000
#define DDSKTX__DDSD_LINEARSIZE            0x00080000
#define DDSKTX__DDSD_DEPTH                 0x00800000

#define DDSKTX__DDPF_ALPHAPIXELS           0x00000001
#define DDSKTX__DDPF_ALPHA                 0x00000002
#define DDSKTX__DDPF_FOURCC                0x00000004
#define DDSKTX__DDPF_INDEXED               0x00000020
#define DDSKTX__DDPF_RGB                   0x00000040
#define DDSKTX__DDPF_YUV                   0x00000200
#define DDSKTX__DDPF_LUMINANCE             0x00020000
#define DDSKTX__DDPF_BUMPDUDV              0x00080000

#define DDSKTX__DDSCAPS_COMPLEX            0x00000008
#define DDSKTX__DDSCAPS_TEXTURE            0x00001000
#define DDSKTX__DDSCAPS_MIPMAP             0x00400000

#define DDSKTX__DDSCAPS2_VOLUME            0x00200000
#define DDSKTX__DDSCAPS2_CUBEMAP           0x00000200
#define DDSKTX__DDSCAPS2_CUBEMAP_POSITIVEX 0x00000400
#define DDSKTX__DDSCAPS2_CUBEMAP_NEGATIVEX 0x00000800
#define DDSKTX__DDSCAPS2_CUBEMAP_POSITIVEY 0x00001000
#define DDSKTX__DDSCAPS2_CUBEMAP_NEGATIVEY 0x00002000
#define DDSKTX__DDSCAPS2_CUBEMAP_POSITIVEZ 0x00004000
#define DDSKTX__DDSCAPS2_CUBEMAP_NEGATIVEZ 0x00008000

#define DDSKTX__DDSCAPS2_CUBEMAP_ALLSIDES (0      \
            | DDSKTX__DDSCAPS2_CUBEMAP_POSITIVEX \
            | DDSKTX__DDSCAPS2_CUBEMAP_NEGATIVEX \
            | DDSKTX__DDSCAPS2_CUBEMAP_POSITIVEY \
            | DDSKTX__DDSCAPS2_CUBEMAP_NEGATIVEY \
            | DDSKTX__DDSCAPS2_CUBEMAP_POSITIVEZ \
            | DDSKTX__DDSCAPS2_CUBEMAP_NEGATIVEZ )

#pragma pack(push, 1)
typedef struct ddsktx__dds_pixel_format
{
    uint32_t size;
    uint32_t flags;
    uint32_t fourcc;
    uint32_t rgb_bit_count;
    uint32_t bit_mask[4];
} ddsktx__dds_pixel_format;

// https://docs.microsoft.com/en-us/windows/desktop/direct3ddds/dds-header
typedef struct ddsktx__dds_header
{
    uint32_t                size;
    uint32_t                flags;
    uint32_t                height;
    uint32_t                width;
    uint32_t                pitch_lin_size;
    uint32_t                depth;
    uint32_t                mip_count;
    uint32_t                reserved1[11];
    ddsktx__dds_pixel_format   pixel_format;
    uint32_t                caps1;
    uint32_t                caps2;
    uint32_t                caps3;
    uint32_t                caps4;
    uint32_t                reserved2;
} ddsktx__dds_header;

// https://docs.microsoft.com/en-us/windows/desktop/direct3ddds/dds-header-dxt10
typedef struct ddsktx__dds_header_dxgi
{
    uint32_t dxgi_format;
    uint32_t dimension;
    uint32_t misc_flags;
    uint32_t array_size;
    uint32_t misc_flags2;
} ddsktx__dds_header_dxgi;

typedef struct ddsktx__ktx_header
{
    uint8_t  id[8];
    uint32_t endianess;
    uint32_t type;
    uint32_t type_size;
    uint32_t format;
    uint32_t internal_format;
    uint32_t base_internal_format;
    uint32_t width;
    uint32_t height;
    uint32_t depth;
    uint32_t array_count;
    uint32_t face_count;
    uint32_t mip_count;
    uint32_t metadata_size;
} ddsktx__ktx_header;
#pragma pack(pop)

typedef struct ddsktx__dds_translate_fourcc_format
{
    uint32_t            dds_format;
    ddsktx_format  format;
    bool                srgb;
} ddsktx__dds_translate_fourcc_format;

typedef struct ddsktx__dds_translate_pixel_format
{
    uint32_t            bit_count;
    uint32_t            flags;
    uint32_t            bit_mask[4];
    ddsktx_format  format;
} ddsktx__dds_translate_pixel_format;

typedef struct ddsktx__mem_reader
{
    const uint8_t* buff;
    int            total;
    int            offset;
} ddsktx__mem_reader;

typedef struct ddsktx__block_info
{
    uint8_t bpp;
    uint8_t block_width;
    uint8_t block_height;
    uint8_t block_size;
    uint8_t min_block_x;
    uint8_t min_block_y;
    uint8_t depth_bits;
    uint8_t stencil_bits;
    uint8_t r_bits;
    uint8_t g_bits;
    uint8_t b_bits;
    uint8_t a_bits;
    uint8_t encoding;    
} ddsktx__block_info;

#ifndef ddsktx_memcpy
#   include <string.h>
#   define ddsktx_memcpy(_dst, _src, _size)    memcpy((_dst), (_src), (_size))
#endif

#ifndef ddsktx_memset
#   include <string.h>
#   define ddsktx_memset(_dst, _v, _size)      memset((_dst), (_v), (_size))
#endif

#ifndef ddsktx_assert
#   include <assert.h>
#   define ddsktx_assert(_a)       assert(_a)
#endif

#ifndef ddsktx_strcpy
#   include <string.h>
#   ifdef _MSC_VER
#       define ddsktx_strcpy(_dst, _src)   strcpy_s((_dst), sizeof(_dst), (_src))
#   else
#       define ddsktx_strcpy(_dst, _src)   strcpy((_dst), (_src))
#   endif
#endif

#ifndef ddsktx_memcmp
#   include <string.h>
#   define ddsktx_memcmp(_ptr1, _ptr2, _num) memcmp((_ptr1), (_ptr2), (_num))
#endif

#define ddsktx__max(a, b)                  ((a) > (b) ? (a) : (b))
#define ddsktx__min(a, b)                  ((a) < (b) ? (a) : (b))
#define ddsktx__align_mask(_value, _mask)  (((_value)+(_mask)) & ((~0)&(~(_mask))))
#define ddsktx__err(_err, _msg)            if (_err)  ddsktx_strcpy(_err->msg, _msg);   return false

static const ddsktx__dds_translate_fourcc_format k__translate_dds_fourcc[] = {
    { DDSKTX__DDS_DXT1,                  DDSKTX_FORMAT_BC1,     false },
    { DDSKTX__DDS_DXT2,                  DDSKTX_FORMAT_BC2,     false },
    { DDSKTX__DDS_DXT3,                  DDSKTX_FORMAT_BC2,     false },
    { DDSKTX__DDS_DXT4,                  DDSKTX_FORMAT_BC3,     false },
    { DDSKTX__DDS_DXT5,                  DDSKTX_FORMAT_BC3,     false },
    { DDSKTX__DDS_ATI1,                  DDSKTX_FORMAT_BC4,     false },
    { DDSKTX__DDS_BC4U,                  DDSKTX_FORMAT_BC4,     false },
    { DDSKTX__DDS_ATI2,                  DDSKTX_FORMAT_BC5,     false },
    { DDSKTX__DDS_BC5U,                  DDSKTX_FORMAT_BC5,     false },
    { DDSKTX__DDS_ETC1,                  DDSKTX_FORMAT_ETC1,     false },
    { DDSKTX__DDS_ETC2,                  DDSKTX_FORMAT_ETC2,     false },
    { DDSKTX__DDS_ET2A,                  DDSKTX_FORMAT_ETC2A,    false },
    { DDSKTX__DDS_PTC2,                  DDSKTX_FORMAT_PTC12A,   false },
    { DDSKTX__DDS_PTC4,                  DDSKTX_FORMAT_PTC14A,   false },
    { DDSKTX__DDS_ATC ,                  DDSKTX_FORMAT_ATC,      false },
    { DDSKTX__DDS_ATCE,                  DDSKTX_FORMAT_ATCE,     false },
    { DDSKTX__DDS_ATCI,                  DDSKTX_FORMAT_ATCI,     false },
    { DDSKTX__DDS_ASTC4x4,               DDSKTX_FORMAT_ASTC4x4,  false },
    { DDSKTX__DDS_ASTC5x5,               DDSKTX_FORMAT_ASTC5x5,  false },
    { DDSKTX__DDS_ASTC6x6,               DDSKTX_FORMAT_ASTC6x6,  false },
    { DDSKTX__DDS_ASTC8x5,               DDSKTX_FORMAT_ASTC8x5,  false },
    { DDSKTX__DDS_ASTC8x6,               DDSKTX_FORMAT_ASTC8x6,  false },
    { DDSKTX__DDS_ASTC10x5,              DDSKTX_FORMAT_ASTC10x5, false },
    { DDSKTX__DDS_A16B16G16R16,          DDSKTX_FORMAT_RGBA16,  false },
    { DDSKTX__DDS_A16B16G16R16F,         DDSKTX_FORMAT_RGBA16F, false },
    { DDSKTX__DDPF_RGB|DDSKTX__DDPF_ALPHAPIXELS, DDSKTX_FORMAT_BGRA8,   false },
    { DDSKTX__DDPF_INDEXED,              DDSKTX_FORMAT_R8,      false },
    { DDSKTX__DDPF_LUMINANCE,            DDSKTX_FORMAT_R8,      false },
    { DDSKTX__DDPF_ALPHA,                DDSKTX_FORMAT_R8,      false },
    { DDSKTX__DDS_R16F,                  DDSKTX_FORMAT_R16F,    false },
    { DDSKTX__DDS_R32F,                  DDSKTX_FORMAT_R32F,    false },
    { DDSKTX__DDS_A8L8,                  DDSKTX_FORMAT_RG8,     false },
    { DDSKTX__DDS_G16R16,                DDSKTX_FORMAT_RG16,    false },
    { DDSKTX__DDS_G16R16F,               DDSKTX_FORMAT_RG16F,   false },
    { DDSKTX__DDS_R8G8B8,                DDSKTX_FORMAT_RGB8,    false },
    { DDSKTX__DDS_A8R8G8B8,              DDSKTX_FORMAT_BGRA8,   false },
    { DDSKTX__DDS_A16B16G16R16,          DDSKTX_FORMAT_RGBA16,  false },
    { DDSKTX__DDS_A16B16G16R16F,         DDSKTX_FORMAT_RGBA16F, false },
    { DDSKTX__DDS_A2B10G10R10,           DDSKTX_FORMAT_RGB10A2, false },
};

static const ddsktx__dds_translate_fourcc_format k__translate_dxgi[] = {
    { DDSKTX__DDS_FORMAT_BC1_UNORM,           DDSKTX_FORMAT_BC1,        false },
    { DDSKTX__DDS_FORMAT_BC1_UNORM_SRGB,      DDSKTX_FORMAT_BC1,        true  },
    { DDSKTX__DDS_FORMAT_BC2_UNORM,           DDSKTX_FORMAT_BC2,        false },
    { DDSKTX__DDS_FORMAT_BC2_UNORM_SRGB,      DDSKTX_FORMAT_BC2,        true  },
    { DDSKTX__DDS_FORMAT_BC3_UNORM,           DDSKTX_FORMAT_BC3,        false },
    { DDSKTX__DDS_FORMAT_BC3_UNORM_SRGB,      DDSKTX_FORMAT_BC3,        true  },
    { DDSKTX__DDS_FORMAT_BC4_UNORM,           DDSKTX_FORMAT_BC4,        false },
    { DDSKTX__DDS_FORMAT_BC5_UNORM,           DDSKTX_FORMAT_BC5,        false },
    { DDSKTX__DDS_FORMAT_BC6H_SF16,           DDSKTX_FORMAT_BC6H,       false },
    { DDSKTX__DDS_FORMAT_BC7_UNORM,           DDSKTX_FORMAT_BC7,        false },
    { DDSKTX__DDS_FORMAT_BC7_UNORM_SRGB,      DDSKTX_FORMAT_BC7,        true  },

    { DDSKTX__DDS_FORMAT_R8_UNORM,            DDSKTX_FORMAT_R8,         false },
    { DDSKTX__DDS_FORMAT_R16_UNORM,           DDSKTX_FORMAT_R16,        false },
    { DDSKTX__DDS_FORMAT_R16_FLOAT,           DDSKTX_FORMAT_R16F,       false },
    { DDSKTX__DDS_FORMAT_R32_FLOAT,           DDSKTX_FORMAT_R32F,       false },
    { DDSKTX__DDS_FORMAT_R8G8_UNORM,          DDSKTX_FORMAT_RG8,        false },
    { DDSKTX__DDS_FORMAT_R16G16_UNORM,        DDSKTX_FORMAT_RG16,       false },
    { DDSKTX__DDS_FORMAT_R16G16_FLOAT,        DDSKTX_FORMAT_RG16F,      false },
    { DDSKTX__DDS_FORMAT_B8G8R8A8_UNORM,      DDSKTX_FORMAT_BGRA8,      false },
    { DDSKTX__DDS_FORMAT_B8G8R8A8_UNORM_SRGB, DDSKTX_FORMAT_BGRA8,      true  },
    { DDSKTX__DDS_FORMAT_R8G8B8A8_UNORM,      DDSKTX_FORMAT_RGBA8,      false },
    { DDSKTX__DDS_FORMAT_R8G8B8A8_UNORM_SRGB, DDSKTX_FORMAT_RGBA8,      true  },
    { DDSKTX__DDS_FORMAT_R16G16B16A16_UNORM,  DDSKTX_FORMAT_RGBA16,     false },
    { DDSKTX__DDS_FORMAT_R16G16B16A16_FLOAT,  DDSKTX_FORMAT_RGBA16F,    false },
    { DDSKTX__DDS_FORMAT_R10G10B10A2_UNORM,   DDSKTX_FORMAT_RGB10A2,    false },
    { DDSKTX__DDS_FORMAT_R11G11B10_FLOAT,     DDSKTX_FORMAT_RG11B10F,   false },
};

static const ddsktx__dds_translate_pixel_format k__translate_dds_pixel[] = {
    {  8, DDSKTX__DDPF_LUMINANCE,            { 0x000000ff, 0x00000000, 0x00000000, 0x00000000 }, DDSKTX_FORMAT_R8      },
    { 16, DDSKTX__DDPF_BUMPDUDV,             { 0x000000ff, 0x0000ff00, 0x00000000, 0x00000000 }, DDSKTX_FORMAT_RG8S    },
    { 24, DDSKTX__DDPF_RGB,                  { 0x00ff0000, 0x0000ff00, 0x000000ff, 0x00000000 }, DDSKTX_FORMAT_RGB8    },
    { 24, DDSKTX__DDPF_RGB,                  { 0x000000ff, 0x0000ff00, 0x00ff0000, 0x00000000 }, DDSKTX_FORMAT_RGB8    },
    { 32, DDSKTX__DDPF_RGB,                  { 0x00ff0000, 0x0000ff00, 0x000000ff, 0x00000000 }, DDSKTX_FORMAT_BGRA8   },
    { 32, DDSKTX__DDPF_RGB|DDSKTX__DDPF_ALPHAPIXELS, { 0x000000ff, 0x0000ff00, 0x00ff0000, 0xff000000 }, DDSKTX_FORMAT_RGBA8   },
    { 32, DDSKTX__DDPF_BUMPDUDV,             { 0x000000ff, 0x0000ff00, 0x00ff0000, 0xff000000 }, DDSKTX_FORMAT_RGBA8S  },
    { 32, DDSKTX__DDPF_RGB,                  { 0x00ff0000, 0x0000ff00, 0x000000ff, 0xff000000 }, DDSKTX_FORMAT_BGRA8   },
    { 32, DDSKTX__DDPF_RGB|DDSKTX__DDPF_ALPHAPIXELS, { 0x00ff0000, 0x0000ff00, 0x000000ff, 0xff000000 }, DDSKTX_FORMAT_BGRA8   }, // D3DFMT_A8R8G8B8
    { 32, DDSKTX__DDPF_RGB|DDSKTX__DDPF_ALPHAPIXELS, { 0x00ff0000, 0x0000ff00, 0x000000ff, 0x00000000 }, DDSKTX_FORMAT_BGRA8   }, // D3DFMT_X8R8G8B8
    { 32, DDSKTX__DDPF_RGB|DDSKTX__DDPF_ALPHAPIXELS, { 0x000003ff, 0x000ffc00, 0x3ff00000, 0xc0000000 }, DDSKTX_FORMAT_RGB10A2 },
    { 32, DDSKTX__DDPF_RGB,                  { 0x0000ffff, 0xffff0000, 0x00000000, 0x00000000 }, DDSKTX_FORMAT_RG16    },
    { 32, DDSKTX__DDPF_BUMPDUDV,             { 0x0000ffff, 0xffff0000, 0x00000000, 0x00000000 }, DDSKTX_FORMAT_RG16S   }
};

typedef enum ddsktx__encode_type
{
    DDSKTX__ENCODE_UNORM,
    DDSKTX__ENCODE_SNORM,
    DDSKTX__ENCODE_FLOAT,
    DDSKTX__ENCODE_INT,
    DDSKTX__ENCODE_UINT,
    DDSKTX__ENCODE_COUNT
} ddsktx__encode_type;

static const ddsktx__block_info k__block_info[] =
{
    //  +-------------------------------------------- bits per pixel
    //  |  +----------------------------------------- block width
    //  |  |  +-------------------------------------- block height
    //  |  |  |   +---------------------------------- block size
    //  |  |  |   |  +------------------------------- min blocks x
    //  |  |  |   |  |  +---------------------------- min blocks y
    //  |  |  |   |  |  |   +------------------------ depth bits
    //  |  |  |   |  |  |   |  +--------------------- stencil bits
    //  |  |  |   |  |  |   |  |   +---+---+---+----- r, g, b, a bits
    //  |  |  |   |  |  |   |  |   r   g   b   a  +-- encoding type
    //  |  |  |   |  |  |   |  |   |   |   |   |  |
    {   4, 4, 4,  8, 1, 1,  0, 0,  0,  0,  0,  0, (uint8_t)(DDSKTX__ENCODE_UNORM) }, // BC1
    {   8, 4, 4, 16, 1, 1,  0, 0,  0,  0,  0,  0, (uint8_t)(DDSKTX__ENCODE_UNORM) }, // BC2
    {   8, 4, 4, 16, 1, 1,  0, 0,  0,  0,  0,  0, (uint8_t)(DDSKTX__ENCODE_UNORM) }, // BC3
    {   4, 4, 4,  8, 1, 1,  0, 0,  0,  0,  0,  0, (uint8_t)(DDSKTX__ENCODE_UNORM) }, // BC4
    {   8, 4, 4, 16, 1, 1,  0, 0,  0,  0,  0,  0, (uint8_t)(DDSKTX__ENCODE_UNORM) }, // BC5
    {   8, 4, 4, 16, 1, 1,  0, 0,  0,  0,  0,  0, (uint8_t)(DDSKTX__ENCODE_FLOAT) }, // BC6H
    {   8, 4, 4, 16, 1, 1,  0, 0,  0,  0,  0,  0, (uint8_t)(DDSKTX__ENCODE_UNORM) }, // BC7
    {   4, 4, 4,  8, 1, 1,  0, 0,  0,  0,  0,  0, (uint8_t)(DDSKTX__ENCODE_UNORM) }, // ETC1
    {   4, 4, 4,  8, 1, 1,  0, 0,  0,  0,  0,  0, (uint8_t)(DDSKTX__ENCODE_UNORM) }, // ETC2
    {   8, 4, 4, 16, 1, 1,  0, 0,  0,  0,  0,  0, (uint8_t)(DDSKTX__ENCODE_UNORM) }, // ETC2A
    {   4, 4, 4,  8, 1, 1,  0, 0,  0,  0,  0,  0, (uint8_t)(DDSKTX__ENCODE_UNORM) }, // ETC2A1
    {   2, 8, 4,  8, 2, 2,  0, 0,  0,  0,  0,  0, (uint8_t)(DDSKTX__ENCODE_UNORM) }, // PTC12
    {   4, 4, 4,  8, 2, 2,  0, 0,  0,  0,  0,  0, (uint8_t)(DDSKTX__ENCODE_UNORM) }, // PTC14
    {   2, 8, 4,  8, 2, 2,  0, 0,  0,  0,  0,  0, (uint8_t)(DDSKTX__ENCODE_UNORM) }, // PTC12A
    {   4, 4, 4,  8, 2, 2,  0, 0,  0,  0,  0,  0, (uint8_t)(DDSKTX__ENCODE_UNORM) }, // PTC14A
    {   2, 8, 4,  8, 2, 2,  0, 0,  0,  0,  0,  0, (uint8_t)(DDSKTX__ENCODE_UNORM) }, // PTC22
    {   4, 4, 4,  8, 2, 2,  0, 0,  0,  0,  0,  0, (uint8_t)(DDSKTX__ENCODE_UNORM) }, // PTC24
    {   4, 4, 4,  8, 1, 1,  0, 0,  0,  0,  0,  0, (uint8_t)(DDSKTX__ENCODE_UNORM) }, // ATC
    {   8, 4, 4, 16, 1, 1,  0, 0,  0,  0,  0,  0, (uint8_t)(DDSKTX__ENCODE_UNORM) }, // ATCE
    {   8, 4, 4, 16, 1, 1,  0, 0,  0,  0,  0,  0, (uint8_t)(DDSKTX__ENCODE_UNORM) }, // ATCI
    {   8, 4, 4, 16, 1, 1,  0, 0,  0,  0,  0,  0, (uint8_t)(DDSKTX__ENCODE_UNORM) }, // ASTC4x4
    {   6, 5, 5, 16, 1, 1,  0, 0,  0,  0,  0,  0, (uint8_t)(DDSKTX__ENCODE_UNORM) }, // ASTC5x5
    {   4, 6, 6, 16, 1, 1,  0, 0,  0,  0,  0,  0, (uint8_t)(DDSKTX__ENCODE_UNORM) }, // ASTC6x6
    {   4, 8, 5, 16, 1, 1,  0, 0,  0,  0,  0,  0, (uint8_t)(DDSKTX__ENCODE_UNORM) }, // ASTC8x5
    {   3, 8, 6, 16, 1, 1,  0, 0,  0,  0,  0,  0, (uint8_t)(DDSKTX__ENCODE_UNORM) }, // ASTC8x6
    {   3, 10, 5, 16, 1, 1, 0, 0,  0,  0,  0,  0, (uint8_t)(DDSKTX__ENCODE_UNORM) }, // ASTC10x5
    {   0, 0, 0,  0, 0, 0,  0, 0,  0,  0,  0,  0, (uint8_t)(DDSKTX__ENCODE_COUNT) }, // Unknown
    {   8, 1, 1,  1, 1, 1,  0, 0,  0,  0,  0,  8, (uint8_t)(DDSKTX__ENCODE_UNORM) }, // A8
    {   8, 1, 1,  1, 1, 1,  0, 0,  8,  0,  0,  0, (uint8_t)(DDSKTX__ENCODE_UNORM) }, // R8
    {  32, 1, 1,  4, 1, 1,  0, 0,  8,  8,  8,  8, (uint8_t)(DDSKTX__ENCODE_UNORM) }, // RGBA8
    {  32, 1, 1,  4, 1, 1,  0, 0,  8,  8,  8,  8, (uint8_t)(DDSKTX__ENCODE_SNORM) }, // RGBA8S
    {  32, 1, 1,  4, 1, 1,  0, 0, 16, 16,  0,  0, (uint8_t)(DDSKTX__ENCODE_UNORM) }, // RG16
    {  24, 1, 1,  3, 1, 1,  0, 0,  8,  8,  8,  0, (uint8_t)(DDSKTX__ENCODE_UNORM) }, // RGB8
    {  16, 1, 1,  2, 1, 1,  0, 0, 16,  0,  0,  0, (uint8_t)(DDSKTX__ENCODE_UNORM) }, // R16
    {  32, 1, 1,  4, 1, 1,  0, 0, 32,  0,  0,  0, (uint8_t)(DDSKTX__ENCODE_FLOAT) }, // R32F
    {  16, 1, 1,  2, 1, 1,  0, 0, 16,  0,  0,  0, (uint8_t)(DDSKTX__ENCODE_FLOAT) }, // R16F
    {  32, 1, 1,  4, 1, 1,  0, 0, 16, 16,  0,  0, (uint8_t)(DDSKTX__ENCODE_FLOAT) }, // RG16F
    {  32, 1, 1,  4, 1, 1,  0, 0, 16, 16,  0,  0, (uint8_t)(DDSKTX__ENCODE_SNORM) }, // RG16S
    {  64, 1, 1,  8, 1, 1,  0, 0, 16, 16, 16, 16, (uint8_t)(DDSKTX__ENCODE_FLOAT) }, // RGBA16F
    {  64, 1, 1,  8, 1, 1,  0, 0, 16, 16, 16, 16, (uint8_t)(DDSKTX__ENCODE_UNORM) }, // RGBA16
    {  32, 1, 1,  4, 1, 1,  0, 0,  8,  8,  8,  8, (uint8_t)(DDSKTX__ENCODE_UNORM) }, // BGRA8
    {  32, 1, 1,  4, 1, 1,  0, 0, 10, 10, 10,  2, (uint8_t)(DDSKTX__ENCODE_UNORM) }, // RGB10A2
    {  32, 1, 1,  4, 1, 1,  0, 0, 11, 11, 10,  0, (uint8_t)(DDSKTX__ENCODE_UNORM) }, // RG11B10F
    {  16, 1, 1,  2, 1, 1,  0, 0,  8,  8,  0,  0, (uint8_t)(DDSKTX__ENCODE_UNORM) }, // RG8
    {  16, 1, 1,  2, 1, 1,  0, 0,  8,  8,  0,  0, (uint8_t)(DDSKTX__ENCODE_SNORM) }  // RG8S
};

// KTX: https://www.khronos.org/opengles/sdk/tools/KTX/file_format_spec/
#define DDSKTX__KTX_MAGIC       stc__makefourcc(0xAB, 'K', 'T', 'X')
#define DDSKTX__KTX_HEADER_SIZE 60     // actual header size is 64, but we read 4 bytes for the 'magic'

#define DDSKTX__KTX_ETC1_RGB8_OES                             0x8D64
#define DDSKTX__KTX_COMPRESSED_R11_EAC                        0x9270
#define DDSKTX__KTX_COMPRESSED_SIGNED_R11_EAC                 0x9271
#define DDSKTX__KTX_COMPRESSED_RG11_EAC                       0x9272
#define DDSKTX__KTX_COMPRESSED_SIGNED_RG11_EAC                0x9273
#define DDSKTX__KTX_COMPRESSED_RGB8_ETC2                      0x9274
#define DDSKTX__KTX_COMPRESSED_SRGB8_ETC2                     0x9275
#define DDSKTX__KTX_COMPRESSED_RGB8_PUNCHTHROUGH_ALPHA1_ETC2  0x9276
#define DDSKTX__KTX_COMPRESSED_SRGB8_PUNCHTHROUGH_ALPHA1_ETC2 0x9277
#define DDSKTX__KTX_COMPRESSED_RGBA8_ETC2_EAC                 0x9278
#define DDSKTX__KTX_COMPRESSED_SRGB8_ALPHA8_ETC2_EAC          0x9279
#define DDSKTX__KTX_COMPRESSED_RGB_PVRTC_4BPPV1_IMG           0x8C00
#define DDSKTX__KTX_COMPRESSED_RGB_PVRTC_2BPPV1_IMG           0x8C01
#define DDSKTX__KTX_COMPRESSED_RGBA_PVRTC_4BPPV1_IMG          0x8C02
#define DDSKTX__KTX_COMPRESSED_RGBA_PVRTC_2BPPV1_IMG          0x8C03
#define DDSKTX__KTX_COMPRESSED_RGBA_PVRTC_2BPPV2_IMG          0x9137
#define DDSKTX__KTX_COMPRESSED_RGBA_PVRTC_4BPPV2_IMG          0x9138
#define DDSKTX__KTX_COMPRESSED_RGB_S3TC_DXT1_EXT              0x83F0
#define DDSKTX__KTX_COMPRESSED_RGBA_S3TC_DXT1_EXT             0x83F1
#define DDSKTX__KTX_COMPRESSED_RGBA_S3TC_DXT3_EXT             0x83F2
#define DDSKTX__KTX_COMPRESSED_RGBA_S3TC_DXT5_EXT             0x83F3
#define DDSKTX__KTX_COMPRESSED_SRGB_ALPHA_S3TC_DXT1_EXT       0x8C4D
#define DDSKTX__KTX_COMPRESSED_SRGB_ALPHA_S3TC_DXT3_EXT       0x8C4E
#define DDSKTX__KTX_COMPRESSED_SRGB_ALPHA_S3TC_DXT5_EXT       0x8C4F
#define DDSKTX__KTX_COMPRESSED_LUMINANCE_LATC1_EXT            0x8C70
#define DDSKTX__KTX_COMPRESSED_LUMINANCE_ALPHA_LATC2_EXT      0x8C72
#define DDSKTX__KTX_COMPRESSED_RGBA_BPTC_UNORM_ARB            0x8E8C
#define DDSKTX__KTX_COMPRESSED_SRGB_ALPHA_BPTC_UNORM_ARB      0x8E8D
#define DDSKTX__KTX_COMPRESSED_RGB_BPTC_SIGNED_FLOAT_ARB      0x8E8E
#define DDSKTX__KTX_COMPRESSED_RGB_BPTC_UNSIGNED_FLOAT_ARB    0x8E8F
#define DDSKTX__KTX_COMPRESSED_SRGB_PVRTC_2BPPV1_EXT          0x8A54
#define DDSKTX__KTX_COMPRESSED_SRGB_PVRTC_4BPPV1_EXT          0x8A55
#define DDSKTX__KTX_COMPRESSED_SRGB_ALPHA_PVRTC_2BPPV1_EXT    0x8A56
#define DDSKTX__KTX_COMPRESSED_SRGB_ALPHA_PVRTC_4BPPV1_EXT    0x8A57
#define DDSKTX__KTX_ATC_RGB_AMD                               0x8C92
#define DDSKTX__KTX_ATC_RGBA_EXPLICIT_ALPHA_AMD               0x8C93
#define DDSKTX__KTX_ATC_RGBA_INTERPOLATED_ALPHA_AMD           0x87EE
#define DDSKTX__KTX_COMPRESSED_RGBA_ADDSKTX_4x4_KHR              0x93B0
#define DDSKTX__KTX_COMPRESSED_RGBA_ADDSKTX_5x5_KHR              0x93B2
#define DDSKTX__KTX_COMPRESSED_RGBA_ADDSKTX_6x6_KHR              0x93B4
#define DDSKTX__KTX_COMPRESSED_RGBA_ADDSKTX_8x5_KHR              0x93B5
#define DDSKTX__KTX_COMPRESSED_RGBA_ADDSKTX_8x6_KHR              0x93B6
#define DDSKTX__KTX_COMPRESSED_RGBA_ADDSKTX_10x5_KHR             0x93B8
#define DDSKTX__KTX_COMPRESSED_SRGB8_ALPHA8_ADDSKTX_4x4_KHR      0x93D0
#define DDSKTX__KTX_COMPRESSED_SRGB8_ALPHA8_ADDSKTX_5x5_KHR      0x93D2
#define DDSKTX__KTX_COMPRESSED_SRGB8_ALPHA8_ADDSKTX_6x6_KHR      0x93D4
#define DDSKTX__KTX_COMPRESSED_SRGB8_ALPHA8_ADDSKTX_8x5_KHR      0x93D5
#define DDSKTX__KTX_COMPRESSED_SRGB8_ALPHA8_ADDSKTX_8x6_KHR      0x93D6
#define DDSKTX__KTX_COMPRESSED_SRGB8_ALPHA8_ADDSKTX_10x5_KHR     0x93D8

#define DDSKTX__KTX_A8                                        0x803C
#define DDSKTX__KTX_R8                                        0x8229
#define DDSKTX__KTX_R16                                       0x822A
#define DDSKTX__KTX_RG8                                       0x822B
#define DDSKTX__KTX_RG16                                      0x822C
#define DDSKTX__KTX_R16F                                      0x822D
#define DDSKTX__KTX_R32F                                      0x822E
#define DDSKTX__KTX_RG16F                                     0x822F
#define DDSKTX__KTX_RG32F                                     0x8230
#define DDSKTX__KTX_RGBA8                                     0x8058
#define DDSKTX__KTX_RGBA16                                    0x805B
#define DDSKTX__KTX_RGBA16F                                   0x881A
#define DDSKTX__KTX_R32UI                                     0x8236
#define DDSKTX__KTX_RG32UI                                    0x823C
#define DDSKTX__KTX_RGBA32UI                                  0x8D70
#define DDSKTX__KTX_RGBA32F                                   0x8814
#define DDSKTX__KTX_RGB565                                    0x8D62
#define DDSKTX__KTX_RGBA4                                     0x8056
#define DDSKTX__KTX_RGB5_A1                                   0x8057
#define DDSKTX__KTX_RGB10_A2                                  0x8059
#define DDSKTX__KTX_R8I                                       0x8231
#define DDSKTX__KTX_R8UI                                      0x8232
#define DDSKTX__KTX_R16I                                      0x8233
#define DDSKTX__KTX_R16UI                                     0x8234
#define DDSKTX__KTX_R32I                                      0x8235
#define DDSKTX__KTX_R32UI                                     0x8236
#define DDSKTX__KTX_RG8I                                      0x8237
#define DDSKTX__KTX_RG8UI                                     0x8238
#define DDSKTX__KTX_RG16I                                     0x8239
#define DDSKTX__KTX_RG16UI                                    0x823A
#define DDSKTX__KTX_RG32I                                     0x823B
#define DDSKTX__KTX_RG32UI                                    0x823C
#define DDSKTX__KTX_R8_SNORM                                  0x8F94
#define DDSKTX__KTX_RG8_SNORM                                 0x8F95
#define DDSKTX__KTX_RGB8_SNORM                                0x8F96
#define DDSKTX__KTX_RGBA8_SNORM                               0x8F97
#define DDSKTX__KTX_R16_SNORM                                 0x8F98
#define DDSKTX__KTX_RG16_SNORM                                0x8F99
#define DDSKTX__KTX_RGB16_SNORM                               0x8F9A
#define DDSKTX__KTX_RGBA16_SNORM                              0x8F9B
#define DDSKTX__KTX_SRGB8                                     0x8C41
#define DDSKTX__KTX_SRGB8_ALPHA8                              0x8C43
#define DDSKTX__KTX_RGBA32UI                                  0x8D70
#define DDSKTX__KTX_RGB32UI                                   0x8D71
#define DDSKTX__KTX_RGBA16UI                                  0x8D76
#define DDSKTX__KTX_RGB16UI                                   0x8D77
#define DDSKTX__KTX_RGBA8UI                                   0x8D7C
#define DDSKTX__KTX_RGB8UI                                    0x8D7D
#define DDSKTX__KTX_RGBA32I                                   0x8D82
#define DDSKTX__KTX_RGB32I                                    0x8D83
#define DDSKTX__KTX_RGBA16I                                   0x8D88
#define DDSKTX__KTX_RGB16I                                    0x8D89
#define DDSKTX__KTX_RGBA8I                                    0x8D8E
#define DDSKTX__KTX_RGB8                                      0x8051
#define DDSKTX__KTX_RGB8I                                     0x8D8F
#define DDSKTX__KTX_RGB9_E5                                   0x8C3D
#define DDSKTX__KTX_R11F_G11F_B10F                            0x8C3A

#define DDSKTX__KTX_ZERO                                      0
#define DDSKTX__KTX_RED                                       0x1903
#define DDSKTX__KTX_ALPHA                                     0x1906
#define DDSKTX__KTX_RGB                                       0x1907
#define DDSKTX__KTX_RGBA                                      0x1908
#define DDSKTX__KTX_BGRA                                      0x80E1
#define DDSKTX__KTX_RG                                        0x8227

#define DDSKTX__KTX_BYTE                                      0x1400
#define DDSKTX__KTX_UNSIGNED_BYTE                             0x1401
#define DDSKTX__KTX_SHORT                                     0x1402
#define DDSKTX__KTX_UNSIGNED_SHORT                            0x1403
#define DDSKTX__KTX_INT                                       0x1404
#define DDSKTX__KTX_UNSIGNED_INT                              0x1405
#define DDSKTX__KTX_FLOAT                                     0x1406
#define DDSKTX__KTX_HALF_FLOAT                                0x140B
#define DDSKTX__KTX_UNSIGNED_INT_5_9_9_9_REV                  0x8C3E
#define DDSKTX__KTX_UNSIGNED_SHORT_5_6_5                      0x8363
#define DDSKTX__KTX_UNSIGNED_SHORT_4_4_4_4                    0x8033
#define DDSKTX__KTX_UNSIGNED_SHORT_5_5_5_1                    0x8034
#define DDSKTX__KTX_UNSIGNED_INT_2_10_10_10_REV               0x8368
#define DDSKTX__KTX_UNSIGNED_INT_10F_11F_11F_REV              0x8C3B

typedef struct ddsktx__ktx_format_info
{
    uint32_t internal_fmt;
    uint32_t internal_fmt_srgb;
    uint32_t fmt;
    uint32_t type;    
} ddsktx__ktx_format_info;

typedef struct ddsktx__ktx_format_info2
{
    uint32_t       internal_fmt;
    ddsktx_format  format;    
} ddsktx__ktx_format_info2;

static const ddsktx__ktx_format_info k__translate_ktx_fmt[] = {
        { DDSKTX__KTX_COMPRESSED_RGBA_S3TC_DXT1_EXT,            DDSKTX__KTX_COMPRESSED_SRGB_ALPHA_S3TC_DXT1_EXT,        DDSKTX__KTX_COMPRESSED_RGBA_S3TC_DXT1_EXT,            DDSKTX__KTX_ZERO,                         }, // BC1
        { DDSKTX__KTX_COMPRESSED_RGBA_S3TC_DXT3_EXT,            DDSKTX__KTX_COMPRESSED_SRGB_ALPHA_S3TC_DXT3_EXT,        DDSKTX__KTX_COMPRESSED_RGBA_S3TC_DXT3_EXT,            DDSKTX__KTX_ZERO,                         }, // BC2
        { DDSKTX__KTX_COMPRESSED_RGBA_S3TC_DXT5_EXT,            DDSKTX__KTX_COMPRESSED_SRGB_ALPHA_S3TC_DXT5_EXT,        DDSKTX__KTX_COMPRESSED_RGBA_S3TC_DXT5_EXT,            DDSKTX__KTX_ZERO,                         }, // BC3
        { DDSKTX__KTX_COMPRESSED_LUMINANCE_LATC1_EXT,           DDSKTX__KTX_ZERO,                                       DDSKTX__KTX_COMPRESSED_LUMINANCE_LATC1_EXT,           DDSKTX__KTX_ZERO,                         }, // BC4
        { DDSKTX__KTX_COMPRESSED_LUMINANCE_ALPHA_LATC2_EXT,     DDSKTX__KTX_ZERO,                                       DDSKTX__KTX_COMPRESSED_LUMINANCE_ALPHA_LATC2_EXT,     DDSKTX__KTX_ZERO,                         }, // BC5
        { DDSKTX__KTX_COMPRESSED_RGB_BPTC_SIGNED_FLOAT_ARB,     DDSKTX__KTX_ZERO,                                       DDSKTX__KTX_COMPRESSED_RGB_BPTC_SIGNED_FLOAT_ARB,     DDSKTX__KTX_ZERO,                         }, // BC6H
        { DDSKTX__KTX_COMPRESSED_RGBA_BPTC_UNORM_ARB,           DDSKTX__KTX_ZERO,                                       DDSKTX__KTX_COMPRESSED_RGBA_BPTC_UNORM_ARB,           DDSKTX__KTX_ZERO,                         }, // BC7
        { DDSKTX__KTX_ETC1_RGB8_OES,                            DDSKTX__KTX_ZERO,                                       DDSKTX__KTX_ETC1_RGB8_OES,                            DDSKTX__KTX_ZERO,                         }, // ETC1
        { DDSKTX__KTX_COMPRESSED_RGB8_ETC2,                     DDSKTX__KTX_ZERO,                                       DDSKTX__KTX_COMPRESSED_RGB8_ETC2,                     DDSKTX__KTX_ZERO,                         }, // ETC2
        { DDSKTX__KTX_COMPRESSED_RGBA8_ETC2_EAC,                DDSKTX__KTX_COMPRESSED_SRGB8_ETC2,                      DDSKTX__KTX_COMPRESSED_RGBA8_ETC2_EAC,                DDSKTX__KTX_ZERO,                         }, // ETC2A
        { DDSKTX__KTX_COMPRESSED_RGB8_PUNCHTHROUGH_ALPHA1_ETC2, DDSKTX__KTX_COMPRESSED_SRGB8_PUNCHTHROUGH_ALPHA1_ETC2,  DDSKTX__KTX_COMPRESSED_RGB8_PUNCHTHROUGH_ALPHA1_ETC2, DDSKTX__KTX_ZERO,                         }, // ETC2A1
        { DDSKTX__KTX_COMPRESSED_RGB_PVRTC_2BPPV1_IMG,          DDSKTX__KTX_COMPRESSED_SRGB_PVRTC_2BPPV1_EXT,           DDSKTX__KTX_COMPRESSED_RGB_PVRTC_2BPPV1_IMG,          DDSKTX__KTX_ZERO,                         }, // PTC12
        { DDSKTX__KTX_COMPRESSED_RGB_PVRTC_4BPPV1_IMG,          DDSKTX__KTX_COMPRESSED_SRGB_PVRTC_4BPPV1_EXT,           DDSKTX__KTX_COMPRESSED_RGB_PVRTC_4BPPV1_IMG,          DDSKTX__KTX_ZERO,                         }, // PTC14
        { DDSKTX__KTX_COMPRESSED_RGBA_PVRTC_2BPPV1_IMG,         DDSKTX__KTX_COMPRESSED_SRGB_ALPHA_PVRTC_2BPPV1_EXT,     DDSKTX__KTX_COMPRESSED_RGBA_PVRTC_2BPPV1_IMG,         DDSKTX__KTX_ZERO,                         }, // PTC12A
        { DDSKTX__KTX_COMPRESSED_RGBA_PVRTC_4BPPV1_IMG,         DDSKTX__KTX_COMPRESSED_SRGB_ALPHA_PVRTC_4BPPV1_EXT,     DDSKTX__KTX_COMPRESSED_RGBA_PVRTC_4BPPV1_IMG,         DDSKTX__KTX_ZERO,                         }, // PTC14A
        { DDSKTX__KTX_COMPRESSED_RGBA_PVRTC_2BPPV2_IMG,         DDSKTX__KTX_ZERO,                                       DDSKTX__KTX_COMPRESSED_RGBA_PVRTC_2BPPV2_IMG,         DDSKTX__KTX_ZERO,                         }, // PTC22
        { DDSKTX__KTX_COMPRESSED_RGBA_PVRTC_4BPPV2_IMG,         DDSKTX__KTX_ZERO,                                       DDSKTX__KTX_COMPRESSED_RGBA_PVRTC_4BPPV2_IMG,         DDSKTX__KTX_ZERO,                         }, // PTC24
        { DDSKTX__KTX_ATC_RGB_AMD,                              DDSKTX__KTX_ZERO,                                       DDSKTX__KTX_ATC_RGB_AMD,                              DDSKTX__KTX_ZERO,                         }, // ATC
        { DDSKTX__KTX_ATC_RGBA_EXPLICIT_ALPHA_AMD,              DDSKTX__KTX_ZERO,                                       DDSKTX__KTX_ATC_RGBA_EXPLICIT_ALPHA_AMD,              DDSKTX__KTX_ZERO,                         }, // ATCE
        { DDSKTX__KTX_ATC_RGBA_INTERPOLATED_ALPHA_AMD,          DDSKTX__KTX_ZERO,                                       DDSKTX__KTX_ATC_RGBA_INTERPOLATED_ALPHA_AMD,          DDSKTX__KTX_ZERO,                         }, // ATCI
        { DDSKTX__KTX_COMPRESSED_RGBA_ADDSKTX_4x4_KHR,          DDSKTX__KTX_COMPRESSED_SRGB8_ALPHA8_ADDSKTX_4x4_KHR,    DDSKTX__KTX_COMPRESSED_RGBA_ADDSKTX_4x4_KHR,          DDSKTX__KTX_ZERO,                         }, // ASTC4x4
        { DDSKTX__KTX_COMPRESSED_RGBA_ADDSKTX_5x5_KHR,          DDSKTX__KTX_COMPRESSED_SRGB8_ALPHA8_ADDSKTX_5x5_KHR,    DDSKTX__KTX_COMPRESSED_RGBA_ADDSKTX_5x5_KHR,          DDSKTX__KTX_ZERO,                         }, // ASTC5x5
        { DDSKTX__KTX_COMPRESSED_RGBA_ADDSKTX_6x6_KHR,          DDSKTX__KTX_COMPRESSED_SRGB8_ALPHA8_ADDSKTX_6x6_KHR,    DDSKTX__KTX_COMPRESSED_RGBA_ADDSKTX_6x6_KHR,          DDSKTX__KTX_ZERO,                         }, // ASTC6x6
        { DDSKTX__KTX_COMPRESSED_RGBA_ADDSKTX_8x5_KHR,          DDSKTX__KTX_COMPRESSED_SRGB8_ALPHA8_ADDSKTX_8x5_KHR,    DDSKTX__KTX_COMPRESSED_RGBA_ADDSKTX_8x5_KHR,          DDSKTX__KTX_ZERO,                         }, // ASTC8x5
        { DDSKTX__KTX_COMPRESSED_RGBA_ADDSKTX_8x6_KHR,          DDSKTX__KTX_COMPRESSED_SRGB8_ALPHA8_ADDSKTX_8x6_KHR,    DDSKTX__KTX_COMPRESSED_RGBA_ADDSKTX_8x6_KHR,          DDSKTX__KTX_ZERO,                         }, // ASTC8x6
        { DDSKTX__KTX_COMPRESSED_RGBA_ADDSKTX_10x5_KHR,         DDSKTX__KTX_COMPRESSED_SRGB8_ALPHA8_ADDSKTX_10x5_KHR,   DDSKTX__KTX_COMPRESSED_RGBA_ADDSKTX_10x5_KHR,         DDSKTX__KTX_ZERO,                         }, // ASTC10x5
        { DDSKTX__KTX_ZERO,                                     DDSKTX__KTX_ZERO,                                       DDSKTX__KTX_ZERO,                                     DDSKTX__KTX_ZERO,                         }, // Unknown
        { DDSKTX__KTX_ALPHA,                                    DDSKTX__KTX_ZERO,                                       DDSKTX__KTX_ALPHA,                                    DDSKTX__KTX_UNSIGNED_BYTE,                }, // A8
        { DDSKTX__KTX_R8,                                       DDSKTX__KTX_ZERO,                                       DDSKTX__KTX_RED,                                      DDSKTX__KTX_UNSIGNED_BYTE,                }, // R8
        { DDSKTX__KTX_RGBA8,                                    DDSKTX__KTX_SRGB8_ALPHA8,                               DDSKTX__KTX_RGBA,                                     DDSKTX__KTX_UNSIGNED_BYTE,                }, // RGBA8
        { DDSKTX__KTX_RGBA8_SNORM,                              DDSKTX__KTX_ZERO,                                       DDSKTX__KTX_RGBA,                                     DDSKTX__KTX_BYTE,                         }, // RGBA8S
        { DDSKTX__KTX_RG16,                                     DDSKTX__KTX_ZERO,                                       DDSKTX__KTX_RG,                                       DDSKTX__KTX_UNSIGNED_SHORT,               }, // RG16
        { DDSKTX__KTX_RGB8,                                     DDSKTX__KTX_SRGB8,                                      DDSKTX__KTX_RGB,                                      DDSKTX__KTX_UNSIGNED_BYTE,                }, // RGB8
        { DDSKTX__KTX_R16,                                      DDSKTX__KTX_ZERO,                                       DDSKTX__KTX_RED,                                      DDSKTX__KTX_UNSIGNED_SHORT,               }, // R16
        { DDSKTX__KTX_R32F,                                     DDSKTX__KTX_ZERO,                                       DDSKTX__KTX_RED,                                      DDSKTX__KTX_FLOAT,                        }, // R32F
        { DDSKTX__KTX_R16F,                                     DDSKTX__KTX_ZERO,                                       DDSKTX__KTX_RED,                                      DDSKTX__KTX_HALF_FLOAT,                   }, // R16F
        { DDSKTX__KTX_RG16F,                                    DDSKTX__KTX_ZERO,                                       DDSKTX__KTX_RG,                                       DDSKTX__KTX_FLOAT,                        }, // RG16F
        { DDSKTX__KTX_RG16_SNORM,                               DDSKTX__KTX_ZERO,                                       DDSKTX__KTX_RG,                                       DDSKTX__KTX_SHORT,                        }, // RG16S
        { DDSKTX__KTX_RGBA16F,                                  DDSKTX__KTX_ZERO,                                       DDSKTX__KTX_RGBA,                                     DDSKTX__KTX_HALF_FLOAT,                   }, // RGBA16F
        { DDSKTX__KTX_RGBA16,                                   DDSKTX__KTX_ZERO,                                       DDSKTX__KTX_RGBA,                                     DDSKTX__KTX_UNSIGNED_SHORT,               }, // RGBA16
        { DDSKTX__KTX_BGRA,                                     DDSKTX__KTX_SRGB8_ALPHA8,                               DDSKTX__KTX_BGRA,                                     DDSKTX__KTX_UNSIGNED_BYTE,                }, // BGRA8
        { DDSKTX__KTX_RGB10_A2,                                 DDSKTX__KTX_ZERO,                                       DDSKTX__KTX_RGBA,                                     DDSKTX__KTX_UNSIGNED_INT_2_10_10_10_REV,  }, // RGB10A2
        { DDSKTX__KTX_R11F_G11F_B10F,                           DDSKTX__KTX_ZERO,                                       DDSKTX__KTX_RGB,                                      DDSKTX__KTX_UNSIGNED_INT_10F_11F_11F_REV, }, // RG11B10F
        { DDSKTX__KTX_RG8,                                      DDSKTX__KTX_ZERO,                                       DDSKTX__KTX_RG,                                       DDSKTX__KTX_UNSIGNED_BYTE,                }, // RG8
        { DDSKTX__KTX_RG8_SNORM,                                DDSKTX__KTX_ZERO,                                       DDSKTX__KTX_RG,                                       DDSKTX__KTX_BYTE,                         }, // RG8S
        { DDSKTX__KTX_R16I,                                     DDSKTX__KTX_ZERO,                                       DDSKTX__KTX_RED,                                      DDSKTX__KTX_UNSIGNED_SHORT,               }, // R16I
        { DDSKTX__KTX_R16UI,                                    DDSKTX__KTX_ZERO,                                       DDSKTX__KTX_RED,                                      DDSKTX__KTX_UNSIGNED_SHORT,               }, // R16UI
};

static const ddsktx__ktx_format_info2 k__translate_ktx_fmt2[] =
{
    { DDSKTX__KTX_A8,                           DDSKTX_FORMAT_A8    },
    { DDSKTX__KTX_RED,                          DDSKTX_FORMAT_R8    },
    { DDSKTX__KTX_RGB,                          DDSKTX_FORMAT_RGB8  },
    { DDSKTX__KTX_RGBA,                         DDSKTX_FORMAT_RGBA8 },
    { DDSKTX__KTX_COMPRESSED_RGB_S3TC_DXT1_EXT, DDSKTX_FORMAT_BC1   },
};

typedef struct ddsktx__format_info
{
    const char* name;
    bool        has_alpha;
} ddsktx__format_info;

static const ddsktx__format_info k__formats_info[] = {
    {"BC1", false},
    {"BC2", true},
    {"BC3", true},
    {"BC4", false},
    {"BC5", false},
    {"BC6H", false},
    {"BC7", true},
    {"ETC1", false},
    {"ETC2", false},
    {"ETC2A", true},
    {"ETC2A1", true},
    {"PTC12", false},
    {"PTC14", false},
    {"PTC12A", true},
    {"PTC14A", true},
    {"PTC22", true},
    {"PTC24", true},
    {"ATC", false},
    {"ATCE", false},
    {"ATCI", false},
    {"ASTC4x4", true},
    {"ASTC5x5", true},
    {"ASTC6x6", false},
    {"ASTC8x5", true},
    {"ASTC8x6", false},
    {"ASTC10x5", false},
    {"<unknown>", false},
    {"A8", true},
    {"R8", false},
    {"RGBA8", true},
    {"RGBA8S", true},
    {"RG16", false},
    {"RGB8", false},
    {"R16", false},
    {"R32F", false},
    {"R16F", false},
    {"RG16F", false},
    {"RG16S", false},
    {"RGBA16F", true},
    {"RGBA16",true},
    {"BGRA8", true},
    {"RGB10A2", true},
    {"RG11B10F", false},
    {"RG8", false},
    {"RG8S", false}
};


static inline int ddsktx__read(ddsktx__mem_reader* reader, void* buff, int size)
{
    int read_bytes = (reader->offset + size) <= reader->total ? size : (reader->total - reader->offset);
    ddsktx_memcpy(buff, reader->buff + reader->offset, read_bytes);
    reader->offset += read_bytes;
    return read_bytes;
}

static bool ddsktx__parse_ktx(ddsktx_texture_info* tc, const void* file_data, int size, ddsktx_error* err)
{
    static const uint8_t ktx__id[] = { 0x20, 0x31, 0x31, 0xBB, 0x0D, 0x0A, 0x1A, 0x0A };

    ddsktx_memset(tc, 0x0, sizeof(ddsktx_texture_info));

    ddsktx__mem_reader r = {(const uint8_t*)file_data, size, sizeof(uint32_t)};
    ddsktx__ktx_header header;
    if (ddsktx__read(&r, &header, sizeof(header)) != DDSKTX__KTX_HEADER_SIZE) {
        ddsktx__err(err, "ktx; header size does not match");
    }

    if (ddsktx_memcmp(header.id, ktx__id, sizeof(header.id)) != 0) {
        ddsktx__err(err, "ktx: invalid file header");
    }

    // TODO: support big endian
    if (header.endianess != 0x04030201) {
        ddsktx__err(err, "ktx: big-endian format is not supported");
    }

    tc->metadata_offset = r.offset;
    tc->metadata_size = (int)header.metadata_size;
    r.offset += (int)header.metadata_size;

    ddsktx_format format = _DDSKTX_FORMAT_COUNT;

    int count = sizeof(k__translate_ktx_fmt)/sizeof(ddsktx__ktx_format_info);
    for (int i = 0; i < count; i++) {
        if (k__translate_ktx_fmt[i].internal_fmt == header.internal_format) {
            format = (ddsktx_format)i;
            break;
        }
    }

    if (format == _DDSKTX_FORMAT_COUNT) {
        count = sizeof(k__translate_ktx_fmt2)/sizeof(ddsktx__ktx_format_info2);
        for (int i = 0; i < count; i++) {
            if (k__translate_ktx_fmt2[i].internal_fmt == header.internal_format) {
                format = (ddsktx_format)k__translate_ktx_fmt2[i].format;
                break;
            }
        }
    }

    if (format == _DDSKTX_FORMAT_COUNT) {
        ddsktx__err(err, "ktx: unsupported format");
    } 

    if (header.face_count > 1 && header.face_count != DDSKTX_CUBE_FACE_COUNT) {
        ddsktx__err(err, "ktx: incomplete cubemap");
    }

    tc->data_offset = r.offset;
    tc->size_bytes = r.total - r.offset;
    tc->format = format;
    tc->width = (int)header.width;
    tc->height = (int)header.height;
    tc->depth = ddsktx__max((int)header.depth, 1);
    tc->num_layers = ddsktx__max((int)header.array_count, 1);
    tc->num_mips = ddsktx__max((int)header.mip_count, 1);
    tc->bpp = k__block_info[format].bpp;

    if (header.face_count == 6)
        tc->flags |= DDSKTX_TEXTURE_FLAG_CUBEMAP;
    tc->flags |= k__formats_info[format].has_alpha ? DDSKTX_TEXTURE_FLAG_ALPHA : 0;
    tc->flags |= DDSKTX_TEXTURE_FLAG_KTX;

    return true;
}

static bool ddsktx__parse_dds(ddsktx_texture_info* tc, const void* file_data, int size, ddsktx_error* err)
{
    ddsktx__mem_reader r = {(const uint8_t*)file_data, size, sizeof(uint32_t)};
    ddsktx__dds_header header;
    if (ddsktx__read(&r, &header, sizeof(header)) < DDSKTX__DDS_HEADER_SIZE ||
        header.size != DDSKTX__DDS_HEADER_SIZE)
    {
        ddsktx__err(err, "dds: header size does not match");
    }

    uint32_t required_flags = (DDSKTX__DDSD_HEIGHT|DDSKTX__DDSD_WIDTH);
    if ((header.flags & required_flags) != required_flags) {
        ddsktx__err(err, "dds: have invalid flags");
    }

    if (header.pixel_format.size != sizeof(ddsktx__dds_pixel_format)) {
        ddsktx__err(err, "dds: pixel format header is invalid");
    }

    uint32_t dxgi_format = 0;
    uint32_t array_size = 1;
    if (DDSKTX__DDPF_FOURCC == (header.flags & DDSKTX__DDPF_FOURCC) && 
        header.pixel_format.fourcc == DDSKTX__DDS_DX10)
    {
        ddsktx__dds_header_dxgi dxgi_header;
        ddsktx__read(&r, &dxgi_header, sizeof(dxgi_header));
        dxgi_format = dxgi_header.dxgi_format;
        array_size = dxgi_header.array_size;
    }

    if ((header.caps1 & DDSKTX__DDSCAPS_TEXTURE) == 0) {
        ddsktx__err(err, "dds: unsupported caps");
    }

    bool cubemap = (header.caps2 & DDSKTX__DDSCAPS2_CUBEMAP) != 0;
    if (cubemap && (header.caps2 & DDSKTX__DDSCAPS2_CUBEMAP_ALLSIDES) != DDSKTX__DDSCAPS2_CUBEMAP_ALLSIDES) {
        ddsktx__err(err, "dds: incomplete cubemap");
    }
    bool volume = (header.caps2 & DDSKTX__DDSCAPS2_VOLUME) != 0;

    ddsktx_format format = _DDSKTX_FORMAT_COUNT;
    bool has_alpha = (header.pixel_format.flags & DDSKTX__DDPF_ALPHA) != 0;
    bool srgb = false;

    if (dxgi_format == 0) {
        if ((header.pixel_format.flags & DDSKTX__DDPF_FOURCC) == DDSKTX__DDPF_FOURCC) {
            int count = sizeof(k__translate_dds_fourcc)/sizeof(ddsktx__dds_translate_fourcc_format);
            for (int i = 0; i < count; i++) {
                if (k__translate_dds_fourcc[i].dds_format == header.pixel_format.fourcc) {
                    format = k__translate_dds_fourcc[i].format;
                    break;
                }
            }
        } else {
            int count = sizeof(k__translate_dds_pixel)/sizeof(ddsktx__dds_translate_pixel_format);
            for (int i = 0; i < count; i++) {
                const ddsktx__dds_translate_pixel_format* f = &k__translate_dds_pixel[i];
                if (f->bit_count == header.pixel_format.rgb_bit_count &&
                    f->flags == header.pixel_format.flags &&
                    f->bit_mask[0] == header.pixel_format.bit_mask[0] &&
                    f->bit_mask[1] == header.pixel_format.bit_mask[1] &&
                    f->bit_mask[2] == header.pixel_format.bit_mask[2] &&
                    f->bit_mask[3] == header.pixel_format.bit_mask[3])
                {
                    format = f->format;
                    break;
                }
            }
        }
    } else {
        int count = sizeof(k__translate_dxgi)/sizeof(ddsktx__dds_translate_fourcc_format);
        for (int i = 0; i < count; i++) {
            if (k__translate_dxgi[i].dds_format == dxgi_format) {
                format = k__translate_dxgi[i].format;
                srgb = k__translate_dxgi[i].srgb;
                break;
            }
        }
    }

    if (format == _DDSKTX_FORMAT_COUNT) {
        ddsktx__err(err, "dds: unknown format");
    }

    ddsktx_memset(tc, 0x0, sizeof(ddsktx_texture_info));
    tc->data_offset = r.offset;
    tc->size_bytes = r.total - r.offset;
    tc->format = format;
    tc->width = (int)header.width;
    tc->height = (int)header.height;
    tc->depth = ddsktx__max(1, (int)header.depth);
    tc->num_layers = ddsktx__max(1, (int)array_size);
    tc->num_mips = (header.caps1 & DDSKTX__DDSCAPS_MIPMAP) ? (int)header.mip_count : 1;
    tc->bpp = k__block_info[format].bpp;
    if (has_alpha || k__formats_info[format].has_alpha)
        tc->flags |= DDSKTX_TEXTURE_FLAG_ALPHA;
    if (cubemap)
        tc->flags |= DDSKTX_TEXTURE_FLAG_CUBEMAP;
    if (volume)
        tc->flags |= DDSKTX_TEXTURE_FLAG_VOLUME;
    if (srgb) 
        tc->flags |= DDSKTX_TEXTURE_FLAG_SRGB;
    tc->flags |= DDSKTX_TEXTURE_FLAG_DDS;

    return true;
}   

void ddsktx_get_sub(const ddsktx_texture_info* tc, ddsktx_sub_data* sub_data, 
                 const void* file_data, int size,
                 int array_idx, int slice_face_idx, int mip_idx)
{
    ddsktx_assert(tc);
    ddsktx_assert(sub_data);
    ddsktx_assert(file_data);
    ddsktx_assert(size > 0);
    ddsktx_assert(array_idx < tc->num_layers);
    ddsktx_assert(!((tc->flags&DDSKTX_TEXTURE_FLAG_CUBEMAP) && (slice_face_idx >= DDSKTX_CUBE_FACE_COUNT)) && "invalid cube-face index");
    ddsktx_assert(!(!(tc->flags&DDSKTX_TEXTURE_FLAG_CUBEMAP) && (slice_face_idx >= tc->depth)) && "invalid depth-slice index");
    ddsktx_assert(mip_idx < tc->num_mips);

    ddsktx__mem_reader r = { (uint8_t*)file_data, size, tc->data_offset };
    ddsktx_format format = tc->format;

    ddsktx_assert(format < _DDSKTX_FORMAT_COUNT && format != _DDSKTX_FORMAT_COMPRESSED);
    const ddsktx__block_info* binfo = &k__block_info[format];
    const int bpp          = binfo->bpp;
    const int block_size   = binfo->block_size;
    const int min_block_x  = binfo->min_block_x;
    const int min_block_y  = binfo->min_block_y;

    int num_faces;

    ddsktx_assert(!((tc->flags & DDSKTX_TEXTURE_FLAG_CUBEMAP) && tc->depth > 1) && "textures must be either Cube or 3D");
    int slice_idx, face_idx, num_slices;
    if (tc->flags & DDSKTX_TEXTURE_FLAG_CUBEMAP) {
        slice_idx = 0;
        face_idx = slice_face_idx;
        num_faces = DDSKTX_CUBE_FACE_COUNT;
        num_slices = 1;
    } else {
        slice_idx = slice_face_idx;
        face_idx = 0;
        num_faces = 1;
        num_slices = tc->depth;
    }    

    if (tc->flags & DDSKTX_TEXTURE_FLAG_DDS) {
        for (int layer = 0, num_layers = tc->num_layers; layer < num_layers; layer++) {
            for (int face = 0; face < num_faces; face++) {
                int width = tc->width;
                int height = tc->height;

                for (int mip = 0, mip_count = tc->num_mips; mip < mip_count; mip++) {
                    int row_bytes, mip_size;
                    
                    if (format < _DDSKTX_FORMAT_COMPRESSED) {
                        int num_blocks_wide = width > 0 ? ddsktx__max(1, (width + 3)/4) : 0;
                        num_blocks_wide = ddsktx__max(min_block_x, num_blocks_wide);

                        int num_blocks_high = height > 0 ? ddsktx__max(1, (height + 3)/4) : 0;
                        num_blocks_high = ddsktx__max(min_block_y, num_blocks_high);

                        row_bytes = num_blocks_wide * block_size;
                        mip_size = row_bytes * num_blocks_high;
                    } else {
                        row_bytes = (width*bpp + 7)/8;  // round to nearest byte
                        mip_size = row_bytes * height;
                    }
                   
                    for (int slice = 0; slice < num_slices; slice++) {
                        if (layer == array_idx && mip == mip_idx && 
                            slice == slice_idx && face_idx == face) 
                        {
                            sub_data->buff = r.buff + r.offset;
                            sub_data->width = width;
                            sub_data->height = height;
                            sub_data->size_bytes = mip_size;
                            sub_data->row_pitch_bytes = row_bytes;
                            return;
                        }

                        r.offset += mip_size;
                        ddsktx_assert(r.offset <= r.total && "texture buffer overflow");
                    } // foreach slice

                    width >>= 1;
                    height >>= 1;

                    if (width == 0) {
                        width = 1;
                    }
                    if (height == 0) {
                        height = 1;
                    }
                }   // foreach mip
            }   // foreach face
        } // foreach array-item
    } else if (tc->flags & DDSKTX_TEXTURE_FLAG_KTX) {
        int width = tc->width;
        int height = tc->height;

        for (int mip = 0, c = tc->num_mips; mip < c; mip++) {
            int row_bytes, mip_size;

            if (format < _DDSKTX_FORMAT_COMPRESSED) {
                int num_blocks_wide = width > 0 ? ddsktx__max(1, (width + 3)/4) : 0;
                num_blocks_wide = ddsktx__max(min_block_x, num_blocks_wide);

                int num_blocks_high = height > 0 ? ddsktx__max(1, (height + 3)/4) : 0;
                num_blocks_high = ddsktx__max(min_block_y, num_blocks_high);

                row_bytes = num_blocks_wide * block_size;
                mip_size = row_bytes * num_blocks_high;
            }
            else {
                row_bytes = (width*bpp + 7)/8;  // round to nearest byte
                mip_size = row_bytes * height;
            }

            int image_size;
            ddsktx__read(&r, &image_size, sizeof(image_size)); 
            ddsktx_assert(image_size == (mip_size*num_faces*num_slices) && "image size mismatch");

            for (int layer = 0, num_layers = tc->num_layers; layer < num_layers; layer++) {
                for (int face = 0; face < num_faces; face++) {
                    for (int slice = 0; slice < num_slices; slice++) {
                        if (layer == array_idx && mip == mip_idx &&
                            slice == slice_idx && face_idx == face) 
                        {
                            sub_data->buff = r.buff + r.offset;
                            sub_data->width = width;
                            sub_data->height = height;
                            sub_data->size_bytes = mip_size;
                            sub_data->row_pitch_bytes = row_bytes;
                            return;
                        }

                        r.offset += mip_size;
                        ddsktx_assert(r.offset <= r.total && "texture buffer overflow");
                    }   // foreach slice

                    
                    r.offset = ddsktx__align_mask(r.offset, 3); // cube-padding
                }   // foreach face
            }   // foreach array-item

            width >>= 1;
            height >>= 1;

            if (width == 0) {
                width = 1;
            }
            if (height == 0) {
                height = 1;
            }
            
            r.offset = ddsktx__align_mask(r.offset, 3); // mip-padding
        }   // foreach mip     
    } else {
        ddsktx_assert(0 && "invalid file format");
    }
}

bool ddsktx_parse(ddsktx_texture_info* tc, const void* file_data, int size, ddsktx_error* err)
{
    ddsktx_assert(tc);
    ddsktx_assert(file_data);
    ddsktx_assert(size > 0);

    ddsktx__mem_reader r = {(const uint8_t*)file_data, size, 0};
    
    // Read file flag and determine the file type
    uint32_t file_flag = 0;
    if (ddsktx__read(&r, &file_flag, sizeof(file_flag)) != sizeof(file_flag)) {
        ddsktx__err(err, "invalid texture file");
    }

    switch (file_flag) {
    case DDSKTX__DDS_MAGIC:
        return ddsktx__parse_dds(tc, file_data, size, err);
    case DDSKTX__KTX_MAGIC:
        return ddsktx__parse_ktx(tc, file_data, size, err);
    default:
        ddsktx__err(err, "unknown texture format");
    }
}

const char* ddsktx_format_str(ddsktx_format format)
{
    return k__formats_info[format].name;
}

bool ddsktx_format_compressed(ddsktx_format format)
{
    ddsktx_assert(format != _DDSKTX_FORMAT_COMPRESSED && format != _DDSKTX_FORMAT_COUNT);
    return format < _DDSKTX_FORMAT_COMPRESSED;
}

#endif  // DDSKTX_IMPLEMENT

