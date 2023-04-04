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

#ifndef OBJCXX_FOUNDATION_CLASSES_NS_EXCEPTION_H
#define OBJCXX_FOUNDATION_CLASSES_NS_EXCEPTION_H

#include <OBJCXX/Foundation/Classes/NSObject.hpp>
#include <OBJCXX/Foundation/Classes/NSString.hpp>
#include <OBJCXX/Foundation/Classes/NSDictionary.hpp>
#include <OBJCXX/Foundation/Classes/NSArray.hpp>

namespace NS
{
    class OBJCXX_EXPORT Exception: public Object
    {
        public:
            
            OBJCXX_USING_BASE( Exception, Object )
            
            Exception( const NS::String & name, const NS::String & reason, const NS::Dictionary & userInfo );
            
            void raise( void ) const;
            
            NS::String     name( void )     const;
            NS::String     reason( void )   const;
            NS::Dictionary userInfo( void ) const;
            
            NS::Array callStackReturnAddresses( void ) const;
            NS::Array callStackSymbols( void )         const;
    };
}

#endif /* OBJCXX_FOUNDATION_CLASSES_NS_EXCEPTION_H */
