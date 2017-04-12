// 7zAesRegister.cpp

#include "StdAfx.h"

#include "../Common/RegisterCodec.h"

#include "7zAes.h"

namespace NCrypto {
namespace N7z {

REGISTER_FILTER_E(7zAES,
    CDecoder(),
    CEncoder(),
    0x6F10701, "7zAES")

}}
