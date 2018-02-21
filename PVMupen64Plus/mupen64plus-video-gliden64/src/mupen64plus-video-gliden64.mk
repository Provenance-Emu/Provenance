#############################
# mupen64plus-video-gliden64
#############################
include $(CLEAR_VARS)
LOCAL_PATH := $(JNI_LOCAL_PATH)
SRCDIR := ./mupen64plus-video-gliden64/src

MY_LOCAL_MODULE := mupen64plus-video-gliden64
MY_LOCAL_SHARED_LIBRARIES := freetype glidenhq osal
MY_LOCAL_ARM_MODE := arm

MY_LOCAL_C_INCLUDES :=                          \
    $(LOCAL_PATH)/$(SRCDIR)                     \
    $(M64P_API_INCLUDES)                        \
    $(SDL_INCLUDES)                             \
    $(FREETYPE_INCLUDES)                        \
    $(LOCAL_PATH)/$(SRCDIR)/osal                \
    $(ANDROID_FRAMEWORK_INCLUDES)               \

MY_LOCAL_SRC_FILES :=                                                              \
    $(SRCDIR)/Combiner.cpp                                                         \
    $(SRCDIR)/CombinerKey.cpp                                                      \
    $(SRCDIR)/CommonPluginAPI.cpp                                                  \
    $(SRCDIR)/Config.cpp                                                           \
    $(SRCDIR)/convert.cpp                                                          \
    $(SRCDIR)/CRC_OPT.cpp                                                          \
    $(SRCDIR)/DebugDump.cpp                                                        \
    $(SRCDIR)/Debugger.cpp                                                         \
    $(SRCDIR)/DepthBuffer.cpp                                                      \
    $(SRCDIR)/DisplayWindow.cpp                                                    \
    $(SRCDIR)/DisplayLoadProgress.cpp                                              \
    $(SRCDIR)/FrameBuffer.cpp                                                      \
    $(SRCDIR)/FrameBufferInfo.cpp                                                  \
    $(SRCDIR)/GBI.cpp                                                              \
    $(SRCDIR)/gDP.cpp                                                              \
    $(SRCDIR)/GLideN64.cpp                                                         \
    $(SRCDIR)/GraphicsDrawer.cpp                                                   \
    $(SRCDIR)/gSP.cpp                                                              \
    $(SRCDIR)/Keys.cpp                                                             \
    $(SRCDIR)/Log_android.cpp                                                      \
    $(SRCDIR)/MupenPlusPluginAPI.cpp                                               \
    $(SRCDIR)/N64.cpp                                                              \
    $(SRCDIR)/NoiseTexture.cpp                                                     \
    $(SRCDIR)/PaletteTexture.cpp                                                   \
    $(SRCDIR)/Performance.cpp                                                      \
    $(SRCDIR)/PostProcessor.cpp                                                    \
    $(SRCDIR)/RDP.cpp                                                              \
    $(SRCDIR)/RSP.cpp                                                              \
    $(SRCDIR)/SoftwareRender.cpp                                                   \
    $(SRCDIR)/TexrectDrawer.cpp                                                    \
    $(SRCDIR)/TextDrawer.cpp                                                       \
    $(SRCDIR)/TextureFilterHandler.cpp                                             \
    $(SRCDIR)/Textures.cpp                                                         \
    $(SRCDIR)/VI.cpp                                                               \
    $(SRCDIR)/ZlutTexture.cpp                                                      \
    $(SRCDIR)/common/CommonAPIImpl_common.cpp                                      \
    $(SRCDIR)/mupenplus/CommonAPIImpl_mupenplus.cpp                                \
    $(SRCDIR)/mupenplus/Config_mupenplus.cpp                                       \
    $(SRCDIR)/mupenplus/MupenPlusAPIImpl.cpp                                       \
    $(SRCDIR)/DepthBufferRender/ClipPolygon.cpp                                    \
    $(SRCDIR)/DepthBufferRender/DepthBufferRender.cpp                              \
    $(SRCDIR)/BufferCopy/ColorBufferToRDRAM.cpp                                    \
    $(SRCDIR)/BufferCopy/DepthBufferToRDRAM.cpp                                    \
    $(SRCDIR)/BufferCopy/RDRAMtoColorBuffer.cpp                                    \
    $(SRCDIR)/Graphics/Context.cpp                                                 \
    $(SRCDIR)/Graphics/ColorBufferReader.cpp                                       \
    $(SRCDIR)/Graphics/CombinerProgram.cpp                                         \
    $(SRCDIR)/Graphics/ObjectHandle.cpp                                            \
    $(SRCDIR)/Graphics/OpenGLContext/GLFunctions.cpp                               \
    $(SRCDIR)/Graphics/OpenGLContext/opengl_Attributes.cpp                         \
    $(SRCDIR)/Graphics/OpenGLContext/opengl_BufferedDrawer.cpp                     \
    $(SRCDIR)/Graphics/OpenGLContext/opengl_BufferManipulationObjectFactory.cpp    \
    $(SRCDIR)/Graphics/OpenGLContext/opengl_CachedFunctions.cpp                    \
    $(SRCDIR)/Graphics/OpenGLContext/opengl_ColorBufferReaderWithBufferStorage.cpp \
    $(SRCDIR)/Graphics/OpenGLContext/opengl_ColorBufferReaderWithPixelBuffer.cpp   \
    $(SRCDIR)/Graphics/OpenGLContext/opengl_ColorBufferReaderWithReadPixels.cpp    \
    $(SRCDIR)/Graphics/OpenGLContext/opengl_ColorBufferReaderWithEGLImage.cpp      \
    $(SRCDIR)/Graphics/OpenGLContext/opengl_ContextImpl.cpp                        \
    $(SRCDIR)/Graphics/OpenGLContext/opengl_GLInfo.cpp                             \
    $(SRCDIR)/Graphics/OpenGLContext/opengl_Parameters.cpp                         \
    $(SRCDIR)/Graphics/OpenGLContext/opengl_TextureManipulationObjectFactory.cpp   \
    $(SRCDIR)/Graphics/OpenGLContext/opengl_UnbufferedDrawer.cpp                   \
    $(SRCDIR)/Graphics/OpenGLContext/opengl_Utils.cpp                              \
    $(SRCDIR)/Graphics/OpenGLContext/GLSL/glsl_CombinerInputs.cpp                  \
    $(SRCDIR)/Graphics/OpenGLContext/GLSL/glsl_CombinerProgramBuilder.cpp          \
    $(SRCDIR)/Graphics/OpenGLContext/GLSL/glsl_CombinerProgramImpl.cpp             \
    $(SRCDIR)/Graphics/OpenGLContext/GLSL/glsl_CombinerProgramUniformFactory.cpp   \
    $(SRCDIR)/Graphics/OpenGLContext/GLSL/glsl_ShaderStorage.cpp                   \
    $(SRCDIR)/Graphics/OpenGLContext/GLSL/glsl_SpecialShadersFactory.cpp           \
    $(SRCDIR)/Graphics/OpenGLContext/GLSL/glsl_Utils.cpp                           \
    $(SRCDIR)/Graphics/OpenGLContext/mupen64plus/mupen64plus_DisplayWindow.cpp     \
    $(SRCDIR)/Graphics/OpenGLContext/GraphicBufferPrivateApi/GraphicBuffer.cpp     \
    $(SRCDIR)/Graphics/OpenGLContext/GraphicBufferPrivateApi/libhardware.cpp       \
    $(SRCDIR)/uCodes/F3D.cpp                                                       \
    $(SRCDIR)/uCodes/F3DAM.cpp                                                     \
    $(SRCDIR)/uCodes/F3DBETA.cpp                                                   \
    $(SRCDIR)/uCodes/F3DDKR.cpp                                                    \
    $(SRCDIR)/uCodes/F3DEX.cpp                                                     \
    $(SRCDIR)/uCodes/F3DEX2.cpp                                                    \
    $(SRCDIR)/uCodes/F3DEX2ACCLAIM.cpp                                             \
    $(SRCDIR)/uCodes/F3DEX2CBFD.cpp                                                \
    $(SRCDIR)/uCodes/F3DZEX2.cpp                                                   \
    $(SRCDIR)/uCodes/F3DFLX2.cpp                                                   \
    $(SRCDIR)/uCodes/F3DGOLDEN.cpp                                                 \
    $(SRCDIR)/uCodes/F3DPD.cpp                                                     \
    $(SRCDIR)/uCodes/F3DSETA.cpp                                                   \
    $(SRCDIR)/uCodes/F3DSWRS.cpp                                                   \
    $(SRCDIR)/uCodes/F3DTEXA.cpp                                                   \
    $(SRCDIR)/uCodes/L3D.cpp                                                       \
    $(SRCDIR)/uCodes/L3DEX2.cpp                                                    \
    $(SRCDIR)/uCodes/L3DEX.cpp                                                     \
    $(SRCDIR)/uCodes/S2DEX2.cpp                                                    \
    $(SRCDIR)/uCodes/S2DEX.cpp                                                     \
    $(SRCDIR)/uCodes/T3DUX.cpp                                                     \
    $(SRCDIR)/uCodes/Turbo3D.cpp                                                   \
    $(SRCDIR)/uCodes/ZSort.cpp                                                     \
    $(SRCDIR)/xxHash/xxhash.c                                                      \

MY_LOCAL_CFLAGS :=          \
    $(COMMON_CFLAGS)        \
    -g                      \
    -DTXFILTER_LIB          \
    -DOS_ANDROID            \
    -DUSE_SDL               \
    -DMUPENPLUSAPI          \
    -DEGL                   \
    -DEGL_EGLEXT_PROTOTYPES \
    -fsigned-char           \
    #-DSDL_NO_COMPAT        \

MY_LOCAL_CPPFLAGS := $(COMMON_CPPFLAGS) -std=c++11 -g

MY_LOCAL_LDFLAGS := $(COMMON_LDFLAGS) -Wl,-version-script,$(LOCAL_PATH)/$(SRCDIR)/mupenplus/video_api_export.ver

MY_LOCAL_LDLIBS := -llog -latomic -lEGL

ifeq ($(TARGET_ARCH_ABI), armeabi-v7a)
    # Use for ARM7a:
    MY_LOCAL_SRC_FILES += $(SRCDIR)/Neon/3DMathNeon.cpp
    MY_LOCAL_SRC_FILES += $(SRCDIR)/Neon/gSPNeon.cpp
    MY_LOCAL_SRC_FILES += $(SRCDIR)/Neon/RSP_LoadMatrixNeon.cpp
    MY_LOCAL_CFLAGS += -D__NEON_OPT
    MY_LOCAL_CFLAGS += -D__VEC4_OPT -mfpu=neon -mfloat-abi=softfp -ftree-vectorize -funsafe-math-optimizations -fno-finite-math-only

else ifeq ($(TARGET_ARCH_ABI), x86)
#    MY_LOCAL_CFLAGS += -DX86_ASM
    MY_LOCAL_CFLAGS += -D__VEC4_OPT
    MY_LOCAL_SRC_FILES += $(SRCDIR)/3DMath.cpp
    MY_LOCAL_SRC_FILES += $(SRCDIR)/RSP_LoadMatrix.cpp
endif

###########
# Build library
###########
include $(CLEAR_VARS)
LOCAL_MODULE            := $(MY_LOCAL_MODULE)
LOCAL_SHARED_LIBRARIES  := $(MY_LOCAL_SHARED_LIBRARIES)
LOCAL_ARM_MODE          := $(MY_LOCAL_ARM_MODE)
LOCAL_C_INCLUDES        := $(MY_LOCAL_C_INCLUDES) $(LOCAL_PATH)/GL/
LOCAL_SRC_FILES         := $(MY_LOCAL_SRC_FILES)
LOCAL_CFLAGS            := $(MY_LOCAL_CFLAGS)
LOCAL_CPPFLAGS          := $(MY_LOCAL_CPPFLAGS)
LOCAL_LDFLAGS           := $(MY_LOCAL_LDFLAGS)
LOCAL_LDLIBS            := $(MY_LOCAL_LDLIBS)

include $(BUILD_SHARED_LIBRARY)
