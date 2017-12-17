/*
 *   Copyright (c) 2015 - 2017 Kulykov Oleh <info@resident.name>
 *
 *   Permission is hereby granted, free of charge, to any person obtaining a copy
 *   of this software and associated documentation files (the "Software"), to deal
 *   in the Software without restriction, including without limitation the rights
 *   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 *   copies of the Software, and to permit persons to whom the Software is
 *   furnished to do so, subject to the following conditions:
 *
 *   The above copyright notice and this permission notice shall be included in
 *   all copies or substantial portions of the Software.
 *
 *   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 *   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 *   THE SOFTWARE.
 */


#include "LzmaSDKObjCExtern.h"


/**
 @brief 12 = 4  Kb min
 @brief 13 = 8  Kb
 @brief 14 = 16 Kb
 @brief 15 = 32 Kb
 @brief 16 = 64 Kb
 @brief 17 = 128 Kb
 @brief 18 = 256 Kb
 @brief 19 = 512 Kb
 @brief 20 = 1 Mb
 @brief 21 = 2 Mb
 @brief 22 = 4 Mb
 @brief 31 = 1 Gb
 */

unsigned int kLzmaSDKObjCStreamReadSize = ((unsigned int)1 << 16);


unsigned int kLzmaSDKObjCStreamWriteSize = ((unsigned int)1 << 16);


unsigned int kLzmaSDKObjCDecoderReadSize = ((unsigned int)1 << 16);


unsigned int kLzmaSDKObjCDecoderWriteSize = ((unsigned int)1 << 18);

