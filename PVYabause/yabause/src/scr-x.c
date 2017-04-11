/*  Copyright 2013 Theo Berkau
    Copyright 2013 Guillaume Duhamel

    This file is part of Yabause.

    Yabause is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    Yabause is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Yabause; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
*/

#include "screen.h"

#include <X11/Xlib.h>
#include <X11/extensions/Xrandr.h>
#include <stdlib.h>

typedef struct
{
   Display *dpy;
   XRRScreenSize *xrrs;
   int num_sizes;
   int current_size;
   short * rates;
   int num_rates;
   int current_rate;
} X11ResolutionList;

static XRRScreenConfiguration *x11Conf = NULL;
static short x11OriginalRate;
static SizeID x11OriginalSizeId;
static Rotation x11OriginalRotation;

ResolutionList ScreenGetResolutions()
{
   X11ResolutionList * list;

   list = malloc(sizeof(X11ResolutionList));

   list->dpy = XOpenDisplay(NULL);
   list->xrrs = XRRSizes(list->dpy, 0, &list->num_sizes);
   list->rates = XRRRates(list->dpy, 0, 0, &list->num_rates);
   list->current_size = 0;
   list->current_rate = 0;

   return list;
}

int ScreenNextResolution(ResolutionList rl, supportedRes_struct * res)
{
   X11ResolutionList * list = rl;

   if (list->current_rate < list->num_rates)
   {
      res->index = list->current_size;
      res->width = list->xrrs[list->current_size].width;
      res->height = list->xrrs[list->current_size].height;
      res->freq = list->rates[list->current_rate];
      res->bpp = 0;
      list->current_rate++;
      return 0;
   }

   list->current_size++;
   if (list->current_size < list->num_sizes)
   {
      list->rates = XRRRates(list->dpy, 0, list->current_size, &list->num_rates);
      list->current_rate = 0;
      return ScreenNextResolution(list, res);
   }

   XCloseDisplay(list->dpy);
   free(list);
   return 1;
}

void ScreenChangeResolution(supportedRes_struct * res)
{
   Display *dpy;
   Window root;

   // Open X11 connection
   dpy = XOpenDisplay(NULL);
   root = RootWindow(dpy, 0);

   if (x11Conf != NULL) XRRFreeScreenConfigInfo(x11Conf);

   // Save original settings
   x11Conf = XRRGetScreenInfo(dpy, root);
   x11OriginalRate = XRRConfigCurrentRate(x11Conf);
   x11OriginalSizeId = XRRConfigCurrentConfiguration(x11Conf, &x11OriginalRotation);

   // Change resolution
   XRRSetScreenConfigAndRate(dpy, x11Conf, root, res->index, RR_Rotate_0, res->freq, CurrentTime);

   // Close connection
   XCloseDisplay(dpy);
}

void ScreenRestoreResolution()
{
   Display *dpy;
   Window root;

   if (x11Conf == NULL) return;

   // Open X11 connection
   dpy = XOpenDisplay(NULL);
   root = RootWindow(dpy, 0);
   XRRSetScreenConfigAndRate(dpy, x11Conf, root, x11OriginalSizeId, x11OriginalRotation, x11OriginalRate, CurrentTime);

   // Close connection
   XCloseDisplay(dpy);
}
