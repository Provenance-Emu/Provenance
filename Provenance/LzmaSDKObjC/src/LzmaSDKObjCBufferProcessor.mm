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


#import <Foundation/Foundation.h>

#include "LzmaSDKObjCBufferProcessor.h"

#include "../lzma/C/Lzma2Enc.h"
#include "../lzma/C/Lzma2Dec.h"


static void * LzmaSDKObjCBufferProcessorAlloc(size_t size) { return (size > 0) ? malloc(size) : NULL; }
static void LzmaSDKObjCBufferProcessorFree(void *address) { if (address) free(address); }
static void * LzmaSDKObjCBufferProcessorSzAlloc(void *p, size_t size) { return LzmaSDKObjCBufferProcessorAlloc(size); }
static void LzmaSDKObjCBufferProcessorSzFree(void *p, void *address) { LzmaSDKObjCBufferProcessorFree(address); }

typedef struct _LzmaSDKObjCBufferProcessorReader : ISeqInStream {
	const unsigned char * data;
	unsigned int dataSize;
	unsigned int offset;
} LzmaSDKObjCBufferProcessorReader;

typedef struct _LzmaSDKObjCBufferProcessorWriter : ISeqOutStream {
	__strong NSMutableData * data;
} LzmaSDKObjCBufferProcessorWriter;


static size_t LzmaSDKObjCBufferProcessorWrite(void *pp, const void *data, size_t size) {
	LzmaSDKObjCBufferProcessorWriter * p = (LzmaSDKObjCBufferProcessorWriter *)pp;
	[p->data appendBytes:data length:size];
	return size;
}

static SRes LzmaSDKObjCBufferProcessorRead(void *pp, void *data, size_t *size) {
	LzmaSDKObjCBufferProcessorReader * p = (LzmaSDKObjCBufferProcessorReader *)pp;
	size_t sizeToRead = *size;
	size_t avaiableSize = p->dataSize - p->offset;
	if (avaiableSize < sizeToRead) sizeToRead = avaiableSize;
	memcpy(data, &p->data[p->offset], sizeToRead);
	p->offset += sizeToRead;
	*size = sizeToRead;
	return SZ_OK;
}

NSData * _Nullable LzmaSDKObjCBufferCompressLZMA2(NSData * _Nonnull dataForCompress, const float compressionRatio) {
	if (!dataForCompress) return nil;
	const unsigned char * data = (const unsigned char *)[dataForCompress bytes];
	const unsigned int dataSize = (unsigned int)[dataForCompress length];
	if (!data || dataSize <= LZMA_PROPS_SIZE) return nil;

	ISzAlloc localAlloc = { LzmaSDKObjCBufferProcessorSzAlloc, LzmaSDKObjCBufferProcessorSzFree };

	CLzma2EncHandle handle = Lzma2Enc_Create(&localAlloc, &localAlloc);
	if (!handle) return nil;

	CLzma2EncProps props;
	Lzma2EncProps_Init(&props);
	props.lzmaProps.writeEndMark = 1;
	props.lzmaProps.numThreads = 1;
	props.numTotalThreads = 1;

	if (compressionRatio < 0.0f) props.lzmaProps.level = 0;
	else if (compressionRatio > 1.0f) props.lzmaProps.level = 9;
	else props.lzmaProps.level = compressionRatio * 9.0f;

	SRes res = Lzma2Enc_SetProps(handle, &props);
	if (res != SZ_OK) return nil;
	const Byte properties = Lzma2Enc_WriteProperties(handle);

	LzmaSDKObjCBufferProcessorWriter outStream;
	memset(&outStream, 0, sizeof(LzmaSDKObjCBufferProcessorWriter));
	outStream.data = [NSMutableData dataWithCapacity:dataSize / 4];
	[outStream.data appendBytes:&properties length:sizeof(Byte)];
	outStream.Write = LzmaSDKObjCBufferProcessorWrite;

	LzmaSDKObjCBufferProcessorReader inStream;
	memset(&inStream, 0, sizeof(LzmaSDKObjCBufferProcessorReader));
	inStream.data = data;
	inStream.dataSize = dataSize;
	inStream.Read = LzmaSDKObjCBufferProcessorRead;

	res = Lzma2Enc_Encode(handle,
						  (ISeqOutStream *)&outStream,
						  (ISeqInStream *)&inStream,
						  NULL);

	Lzma2Enc_Destroy(handle);
	return [outStream.data length] > sizeof(Byte) ? outStream.data : nil;
}

NSData * _Nullable LzmaSDKObjCBufferDecompressLZMA2(NSData * _Nonnull dataForDecompress) {
	if (!dataForDecompress) return nil;
	const unsigned char * data = (const unsigned char *)[dataForDecompress bytes];
	const unsigned int dataSize = (unsigned int)[dataForDecompress length];
	if (!data || dataSize <= sizeof(Byte)) return nil;

	CLzma2Dec dec;
	Lzma2Dec_Construct(&dec);

	const Byte * inData = data;
	SizeT inSize = dataSize;
	const Byte properties = *(inData);
	inData++;
	inSize--;

	ISzAlloc localAlloc = { LzmaSDKObjCBufferProcessorSzAlloc, LzmaSDKObjCBufferProcessorSzFree };

	SRes res = Lzma2Dec_AllocateProbs(&dec, properties, &localAlloc);
	if (res != SZ_OK) return nil;

	res = Lzma2Dec_Allocate(&dec, properties, &localAlloc);
	if (res != SZ_OK) return nil;

	Lzma2Dec_Init(&dec);

	NSMutableData * outData = [NSMutableData dataWithCapacity:dataSize];
	Byte dstBuff[10240];
	while ((inSize > 0) && (res == SZ_OK)) {
		ELzmaStatus status = LZMA_STATUS_NOT_SPECIFIED;
		SizeT dstSize = 10240;
		SizeT srcSize = inSize;

		res = Lzma2Dec_DecodeToBuf(&dec,
								   dstBuff,
								   &dstSize,
								   inData,
								   &srcSize,
								   LZMA_FINISH_ANY,
								   &status);
		if ((inSize >= srcSize) && (res == SZ_OK)) {
			inData += srcSize;
			inSize -= srcSize;
			[outData appendBytes:dstBuff length:dstSize];
		} else {
			break;
		}
	}

	Lzma2Dec_FreeProbs(&dec, &localAlloc);
	Lzma2Dec_Free(&dec, &localAlloc);

	return [outData length] > 0 ? outData : nil;
}
