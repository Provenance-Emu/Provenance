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

#ifndef UIKIT_UI_CONTROL_HPP
#define UIKIT_UI_CONTROL_HPP

#include <OBJCXX.hpp>
#include <UIKit/UIView.hpp>

namespace UI
{
    class Control: public View
    {
        public:
            
            enum State: unsigned int
            {
                Normal      = 0,
                Highlighted = 1 << 0,
                Disabled    = 1 << 1,
                Selected    = 1 << 2,
                Focused     = 1 << 3,
                Application = 0x00FF0000,
                Reserved    = 0xFF000000
            };
            
            enum Events: unsigned int
            {
                TouchDown               = 1 <<  0,
                TouchDownRepeat         = 1 <<  1,
                TouchDragInside         = 1 <<  2,
                TouchDragOutside        = 1 <<  3,
                TouchDragEnter          = 1 <<  4,
                TouchDragExit           = 1 <<  5,
                TouchUpInside           = 1 <<  6,
                TouchUpOutside          = 1 <<  7,
                TouchCancel             = 1 <<  8,

                ValueChanged            = 1 << 12,
                PrimaryActionTriggered  = 1 << 13,

                EditingDidBegin         = 1 << 16,
                EditingChanged          = 1 << 17,
                EditingDidEnd           = 1 << 18,
                EditingDidEndOnExit     = 1 << 19,

                AllTouchEvents          = 0x00000FFF,
                AllEditingEvents        = 0x000F0000,
                ApplicationReserved     = 0x0F000000,
                SystemReserved          = 0xF0000000,
                AllEvents               = 0xFFFFFFFF
            };
            
            OBJCXX_USING_BASE( Control, View )
            
            void addTargetActionForControlEvents( const NS::Object & target, SEL action, unsigned int events );
    };
}

#endif /* UIKIT_UI_CONTROL_HPP */
