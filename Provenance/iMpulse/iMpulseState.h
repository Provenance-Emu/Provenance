/*
 Copyright (C) 2012,2013 by Rand Paulin for Black Powder Media, iMpulse Controller
 
 Copyright (C) 2011 by Stuart Carnie
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

typedef enum iMpulseState {
    iMpulseJoystickNone       = 0x000,
    iMpulseJoystickUp         = 0x001,
    iMpulseJoystickRight      = 0x002,
    iMpulseJoystickDown       = 0x004,
    iMpulseJoystickLeft       = 0x008,
    
    iMpulseJoystickUpRight    = iMpulseJoystickUp   | iMpulseJoystickRight,
    iMpulseJoystickDownRight  = iMpulseJoystickDown | iMpulseJoystickRight,
    iMpulseJoystickUpLeft     = iMpulseJoystickUp   | iMpulseJoystickLeft,
    iMpulseJoystickDownLeft   = iMpulseJoystickDown | iMpulseJoystickLeft,
    
    GenericButtonA            = 0x010,
    GenericButtonB            = 0x020,
    GenericButtonC            = 0x040,
    GenericButtonD            = 0x080,
    GenericButtonE            = 0x100,
    GenericButtonF            = 0x200,
    GenericButtonG            = 0x400,
    GenericButtonH            = 0x800,

// iMpulse aliases
    iMpulseButton1V            = 0x010,
    iMpulseButton1u            = 0x020,
    iMpulseButton1n            = 0x080,
    iMpulseButton1W            = 0x200,
    iMpulseButton1M            = 0x400,
    iMpulseButton1A            = 0x800,

// iMpulse new 2 player mode:
    iMpulseJoystick2Up         = 0x01000,
    iMpulseJoystick2Right      = GenericButtonE,
    iMpulseJoystick2Down       = 0x02000,
    iMpulseJoystick2Left       = GenericButtonC,

    iMpulseJoystick2UpRight    = iMpulseJoystick2Up   | iMpulseJoystick2Right,
    iMpulseJoystick2DownRight  = iMpulseJoystick2Down | iMpulseJoystick2Right,
    iMpulseJoystick2UpLeft     = iMpulseJoystick2Up   | iMpulseJoystick2Left,
    iMpulseJoystick2DownLeft   = iMpulseJoystick2Down | iMpulseJoystick2Left,
    
    iMpulseButton2V            = 0x04000,
    iMpulseButton2W            = 0x08000,
    iMpulseButton2M            = 0x10000,
    iMpulseButton2A            = 0x20000,
    iMpulseButton2u            = 0x40000,
    iMpulseButton2n            = 0x80000,
    
    iMpulsePlayer1              = iMpulseJoystickUp | iMpulseJoystickRight | iMpulseJoystickDown | iMpulseJoystickLeft \
                                | iMpulseButton1V | iMpulseButton1u  | iMpulseButton1n | iMpulseButton1W \
                                | iMpulseButton1M | iMpulseButton1A,
    iMpulsePlayer2              = iMpulseJoystick2Up | iMpulseJoystick2Right | iMpulseJoystick2Down | iMpulseJoystick2Left \
                                | iMpulseButton2V | iMpulseButton2u  | iMpulseButton2n | iMpulseButton2W \
                                | iMpulseButton2M | iMpulseButton2A,
} iMpulseState;
