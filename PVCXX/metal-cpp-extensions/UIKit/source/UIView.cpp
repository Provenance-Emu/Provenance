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

#include <UIKit.hpp>

namespace UI
{
    View::View( const NS::Rect & frame ):
        Responder
        (
            "UIView",
            [ = ]
            {
                return this->message< id >( "initWithFrame:" ).send< NS::Rect >( frame );
            }
        )
    {}
    
    void View::sizeToFit( void )
    {
        this->message< void >( "sizeToFit" ).send();
    }
    
    void View::addSubview( const UI::View & view )
    {
        this->message< void >( "addSubview:" ).send< id >( view );
    }
    
    NS::Point View::center( void ) const
    {
        return this->message< NS::Point >( "center" ).send();
    }
    
    void View::setCenter( NS::Point value )
    {
        this->message< void >( "setCenter:" ).send< NS::Point >( value );
    }
}
