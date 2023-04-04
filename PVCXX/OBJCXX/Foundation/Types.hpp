/*******************************************************************************
 * The MIT License (MIT)
 * 
 * Copyright (c) 2015 Jean-David Gadina - www.xs-labs.com / www.digidna.net
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 ******************************************************************************/

/*!
 * @copyright   (c) 2015 - Jean-David Gadina - www.xs-labs.com / www.digidna.net
 * @brief       ...
 */

#ifndef OBJCXX_FOUNDATION_TYPES_H
#define OBJCXX_FOUNDATION_TYPES_H

namespace NS
{
    typedef struct _Zone Zone;
    
    #if defined( _WIN64 )
        typedef          long long      Integer;
        typedef unsigned long long      UInteger;
        typedef               double    CGFloat;
    #elif defined( __LP64__ )
        typedef          long           Integer;
        typedef unsigned long           UInteger;
        typedef          double         CGFloat;
    #else
        typedef          int            Integer;
        typedef unsigned int            UInteger;
        typedef          float          CGFloat;
    #endif
    
    typedef struct
    {
        CGFloat x;
        CGFloat y;
    }
    CGPoint;
    
    typedef struct
    {
        CGFloat width;
        CGFloat height;
    }
    CGSize;
    
    typedef struct
    {
        CGPoint origin;
        CGSize  size;
    }
    CGRect;
    
    typedef struct
    {
        UInteger location;
        UInteger length;
    }
    Range;
    
    typedef CGPoint Point;
    typedef CGSize  Size;
    typedef CGRect  Rect;
}

#endif /* OBJCXX_FOUNDATION_TYPES_H */
