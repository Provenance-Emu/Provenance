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

#ifndef OBJCXX_CLASS_BUILDER_H
#define OBJCXX_CLASS_BUILDER_H

#include <string>
#include <OBJCXX/RT.hpp>
#include <XS/PIMPL/Object.hpp>

#include <iostream>

namespace OBJCXX
{
    class OBJCXX_EXPORT ClassBuilder: public XS::PIMPL::Object< ClassBuilder >
    {
        public:
            
            using XS::PIMPL::Object< ClassBuilder >::impl;
            
            typedef enum
            {
                TypeSignedChar,
                TypeSignedShort,
                TypeSignedInt,
                TypeSignedLong,
                TypeSignedLongLong,
                TypeUnsignedChar,
                TypeUnsignedShort,
                TypeUnsignedInt,
                TypeUnsignedLong,
                TypeUnsignedLongLong,
                TypeFloat,
                TypeDouble,
                TypeBool,
                TypeCharPointer,
                TypeObject,
                TypeClass,
                TypeSelector,
            }
            Type;
            
            ClassBuilder( void );
            ClassBuilder( const std::string & name, const std::string & super, size_t extraBytes = 0 );
            
            Class cls( void ) const;
            
            size_t      sizeForType( Type type )      const;
            uint8_t     alignmentForType( Type type ) const;
            std::string encodingForType( Type type )  const;
            
            bool addProtocol( const std::string & name );
            
            bool addInstanceVariable( const std::string & name, Type type ) const;
            bool addInstanceVariable( const std::string & name, size_t size, uint8_t alignment, const std::string & types ) const;
            
            bool addProperty( const std::string & name, Type type );
            
            bool addClassMethod( const std::string & name, IMP implementation, const std::string & types ) const;
            bool addInstanceMethod( const std::string & name, IMP implementation, const std::string & types );
            
            void registerClass( void );
            
            template< class _C_, typename _R_, typename ... _A_ >
            class Method
            {
                public:
                    
                    Method( Class cls, const std::string & name, _R_ ( _C_::* imp )( _A_ ... ), const std::string & types ):
                        _class( cls ),
                        _name(  name ),
                        _types( types ),
                        _imp(   imp )
                    {}
                    
                    Method( const Method & o ):
                        _class( o._class ),
                        _name(  o._name ),
                        _types( o._types ),
                        _imp(   o._imp )
                    {}
                    
                    Method & operator =( Method o )
                    {
                        swap( *( this ), o );
                        
                        return *( this );
                    }
                    
                    friend void swap( Method & o1, Method & o2 )
                    {
                        using std::swap;
                        
                        swap( o1._class, o2._class );
                        swap( o1._name,  o2._name );
                        swap( o1._types, o2._types );
                        swap( o1._imp,   o2._imp );
                    }
                    
                    bool add( void )
                    {
                        SEL  s = RT::Internal::sel_registerName( this->_name.c_str() );
						auto f = &CXX_IMP< _R_, _A_ ... >;
                        
                        if
                        (
                            RT::Internal::class_addMethod
                            (
                                this->_class,
                                s,
                                reinterpret_cast< IMP >( f ),
                                this->_types.c_str()
                            )
                            == false
                        )
                        {
                            return false;
                        }
                        
                        RT::Internal::objc_setAssociatedObject
                        (
                            reinterpret_cast< id >( this->_class ),
                            s,
                            reinterpret_cast< id >( new Method( *( this ) ) ),
                            RT::Internal::AssociationPolicy::Assign
                        );
                        
                        return true;
                    }
                    
                    template< typename _OBJCR_, typename ... _OBJCA_ >
                    bool add( void )
                    {
                        SEL s  = s = RT::Internal::sel_registerName( this->_name.c_str() );
						auto f = &CXX_IMP< _OBJCR_, _OBJCA_ ... >;
                        
                        if
                        (
                            RT::Internal::class_addMethod
                            (
                                this->_class,
                                s,
                                reinterpret_cast< IMP >( f ),
                                this->_types.c_str()
                            )
                            == false
                        )
                        {
                            return false;
                        }
                        
                        RT::Internal::objc_setAssociatedObject
                        (
                            reinterpret_cast< id >( this->_class ),
                            s,
                            reinterpret_cast< id >( new Method( *( this ) ) ),
                            RT::Internal::AssociationPolicy::Assign
                        );
                        
                        return true;
                    }
                    
                private:
                    
                    Class       _class;
                    std::string _name;
                    std::string _types;
                    
                    _R_ ( _C_::* _imp )( _A_ ... );
                    
                    template< typename _OBJCR_, typename ... _OBJCA_ >
                    static typename std::enable_if< !std::is_void< _OBJCR_ >::value && !std::is_same< _OBJCR_, id >::value, _OBJCR_ >::type CXX_IMP( id self, SEL _cmd, _OBJCA_ ... args )
                    {
                        _C_                           o( self );
                        Method< _C_, _R_, _A_ ... > * m;
                        _R_ ( _C_::* imp )( _A_ ... );
                        
                        m = reinterpret_cast< Method< _C_, _R_, _A_ ... > * >
                        (
                            RT::Internal::objc_getAssociatedObject
                            (
                                reinterpret_cast< id >( RT::Internal::object_getClass( self ) ),
                                _cmd
                            )
                        );
                        
                        if( m == nullptr || m->_imp == nullptr )
                        {
                            return {};
                        }
                        
                        imp = m->_imp;
                        
                        return ( o.*imp )( args ... );
                    }
                    
                    template< typename _OBJCR_, typename ... _OBJCA_ >
                    static typename std::enable_if< !std::is_void< _OBJCR_ >::value && std::is_same< _OBJCR_, id >::value, _OBJCR_ >::type CXX_IMP( id self, SEL _cmd, _OBJCA_ ... args )
                    {
                        _C_                           o( self );
                        Method< _C_, _R_, _A_ ... > * m;
                        _R_ ( _C_::* imp )( _A_ ... );
                        
                        m = reinterpret_cast< Method< _C_, _R_, _A_ ... > * >
                        (
                            RT::Internal::objc_getAssociatedObject
                            (
                                reinterpret_cast< id >( RT::Internal::object_getClass( self ) ),
                                _cmd
                            )
                        );
                        
                        if( m == nullptr || m->_imp == nullptr )
                        {
                            return {};
                        }
                        
                        imp = m->_imp;
                        
                        return RT::Internal::objc_msgSend
                        (
                            RT::Internal::objc_msgSend
                            (
                                ( o.*imp )( args ... ),
                                RT::Internal::sel_registerName( "retain" )
                            ),
                            RT::Internal::sel_registerName( "autorelease" )
                        );
                    }
                    
                    template< typename _OBJCR_, typename ... _OBJCA_ >
                    static typename std::enable_if< std::is_void< _OBJCR_ >::value, _OBJCR_ >::type CXX_IMP( id self, SEL _cmd, _OBJCA_ ... args )
                    {
                        _C_                           o( self );
                        Method< _C_, _R_, _A_ ... > * m;
                        _R_ ( _C_::* imp )( _A_ ... );
                        
                        m = reinterpret_cast< Method< _C_, _R_, _A_ ... > * >
                        (
                            RT::Internal::objc_getAssociatedObject
                            (
                                reinterpret_cast< id >( RT::Internal::object_getClass( self ) ),
                                _cmd
                            )
                        );
                        
                        if( m == nullptr || m->_imp == nullptr )
                        {
                            return;
                        }
                        
                        imp = m->_imp;
                        
                        ( o.*imp )( args ... );
                    }
            };
            
            template< class _C_, typename _R_, typename ... _A_ >
            Method< _C_, _R_, _A_ ... > instanceMethod( const std::string & name, _R_ ( _C_::* imp )( _A_ ... ), const std::string & types )
            {
                Method< _C_, _R_, _A_ ... > m( this->cls(), name, imp, types );
                
                return m;
            }
    };
}

#endif /* OBJCXX_CLASS_BUILDER_H */
