/*  This file was imported form CrabEmu ( http://crabemu.sourceforge.net/ ) --
    A Sega Master System emulator for Mac OS X (among other targets). The rest
    of the file is left intact from CrabEmu to make things easier if this were
    to be upgraded in the future. */

/*
    This file is part of CrabEmu.

    Copyright (C) 2008 Lawrence Sebald

    CrabEmu is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License version 2 
    as published by the Free Software Foundation.

    CrabEmu is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with CrabEmu; if not, write to the Free Software
    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
*/

#include <stdio.h>
#include <stdlib.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/hid/IOHIDLib.h>
#include <IOKit/hid/IOHIDUsageTables.h>
#include <CoreFoundation/CoreFoundation.h>

#include "macjoy.h"

static int joy_count = 0;
static joydata_t *joys = NULL;

static void joy_find_elements(CFMutableDictionaryRef prop, joydata_t *joy);

/* Compare two buttons for sorting. */
static int joy_cmp_buttons(const void *e1, const void *e2)  {
    const joy_elemdata_t *b1 = (const joy_elemdata_t *)e1;
    const joy_elemdata_t *b2 = (const joy_elemdata_t *)e2;
    
    return b1->number < b2->number ? -1 :
        (b1->number > b2->number ? 1 : 0);
}

/* Get the io_iterator_t object needed to iterate through the list of HID
   devices. */
static void joy_get_iterator(mach_port_t port, io_iterator_t *iter) {
    CFMutableDictionaryRef d;
    IOReturn rv;

    /* Create a matching dictionary that will be used to search the device
        tree. */
    if(!(d = IOServiceMatching(kIOHIDDeviceKey)))  {
        return;
    }

    /* Get all matching devices from IOKit. */
    rv = IOServiceGetMatchingServices(port, d, iter);

    if(rv != kIOReturnSuccess || !(*iter))  {
        return;
    }
}

/* Create the interface needed to do stuff with the device. */
static int joy_create_interface(io_object_t hidDevice, joydata_t *joy)  {
    IOCFPlugInInterface **plugin;
    SInt32 score = 0;

    /* Create the plugin that we will use to actually get the device interface
        that is needed. */
    if(IOCreatePlugInInterfaceForService(hidDevice,
                                         kIOHIDDeviceUserClientTypeID,
                                         kIOCFPlugInInterfaceID, &plugin,
                                         &score) != kIOReturnSuccess)   {
        return 0;
    }

    /* Grab the device interface from the plugin. */
    if((*plugin)->QueryInterface(plugin,
                                 CFUUIDGetUUIDBytes(kIOHIDDeviceInterfaceID),
                                 (LPVOID)&joy->iface) != S_OK)  {
        return 0;
    }

    /* The plugin has done all it needs to, release it. */
    (*plugin)->Release(plugin);

    return 1;
}

/* Fill in a elemdata_t structure with information about the given physical
   element. */
static void joy_fill_elem(CFTypeRef elem, joy_elemdata_t *ptr)  {
    CFTypeRef ref;
    int num;

    memset(ptr, 0, sizeof(joy_elemdata_t));

    /* Grab the element cookie. */
    if((ref = CFDictionaryGetValue(elem, CFSTR(kIOHIDElementCookieKey))))   {
        if(CFNumberGetValue(ref, kCFNumberIntType, &num))   {
            ptr->cookie = (IOHIDElementCookie)num;
        }
    }

    /* Grab the element's minimum value. */
    if((ref = CFDictionaryGetValue(elem, CFSTR(kIOHIDElementMinKey))))  {
        if(CFNumberGetValue(ref, kCFNumberIntType, &num))   {
            ptr->min = num;
        }
    }

    /* Grab the element's maximum value. */
    if((ref = CFDictionaryGetValue(elem, CFSTR(kIOHIDElementMaxKey))))  {
        if(CFNumberGetValue(ref, kCFNumberIntType, &num))   {
            ptr->max = num;
        }
    }
}

/* Callback function to handle each sub-element of the controller class. */
static void joy_elem_array_hnd(const void *value, void *parameter)  {
    CFTypeRef elem = (CFTypeRef)value;
    CFTypeID t = CFGetTypeID(value);
    joydata_t *joy = (joydata_t *)parameter;
    long elemType, elemPage, elemUsage;
    CFTypeRef type, page, usage;
    void *ptr;
    int et;

    /* Make sure we're dealing with a dictionary. */
    if(t == CFDictionaryGetTypeID()) {
        /* Grab the type of the element. */
        type = CFDictionaryGetValue(elem, CFSTR(kIOHIDElementTypeKey));

        if(!type)   {
            return;
        }

        /* Grab the HID usage page. */
        page = CFDictionaryGetValue(elem, CFSTR(kIOHIDElementUsagePageKey));

        if(!page)   {
            return;
        }

        /* Grab the HID usage type. */
        usage = CFDictionaryGetValue(elem, CFSTR(kIOHIDElementUsageKey));

        if(!usage)  {
            return;
        }

        /* Get the integer values from the data grabbed above. */
        if(!CFNumberGetValue(type, kCFNumberLongType, &elemType))   {
            return;
        }

        if(!CFNumberGetValue(page, kCFNumberLongType, &elemPage))   {
            return;
        }

        if(!CFNumberGetValue(usage, kCFNumberLongType, &elemUsage)) {
            return;
        }

        /* If the element is listed as a button, axis, or misc input, check
            what it actually is. */
        if(elemType == kIOHIDElementTypeInput_Button ||
           elemType == kIOHIDElementTypeInput_Axis ||
           elemType == kIOHIDElementTypeInput_Misc) {
            switch(elemPage)    {
                case kHIDPage_Button:
                    ptr = realloc(joy->buttons, (joy->buttons_count + 1) *
                                  sizeof(joy_elemdata_t));

                    if(ptr) {
                        joy->buttons = (joy_elemdata_t *)ptr;
                        joy_fill_elem(elem, joy->buttons + joy->buttons_count);
                        joy->buttons[joy->buttons_count].number = elemUsage;
                        ++joy->buttons_count;
                    }
                    break;

                case kHIDPage_GenericDesktop:
                    switch(elemUsage)   {
                        case kHIDUsage_GD_X:
                            et = JOY_TYPE_X_AXIS;
                            goto axis;

                        case kHIDUsage_GD_Y:
                            et = JOY_TYPE_Y_AXIS;
                            goto axis;

                        case kHIDUsage_GD_Z:
                            et = JOY_TYPE_Z_AXIS;
                            goto axis;

                        case kHIDUsage_GD_Rx:
                            et = JOY_TYPE_X2_AXIS;
                            goto axis;

                        case kHIDUsage_GD_Ry:
                            et = JOY_TYPE_Y2_AXIS;
                            goto axis;

                        case kHIDUsage_GD_Rz:
                            et = JOY_TYPE_Z2_AXIS;
axis:
                            ptr = realloc(joy->axes, (joy->axes_count + 1) *
                                          sizeof(joy_elemdata_t));

                            if(ptr) {
                                joy->axes = (joy_elemdata_t *)ptr;
                                joy_fill_elem(elem, joy->axes +
                                              joy->axes_count);
                                joy->axes[joy->axes_count].type = et;
                                ++joy->axes_count;
                            }
                            break;

                        case kHIDUsage_GD_Hatswitch:
                            ptr = realloc(joy->hats, (joy->hats_count + 1) *
                                          sizeof(joy_elemdata_t));

                            if(ptr) {
                                joy->hats = (joy_elemdata_t *)ptr;
                                joy_fill_elem(elem, joy->hats +
                                              joy->hats_count);
                                ++joy->hats_count;
                            }
                            break;
                    }
                    break;
            }
            
        }
        /* If we've found another element array, effectively recurse. */
        else if(elemType == kIOHIDElementTypeCollection)    {
            joy_find_elements((CFMutableDictionaryRef)elem, joy);
        }
    }
}

/* Process all the sub-elements of a given property list. */
static void joy_find_elements(CFMutableDictionaryRef prop, joydata_t *joy)  {
    CFTypeRef elem;
    CFTypeID type;

    if((elem = CFDictionaryGetValue(prop, CFSTR(kIOHIDElementKey))))    {
        type = CFGetTypeID(elem);

        if(type == CFArrayGetTypeID())  {
            /* Call our function on each element of the array. */
            CFRange r = { 0, CFArrayGetCount(elem) };
            CFArrayApplyFunction(elem, r, &joy_elem_array_hnd, (void *)joy);
        }
    }
}

/* Read the device passed in, and add it to our joystick list if appropriate. */
static void joy_read_device(io_object_t dev)    {
    CFMutableDictionaryRef props = 0;

    /* Create a dictionary to read the device's properties. */
    if(IORegistryEntryCreateCFProperties(dev, &props, kCFAllocatorDefault,
                                         kNilOptions) == KERN_SUCCESS)  {
        CFTypeRef inf;
        SInt32 page, usage;
        void *ptr;

        /* Grab the primary usage page of the device. */
        inf = CFDictionaryGetValue(props, CFSTR(kIOHIDPrimaryUsagePageKey));

        if(!inf || !CFNumberGetValue((CFNumberRef)inf, kCFNumberSInt32Type,
                                     &page))    {
            goto out;
        }

        /* Ignore devices that are not in the Generic Desktop page. */
        if(page != kHIDPage_GenericDesktop) {
            goto out;
        }

        /* Grab the primary device usage. */
        inf = CFDictionaryGetValue(props, CFSTR(kIOHIDPrimaryUsageKey));

        if(!inf || !CFNumberGetValue((CFNumberRef)inf, kCFNumberSInt32Type,
                                     &usage))   {
            goto out;
        }

        /* Ignore devices that are not either a Game Pad or Joystick. */
        if(usage != kHIDUsage_GD_GamePad && usage != kHIDUsage_GD_Joystick) {
            goto out;
        }

        /* Allocate space for the new joystick structure. */
        ptr = realloc(joys, (joy_count + 1) * sizeof(joydata_t));

        if(ptr == NULL) {
            goto out;
        }

        joys = (joydata_t *)ptr;
        memset(joys + joy_count, 0, sizeof(joydata_t));

        /* Grab and store the name of the device. */
        inf = CFDictionaryGetValue(props, CFSTR(kIOHIDProductKey));

        if(!CFStringGetCString((CFStringRef)inf, joys[joy_count].name, 256,
                               kCFStringEncodingUTF8))  {
            goto out;
        }

        /* Create the device interface needed to interact with the device. */
        if(!joy_create_interface(dev, joys + joy_count))    {
            goto out;
        }

        /* Find all elements of the device. */
        joy_find_elements(props, joys + joy_count);

        qsort(joys[joy_count].buttons, joys[joy_count].buttons_count,
              sizeof(joy_elemdata_t), &joy_cmp_buttons);

        ++joy_count;
    }

out:
    CFRelease(props);
}

/* Release the given joystick's interface and clean up any memory used by it. */
static void joy_release_joystick(joydata_t *joy)    {
    (*joy->iface)->Release(joy->iface);

    joy->iface = NULL;

    if(joy->buttons)
        free(joy->buttons);

    if(joy->axes)
        free(joy->axes);

    if(joy->hats)
        free(joy->hats);
}

/* Scan the system for any joysticks connected. */
int joy_scan_joysticks(void)    {
    io_iterator_t iter = 0;
    io_object_t dev;

    if(joys != NULL)    {
        return -1;
    }

    /* Get the iterator needed for going through the list of devices. */
    joy_get_iterator(kIOMasterPortDefault, &iter);

    if(iter != 0)   {
        while((dev = IOIteratorNext(iter))) {
            joy_read_device(dev);
            IOObjectRelease(dev);
        }

        /* Release the iterator. */
        IOObjectRelease(iter);
    }

    return joy_count;
}

/* Clean up any data allocated by the program for joysticks. */
void joy_release_joysticks(void)    {
    int i;

    for(i = 0; i < joy_count; ++i)  {
        joy_close_joystick(joys + i);
        joy_release_joystick(joys + i);
    }

    if(joys != NULL)    {
        free(joys);
        joys = NULL;
    }

    joy_count = 0;
}

/* Get the joystick at a given index in our list of joysticks. */
joydata_t *joy_get_joystick(int index)  {
    if(index < 0 || index >= joy_count) {
        return NULL;
    }

    return &joys[index];
}

/* Grab the device for exclusive use by this program. The device must be closed
   properly (with the joy_close_joystick function, or you may need to
   unplug/replug the joystick to get it to work again). */
int joy_open_joystick(joydata_t *joy)   {
    if((*joy->iface)->open(joy->iface, 0))  {
        return 0;
    }

    joy->open = 1;

    return 1;
}

/* Close the device and return its resources to the system. */
int joy_close_joystick(joydata_t *joy)  {
    IOReturn rv;

    if(!joy->open)  {
        return 1;
    }

    rv = (*joy->iface)->close(joy->iface);

    if(rv == kIOReturnNotOpen) {
        /* The device wasn't open so it can't be closed. */
        return 1;
    }
    else if(rv != kIOReturnSuccess)    {
        return 0;
    }

    joy->open = 0;

    return 1;
}

/* Read a given element from the joystick. The joystick must be open for this
   function to actually do anything useful. */
int joy_read_element(joydata_t *joy, joy_elemdata_t *elem)  {
    IOHIDEventStruct ev;

    memset(&ev, 0, sizeof(IOHIDEventStruct));

    (*joy->iface)->getElementValue(joy->iface, elem->cookie, &ev);

    return ev.value;
}

/* Read the value of a given button. Returns -1 on failure. */
int joy_read_button(joydata_t *joy, int num)  {
    /* Subtract 1 from the number to get the index. */
    --num;

    if(num >= joy->buttons_count) {
        return -1;
    }

    return joy_read_element(joy, joy->buttons + num);
}

/* Read the value of a given axis. Returns 0 on failure (or if the axis reports
   that its value is 0). */
int joy_read_axis(joydata_t *joy, int index)    {
    float value;

    if(index >= joy->axes_count)    {
        return 0;
    }

    value = joy_read_element(joy, joy->axes + index) /
        (float)(joy->axes[index].max + 1);

    return (int)(value * 32768);
}

/* Read the value of a given hat. Returns -1 on failure. */
int joy_read_hat(joydata_t *joy, int index) {
    int value;

    if(index >= joy->hats_count)    {
        return -1;
    }

    value = joy_read_element(joy, joy->hats + index) - joy->hats[index].min;

    /* 4-position hat switch -- Make it look like an 8-position one. */
    if(joy->hats[index].max - joy->hats[index].min + 1 == 4)    {
        value <<= 1;
    }

    switch(value)   {
        case 0:
            return JOY_HAT_UP;
        case 1:
            return JOY_HAT_UP | JOY_HAT_RIGHT;
        case 2:
            return JOY_HAT_RIGHT;
        case 3:
            return JOY_HAT_RIGHT | JOY_HAT_DOWN;
        case 4:
            return JOY_HAT_DOWN;
        case 5:
            return JOY_HAT_DOWN | JOY_HAT_LEFT;
        case 6:
            return JOY_HAT_LEFT;
        case 7:
            return JOY_HAT_LEFT | JOY_HAT_UP;
        default:
            return JOY_HAT_CENTER;
    }
}
