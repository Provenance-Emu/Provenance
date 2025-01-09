/*
Copyright (C) 2003 Rice1964

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

*/

#include "CSortedList.h"
#include "Debugger.h"
#include "RSP_Parser.h"
#include "RenderBase.h"
#include "TextureManager.h"
#include "liblinux/BMGImage.h"
#include "liblinux/pngrw.h"
#include "m64p_types.h"
#include "osal_files.h"
#include "osal_preproc.h"

#define M64P_PLUGIN_PROTOTYPES 1
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <algorithm>

#include "ConvertImage.h"
#include "DeviceBuilder.h"
#include "Render.h"
#include "TextureFilters.h"
#include "Video.h"
#include "liblinux/BMGDLL.h"
#include "liblinux/BMGLibPNG.h"
#include "m64p_plugin.h"
#include "typedefs.h"

#ifdef min
#undef min
#endif

/************************************************************************/
/* 2X filters                                                           */
/************************************************************************/
// Basic 2x R8G8B8A8 filter with interpolation

void Texture2x_32( DrawInfo &srcInfo, DrawInfo &destInfo)
{
    uint32 *pDst1, *pDst2;
    uint32 *pSrc, *pSrc2;
    uint32 nWidth = srcInfo.dwWidth;
    uint32 nHeight = srcInfo.dwHeight;

    uint32 b1;
    uint32 g1;
    uint32 r1;
    uint32 a1;
    uint32 b2 = 0;
    uint32 g2 = 0;
    uint32 r2 = 0;
    uint32 a2 = 0;
    uint32 b3 = 0;
    uint32 g3 = 0;
    uint32 r3 = 0;
    uint32 a3 = 0;
    uint32 b4 = 0;
    uint32 g4 = 0;
    uint32 r4 = 0;
    uint32 a4 = 0;


    for (uint32 ySrc = 0; ySrc < nHeight; ySrc++)
    {
        pSrc = (uint32*)(((uint8*)srcInfo.lpSurface)+ySrc*srcInfo.lPitch);
        pSrc2 = (uint32*)(((uint8*)srcInfo.lpSurface)+(ySrc+1)*srcInfo.lPitch);
        pDst1 = (uint32*)(((uint8*)destInfo.lpSurface)+(ySrc*2)*destInfo.lPitch);
        pDst2 = (uint32*)(((uint8*)destInfo.lpSurface)+(ySrc*2+1)*destInfo.lPitch);

        for (uint32 xSrc = 0; xSrc < nWidth; xSrc++)
        {
            b1 = (pSrc[xSrc]>>0)&0xFF;
            g1 = (pSrc[xSrc]>>8)&0xFF;
            r1 = (pSrc[xSrc]>>16)&0xFF;
            a1 = (pSrc[xSrc]>>24)&0xFF;

            if( xSrc<nWidth-1 )
            {
                b2 = (pSrc[xSrc+1]>>0)&0xFF;
                g2 = (pSrc[xSrc+1]>>8)&0xFF;
                r2 = (pSrc[xSrc+1]>>16)&0xFF;
                a2 = (pSrc[xSrc+1]>>24)&0xFF;
            }

            if( ySrc<nHeight-1 )
            {
                b3 = (pSrc2[xSrc]>>0)&0xFF;
                g3 = (pSrc2[xSrc]>>8)&0xFF;
                r3 = (pSrc2[xSrc]>>16)&0xFF;
                a3 = (pSrc2[xSrc]>>24)&0xFF;
                if( xSrc<nWidth-1 )
                {
                    b4 = (pSrc2[xSrc+1]>>0)&0xFF;
                    g4 = (pSrc2[xSrc+1]>>8)&0xFF;
                    r4 = (pSrc2[xSrc+1]>>16)&0xFF;
                    a4 = (pSrc2[xSrc+1]>>24)&0xFF;
                }
            }


            // Pixel 1
            pDst1[xSrc*2] = pSrc[xSrc];

            // Pixel 2
            if( xSrc<nWidth-1 )
            {
                pDst1[xSrc*2+1] = DWORD_MAKE((r1+r2)/2, (g1+g2)/2, (b1+b2)/2, (a1+a2)/2);
            }
            else
                pDst1[xSrc*2+1] = pSrc[xSrc];


            // Pixel 3
            if( ySrc<nHeight-1 )
            {
                pDst2[xSrc*2] = DWORD_MAKE((r1+r3)/2, (g1+g3)/2, (b1+b3)/2, (a1+a3)/2);
            }
            else
                pDst2[xSrc*2] = pSrc[xSrc];

            // Pixel 4
            if( xSrc<nWidth-1 )
            {
                if( ySrc<nHeight-1 )
                {
                    pDst2[xSrc*2+1] = DWORD_MAKE((r1+r2+r3+r4)/4, (g1+g2+g3+g4)/4, (b1+b2+b3+b4)/4, (a1+a2+a3+a4)/4);
                }
                else
                {
                    pDst2[xSrc*2+1] = DWORD_MAKE((r1+r2)/2, (g1+g2)/2, (b1+b2)/2, (a1+a2)/2);
                }
            }
            else
            {
                if( ySrc<nHeight-1 )
                {
                    pDst2[xSrc*2+1] = DWORD_MAKE((r1+r3)/2, (g1+g3)/2, (b1+b3)/2, (a1+a3)/2);
                }
                else
                    pDst2[xSrc*2+1] = pSrc[xSrc];
            }
        }
    }
}

// Basic 2x R4G4B4A4 filter with interpolation
void Texture2x_16( DrawInfo &srcInfo, DrawInfo &destInfo )
{
    uint16 *pDst1, *pDst2;
    uint16 *pSrc, *pSrc2;
    uint32 nWidth = srcInfo.dwWidth;
    uint32 nHeight = srcInfo.dwHeight;

    uint16 b1;
    uint16 g1;
    uint16 r1;
    uint16 a1;
    uint16 b2 = 0;
    uint16 g2 = 0;
    uint16 r2 = 0;
    uint16 a2 = 0;
    uint16 b3 = 0;
    uint16 g3 = 0;
    uint16 r3 = 0;
    uint16 a3 = 0;
    uint16 b4 = 0;
    uint16 g4 = 0;
    uint16 r4 = 0;
    uint16 a4 = 0;

    for (uint16 ySrc = 0; ySrc < nHeight; ySrc++)
    {
        pSrc = (uint16*)(((uint8*)srcInfo.lpSurface)+ySrc*srcInfo.lPitch);
        pSrc2 = (uint16*)(((uint8*)srcInfo.lpSurface)+(ySrc+1)*srcInfo.lPitch);
        pDst1 = (uint16*)(((uint8*)destInfo.lpSurface)+(ySrc*2)*destInfo.lPitch);
        pDst2 = (uint16*)(((uint8*)destInfo.lpSurface)+(ySrc*2+1)*destInfo.lPitch);

        for (uint16 xSrc = 0; xSrc < nWidth; xSrc++)
        {
            b1 = (pSrc[xSrc]>> 0)&0xF;
            g1 = (pSrc[xSrc]>> 4)&0xF;
            r1 = (pSrc[xSrc]>> 8)&0xF;
            a1 = (pSrc[xSrc]>>12)&0xF;

            if( xSrc<nWidth-1 )
            {
                b2 = (pSrc[xSrc+1]>> 0)&0xF;
                g2 = (pSrc[xSrc+1]>> 4)&0xF;
                r2 = (pSrc[xSrc+1]>> 8)&0xF;
                a2 = (pSrc[xSrc+1]>>12)&0xF;
            }

            if( ySrc<nHeight-1 )
            {
                b3 = (pSrc2[xSrc]>> 0)&0xF;
                g3 = (pSrc2[xSrc]>> 4)&0xF;
                r3 = (pSrc2[xSrc]>> 8)&0xF;
                a3 = (pSrc2[xSrc]>>12)&0xF;
                if( xSrc<nWidth-1 )
                {
                    b4 = (pSrc2[xSrc+1]>> 0)&0xF;
                    g4 = (pSrc2[xSrc+1]>> 4)&0xF;
                    r4 = (pSrc2[xSrc+1]>> 8)&0xF;
                    a4 = (pSrc2[xSrc+1]>>12)&0xF;
                }
            }

            // Pixel 1
            pDst1[xSrc*2] = pSrc[xSrc];

            // Pixel 2
            if( xSrc<nWidth-1 )
            {
                pDst1[xSrc*2+1] = WORD_MAKE((r1+r2)/2, (g1+g2)/2, (b1+b2)/2, (a1+a2)/2);
            }
            else
                pDst1[xSrc*2+1] = pSrc[xSrc];


            // Pixel 3
            if( ySrc<nHeight-1 )
            {
                pDst2[xSrc*2] = WORD_MAKE((r1+r3)/2, (g1+g3)/2, (b1+b3)/2, (a1+a3)/2);
            }
            else
                pDst2[xSrc*2] = pSrc[xSrc];

            // Pixel 4
            if( xSrc<nWidth-1 )
            {
                if( ySrc<nHeight-1 )
                {
                    pDst2[xSrc*2+1] = WORD_MAKE((r1+r2+r3+r4)/4, (g1+g2+g3+g4)/4, (b1+b2+b3+b4)/4, (a1+a2+a3+a4)/4);
                }
                else
                {
                    pDst2[xSrc*2+1] = WORD_MAKE((r1+r2)/2, (g1+g2)/2, (b1+b2)/2, (a1+a2)/2);
                }
            }
            else
            {
                if( ySrc<nHeight-1 )
                {
                    pDst2[xSrc*2+1] = WORD_MAKE((r1+r3)/2, (g1+g3)/2, (b1+b3)/2, (a1+a3)/2);
                }
                else
                    pDst2[xSrc*2+1] = pSrc[xSrc];
            }
        }
    }
}

/************************************************************************/
/* Sharpen filters                                                      */
/************************************************************************/
void SharpenFilter_32(uint32 *pdata, uint32 width, uint32 height, uint32 pitch, uint32 filter)
{
    uint32 len=height*pitch;
    uint32 *pcopy = new uint32[len];

    if( !pcopy )    return;

    memcpy(pcopy, pdata, len<<2);

    uint32 mul1, mul2, mul3, shift4;
    switch( filter )
    {
        case TEXTURE_SHARPEN_MORE_ENHANCEMENT:
            mul1=1;
            mul2=8;
            mul3=12;
            shift4=2;
            break;
        case TEXTURE_SHARPEN_ENHANCEMENT:
        default:
            mul1=1;
            mul2=8;
            mul3=16;
            shift4=3;
            break;
    }

    uint32 x,y,z;
    uint32 *src1, *src2, *src3, *dest;
    uint32 val[4];
    uint32 t1,t2,t3,t4,t5,t6,t7,t8,t9;

    for( y=1; y<height-1; y++)
    {
        dest = pdata+y*pitch;
        src1 = pcopy+(y-1)*pitch;
        src2 = src1 + pitch;
        src3 = src2 + pitch;
        for( x=1; x<width-1; x++)
        {
            for( z=0; z<4; z++ )
            {
                t1 = *((uint8*)(src1+x-1)+z);
                t2 = *((uint8*)(src1+x  )+z);
                t3 = *((uint8*)(src1+x+1)+z);
                t4 = *((uint8*)(src2+x-1)+z);
                t5 = *((uint8*)(src2+x  )+z);
                t6 = *((uint8*)(src2+x+1)+z);
                t7 = *((uint8*)(src3+x-1)+z);
                t8 = *((uint8*)(src3+x  )+z);
                t9 = *((uint8*)(src3+x+1)+z);
                val[z]=t5;
                if( (t5*mul2) > (t1+t3+t7+t9+t2+t4+t6+t8)*mul1 )
                {
                    val[z]= std::min((((t5*mul3) - (t1+t3+t7+t9+t2+t4+t6+t8)*mul1)>>shift4),0xFFU);
                }
            }
            dest[x] = val[0]|(val[1]<<8)|(val[2]<<16)|(val[3]<<24);
        }
    }
    delete [] pcopy;
}

void SharpenFilter_16(uint16 *pdata, uint32 width, uint32 height, uint32 pitch, uint32 filter)
{
    //return;   // Sharpen does not make sense for 16 bits

    uint32 len=height*pitch;
    uint16 *pcopy = new uint16[len];

    if( !pcopy )    return;

    memcpy(pcopy, pdata, len<<1);

    uint16 mul1, mul2, mul3, shift4;
    switch( filter )
    {
        case TEXTURE_SHARPEN_MORE_ENHANCEMENT:
            mul1=1;
            mul2=8;
            mul3=12;
            shift4=2;
            break;
        case TEXTURE_SHARPEN_ENHANCEMENT:
        default:
            mul1=1;
            mul2=8;
            mul3=16;
            shift4=3;
            break;
    }

    uint32 x,y,z;
    uint16 *src1, *src2, *src3, *dest;
    uint16 val[4];
    uint16 t1,t2,t3,t4,t5,t6,t7,t8,t9;

    for( y=1; y<height-1; y++)
    {
        dest = pdata+y*pitch;
        src1 = pcopy+(y-1)*pitch;
        src2 = src1 + pitch;
        src3 = src2 + pitch;
        for( x=1; x<width-1; x++)
        {
            for( z=0; z<4; z++ )
            {
                uint32 shift = (z%1)?4:0;
                t1 = (*((uint8*)(src1+x-1)+(z>>1)))>>shift;
                t2 = (*((uint8*)(src1+x  )+(z>>1)))>>shift;
                t3 = (*((uint8*)(src1+x+1)+(z>>1)))>>shift;
                t4 = (*((uint8*)(src2+x-1)+(z>>1)))>>shift;
                t5 = (*((uint8*)(src2+x  )+(z>>1)))>>shift;
                t6 = (*((uint8*)(src2+x+1)+(z>>1)))>>shift;
                t7 = (*((uint8*)(src3+x-1)+(z>>1)))>>shift;
                t8 = (*((uint8*)(src3+x  )+(z>>1)))>>shift;
                t9 = (*((uint8*)(src3+x+1)+(z>>1)))>>shift;
                val[z]=t5;
                if( (t5*mul2) > (t1+t3+t7+t9+t2+t4+t6+t8)*mul1 )
                {
                    val[z] = (((t5*mul3) - (t1+t3+t7+t9+t2+t4+t6+t8)*mul1)>>shift4);
                    val[z]= std::min(val[z],(unsigned short)0xFU);
                }
            }
            dest[x] = val[0]|(val[1]<<4)|(val[2]<<8)|(val[3]<<12);
        }
    }
    delete [] pcopy;
}

/************************************************************************/
/* Smooth filters                                                       */
/************************************************************************/
void SmoothFilter_32(uint32 *pdata, uint32 width, uint32 height, uint32 pitch, uint32 filter)
{
    uint32 len=height*pitch;
    uint32 *pcopy = new uint32[len];

    if( !pcopy )    return;

    memcpy(pcopy, pdata, len<<2);

    uint32 mul1, mul2, mul3, shift4;
    switch( filter )
    {
        case TEXTURE_ENHANCEMENT_WITH_SMOOTH_FILTER_1:
            mul1=1;
            mul2=2;
            mul3=4;
            shift4=4;
            break;
        case TEXTURE_ENHANCEMENT_WITH_SMOOTH_FILTER_2:
            mul1=1;
            mul2=1;
            mul3=8;
            shift4=4;
            break;
        case TEXTURE_ENHANCEMENT_WITH_SMOOTH_FILTER_3:
            mul1=1;
            mul2=1;
            mul3=2;
            shift4=2;
            break;
        case TEXTURE_ENHANCEMENT_WITH_SMOOTH_FILTER_4:
        default:
            mul1=1;
            mul2=1;
            mul3=6;
            shift4=3;
            break;
    }

    uint32 x,y,z;
    uint32 *src1, *src2, *src3, *dest;
    uint32 val[4];
    uint32 t1,t2,t3,t4,t5,t6,t7,t8,t9;

    if( filter == TEXTURE_ENHANCEMENT_WITH_SMOOTH_FILTER_3 || filter == TEXTURE_ENHANCEMENT_WITH_SMOOTH_FILTER_4 )
    {
        for( y=1; y<height-1; y+=2)
        {
            dest = pdata+y*pitch;
            src1 = pcopy+(y-1)*pitch;
            src2 = src1 + pitch;
            src3 = src2 + pitch;
            for( x=0; x<width; x++)
            {
                for( z=0; z<4; z++ )
                {
                    t2 = *((uint8*)(src1+x  )+z);
                    t5 = *((uint8*)(src2+x  )+z);
                    t8 = *((uint8*)(src3+x  )+z);
                    val[z] = ((t2+t8)*mul2+(t5*mul3))>>shift4;
                }
                dest[x] = val[0]|(val[1]<<8)|(val[2]<<16)|(val[3]<<24);
            }
        }
    }
    else
    {
        for( y=0; y<height; y++)
        {
            dest = pdata+y*pitch;
            if( y>0 )
            {
                src1 = pcopy+(y-1)*pitch;
                src2 = src1 + pitch;
            }
            else
            {
                src1 = src2 = pcopy;
            }

            src3 = src2;
            if( y<height-1) src3 += pitch;

            for( x=1; x<width-1; x++)
            {
                for( z=0; z<4; z++ )
                {
                    t1 = *((uint8*)(src1+x-1)+z);
                    t2 = *((uint8*)(src1+x  )+z);
                    t3 = *((uint8*)(src1+x+1)+z);
                    t4 = *((uint8*)(src2+x-1)+z);
                    t5 = *((uint8*)(src2+x  )+z);
                    t6 = *((uint8*)(src2+x+1)+z);
                    t7 = *((uint8*)(src3+x-1)+z);
                    t8 = *((uint8*)(src3+x  )+z);
                    t9 = *((uint8*)(src3+x+1)+z);
                    val[z] = ((t1+t3+t7+t9)*mul1+((t2+t4+t6+t8)*mul2)+(t5*mul3))>>shift4;
                }
                dest[x] = val[0]|(val[1]<<8)|(val[2]<<16)|(val[3]<<24);
            }
        }
    }
    delete [] pcopy;
}

void SmoothFilter_16(uint16 *pdata, uint32 width, uint32 height, uint32 pitch, uint32 filter)
{
    uint32 len=height*pitch;
    uint16 *pcopy = new uint16[len];

    if( !pcopy )
        return;

    memcpy(pcopy, pdata, len<<1);

    uint16 mul1, mul2, mul3, shift4;
    switch( filter )
    {
        case TEXTURE_ENHANCEMENT_WITH_SMOOTH_FILTER_1:
            mul1=1;
            mul2=2;
            mul3=4;
            shift4=4;
            break;
        case TEXTURE_ENHANCEMENT_WITH_SMOOTH_FILTER_2:
            mul1=1;
            mul2=1;
            mul3=8;
            shift4=4;
            break;
        case TEXTURE_ENHANCEMENT_WITH_SMOOTH_FILTER_3:
            mul1=1;
            mul2=1;
            mul3=2;
            shift4=2;
            break;
        case TEXTURE_ENHANCEMENT_WITH_SMOOTH_FILTER_4:
        default:
            mul1=1;
            mul2=1;
            mul3=6;
            shift4=3;
            break;
    }

    uint32 x,y,z;
    uint16 *src1, *src2, *src3, *dest;
    uint16 val[4];
    uint16 t1,t2,t3,t4,t5,t6,t7,t8,t9;

    if( filter == TEXTURE_ENHANCEMENT_WITH_SMOOTH_FILTER_3 || filter == TEXTURE_ENHANCEMENT_WITH_SMOOTH_FILTER_4 )
    {
        for( y=1; y<height-1; y+=2)
        {
            dest = pdata+y*pitch;
            src1 = pcopy+(y-1)*pitch;
            src2 = src1 + pitch;
            src3 = src2 + pitch;
            for( x=0; x<width; x++)
            {
                for( z=0; z<4; z++ )
                {
                    uint32 shift = (z&1)?4:0;
                    t2 = (*((uint8*)(src1+x  )+(z>>1)))>>shift;
                    t5 = (*((uint8*)(src2+x  )+(z>>1)))>>shift;
                    t8 = (*((uint8*)(src3+x  )+(z>>1)))>>shift;
                    val[z] = ((t2+t8)*mul2+(t5*mul3))>>shift4;
                }
                dest[x] = val[0]|(val[1]<<4)|(val[2]<<8)|(val[3]<<12);
            }
        }
    }
    else
    {
        for( y=0; y<height; y++)
        {
            dest = pdata+y*pitch;
            if( y>0 )
            {
                src1 = pcopy+(y-1)*pitch;
                src2 = src1 + pitch;
            }
            else
            {
                src1 = src2 = pcopy;
            }

            src3 = src2;
            if( y<height-1) src3 += pitch;

            for( x=1; x<width-1; x++)
            {
                for( z=0; z<4; z++ )
                {
                    uint32 shift = (z&1)?4:0;
                    t1 = (*((uint8*)(src1+x-1)+(z>>1)))>>shift;
                    t2 = (*((uint8*)(src1+x  )+(z>>1)))>>shift;
                    t3 = (*((uint8*)(src1+x+1)+(z>>1)))>>shift;
                    t4 = (*((uint8*)(src2+x-1)+(z>>1)))>>shift;
                    t5 = (*((uint8*)(src2+x  )+(z>>1)))>>shift;
                    t6 = (*((uint8*)(src2+x+1)+(z>>1)))>>shift;
                    t7 = (*((uint8*)(src3+x-1)+(z>>1)))>>shift;
                    t8 = (*((uint8*)(src3+x  )+(z>>1)))>>shift;
                    t9 = (*((uint8*)(src3+x+1)+(z>>1)))>>shift;
                    val[z] = ((t1+t3+t7+t9)*mul1+((t2+t4+t6+t8)*mul2)+(t5*mul3))>>shift4;
                }
                dest[x] = val[0]|(val[1]<<4)|(val[2]<<8)|(val[3]<<12);
            }
        }
    }
    delete [] pcopy;
}


void EnhanceTexture(TxtrCacheEntry *pEntry)
{
    if( pEntry->dwEnhancementFlag == options.textureEnhancement )
    {
        // The texture has already been enhanced
        return;
    }
    else if( options.textureEnhancement == TEXTURE_NO_ENHANCEMENT )
    {
        //Texture enhancement has being turned off
        //Delete any allocated memory for the enhanced texture
        SAFE_DELETE(pEntry->pEnhancedTexture);
        //Set the enhancement flag so the texture wont be processed again
        pEntry->dwEnhancementFlag = TEXTURE_NO_ENHANCEMENT;
        return;
    }

    if( status.primitiveType != PRIM_TEXTRECT && options.bTexRectOnly )
    {
        return;
    }

    DrawInfo srcInfo;   
    //Start the draw update
    if( pEntry->pTexture->StartUpdate(&srcInfo) == false )
    {
        //If we get here we were unable to start the draw update
        //Delete any allocated memory for the enhanced texture
        SAFE_DELETE(pEntry->pEnhancedTexture);
        return;
    }

    uint32 realwidth = srcInfo.dwWidth;
    uint32 realheight = srcInfo.dwHeight;
    uint32 nWidth = srcInfo.dwCreatedWidth;
    uint32 nHeight = srcInfo.dwCreatedHeight;
    
    //Sharpen option is enabled, sharpen the texture
    if( options.textureEnhancement == TEXTURE_SHARPEN_ENHANCEMENT || options.textureEnhancement == TEXTURE_SHARPEN_MORE_ENHANCEMENT )
    {
        if( pEntry->pTexture->GetPixelSize() == 4 )
            SharpenFilter_32((uint32*)srcInfo.lpSurface, nWidth, nHeight, nWidth, options.textureEnhancement);
        else
            SharpenFilter_16((uint16*)srcInfo.lpSurface, nWidth, nHeight, nWidth, options.textureEnhancement);
        pEntry->dwEnhancementFlag = options.textureEnhancement;
        //End the draw update
        pEntry->pTexture->EndUpdate(&srcInfo);
        //Delete any allocated memory for the enhanced texture
        SAFE_DELETE(pEntry->pEnhancedTexture);
        return;
    }

    pEntry->dwEnhancementFlag = options.textureEnhancement;
    if( options.bSmallTextureOnly )
    {
        if( nWidth + nHeight > 256 )
        {
            //End the draw update
            pEntry->pTexture->EndUpdate(&srcInfo);
            //Delete any data allocated for the enhanced texture
            SAFE_DELETE(pEntry->pEnhancedTexture);
            //Set the enhancement flag so the texture wont be processed again
            pEntry->dwEnhancementFlag = TEXTURE_NO_ENHANCEMENT;
            return;
        }
    }


    CTexture* pSurfaceHandler = NULL;
    if( options.textureEnhancement == TEXTURE_HQ4X_ENHANCEMENT )
    {
        if( nWidth + nHeight > 1024/4 )
        {
            // Don't enhance for large textures
            pEntry->pTexture->EndUpdate(&srcInfo);
            SAFE_DELETE(pEntry->pEnhancedTexture);
            pEntry->dwEnhancementFlag = TEXTURE_NO_ENHANCEMENT;
            return;
        }
        pSurfaceHandler = CDeviceBuilder::GetBuilder()->CreateTexture(nWidth*4, nHeight*4);
    }
    else
    {
        if( nWidth + nHeight > 1024/2 )
        {
            // Don't enhance for large textures
            pEntry->pTexture->EndUpdate(&srcInfo);
            SAFE_DELETE(pEntry->pEnhancedTexture);
            pEntry->dwEnhancementFlag = TEXTURE_NO_ENHANCEMENT;
            return;
        }
        pSurfaceHandler = CDeviceBuilder::GetBuilder()->CreateTexture(nWidth*2, nHeight*2);
    }
    DrawInfo destInfo;
    if(pSurfaceHandler)
    {
        if(pSurfaceHandler->StartUpdate(&destInfo))
        {
            if( options.textureEnhancement == TEXTURE_2XSAI_ENHANCEMENT )
            {
                if( pEntry->pTexture->GetPixelSize() == 4 )
                    Super2xSaI_32((uint32*)(srcInfo.lpSurface),(uint32*)(destInfo.lpSurface), nWidth, realheight, nWidth);
                else
                    Super2xSaI_16((uint16*)(srcInfo.lpSurface),(uint16*)(destInfo.lpSurface), nWidth, realheight, nWidth);
            }
            else if( options.textureEnhancement == TEXTURE_HQ2X_ENHANCEMENT )
            {
                if( pEntry->pTexture->GetPixelSize() == 4 )
                {
                    hq2x_init(32);
                    hq2x_32((uint8*)(srcInfo.lpSurface), srcInfo.lPitch, (uint8*)(destInfo.lpSurface), destInfo.lPitch, nWidth, realheight);
                }
                else
                {
                    hq2x_init(16);
                    hq2x_16((uint8*)(srcInfo.lpSurface), srcInfo.lPitch, (uint8*)(destInfo.lpSurface), destInfo.lPitch, nWidth, realheight);
                }
            }
            else if( options.textureEnhancement == TEXTURE_LQ2X_ENHANCEMENT )
            {
                if( pEntry->pTexture->GetPixelSize() == 4 )
                {
                    hq2x_init(32);
                    lq2x_32((uint8*)(srcInfo.lpSurface), srcInfo.lPitch, (uint8*)(destInfo.lpSurface), destInfo.lPitch, nWidth, realheight);
                }
                else
                {
                    hq2x_init(16);
                    lq2x_16((uint8*)(srcInfo.lpSurface), srcInfo.lPitch, (uint8*)(destInfo.lpSurface), destInfo.lPitch, nWidth, realheight);
                }
            }
            else if( options.textureEnhancement == TEXTURE_HQ4X_ENHANCEMENT )
            {
                if( pEntry->pTexture->GetPixelSize() == 4 )
                {
                    hq4x_InitLUTs();
                    hq4x_32((uint8*)(srcInfo.lpSurface), (uint8*)(destInfo.lpSurface), realwidth, realheight, nWidth, destInfo.lPitch);
                }
                else
                {
                    hq4x_InitLUTs();
                    hq4x_16((uint8*)(srcInfo.lpSurface), (uint8*)(destInfo.lpSurface), realwidth, realheight, nWidth, destInfo.lPitch);
                }
            }
            else 
            {
                if( pEntry->pTexture->GetPixelSize() == 4 )
                    Texture2x_32( srcInfo, destInfo);
                else
                    Texture2x_16( srcInfo, destInfo);
            }

            if( options.textureEnhancementControl >= TEXTURE_ENHANCEMENT_WITH_SMOOTH_FILTER_1 )
            {
                if( options.textureEnhancement != TEXTURE_HQ4X_ENHANCEMENT )
                {
                    if( pEntry->pTexture->GetPixelSize() == 4 )
                        SmoothFilter_32((uint32*)destInfo.lpSurface, realwidth<<1, realheight<<1, nWidth<<1, options.textureEnhancementControl);
                    else
                        SmoothFilter_16((uint16*)destInfo.lpSurface, realwidth<<1, realheight<<1, nWidth<<1, options.textureEnhancementControl);
                }
                else
                {
                    if( pEntry->pTexture->GetPixelSize() == 4 )
                        SmoothFilter_32((uint32*)destInfo.lpSurface, realwidth<<2, realheight<<2, nWidth<<2, options.textureEnhancementControl);
                    else
                        SmoothFilter_16((uint16*)destInfo.lpSurface, realwidth<<2, realheight<<2, nWidth<<2, options.textureEnhancementControl);
                }
            }

            pSurfaceHandler->EndUpdate(&destInfo);  
        }
    
        pSurfaceHandler->m_bIsEnhancedTexture = true;
    }

    pEntry->pTexture->EndUpdate(&srcInfo);

    pEntry->pEnhancedTexture = pSurfaceHandler;
}

/****
 All code bellow, CLEAN ME
****/

enum TextureType
{
    NO_TEXTURE,
    RGB_PNG,
    COLOR_INDEXED_BMP,
    RGB_WITH_ALPHA_TOGETHER_PNG,
    RGBA_PNG_FOR_CI,
    RGBA_PNG_FOR_ALL_CI,
};
typedef struct {
    unsigned int width;
    unsigned int height;
    int fmt;
    int siz;
    int crc32;
    int pal_crc32;
    char *foldername;
    char *filename;
    char *filename_a;
    //char name[40];
    TextureType type;
    bool        bSeparatedAlpha;
} ExtTxtrInfo;

CSortedList<uint64,ExtTxtrInfo> gTxtrDumpInfos;
CSortedList<uint64,ExtTxtrInfo> gHiresTxtrInfos;

extern char * right(const char * src, int nchars);

#define SURFFMT_P8 41

int GetImageInfoFromFile(char* pSrcFile, IMAGE_INFO *pSrcInfo)
{
    unsigned char sig[8];
    FILE *f;

    f = fopen(pSrcFile, "rb");
    if (f == NULL)
    {
      DebugMessage(M64MSG_ERROR, "GetImageInfoFromFile() error: couldn't open file '%s'", pSrcFile);
      return 1;
    }
    if (fread(sig, 1, 8, f) != 8)
    {
      DebugMessage(M64MSG_ERROR, "GetImageInfoFromFile() error: couldn't read first 8 bytes of file '%s'", pSrcFile);
      fclose(f);
      return 1;
    }
    fclose(f);

    if(sig[0] == 'B' && sig[1] == 'M') // BMP
    {
        struct BMGImageStruct img;
        memset(&img, 0, sizeof(BMGImageStruct));
        BMG_Error code = ReadBMP(pSrcFile, &img);
        if( code == BMG_OK )
        {
            pSrcInfo->Width = img.width;
            pSrcInfo->Height = img.height;
            pSrcInfo->Depth = img.bits_per_pixel;
            pSrcInfo->MipLevels = 1;
            if(img.bits_per_pixel == 32)
                pSrcInfo->Format = SURFFMT_A8R8G8B8;
            else if(img.bits_per_pixel == 8)
                pSrcInfo->Format = SURFFMT_P8;
            // Resource and File Format ignored
            FreeBMGImage(&img);
            return 0;
        }
        DebugMessage(M64MSG_ERROR, "Couldn't read BMP file '%s'; error = %i", pSrcFile, code);
        return 1;
    }
    else if(sig[0] == 137 && sig[1] == 'P' && sig[2] == 'N' && sig[3] == 'G' && sig[4] == '\r' && sig[5] == '\n' &&
               sig[6] == 26 && sig[7] == '\n') // PNG
    {
        struct BMGImageStruct img;
        memset(&img, 0, sizeof(BMGImageStruct));
        BMG_Error code = ReadPNGInfo(pSrcFile, &img);
        if( code == BMG_OK )
        {
            pSrcInfo->Width = img.width;
            pSrcInfo->Height = img.height;
            pSrcInfo->Depth = img.bits_per_pixel;
            pSrcInfo->MipLevels = 1;
            if(img.bits_per_pixel == 32)
                pSrcInfo->Format = SURFFMT_A8R8G8B8;
            else if(img.bits_per_pixel == 8)
                pSrcInfo->Format = SURFFMT_P8;
            // Resource and File Format ignored
            FreeBMGImage(&img);
            return 0;
        }
        DebugMessage(M64MSG_ERROR, "Couldn't read PNG file '%s'; error = %i", pSrcFile, code);
        return 1;
    }

    DebugMessage(M64MSG_ERROR, "GetImageInfoFromFile : unknown file format (%s)", pSrcFile);
    return 1;
}

BOOL PathFileExists(char* pszPath)
{
    FILE *f;
    f = fopen(pszPath, "rb");
    if(f != NULL)
    {
        fclose(f);
        return TRUE;
    }
    return FALSE;
}

/********************************************************************************************************************
 * Truncates the current list with information about hires textures and scans the hires folder for hires textures and
 * creates a list with records of properties of the hires textures.
 * parameter:
 * foldername: the folder that should be scaned for valid hires textures.
 * infos: a pointer that will point to the list containing the records with the infos about the found hires textures.
 *        In case of enabled caching, these records will also contain the actual textures.
 * extraCheck: ?
 * bRecursive: flag that indicates if also subfolders should be scanned for hires textures
 * bCacheTextures: flag that indicates if the identified hires textures should also be cached
 * bMainFolder: indicates if the folder is the main folder that will be scanned. That way, texture counting does not
 *              start at 1 each time a subfolder is accessed. (microdev: I know that is not important but it really
 *              bugged me ;-))
 * return:
 * infos: the list with the records of the identified hires textures. Be aware that these records also contains the
 *        actual textures if caching is enabled.
 ********************************************************************************************************************/
void FindAllTexturesFromFolder(char *foldername, CSortedList<uint64,ExtTxtrInfo> &infos, bool extraCheck, bool bRecursive)
{
    // check if folder actually exists
    if (!osal_is_directory(foldername))
        return;

    // the path of the texture
    char texturefilename[PATH_MAX];
    //
    IMAGE_INFO  imgInfo;
    //
    IMAGE_INFO  imgInfo2;

    void *dir;
    dir = osal_search_dir_open(foldername);
    const char *foundfilename;

    int crc, palcrc32;
    unsigned int fmt, siz;
    char crcstr[16], crcstr2[16];

    do
    {
        foundfilename = osal_search_dir_read_next(dir);

        // The array is empty,  break the current operation
        if (foundfilename == NULL)
            break;
        // The current file is a hidden one
        if (foundfilename[0] == '.' )
            // These files we don't need
            continue;

        // Get the folder name
        strcpy(texturefilename, foldername);
        // And append the file name
        strcat(texturefilename, foundfilename);

        // Check if the current file is a directory and if recursive scanning is enabled
        if (osal_is_directory(texturefilename) && bRecursive )
        {
            // Add file-separator
            strcat(texturefilename, OSAL_DIR_SEPARATOR_STR);
            // Scan detected folder for hires textures (recursive call)
            FindAllTexturesFromFolder(texturefilename, infos, extraCheck, bRecursive);
            continue;
        }
        // well, the current file is actually no file (probably a directory & recursive scanning is not enabled)
        if( strstr(foundfilename,(const char*)g_curRomInfo.szGameName) == 0 )
            // go on with the next one
            continue;

        TextureType type = NO_TEXTURE;
        bool bSeparatedAlpha = false;

        // Detect the texture type by it's extention
        // microdev: this is not the smartest way. Should be done by header analysis if possible
        if( strcasecmp(right(foundfilename,7), "_ci.bmp") == 0 )
        {
            // Identify type
            if( GetImageInfoFromFile(texturefilename, &imgInfo) != 0)
            {
                DebugMessage(M64MSG_WARNING, "Cannot get image info for file: %s", foundfilename);
                continue;
            }

            if( imgInfo.Format == SURFFMT_P8 )
                // and store it to the record
                type = COLOR_INDEXED_BMP;
            else
                // Type is not supported, go on with the next one
                continue;
        }
        // Detect the texture type by its extention
        else if( strcasecmp(right(foundfilename,13), "_ciByRGBA.png") == 0 )
        {
            // Identify type
            if( GetImageInfoFromFile(texturefilename, &imgInfo) != 0 )
            {
                DebugMessage(M64MSG_WARNING, "Cannot get image info for file: %s", foundfilename);
                continue;
            }

            if( imgInfo.Format == SURFFMT_A8R8G8B8 )
                // and store it to the record
                type = RGBA_PNG_FOR_CI;
            else
                // Type is not supported, go on with the next one
                continue;
        }
        // Detect the texture type by its extention
        else if( strcasecmp(right(foundfilename,16), "_allciByRGBA.png") == 0 )
        {
            // Identify type
            if( GetImageInfoFromFile(texturefilename, &imgInfo) != 0 )
            {
                DebugMessage(M64MSG_WARNING, "Cannot get image info for file: %s", foundfilename);
                continue;
            }
            if( imgInfo.Format == SURFFMT_A8R8G8B8 )
                // and store it to the record
                type = RGBA_PNG_FOR_ALL_CI;
            else
                // Type not supported, go on with next one
                continue;
        }
        // Detect the texture type by its extention
        else if( strcasecmp(right(foundfilename,8), "_rgb.png") == 0 )
        {
            // Identify type
            if( GetImageInfoFromFile(texturefilename, &imgInfo) != 0 )
            {
                DebugMessage(M64MSG_WARNING, "Cannot get image info for file: %s", foundfilename);
                continue;
            }

            // Store type to the record
            type = RGB_PNG;

            char filename2[PATH_MAX];
            // Assemble the file name for the separate alpha channel file
            strcpy(filename2,texturefilename);
            strcpy(filename2+strlen(filename2)-8,"_a.png");
            // Check if the file actually exists
            if( PathFileExists(filename2) )
            {
                // Check if the file with this name is actually a texture (well an alpha channel one)
                if( GetImageInfoFromFile(filename2, &imgInfo2) != 0 )
                {
                    // Nope, it isn't. => Go on with the next file
                    DebugMessage(M64MSG_WARNING, "Cannot get image info for file: %s", filename2);
                    continue;
                }
                
                // Yes it is a texture file. Check if the size of the alpha channel is the same as the one of the texture
                if( extraCheck && (imgInfo2.Width != imgInfo.Width || imgInfo2.Height != imgInfo.Height) )
                {
                    // Nope, it isn't => go on with next file
                    DebugMessage(M64MSG_WARNING, "RGB and alpha texture size mismatch: %s", filename2);
                    continue;
                }

                bSeparatedAlpha = true;
            }
        }
        // Detect the texture type by its extention
        else if( strcasecmp(right(foundfilename,8), "_all.png") == 0 )
        {
            // Check if texture is of expected type
            if( GetImageInfoFromFile(texturefilename, &imgInfo) != 0 )
            {
                DebugMessage(M64MSG_WARNING, "Cannot get image info for file: %s", foundfilename);
                // Nope, continue with next file
                continue;
            }

            // Indicate file type
            type = RGB_WITH_ALPHA_TOGETHER_PNG;
        }
    
        // If a known texture format has been detected...
        if( type != NO_TEXTURE )
        {
        /*
            Try to read image information here.

            (CASTLEVANIA2)#(58E2333F)#(2)#(0)#(D7A5C6D9)_ciByRGBA.png
            (------1-----)#(---2----)#(3)#(4)#(---5----)_ciByRGBA.png
 
            1. Internal ROM name
            2. The DRAM CRC
            3. The image pixel size (8b=0, 16b=1, 24b=2, 32b=3)
            4. The texture format (RGBA=0, YUV=1, CI=2, IA=3, I=4)
            5. The palette CRC

            <internal Rom name>#<DRAM CRC>#<24bit>#<RGBA>#<PAL CRC>_ciByRGBA.png
            */

            // Get the actual file name
            strcpy(texturefilename, foundfilename);
            // Place the pointer before the DRAM-CRC (first occurrence of '#')
            char *ptr = strchr(texturefilename,'#');
            // Terminate the string ('0' means end of string - or in this case begin of string)
            *ptr++ = 0;
            if( type == RGBA_PNG_FOR_CI )
            {
                // Extract the information from the file name; information is:
                // <DRAM(or texture)-CRC><texture type><texture format><PAL(or palette)-CRC>
                sscanf(ptr,"%8c#%d#%d#%8c", crcstr, &fmt, &siz,crcstr2);
                // Terminate the ascii represntation of the palette crc
                crcstr2[8] = 0;
                // Transform the ascii presentation of the hex value to an unsigned integer
                palcrc32 = strtoul(crcstr2,NULL,16);
            }
            else
            {
                // Extract the information from the file name - this file does not have a palette crc; information is:
                // <DRAM(or texture)-CRC><texture type><texture format>
                // o gosh, commenting source code is really boring - but necessary!! Thus do it! (and don't use drugs ;-))
                sscanf(ptr,"%8c#%d#%d", crcstr, &fmt, &siz);
                // Use dummy for palette crc - that way each texture can be handled in a heterogeneous way
                palcrc32 = 0xFFFFFFFF;
            }
            // Terminate the ascii represntation of the texture crc
            crcstr[8]=0;
            // Transform the ascii presentation of the hex value to an unsigned integer
            crc = strtoul(crcstr,NULL,16);
            // For the detection of an existing item

            int foundIdx = -1;
            for( int k=0; k<infos.size(); k++)
            {
                // Check if texture already exists in the list
                // microdev: that's why I somehow love documenting code: that makes the implementation of a WIP folder check
                // fucking easy :-)
                if( infos[k].crc32 == crc && infos[k].pal_crc32 == palcrc32 )
                {
                    // Indeeed, the texture already exists
                    // microdev: MAYBE ADD CODE TO MOVE IT TO A 'DUBLICATE' FOLDER TO EASE WORK OF RETEXTURERS
                    foundIdx = k;
                    break;
                }
            }

            if( foundIdx < 0 || type != infos[foundIdx].type)
            {
                // Create a new entry
                ExtTxtrInfo newinfo;
                // Store the width
                newinfo.width = imgInfo.Width;
                // Store the height
                newinfo.height = imgInfo.Height;
                // Store the name of the folder it has been found in
                //strcpy(newinfo.name,g_curRomInfo.szGameName);
                newinfo.foldername = new char[strlen(foldername)+1];
                strcpy(newinfo.foldername,foldername);
                // store the filename
                newinfo.filename = strdup(foundfilename);
                newinfo.filename_a = NULL;
                // Store the format
                newinfo.fmt = fmt;
                // Store the size (bit-size, not texture size)
                newinfo.siz = siz;
                // Store DRAM (texture) CRC
                newinfo.crc32 = crc;
                // Store PAL (palette) CRC (the actual one, or the dummy value ('FFFFFFFF'))
                newinfo.pal_crc32 = palcrc32;
                // Store the texture type
                newinfo.type = type;
                //Indicate if there is a separate alpha file that has to be loaded
                newinfo.bSeparatedAlpha = bSeparatedAlpha;
                if (bSeparatedAlpha) {
                    char filename2[PATH_MAX];
                    strcpy(filename2, foundfilename);
                    strcpy(filename2+strlen(filename2)-8,"_a.png");
                    newinfo.filename_a = strdup(filename2);
                }
                // Generate the key for the record describing the hires texture.
                // This key is used to find it back in the list
                // The key format is: <DRAM(texture)-CRC-8byte><PAL(palette)-CRC-6byte(2bytes have been truncated to have space for format and size)><format-1byte><size-1byte>
                uint64 crc64 = newinfo.crc32;
                crc64 <<= 32;
                if (options.bLoadHiResCRCOnly)
                    crc64 |= newinfo.pal_crc32&0xFFFFFFFF;
                else
                    crc64 |= (newinfo.pal_crc32&0xFFFFFF00)|(newinfo.fmt<<4)|newinfo.siz;
                // Add the new record to the list
                infos.add(crc64,newinfo);
            }
        }
    } while(foundfilename != NULL);

    osal_search_dir_close(dir);
}
/********************************************************************************************************************
 * Checks if a folder is actually existant. If not, it tries to create this folder
 * parameter:
 * pathname: the name of the folder that should be checked or created if not existant
 * return:
 * return value: flag that indicates true if the folder is existant or could be created. If none was the case,
 *               false will be returned
 ********************************************************************************************************************/

bool CheckAndCreateFolder(const char* pathname)
{
    // Check if provided folder already exists
    if( !PathFileExists((char*)pathname) )
    {
        // It didn't. Try creating it.
        if (osal_mkdirp(pathname, 0700) != 0)
        {
            // It didn't work (probably insufficient permissions or read-only media) ==> return false
            DebugMessage(M64MSG_WARNING, "Can not create new folder: %s", pathname);
            return false;
        }
    }
    // success

    return true;
}
// microdev: THIS HAS TO BE CLEANED UP...


// Texture dumping filenaming
// GameName_FrameCount_CRC_Fmt_Siz.bmp
// File format:     BMP
// GameName:        N64 game internal name
// CRC:             32 bit, 8 hex digits
// Fmt:             0 - 4
// Siz:             0 - 3

const char *subfolders[] = {
    "png_all",
    "png_by_rgb_a",
    "ci_bmp",
    "ci_bmp_with_pal_crc",
    "ci_by_png",
};

void FindAllDumpedTextures(void)
{
    char    foldername[PATH_MAX + 64];
    strncpy(foldername, ConfigGetUserDataPath(), PATH_MAX);
    foldername[PATH_MAX] = 0;

    if (foldername[strlen(foldername) - 1] != OSAL_DIR_SEPARATOR_CHAR)
        strcat(foldername, OSAL_DIR_SEPARATOR_STR);
    strcat(foldername,"texture_dump" OSAL_DIR_SEPARATOR_STR);

    CheckAndCreateFolder(foldername);

    strcat(foldername,(const char*)g_curRomInfo.szGameName);
    strcat(foldername, OSAL_DIR_SEPARATOR_STR);

    gTxtrDumpInfos.clear();
    if( !PathFileExists(foldername) )
    {
        CheckAndCreateFolder(foldername);
        char    foldername2[PATH_MAX];
        for( int i=0; i<5; i++)
        {
            strcpy(foldername2,foldername);
            strcat(foldername2,subfolders[i]);
            CheckAndCreateFolder(foldername2);
        }
        return;
    }
    else
    {
        gTxtrDumpInfos.clear();
        FindAllTexturesFromFolder(foldername,gTxtrDumpInfos, false, true);

        char    foldername2[PATH_MAX];
        for( int i=0; i<5; i++)
        {
            strcpy(foldername2,foldername);
            strcat(foldername2,subfolders[i]);
            CheckAndCreateFolder(foldername2);
        }
    }
}

/********************************************************************************************************************
 * Truncates the current list with information about hires textures and scans the hires folder for hires textures and
 * creates a list with records of properties of the hires textures.
 * parameter:
 * none
 * return:
 * none
 ********************************************************************************************************************/
void FindAllHiResTextures(void)
{
    char    foldername[PATH_MAX + 64];
    strncpy(foldername, ConfigGetUserDataPath(), PATH_MAX);
    foldername[PATH_MAX] = 0;

    // Assure that a backslash exists at the end (should be handled by GetPluginDir())
    if(foldername[strlen(foldername) - 1] != OSAL_DIR_SEPARATOR_CHAR)
        strcat(foldername, OSAL_DIR_SEPARATOR_STR);
    // Add the relative path to the hires folder
    strcat(foldername,"hires_texture" OSAL_DIR_SEPARATOR_STR);
    // It does not exist? => Create it
    CheckAndCreateFolder(foldername);

    // Add the path to a sub-folder corresponding to the rom name
    // HOOK IN: PACK SELECT
    strcat(foldername,(const char*)g_curRomInfo.szGameName);
    strcat(foldername, OSAL_DIR_SEPARATOR_STR);
    // Truncate the current list with the hires texture info
    gHiresTxtrInfos.clear();
    if (!osal_is_directory(foldername))
    {
        DebugMessage(M64MSG_WARNING, "Couldn't open hi-res texture directory: %s", foldername);
        return;
    }
    else
    {
        // Find all hires textures and also cache them if configured to do so
        FindAllTexturesFromFolder(foldername,gHiresTxtrInfos, true, true);
    }
}

void CloseHiresTextures(void)
{
    for( int i=0; i<gHiresTxtrInfos.size(); i++)
    {
        if( gHiresTxtrInfos[i].foldername )
            delete [] gHiresTxtrInfos[i].foldername;
        if( gHiresTxtrInfos[i].filename )
            delete [] gHiresTxtrInfos[i].filename;
        if( gHiresTxtrInfos[i].filename_a )
            delete [] gHiresTxtrInfos[i].filename_a;
    }

    gHiresTxtrInfos.clear();
}

void CloseTextureDump(void)
{
    for( int i=0; i<gTxtrDumpInfos.size(); i++)
    {
        if( gTxtrDumpInfos[i].foldername )  
            delete [] gTxtrDumpInfos[i].foldername;
        if( gTxtrDumpInfos[i].filename )
            delete [] gTxtrDumpInfos[i].filename;
        if( gTxtrDumpInfos[i].filename_a )
            delete [] gTxtrDumpInfos[i].filename_a;
    }

    gTxtrDumpInfos.clear();
}

void CloseExternalTextures(void)
{
    CloseHiresTextures();
    CloseTextureDump();
}

/********************************************************************************************************************
 * Scans the hires folder for hires textures and creates a list with records of properties of the hires textures.
 * in case of enabled hires caching also the actual hires textures will be added to the record. Before textures will
 * be loaded, existing list of texture information will be truncated.
 * parameter:
 * bWIPFolder: Indicates if all textures should be inited or just the WIP folder. Just the content of the WIP folder
 *             will be reloaded if a savestate has been loaded or if there has been a switch between window and full-
 *             screen mode. (Not implemented yet)
 * return:
 * none
 ********************************************************************************************************************/
void InitHiresTextures(void)
{
    if( options.bLoadHiResTextures )
    {
        DebugMessage(M64MSG_INFO, "Texture loading option is enabled. Finding all hires textures");
        FindAllHiResTextures();
    }
}

void InitTextureDump(void)
{
    if( options.bDumpTexturesToFiles )
    {
        DebugMessage(M64MSG_INFO, "Texture dump option is enabled. Finding all dumpped textures");
        FindAllDumpedTextures();
    }
}

/********************************************************************************************************************
 * Inits the hires textures. For doing so, all hires textures info & the cached textures (for dumping and the hires ones)
 * are deleted. Afterwards they are reloaded from file system. This only takes place if a new rom has been loaded.
 * parameter:
 * none
 * return:
 * none
 ********************************************************************************************************************/
void InitExternalTextures(void)
{
    DebugMessage(M64MSG_VERBOSE, "InitExternalTextures");
    // remove all hires & dump textures from cache
    CloseExternalTextures();
    // reload and recache hires textures
    InitHiresTextures();
    // prepare list of already dumped textures (for avoiding to redump them). Available hires textures will
    // also be excluded from dumping
    InitTextureDump();
}

/********************************************************************************************************************
 * Determines the scale factor for resizing the original texture to the hires replacement. The scale factor is a left
 * shift. That means scale factor 1 = size(original texture)*2= size(hires texture),
 * factor 2 = size(original texture)*4= size(hires texture), etc. (I'm not yet sure why it has to be 2^x. Most probably
 * because of block size. Has to be further determined.
 * parameter:
 * info: the record describing the external texture
 * entry: the original texture in the texture cache
 * return:
 * info.scaleShift: the value for left shift the original texture size to the corresponding hires texture size
 * return value: the value for left shift the original texture size to the corresponding hires texture size.
 *               The function returns -1 if the dimensions of the hires texture are not a power of two of the
 *               original texture.
 ********************************************************************************************************************/
int FindScaleFactor(const ExtTxtrInfo &info, TxtrCacheEntry &entry)
{
    // init scale shift
    int scaleShift = 0;
    // check if the original texture dimensions (x and y) scaled with the current shift is still smaller or of the same size as the hires one
    while(info.height >= entry.ti.HeightToLoad*(1<<scaleShift)  && info.width >= entry.ti.WidthToLoad*(1<<scaleShift))
    {
        // check if the original texture dimensions (x and y)scaled with the current shift have the same size as the hires one
        if(info.height == entry.ti.HeightToLoad*(1<<scaleShift)  && info.width == entry.ti.WidthToLoad*(1<<scaleShift))
            // found appropriate scale shift, return it
            return scaleShift;

        scaleShift++;
    }

    // original texture dimensions (x or y or both) scaled with the last scale shift have become larger than the dimensions
    // of the hires texture. That means the dimensions of the hires replacement are not power of 2 of the original texture.
    // Therefore indicate a crop shift (or -1 when the hires_texture was smaller from the beginning)
    scaleShift -= 1;
    return scaleShift;
}


/********************************************************************************************************************
 * Checks if a hires replacement for a texture is available.
 * parameter:
 * infos: The list of external textures
 * entry: the original texture in the texture cache
 * return:
 * indexa: returns the index in "infos" where a hires replacement for a texture without
 *         palette crc or a RGBA_PNG_FOR_ALL_CI texture has been found
 * return value: the index in "infos" where the corresponding hires texture has been found
 ********************************************************************************************************************/
int CheckTextureInfos( CSortedList<uint64,ExtTxtrInfo> &infos, TxtrCacheEntry &entry, int &indexa, int &scaleShift, bool bForDump = false)
{
    if ((entry.ti.WidthToLoad  != 0 && entry.ti.WidthToCreate  / entry.ti.WidthToLoad  > 2) ||
        (entry.ti.HeightToLoad != 0 && entry.ti.HeightToCreate / entry.ti.HeightToLoad > 2 ))
    {
        //DebugMessage(M64MSG_WARNING, "Hires texture does not support extreme texture replication");
        return -1;
    }
    // determine if texture is a color-indexed (CI) texture

    bool bCI = (gRDP.otherMode.text_tlut>=2 || entry.ti.Format == TXT_FMT_CI || entry.ti.Format == TXT_FMT_RGBA) && entry.ti.Size <= TXT_SIZE_8b;
    // generate two alternative ids

    uint64 crc64a = entry.dwCRC;
    crc64a <<= 32;
    uint64 crc64b = crc64a;
    if (options.bLoadHiResCRCOnly) {
        crc64a |= (0xFFFFFFFF);
        crc64b |= (entry.dwPalCRC&0xFFFFFFFF);
    } else {
        crc64a |= (0xFFFFFF00|(entry.ti.Format<<4)|entry.ti.Size);
        crc64b |= ((entry.dwPalCRC&0xFFFFFF00)|(entry.ti.Format<<4)|entry.ti.Size);
    }

    // infos is the list containing the references to the detected external textures
    // get the number of items contained in this list
    int infosize = infos.size();
    int indexb=-1;
    // try to identify the external texture that
    // corresponds to the original texture
    indexa = infos.find(crc64a);        // For CI without pal CRC, and for RGBA_PNG_FOR_ALL_CI
    if( bCI )   
        // and also for textures with separate alpha channel
        indexb = infos.find(crc64b);    // For CI or PNG with pal CRC

    // did not found the ext. text.
    if( indexa >= infosize )
        indexa = -1;
    // did not found the ext. text. w/ sep. alpha channel
    if( indexb >= infosize )
        indexb = -1;

    scaleShift = -1;

    // found texture with sep. alpha channel

    if( indexb >= 0 )
    {
        // determine the factor for scaling
        scaleShift = FindScaleFactor(infos[indexb], entry);
        // ok. the scale factor is supported. A valid replacement has been found
        if( scaleShift >= 0 )
            return indexb;
    }
    // if texture is 4bit, should be dumped and there is no match in the list of external textures

    if( bForDump && bCI && indexb < 0)
        // than return that there is no replacement & therefore texture can be dumped (microdev: not sure about that...)
        return -1;

    // texture has no separate alpha channel, try to find it in the ext. text. list
    if( indexa >= 0 )
        scaleShift = FindScaleFactor(infos[indexa], entry);
    // ok. the scale factor is supported. A valid replacement has been found
    // this is a texture without ext. alpha channel

    if( scaleShift >= 0 )
        return indexa;
    // no luck at all. there is no valid replacement
    else
        return -1;
}

bool SaveCITextureToFile(TxtrCacheEntry &entry, char *filename, bool bShow, bool bWhole);

void DumpCachedTexture( TxtrCacheEntry &entry )
{
    char cSep = '/';

    CTexture *pSrcTexture = entry.pTexture;
    if( pSrcTexture )
    {
        // Check the vector table
        int ciidx, scaleShift;
        if( CheckTextureInfos(gTxtrDumpInfos,entry,ciidx,scaleShift,true) >= 0 )
            return;     // This texture has been dumpped

        char filename1[PATH_MAX + 64];
        char filename2[PATH_MAX + 64];
        char filename3[PATH_MAX + 64];
        char gamefolder[PATH_MAX + 64];
        strncpy(gamefolder, ConfigGetUserDataPath(), PATH_MAX);
        gamefolder[PATH_MAX] = 0;
        
        strcat(gamefolder,"texture_dump" OSAL_DIR_SEPARATOR_STR);
        strcat(gamefolder,(const char*)g_curRomInfo.szGameName);
        strcat(gamefolder, OSAL_DIR_SEPARATOR_STR);

        //sprintf(filename1+strlen(filename1), "%08X#%d#%d", entry.dwCRC, entry.ti.Format, entry.ti.Size);
        sprintf(filename1, "%s%s#%08X#%d#%d", gamefolder, g_curRomInfo.szGameName, entry.dwCRC, entry.ti.Format, entry.ti.Size);

        if( (gRDP.otherMode.text_tlut>=2 || entry.ti.Format == TXT_FMT_CI || entry.ti.Format == TXT_FMT_RGBA) && entry.ti.Size <= TXT_SIZE_8b )
        {
            if( ciidx < 0 )
            {
                sprintf(filename1, "%sci_bmp%c%s#%08X#%d#%d_ci", gamefolder, cSep, g_curRomInfo.szGameName, entry.dwCRC, entry.ti.Format, entry.ti.Size);
                SaveCITextureToFile(entry, filename1, false, false);
            }

            sprintf(filename1, "%sci_bmp_with_pal_crc%c%s#%08X#%d#%d#%08X_ci", gamefolder, cSep, g_curRomInfo.szGameName, entry.dwCRC, entry.ti.Format, entry.ti.Size,entry.dwPalCRC);
            SaveCITextureToFile(entry, filename1, false, false);

            sprintf(filename1, "%sci_by_png%c%s#%08X#%d#%d#%08X_ciByRGBA", gamefolder, cSep, g_curRomInfo.szGameName, entry.dwCRC, entry.ti.Format, entry.ti.Size,entry.dwPalCRC);
            CRender::g_pRender->SaveTextureToFile(*pSrcTexture, filename1, TXT_RGBA, false, false, entry.ti.WidthToLoad, entry.ti.HeightToLoad);
        }
        else
        {
            sprintf(filename1, "%spng_by_rgb_a%c%s#%08X#%d#%d_rgb", gamefolder, cSep, g_curRomInfo.szGameName, entry.dwCRC, entry.ti.Format, entry.ti.Size);
            sprintf(filename2, "%spng_by_rgb_a%c%s#%08X#%d#%d_a", gamefolder, cSep, g_curRomInfo.szGameName, entry.dwCRC, entry.ti.Format, entry.ti.Size);
            sprintf(filename3, "%spng_all%c%s#%08X#%d#%d_all", gamefolder, cSep, g_curRomInfo.szGameName, entry.dwCRC, entry.ti.Format, entry.ti.Size);


            CRender::g_pRender->SaveTextureToFile(*pSrcTexture, filename1, TXT_RGB, false, false, entry.ti.WidthToLoad, entry.ti.HeightToLoad);
            CRender::g_pRender->SaveTextureToFile(*pSrcTexture, filename3, TXT_RGBA, false, false, entry.ti.WidthToLoad, entry.ti.HeightToLoad);
            if( entry.ti.Format != TXT_FMT_I )
            {
                DrawInfo srcInfo;   
                uint32 aFF = 0xFF;
                if( pSrcTexture->StartUpdate(&srcInfo) )
                {
                    // Copy RGB to buffer
                    for( int i=entry.ti.HeightToLoad-1; i>=0; i--)
                    {
                        unsigned char *pSrc = (unsigned char*)srcInfo.lpSurface+srcInfo.lPitch * i;
                        for( uint32 j=0; j<entry.ti.WidthToLoad; j++)
                        {
                            aFF &= pSrc[3];
                            pSrc += 4;
                        }
                    }
                    pSrcTexture->EndUpdate(&srcInfo);
                }

                if( aFF != 0xFF)
                    CRender::g_pRender->SaveTextureToFile(*pSrcTexture, filename2, TXT_ALPHA, false, false);
            }       
        }

        ExtTxtrInfo newinfo;
        newinfo.width = entry.ti.WidthToLoad;
        newinfo.height = entry.ti.HeightToLoad;
        //strcpy(newinfo.name,g_curRomInfo.szGameName);
        newinfo.fmt = entry.ti.Format;
        newinfo.siz = entry.ti.Size;
        newinfo.crc32 = entry.dwCRC;

        newinfo.pal_crc32 = entry.dwPalCRC;
        newinfo.foldername = NULL;
        newinfo.filename = NULL;
        newinfo.filename_a = NULL;
        newinfo.type = NO_TEXTURE;
        newinfo.bSeparatedAlpha = false;

        uint64 crc64 = newinfo.crc32;
        crc64 <<= 32;
        if (options.bLoadHiResCRCOnly)
            crc64 |= newinfo.pal_crc32&0xFFFFFFFF;
        else
            crc64 |= (newinfo.pal_crc32&0xFFFFFF00)|(newinfo.fmt<<4)|newinfo.siz;
        gTxtrDumpInfos.add(crc64,newinfo);

    }
}

bool LoadRGBBufferFromPNGFile(char *filename, unsigned char **pbuf, int &width, int &height, int bits_per_pixel = 24 )
{
    struct BMGImageStruct img;
    memset(&img, 0, sizeof(BMGImageStruct));
    if (!PathFileExists(filename))
    {
        DebugMessage(M64MSG_ERROR, "File at '%s' doesn't exist in LoadRGBBufferFromPNGFile!", filename);
        return false;
    }

    BMG_Error code = ReadPNG( filename, &img );
    if( code == BMG_OK )
    {
        *pbuf = NULL;

        *pbuf = new unsigned char[img.width*img.height*bits_per_pixel/8];
        if (*pbuf == NULL)
        {
            DebugMessage(M64MSG_ERROR, "new[] returned NULL for image width=%i height=%i bpp=%i", img.width, img.height, bits_per_pixel);
            return false;
        }
        if (img.bits_per_pixel == bits_per_pixel)
        {
            memcpy(*pbuf, img.bits, img.width*img.height*bits_per_pixel/8);
        }
        else if (img.bits_per_pixel == 24 && bits_per_pixel == 32)
        {
            unsigned char *pSrc = img.bits;
            unsigned char *pDst = *pbuf;
            for (int i = 0; i < (int)(img.width*img.height); i++)
            {
                *pDst++ = *pSrc++;
                *pDst++ = *pSrc++;
                *pDst++ = *pSrc++;
                *pDst++ = 0;
            }
        }
        // loaded image has alpha, needed image has to be without alpha channel
        else if (img.bits_per_pixel == 32 && bits_per_pixel == 24)
        {
            // pointer to source image data
            unsigned char *pSrc = img.bits;
            // buffer for destination image
            unsigned char *pDst = *pbuf;
            // copy data of the loaded image to the buffer by skipping the alpha byte
            for (int i = 0; i < (int)(img.width*img.height); i++)
            {
                // copy R
                *pDst++ = *pSrc++;
                // copy G
                *pDst++ = *pSrc++;
                // copy B
                *pDst++ = *pSrc++;
                // skip the alpha byte of the loaded image
                pSrc++;
            }
        }
        else if (img.bits_per_pixel == 8 && (bits_per_pixel == 24 || bits_per_pixel == 32))
        {
            // do palette lookup and convert 8bpp to 24/32bpp
            int destBytePP = bits_per_pixel / 8;
            int paletteBytePP = img.bytes_per_palette_entry;
            unsigned char *pSrc = img.bits;
            unsigned char *pDst = *pbuf;
            // clear the destination image data (just to clear alpha if bpp=32)
            memset(*pbuf, 0, img.width*img.height*destBytePP);
            for (int i = 0; i < (int)(img.width*img.height); i++)
            {
                unsigned char clridx = *pSrc++;
                unsigned char *palcolor = img.palette + clridx * paletteBytePP;
                pDst[0] = palcolor[2]; // red
                pDst[1] = palcolor[1]; // green
                pDst[2] = palcolor[0]; // blue
                pDst += destBytePP;
            }
        }
        else
        {
            DebugMessage(M64MSG_ERROR, "PNG file '%s' is %i bpp but texture is %i bpp.", filename, img.bits_per_pixel, bits_per_pixel);
            delete [] *pbuf;
            *pbuf = NULL;
        }

        width = img.width;
        height = img.height;
        FreeBMGImage(&img);

        return true;
    }
    else
    {
        DebugMessage(M64MSG_ERROR, "ReadPNG() returned error for '%s' in LoadRGBBufferFromPNGFile!", filename);
        *pbuf = NULL;
        return false;
    }
}

bool LoadRGBABufferFromColorIndexedFile(char *filename, TxtrCacheEntry &entry, unsigned char **pbuf, int &width, int &height)
{
    BITMAPFILEHEADER fileHeader;
    BITMAPINFOHEADER infoHeader;

    FILE *f;
    f = fopen(filename, "rb");
    if(f != NULL)
    {
        if (fread(&fileHeader, sizeof(BITMAPFILEHEADER), 1, f) != 1 ||
            fread(&infoHeader, sizeof(BITMAPINFOHEADER), 1, f) != 1)
        {
            DebugMessage(M64MSG_ERROR, "Couldn't read BMP headers in file '%s'", filename);
            return false;
        }

        if( infoHeader.biBitCount != 4 && infoHeader.biBitCount != 8 )
        {
            fclose(f);
            DebugMessage(M64MSG_ERROR, "Unsupported BMP file format: %s", filename);
            *pbuf = NULL;
            return false;
        }

        int tablesize = infoHeader.biBitCount == 4 ? 16 : 256;
        uint32 *pTable = new uint32[tablesize];
        if (fread(pTable, tablesize*4, 1, f) != 1)
        {
            DebugMessage(M64MSG_ERROR, "Couldn't read BMP palette in file '%s'", filename);
            delete [] pTable;
            return false;
        }

        // Create the pallette table
        uint16 * pPal = (uint16 *)entry.ti.PalAddress;
        if( entry.ti.Size == TXT_SIZE_4b )
        {
            // 4-bit table
            for( int i=0; i<16; i++ )
            {
                pTable[i] = entry.ti.TLutFmt == TLUT_FMT_RGBA16 ? Convert555ToRGBA(pPal[i^1]) : ConvertIA16ToRGBA(pPal[i^1]);
            }
        }
        else
        {
            // 8-bit table
            for( int i=0; i<256; i++ )
            {
                pTable[i] = entry.ti.TLutFmt == TLUT_FMT_RGBA16 ? Convert555ToRGBA(pPal[i^1]) : ConvertIA16ToRGBA(pPal[i^1]);
            }
        }

        *pbuf = new unsigned char[infoHeader.biWidth*infoHeader.biHeight*4];
        if( *pbuf )
        {
            unsigned char *colorIdxBuf = new unsigned char[infoHeader.biSizeImage];
            if( colorIdxBuf )
            {
                if (fread(colorIdxBuf, infoHeader.biSizeImage, 1, f) != 1)
                {
                    DebugMessage(M64MSG_ERROR, "Couldn't read BMP image data in file '%s'", filename);
                }

                width = infoHeader.biWidth;
                height = infoHeader.biHeight;

                // Converting pallette texture to RGBA texture
                int idx = 0;
                uint32 *pbuf2 = (uint32*) *pbuf;

                for( int i=height-1; i>=0; i--)
                {
                    for( int j=0; j<width; j++)
                    {
                        if( entry.ti.Size == TXT_SIZE_4b )
                        {
                            // 4 bits
                            if( idx%2 )
                            {
                                // 1
                                *pbuf2++ = pTable[colorIdxBuf[(idx++)>>1]&0xF];
                            }
                            else
                            {
                                // 0
                                *pbuf2++ = pTable[(colorIdxBuf[(idx++)>>1]>>4)&0xF];
                            }
                        }
                        else
                        {
                            // 8 bits
                            *pbuf2++ = pTable[colorIdxBuf[idx++]];
                        }
                    }
                    if( entry.ti.Size == TXT_SIZE_4b )
                    {
                        if( idx%8 ) idx = (idx/8+1)*8;
                    }
                    else
                    {
                        if( idx%4 ) idx = (idx/4+1)*4;
                    }
                }

                delete [] colorIdxBuf;
            }
            else
            {
                TRACE0("Out of memory");
            }

            delete [] pTable;
            return true;
        }
        else
        {
            fclose(f);
            delete [] pTable;
            return false;
        }
    }
    else
    {
        // Do something
        TRACE1("Fail to open file %s", filename);
        *pbuf = NULL;
        return false;
    }
}

bool LoadRGBBufferFromBMPFile(char *filename, unsigned char **pbuf, int &width, int &height)
{
    BITMAPFILEHEADER fileHeader;
    BITMAPINFOHEADER infoHeader;

    FILE *f;
    f = fopen(filename, "rb");
    if(f != NULL)
    {
        if (fread(&fileHeader, sizeof(BITMAPFILEHEADER), 1, f) != 1 ||
            fread(&infoHeader, sizeof(BITMAPINFOHEADER), 1, f) != 1)
        {
            DebugMessage(M64MSG_ERROR, "Couldn't read BMP headers in file '%s'", filename);
            return false;
        }

        if( infoHeader.biBitCount != 24 )
        {
            fclose(f);
            DebugMessage(M64MSG_ERROR, "Unsupported BMP file 16 bits format: %s", filename);
            *pbuf = NULL;
            return false;
        }

        *pbuf = new unsigned char[infoHeader.biWidth*infoHeader.biHeight*3];
        if( *pbuf )
        {
            if (fread(*pbuf, infoHeader.biWidth*infoHeader.biHeight*3, 1, f) != 1)
                DebugMessage(M64MSG_ERROR, "Couldn't read RGB BMP image data in file '%s'", filename);
            fclose(f);
            width = infoHeader.biWidth;
            height = infoHeader.biHeight;
            return true;
        }
        else
        {
            fclose(f);
            return false;
        }
    }
    else
    {
        // Do something
        DebugMessage(M64MSG_WARNING, "Fail to open file %s", filename);
        *pbuf = NULL;
        return false;
    }
}

/*******************************************************
 * Loads the hires equivaltent of a texture
 * parameter:
 * TxtrCacheEntry: The original texture in the texture cache
 * return:
 * none
 *******************************************************/
void LoadHiresTexture( TxtrCacheEntry &entry )
{
    // check if the external texture has already been loaded
    if( entry.bExternalTxtrChecked )
        return;
    // there is already an enhanced texture (e.g. a filtered one)

    if( entry.pEnhancedTexture )
    {
        // delete it from memory before loading the external one
        SAFE_DELETE(entry.pEnhancedTexture);
    }

    int ciidx, scaleShift;
    // search the index of the appropriate hires replacement texture
    // in the list containing the infos of the external textures
    // ciidx is not needed here (just needed for dumping)
    int idx = CheckTextureInfos(gHiresTxtrInfos,entry,ciidx,scaleShift,false);
    if( idx < 0 )
    {
        // there is no hires replacement => indicate that
        entry.bExternalTxtrChecked = true;
        return;
    }

    // Load the bitmap file
    char filename_rgb[PATH_MAX];
    char filename_a[PATH_MAX];

    strcpy(filename_rgb, gHiresTxtrInfos[idx].foldername);
    strcat(filename_rgb, gHiresTxtrInfos[idx].filename);

    if (gHiresTxtrInfos[idx].filename_a) {
        strcpy(filename_a, gHiresTxtrInfos[idx].foldername);
        strcat(filename_a, gHiresTxtrInfos[idx].filename_a);
    } else {
        strcpy(filename_a, "");
    }

    // Load BMP image to buffer_rbg
    unsigned char *buf_rgba = NULL;
    unsigned char *buf_a = NULL;
    int width, height;

    bool bResRGBA=false, bResA=false;
    bool bCI = ((gRDP.otherMode.text_tlut>=2 || entry.ti.Format == TXT_FMT_CI || entry.ti.Format == TXT_FMT_RGBA) && entry.ti.Size <= TXT_SIZE_8b );

    switch( gHiresTxtrInfos[idx].type )
    {
        case RGB_PNG:
            if( bCI )   
                return;
            else
            {
                bResRGBA = LoadRGBBufferFromPNGFile(filename_rgb, &buf_rgba, width, height);
                if( bResRGBA && gHiresTxtrInfos[idx].bSeparatedAlpha )
                    bResA = LoadRGBBufferFromPNGFile(filename_a, &buf_a, width, height);
            }
            break;
        case COLOR_INDEXED_BMP:
            if( bCI )   
                bResRGBA = LoadRGBABufferFromColorIndexedFile(filename_rgb, entry, &buf_rgba, width, height);
            else
                return;
            break;
        case RGBA_PNG_FOR_CI:
        case RGBA_PNG_FOR_ALL_CI:
            if( bCI )   
                bResRGBA = LoadRGBBufferFromPNGFile(filename_rgb, &buf_rgba, width, height, 32);
            else
                return;
            break;
        case RGB_WITH_ALPHA_TOGETHER_PNG:
            if( bCI )   
                return;
            else
                bResRGBA = LoadRGBBufferFromPNGFile(filename_rgb, &buf_rgba, width, height, 32);
            break;
        default:
            return;
    }

    if( !bResRGBA || !buf_rgba )
    {
        DebugMessage(M64MSG_ERROR, "RGBBuffer creation failed for file '%s'.", filename_rgb);
        return;
    }
    // check if the alpha channel has been loaded if the texture has a separate alpha channel
    else if( gHiresTxtrInfos[idx].bSeparatedAlpha && !bResA )
    {
        DebugMessage(M64MSG_ERROR, "Alpha buffer creation failed for file '%s'.", filename_a);
        delete [] buf_rgba;
        return;
    }

    // calculate the texture size magnification by comparing the N64 texture size and the hi-res texture size
    int scale = 1 << scaleShift;
    int mirrorx = 1;
    int mirrory = 1;
    int input_height_shift = height - entry.ti.HeightToLoad * scale;
    int input_pitch_a = width;
    int input_pitch_rgb = width;
    width = entry.ti.WidthToLoad * scale;
    height = entry.ti.HeightToLoad * scale;
    if (entry.ti.WidthToCreate/entry.ti.WidthToLoad == 2) mirrorx = 2;
    if (entry.ti.HeightToCreate/entry.ti.HeightToLoad == 2) mirrory = 2;
    entry.pEnhancedTexture = CDeviceBuilder::GetBuilder()->CreateTexture(entry.ti.WidthToCreate*scale, entry.ti.HeightToCreate*scale);
    DrawInfo info;
    
    if( entry.pEnhancedTexture && entry.pEnhancedTexture->StartUpdate(&info) )
    {

        if( gHiresTxtrInfos[idx].type == RGB_PNG )
        {
            input_pitch_rgb *= 3;
            input_pitch_a *= 3;

            if (info.lPitch < width * 4)
                DebugMessage(M64MSG_ERROR, "Texture pitch %i less than width %i times 4", info.lPitch, width);
            if (height > info.dwHeight)
                DebugMessage(M64MSG_ERROR, "Texture source height %i greater than destination height %i", height, info.dwHeight);

            // Update the texture by using the buffer
            for( int i=0; i<height; i++)
            {
                unsigned char *pRGB = buf_rgba + (input_height_shift + i) * input_pitch_rgb;
                unsigned char *pA = buf_a + (input_height_shift + i) * input_pitch_a;
                unsigned char* pdst = (unsigned char*)info.lpSurface + (height - i - 1)*info.lPitch;
                for( int j=0; j<width; j++)
                {
                    *pdst++ = *pRGB++;      // R
                    *pdst++ = *pRGB++;      // G
                    *pdst++ = *pRGB++;      // B

                    if( gHiresTxtrInfos[idx].bSeparatedAlpha )
                    {
                        *pdst++ = *pA;
                        pA += 3;
                    }
                    else if( entry.ti.Format == TXT_FMT_I )
                    {
                        *pdst++ = pRGB[-1];
                    }
                    else
                    {
                        *pdst++ = 0xFF;
                    }
                }
            }
        }
        else
        {
            input_pitch_rgb *= 4;

            // Update the texture by using the buffer
            for( int i=height-1; i>=0; i--)
            {
                uint32 *pRGB = (uint32*)(buf_rgba + (input_height_shift + i) * input_pitch_rgb);
                uint32 *pdst = (uint32*)((unsigned char*)info.lpSurface + (height - i - 1)*info.lPitch);
                for( int j=0; j<width; j++)
                {
                    *pdst++ = *pRGB++;      // RGBA
                }
            }
        }

        if (mirrorx == 2)
        {
            //printf("Mirror: ToCreate: (%d,%d) ToLoad: (%d,%d) Scale: (%i,%i) Mirror: (%i,%i) Size: (%i,%i) Mask: %i\n", entry.ti.WidthToCreate, entry.ti.HeightToCreate, entry.ti.WidthToLoad, entry.ti.HeightToLoad, scale, scale, mirrorx, mirrory, width, height, entry.ti.maskS+scaleShift);
            gTextureManager.Mirror(info.lpSurface, width, entry.ti.maskS+scaleShift, width*2, width*2, height, S_FLAG, 4 );
        }

        if (mirrory == 2)
        {
            //printf("Mirror: ToCreate: (%d,%d) ToLoad: (%d,%d) Scale: (%i,%i) Mirror: (%i,%i) Size: (%i,%i) Mask: %i\n", entry.ti.WidthToCreate, entry.ti.HeightToCreate, entry.ti.WidthToLoad, entry.ti.HeightToLoad, scale, scale, mirrorx, mirrory, width, height, entry.ti.maskT+scaleShift);
            gTextureManager.Mirror(info.lpSurface, height, entry.ti.maskT+scaleShift, height*2, entry.pEnhancedTexture->m_dwCreatedTextureWidth, height, T_FLAG, 4 );
        }

        if( entry.ti.WidthToCreate*scale < entry.pEnhancedTexture->m_dwCreatedTextureWidth )
        {
            // Clamp
            gTextureManager.Clamp(info.lpSurface, width, entry.pEnhancedTexture->m_dwCreatedTextureWidth, entry.pEnhancedTexture->m_dwCreatedTextureWidth, height, S_FLAG, 4 );
        }
        if( entry.ti.HeightToCreate*scale < entry.pEnhancedTexture->m_dwCreatedTextureHeight )
        {
            // Clamp
            gTextureManager.Clamp(info.lpSurface, height, entry.pEnhancedTexture->m_dwCreatedTextureHeight, entry.pEnhancedTexture->m_dwCreatedTextureWidth, height, T_FLAG, 4 );
        }

        entry.pEnhancedTexture->EndUpdate(&info);
        entry.pEnhancedTexture->m_bIsEnhancedTexture = true;
        entry.dwEnhancementFlag = TEXTURE_EXTERNAL;

        DebugMessage(M64MSG_VERBOSE, "Loaded hi-res texture: %s", filename_rgb);
    }
    else
    {
        DebugMessage(M64MSG_ERROR, "New texture creation failed.");
        TRACE0("Cannot create a new texture");
    }

    if( buf_rgba )
    {
        delete [] buf_rgba;
    }

    if( buf_a )
    {
        delete [] buf_a;
    }
}

