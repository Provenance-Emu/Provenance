/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - cheat.h                                                 *
 *   Mupen64Plus homepage: https://mupen64plus.org/                        *
 *   Copyright (C) 2008 Okaygo                                             *
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

#ifndef M64P_MAIN_CHEAT_H
#define M64P_MAIN_CHEAT_H

#include "api/m64p_types.h"

#include "list.h"

#include <stdint.h>

#define ENTRY_BOOT 0
#define ENTRY_VI 1

struct SDL_mutex;
struct r4300_core;

struct cheat_ctx
{
    struct SDL_mutex* mutex;
    struct list_head active_cheats;
};

void cheat_apply_cheats(struct cheat_ctx* ctx, struct r4300_core* r4300, int entry);

void cheat_init(struct cheat_ctx* ctx);
void cheat_uninit(struct cheat_ctx* ctx);
int cheat_add_new(struct cheat_ctx* ctx, const char* name, m64p_cheat_code* code_list, int num_codes);
int cheat_set_enabled(struct cheat_ctx* ctx, const char* name, int enabled);
void cheat_delete_all(struct cheat_ctx* ctx);
int cheat_add_hacks(struct cheat_ctx* ctx, const char* rom_cheats);

#endif
