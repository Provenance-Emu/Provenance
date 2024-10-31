/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - sdl_key_converter.h                                     *
 *   Mupen64Plus homepage: https://mupen64plus.org/                        *
 *   Copyright (C) 2013 Mupen64plus development team                       *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the                         *
 *   Free Software Foundation, Inc.,                                       *
 *   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.          *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

#include <SDL.h>
#include <stdint.h>

#include "osal/preproc.h"

uint16_t sdl_keysym2scancode(uint16_t keysym);
uint16_t sdl_scancode2keysym(uint16_t scancode);

#if SDL_VERSION_ATLEAST(1,3,0)

static osal_inline uint16_t sdl_keysym2native(uint16_t keysym)
{
    return sdl_keysym2scancode(keysym);
}

static osal_inline uint16_t sdl_native2keysym(uint16_t native)
{
    return sdl_scancode2keysym(native);
}

#else

static osal_inline uint16_t sdl_keysym2native(uint16_t keysym)
{
    return keysym;
}

static osal_inline uint16_t sdl_native2keysym(uint16_t native)
{
    return native;
}

#endif
