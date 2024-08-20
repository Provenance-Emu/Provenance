###########
# glidenhq
###########
include $(CLEAR_VARS)
LOCAL_PATH := $(JNI_LOCAL_PATH)
SRCDIR := ./$(BASE_DIR)/src/GLideNHQ
LOCAL_SHARED_LIBRARIES := osal
LOCAL_MODULE := glidenhq
LOCAL_STATIC_LIBRARIES := png
LOCAL_ARM_MODE := arm

LOCAL_C_INCLUDES :=                     \
    $(LOCAL_PATH)/$(SRCDIR)             \
    $(LOCAL_PATH)/$(SRCDIR)/..          \
    $(LOCAL_PATH)/$(SRCDIR)/../osal     \
    $(PNG_INCLUDES)                     \
    $(GL_INCLUDES)

LOCAL_SRC_FILES :=                          \
    $(SRCDIR)/TextureFilters.cpp            \
    $(SRCDIR)/TextureFilters_2xsai.cpp      \
    $(SRCDIR)/TextureFilters_hq2x.cpp       \
    $(SRCDIR)/TextureFilters_hq4x.cpp       \
    $(SRCDIR)/TextureFilters_xbrz.cpp       \
    $(SRCDIR)/TxCache.cpp                   \
    $(SRCDIR)/TxDbg.cpp                     \
    $(SRCDIR)/TxFilter.cpp                  \
    $(SRCDIR)/TxFilterExport.cpp            \
    $(SRCDIR)/TxHiResCache.cpp              \
    $(SRCDIR)/TxImage.cpp                   \
    $(SRCDIR)/TxQuantize.cpp                \
    $(SRCDIR)/TxReSample.cpp                \
    $(SRCDIR)/TxTexCache.cpp                \
    $(SRCDIR)/TxUtil.cpp                    \
    $(SRCDIR)/txWidestringWrapper.cpp       \

LOCAL_CFLAGS :=         \
    $(COMMON_CFLAGS)    \
    -DOS_ANDROID        \
    -DTXFILTER_LIB      \
    -fsigned-char       \
    #-DDEBUG             \
    #-DSDL_NO_COMPAT     \

LOCAL_CPPFLAGS := $(COMMON_CPPFLAGS) -std=c++11 -fexceptions

include $(BUILD_STATIC_LIBRARY)
