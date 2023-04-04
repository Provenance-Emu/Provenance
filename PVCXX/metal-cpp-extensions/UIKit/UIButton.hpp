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

#ifndef UIKIT_UI_BUTTON_HPP
#define UIKIT_UI_BUTTON_HPP

#include <OBJCXX.hpp>
#include <UIKit/UIControl.hpp>

namespace UI
{
    class Button: public Control
    {
        public:
            
            enum Type: int
            {
                Custom           = 0, 
                System           = 1,
                DetailDisclosure = 2,
                InfoLight        = 3,
                InfoDark         = 4,
                ContactAdd       = 5,
                RoundedRect      = System
            };
            
            static Button buttonWithType( Type type );
            
            OBJCXX_USING_BASE( Button, Control )
            
            NS::String titleForState( unsigned int state ) const;
            void       setTitleForState( const NS::String & value, unsigned int state );
            
        private:
            
            Button( void ) = default;
    };
}

#endif /* UIKIT_UI_BUTTON_HPP */
