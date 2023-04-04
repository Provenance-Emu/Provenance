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

#ifndef OBJCXX_FOUNDATION_CLASSES_NS_NUMBER_H
#define OBJCXX_FOUNDATION_CLASSES_NS_NUMBER_H

#include <OBJCXX/Foundation/Classes/NSValue.hpp>

namespace NS
{
    class OBJCXX_EXPORT Number: public Value
    {
        public:
            
            OBJCXX_USING_BASE( Number, Value )
            
            Number( void );
            Number( bool value );
            Number( char value );
            Number( short value );
            Number( int value );
            Number( long value );
            Number( long long value );
            Number( unsigned char value );
            Number( unsigned short value );
            Number( unsigned int value );
            Number( unsigned long value );
            Number( unsigned long long value );
            Number( float value );
            Number( double value );
            
            bool                boolValue( void );
            char                charValue( void );
            short               shortValue( void );
            int                 intValue( void );
            long                longValue( void );
            long long           longLongValue( void );
            unsigned char       unsignedCharValue( void );
            unsigned short      unsignedShortValue( void );
            unsigned int        unsignedIntValue( void );
            unsigned long       unsignedLongValue( void );
            unsigned long long  unsignedLongLongValue( void );
            float               floatValue( void );
            double              doubleValue( void );
    };
}

#endif /* OBJCXX_FOUNDATION_CLASSES_NS_NUMBER_H */
