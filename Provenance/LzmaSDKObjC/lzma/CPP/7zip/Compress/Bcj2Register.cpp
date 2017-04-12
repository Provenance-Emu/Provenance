// Bcj2Register.cpp

#include "StdAfx.h"

#include "../Common/RegisterCodec.h"

#include "Bcj2Coder.h"

namespace NCompress {
namespace NBcj2 {

REGISTER_CODEC_CREATE_2(CreateCodec, CDecoder(), ICompressCoder2)
#ifndef EXTRACT_ONLY
REGISTER_CODEC_CREATE_2(CreateCodecOut, CEncoder(), ICompressCoder2)
#else
#define CreateCodecOut NULL
#endif

REGISTER_CODEC_VAR
  { CreateCodec, CreateCodecOut, 0x303011B, "BCJ2", 4, false };

REGISTER_CODEC(BCJ2)

}}
