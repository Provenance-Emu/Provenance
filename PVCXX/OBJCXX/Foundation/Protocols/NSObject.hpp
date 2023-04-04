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

#ifndef OBJCXX_FOUNDATION_PROTOCOLS_NS_OBJECT_H
#define OBJCXX_FOUNDATION_PROTOCOLS_NS_OBJECT_H

namespace OBJCXX
{
    class Object;
}

namespace NS
{
    namespace Protocols
    {
        class OBJCXX_EXPORT Object
        {
            public:
                
                Object( void )              = default;
                Object( const Object & o )  = default;
                virtual ~Object( void )     = default;
                
                virtual Class           getClass( void )                      const = 0;
                virtual Class           superclass( void )                    const = 0;
                virtual bool            isEqual( const OBJCXX::Object & o )   const = 0;
                virtual UInteger        hash( void )                          const = 0;
                virtual id              self( void )                          const = 0;
                virtual bool            isKindOfClass( Class cls )            const = 0;
                virtual bool            isMemberOfClass( Class cls )          const = 0;
                virtual bool            respondsToSelector( SEL sel )         const = 0;
                virtual bool            conformsToProtocol( void * protocol ) const = 0;
                virtual std::string     description( void )                   const = 0;
                virtual std::string     debugDescription( void )              const = 0;
                virtual id              performSelector( SEL sel )                  = 0;
                virtual id              performSelector( SEL sel, id o1 )           = 0;
                virtual id              performSelector( SEL sel, id o1, id o2 )    = 0;
                virtual bool            isProxy( void )                       const = 0;
                virtual id              retain( void )                              = 0;
                virtual void            release( void )                             = 0;
                virtual id              autorelease( void )                   const = 0;
                virtual UInteger        retainCount( void )                   const = 0;
                virtual void          * zone( void )                          const = 0;
        };
    }
}

#endif /* OBJCXX_FOUNDATION_PROTOCOLS_NS_OBJECT_H */
