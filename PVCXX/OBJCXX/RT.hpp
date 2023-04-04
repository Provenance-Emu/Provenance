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

#ifndef OBJCXX_RT_H
#define OBJCXX_RT_H

/*
 * Disable warnings about class members not having DLL-interface.
 * Eg: std::shared_ptr
 */
#ifdef _WIN32
    #pragma warning( push )
    #pragma warning( disable: 4251 )
#endif

#ifdef _WIN32
    #ifdef OBJCXX_DLL_BUILD
        #define OBJCXX_EXPORT __declspec( dllexport )
    #else
        #define OBJCXX_EXPORT __declspec( dllimport )
    #endif
#else
        #define OBJCXX_EXPORT     
#endif

#ifdef WIN32
    #define OBJCXX_EXTERN __declspec( dllimport )
#else
    #define OBJCXX_EXTERN extern
#endif

#include <type_traits>
#include <string>
#include <XS/PIMPL/Object.hpp>
#include <cstdint>
#include <cstdlib>
#include <cstdarg>

#ifndef __OBJC__

extern "C"
{
    typedef struct objc_class    * Class;
    typedef struct objc_object   * id;
    typedef struct objc_selector * SEL;
    typedef struct objc_method   * Method;
    typedef struct objc_ivar     * Ivar;
    typedef struct objc_object     Protocol;
    
    typedef id ( * IMP )( id self, SEL _cmd, ... );
    
    struct objc_super
    {
        id    receiver;
        Class super_class;
    };
    
    typedef id ( * objc_exception_preprocessor )( id exception );
}

#else

#include <objc/runtime.h>
#include <objc/objc-exception.h>

#endif

extern "C"
{
    OBJCXX_EXPORT id OBJCXX_Exception_Preprocessor( id e );
}

namespace OBJCXX
{
    namespace RT
    {
        class OBJCXX_EXPORT Internal
        {
            public:
                
                Internal( void ) = delete;
                
                enum class AssociationPolicy: int
                {
                    Assign          = 0,
                    RetainNonAtomic = 1,
                    CopyNonAtomic   = 3,
                    Retain          = 01401,
                    Copy            = 01403
                };
                
                static Class                        ( * objc_getClass                 )( const char * );
                static Class                        ( * objc_getMetaClass             )( const char * );
                static Protocol                 *   ( * objc_getProtocol              )( const char * );
                static id                           ( * objc_msgSend                  )( id, SEL, ... );
                static double                       ( * objc_msgSend_fpret            )( id, SEL, ... );
                static void                         ( * objc_msgSend_stret            )( void *, id, SEL, ... );
                static id                           ( * objc_msgSendSuper             )( struct objc_super *, SEL, ... );
                static Class                        ( * objc_allocateClassPair        )( Class, const char *, size_t );
                static void                         ( * objc_registerClassPair        )( Class );
                static void                         ( * objc_setAssociatedObject      )( id, const void *, id, AssociationPolicy );
                static id                           ( * objc_getAssociatedObject      )( id, const void * );
                static SEL                          ( * sel_registerName              )( const char * );
                static const char                 * ( * sel_getName                   )( SEL );
                static Class                        ( * object_getClass               )( id );
                static IMP                          ( * method_getImplementation      )( Method );
                static SEL                          ( * method_getName                )( Method );
                static const char                 * ( * method_getTypeEncoding        )( Method );
                static Class                        ( * class_getSuperclass           )( Class );
                static const char                 * ( * class_getName                 )( Class );
                static Method                     * ( * class_copyMethodList          )( Class, unsigned int * );
                static bool                         ( * class_addIvar                 )( Class, const char *, size_t, uint8_t, const char * );
                static bool                         ( * class_addMethod               )( Class, SEL, IMP, const char * );
                static bool                         ( * class_addProtocol             )( Class, Protocol * );
                static Ivar                         ( * class_getInstanceVariable     )( Class, const char * );
                static ptrdiff_t                    ( * ivar_getOffset                )( Ivar );
                static void                         ( * NSLogv                        )( id, va_list );
                static objc_exception_preprocessor  ( * objc_setExceptionPreprocessor )( objc_exception_preprocessor );
        };
        
        OBJCXX_EXPORT void Init( void );

        OBJCXX_EXPORT Class       GetClass( const std::string & name );
        OBJCXX_EXPORT Class       GetClass( id object );
        OBJCXX_EXPORT std::string GetClassName( Class cls );
        OBJCXX_EXPORT SEL         GetSelector( const std::string & name );
        OBJCXX_EXPORT id          GetLastException( void );
        OBJCXX_EXPORT void        RethrowLastException( void );
        
        class OBJCXX_EXPORT MessageBase: public XS::PIMPL::Object< MessageBase >
        {
            public:
                
                using XS::PIMPL::Object< MessageBase >::impl;
                
                MessageBase( id object, const std::string & selector );
                MessageBase( Class cls, const std::string & selector );
                MessageBase( const std::string & cls, const std::string & selector );
                
                id object( void );
                SEL selector( void );
        };
        
        template< typename _T_, class _E_ = void >
        class Message;
        
        template< class _U_ > struct IsVoidReturnType:   public std::integral_constant< bool, std::is_void< _U_ >::value > {};
        template< class _U_ > struct IsFloatReturnType:  public std::integral_constant< bool, std::is_floating_point< _U_ >::value > {};
        template< class _U_ > struct IsStructReturnType: public std::integral_constant< bool, std::is_class< _U_ >::value > {};
        template< class _U_ > struct IsSimpleReturnType: public std::integral_constant< bool, !IsVoidReturnType< _U_ >::value && !IsStructReturnType< _U_ >::value && !IsFloatReturnType< _U_ >::value > {};
        
        template< typename _T_ >
        class OBJCXX_EXPORT Message< _T_, typename std::enable_if< IsSimpleReturnType< _T_ >::value && sizeof( _T_ ) < sizeof( id ) >::type >: public MessageBase
        {
            public:
                
                Message( id object, const std::string & selector ): MessageBase( object, selector )
                {}
                
                Message( Class cls, const std::string & selector ): MessageBase( cls, selector )
                {}
                
                Message( const std::string & cls, const std::string & selector ): MessageBase( cls, selector )
                {}

                template< typename ... _A_ >
                _T_ send( _A_ ... args )
                {
                    try
                    {
                        uintptr_t r;
                        
                        r = reinterpret_cast< uintptr_t >( Internal::objc_msgSend( this->object(), this->selector(), args ... ) );
                        
                        return static_cast< _T_ >( r );
                    }
                    catch( ... )
                    {
                        RethrowLastException();
                        
                        return {};
                    }
                }
        };
        
        template< typename _T_ >
        class OBJCXX_EXPORT Message< _T_, typename std::enable_if< IsSimpleReturnType< _T_ >::value && sizeof( _T_ ) >= sizeof( id ) >::type >: public MessageBase
        {
            public:
                
                Message( id object, const std::string & selector ): MessageBase( object, selector )
                {}
                
                Message( Class cls, const std::string & selector ): MessageBase( cls, selector )
                {}
                
                Message( const std::string & cls, const std::string & selector ): MessageBase( cls, selector )
                {}

                template< typename ... _A_ >
                _T_ send( _A_ ... args )
                {
                    try
                    {
                        return reinterpret_cast< _T_ >( Internal::objc_msgSend( this->object(), this->selector(), args ... ) );
                    }
                    catch( ... )
                    {
                        RethrowLastException();
                        
                        return {};
                    }
                }
        };
        
        template< typename _T_ >
        class OBJCXX_EXPORT Message< _T_, typename std::enable_if< IsVoidReturnType< _T_ >::value >::type >: public MessageBase
        {
            public:
                
                Message( id object, const std::string & selector ): MessageBase( object, selector )
                {}
                
                Message( Class cls, const std::string & selector ): MessageBase( cls, selector )
                {}
                
                Message( const std::string & cls, const std::string & selector ): MessageBase( cls, selector )
                {}

                template< typename ... _A_ >
                void send( _A_ ... args )
                {
                    try
                    {
                        Internal::objc_msgSend( this->object(), this->selector(), args ... );
                    }
                    catch( ... )
                    {
                        RethrowLastException();
                    }
                }
        };
        
        template< typename _T_ >
        class OBJCXX_EXPORT Message< _T_, typename std::enable_if< IsFloatReturnType< _T_ >::value >::type >: public MessageBase
        {
            public:
                
                Message( id object, const std::string & selector ): MessageBase( object, selector )
                {}
                
                Message( Class cls, const std::string & selector ): MessageBase( cls, selector )
                {}
                
                Message( const std::string & cls, const std::string & selector ): MessageBase( cls, selector )
                {}

                template< typename ... _A_ >
                _T_ send( _A_ ... args )
                {
                    try
                    {
                        return static_cast< _T_ >( Internal::objc_msgSend_fpret( this->object(), this->selector(), args ... ) );
                    }
                    catch( ... )
                    {
                        RethrowLastException();
                        
                        return static_cast< _T_ >( 0 );
                    }
                }
        };
        
        template< typename _T_ >
        class OBJCXX_EXPORT Message< _T_, typename std::enable_if< IsStructReturnType< _T_ >::value >::type >: public MessageBase
        {
            public:
                
                Message( id object, const std::string & selector ): MessageBase( object, selector )
                {}
                
                Message( Class cls, const std::string & selector ): MessageBase( cls, selector )
                {}
                
                Message( const std::string & cls, const std::string & selector ): MessageBase( cls, selector )
                {}

                template< typename ... _A_ >
                _T_ send( _A_ ... args )
                {
                    try
                    {
                        return reinterpret_cast< _T_ ( * )( id, SEL, ... ) >
                        (
                            Internal::objc_msgSend
                        )
                        ( this->object(), this->selector(), args ... );
                    }
                    catch( ... )
                    {
                        RethrowLastException();
                        
                        return {};
                    }
                }
        };
        
        template < typename _T_ >
        static std::string GetEncodingForType( void )
        {
            if( std::is_same< _T_, char >::value )
            {
                return "c";
            }
            else if( std::is_same< _T_, short >::value )
            {
                return "s";
            }
            else if( std::is_same< _T_, int >::value )
            {
                return "i";
            }
            else if( std::is_same< _T_, long >::value )
            {
                return "l";
            }
            else if( std::is_same< _T_, long long >::value )
            {
                return "q";
            }
            else if( std::is_same< _T_, unsigned char >::value )
            {
                return "C";
            }
            else if( std::is_same< _T_, unsigned short >::value )
            {
                return "S";
            }
            else if( std::is_same< _T_, unsigned int >::value )
            {
                return "I";
            }
            else if( std::is_same< _T_, unsigned long >::value )
            {
                return "L";
            }
            else if( std::is_same< _T_, unsigned long long >::value )
            {
                return "Q";
            }
            else if( std::is_same< _T_, float >::value )
            {
                return "f";
            }
            else if( std::is_same< _T_, double >::value )
            {
                return "d";
            }
            else if( std::is_same< _T_, bool >::value )
            {
                return "B";
            }
            else if( std::is_void< _T_ >::value )
            {
                return "v";
            }
            else if( std::is_same< _T_, char * >::value )
            {
                return "*";
            }
            else if( std::is_same< _T_, id >::value )
            {
                return "@";
            }
            else if( std::is_same< _T_, Class >::value )
            {
                return "#";
            }
            else if( std::is_same< _T_, SEL >::value )
            {
                return ":";
            }
            else if( std::is_pointer< _T_ >::value )
            {
                return "^";
            }
            
            return "?";
        }
        
        template< std::size_t _I_, std::size_t _N_, typename _F_ >
        static inline void For( _F_ const & f )
        {
            /* For constexpr and lambdas - We're on C++17 anyway... */
            #ifdef __clang__
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Wc++98-compat"
            #pragma clang diagnostic ignored "-Wc++98-c++11-c++14-compat"
            #endif
            if constexpr( _I_ < _N_ )
            {
                 f( std::integral_constant< size_t, _I_ >{} );
                 For< _I_ + 1, _N_ >( f );
            }
            #ifdef __clang__
            #pragma clang diagnostic pop
            #endif
        }
    }
}

#endif /* OBJCXX_RT_H */
