//
//  USBGamePad.cpp
//  USBGamePad
//
//  Created by Joseph Mattiello on 8/6/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

#include <os/log.h>

#include <DriverKit/IOUserServer.h>
#include <DriverKit/IOLib.h>

#include "USBGamePad.h"

kern_return_t
IMPL(USBGamePad, Start)
{
    kern_return_t ret;
    ret = Start(provider, SUPERDISPATCH);
    os_log(OS_LOG_DEFAULT, "Hello World");
    return ret;
}

struct MyCustomKeyboardDriver_IVars
{
    OSArray *elements;
    
    struct {
        OSArray *elements;
    } keyboard;
};

bool MyCustomKeyboardDriver::init()
{
   if (!super::init()) {return false;}
    
   // Allocate memory for the instance variables.
   ivars = IONewZero(MyCustomKeyboardDriver_IVars, 1);
   if (!ivars) {return false;}
    
exit:
   return true;
}
