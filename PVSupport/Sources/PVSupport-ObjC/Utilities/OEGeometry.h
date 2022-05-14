/*
 Copyright (c) 2014, OpenEmu Team
 
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
     * Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.
     * Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in the
       documentation and/or other materials provided with the distribution.
     * Neither the name of the OpenEmu Team nor the
       names of its contributors may be used to endorse or promote products
       derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
 EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _OEGeometry_
#define _OEGeometry_
typedef struct OEIntPoint {
    int x;
    int y;
} OEIntPoint;

typedef struct OEIntSize {
    int width;
    int height;
} OEIntSize;

typedef struct OEIntRect {
    OEIntPoint origin;
    OEIntSize size;
} OEIntRect;

static inline OEIntPoint OEIntPointMake(int x, int y)
{
    return (OEIntPoint){ x, y };
}

static inline OEIntSize OEIntSizeMake(int width, int height)
{
    return (OEIntSize){ width, height };
}

static inline OEIntRect OEIntRectMake(int x, int y, int width, int height)
{
    return (OEIntRect){ (OEIntPoint){ x, y }, (OEIntSize){ width, height } };
}

static inline BOOL OEIntPointEqualToPoint(OEIntPoint point1, OEIntPoint point2)
{
    return point1.x == point2.x && point1.y == point2.y;
}

static inline BOOL OEIntSizeEqualToSize(OEIntSize size1, OEIntSize size2)
{
    return size1.width == size2.width && size1.height == size2.height;
}

static inline BOOL OEIntRectEqualToRect(OEIntRect rect1, OEIntRect rect2)
{
    return OEIntPointEqualToPoint(rect1.origin, rect2.origin) && OEIntSizeEqualToSize(rect1.size, rect2.size);
}

static inline BOOL OEIntSizeIsEmpty(OEIntSize size)
{
    return size.width == 0 || size.height == 0;
}

static inline BOOL OEIntRectIsEmpty(OEIntRect rect)
{
    return OEIntSizeIsEmpty(rect.size);
}

static inline CGSize CGSizeFromOEIntSize(OEIntSize size)
{
    return CGSizeMake(size.width, size.height);
}

static inline NSString *NSStringFromOEIntPoint(OEIntPoint p)
{
    return [NSString stringWithFormat:@"{ %d, %d }", p.x, p.y];
}

static inline NSString *NSStringFromOEIntSize(OEIntSize s)
{
    return [NSString stringWithFormat:@"{ %d, %d }", s.width, s.height];
}

static inline NSString *NSStringFromOEIntRect(OEIntRect r)
{
    return [NSString stringWithFormat:@"{ %@, %@ }", NSStringFromOEIntPoint(r.origin), NSStringFromOEIntSize(r.size)];
}

static inline CGSize OEScaleSize(CGSize size, CGFloat factor)
{
    return (CGSize){size.width*factor, size.height*factor};
}

static inline CGSize OERoundSize(CGSize size)
{
    return (CGSize){roundf(size.width), roundf(size.height)};
}

static inline BOOL CGPointInTriangle(CGPoint p, CGPoint A, CGPoint B, CGPoint C)
{
    CGFloat d = (B.y-C.y) * (A.x-C.x) + (C.x - B.x) * (A.y - C.y);
    CGFloat a = ((B.y - C.y)*(p.x - C.x) + (C.x - B.x)*(p.y - C.y)) / d;
    CGFloat b = ((C.y - A.y)*(p.x - C.x) + (A.x - C.x)*(p.y - C.y)) / d;
    CGFloat c = 1 - a - b;

    return 0 <= a && a <= 1 && 0 <= b && b <= 1 && 0 <= c && c <= 1;
}
#endif
