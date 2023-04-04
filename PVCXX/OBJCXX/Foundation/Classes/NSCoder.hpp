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

#ifndef OBJCXX_FOUNDATION_CLASSES_NS_CODER_H
#define OBJCXX_FOUNDATION_CLASSES_NS_CODER_H

#include <OBJCXX/Foundation/Classes/NSObject.hpp>
#include <OBJCXX/Foundation/Classes/NSString.hpp>
#include <OBJCXX/Foundation/Classes/NSData.hpp>
#include <OBJCXX/Foundation/Classes/NSSet.hpp>

namespace NS
{
    class OBJCXX_EXPORT Coder: public Object
    {
        public:
            
            OBJCXX_USING_BASE( Coder, Object )
            
            Coder( void );
            
            bool allowsKeyedCoding( void );
            bool containsValueForKey( const String & key );
            void encodeArrayOfObjCType( const char * type, UInteger count, const void * array );
            void encodeBool( bool boolv, const String & key );
            void encodeBycopyObject( id anObject );
            void encodeByrefObject( id anObject );
            void encodeBytes( const void * byteaddr, UInteger length );
            void encodeBytes( const uint8_t * bytesp, UInteger lenv, const String & key );
            void encodeConditionalObject( id object );
            void encodeConditionalObject( id objv, const String & key );
            void encodeDataObject( const Data & data );
            void encodeDouble( double realv, const String & key );
            void encodeFloat( float realv, const String & key );
            void encodeInt( int intv, const String & key );
            void encodeInteger( Integer intv, const String & key );
            void encodeInt32( int32_t intv, const String & key );
            void encodeInt64( int64_t intv, const String & key );
            void encodeNXObject( id object );
            void encodeObject( id object );
            void encodeObject( id object, const String & key );
            void encodePropertyList( id plist );
            void encodeRootObject( id rootObject );
            
            /*
            void encodePoint( Point point );
            void encodePoint( Point point, const String & key );
            void encodeRect( Rect rect );
            void encodeRect( Rect rect, const String & key );
            void encodeSize( Size size );
            void encodeSize( Size size, const String & key );
            */
            
            /*
            void encodeValueOfObjCType( const char * type, const void * addr );
            void encodeValuesOfObjCTypes( const char * types, ... );
            void encodeCMTime( CMTime time, const String & key );
            void encodeCMTimeRange( CMTimeRange timeRange, const String & key );
            void encodeCMTimeMapping( CMTimeMapping timeMapping, const String & key );
            */
            
            bool            decodeBoolForKey( const String & key );
            const uint8_t * decodeBytesForKey( const String & key, UInteger * lengthp );
            void          * decodeBytesWithReturnedLength( UInteger * lengthp );
            Data            decodeDataObject( void );
            double          decodeDoubleForKey( const String & key );
            float           decodeFloatForKey( const String & key );
            int             decodeIntForKey( const String & key );
            Integer         decodeIntegerForKey( const String & key );
            int32_t         decodeInt32ForKey( const String & key );
            int64_t         decodeInt64ForKey( const String & key );
            id              decodeNXObject( void );
            id              decodeObject( void );
            id              decodeObjectForKey( const String & key );
            id              decodePropertyListForKey( const String & key );
            
            /*
            Point           decodePoint( void );
            Point           decodePointForKey( const String & key );
            Rect            decodeRect( void );
            Rect            decodeRectForKey( const String & key );
            Size            decodeSize( void );
            Size            decodeSizeForKey( const String & key );
            */
            
            /*
            void            decodeArrayOfObjCType( const char * itemType, Integer count, void * array );
            void            decodeValueOfObjCType( const char * type, void * data );
            void            decodeValuesOfObjCTypes( const char * types, ... );
            id              decodeObjectOfClass( Class aClass, const String & key );
            id              decodeObjectOfClasses( const Set & classes, const String & key );
            CMTime          decodeCMTimeForKey( const String & key );
            CMTimeRange     decodeCMTimeRangeForKey( const String & key );
            CMTimeMapping   decodeCMTimeMappingForKey( const String & key );
            */
            
            bool         requiresSecureCoding( void );
            Set          allowedClasses( void );
            void         setAllowedClasses( const Set & allowedClasses );
            unsigned int systemVersion( void );
            Integer      versionForClassName( const String & className );
            Zone       * objectZone( void );
            void         setObjectZone( Zone * zone );
    };
}

#endif /* OBJCXX_FOUNDATION_CLASSES_NS_CODER_H */
