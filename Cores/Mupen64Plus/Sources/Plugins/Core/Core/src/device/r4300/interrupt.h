/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - interrupt.h                                              *
 *   Mupen64Plus homepage: https://mupen64plus.org/                        *
 *   Copyright (C) 2002 Hacktarux                                          *
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

#ifndef M64P_DEVICE_R4300_INTERRUPT_H
#define M64P_DEVICE_R4300_INTERRUPT_H

#include <stdint.h>

struct r4300_core;
struct cp0;
struct interrupt_queue;

void init_interrupt(struct cp0* cp0);

void raise_maskable_interrupt(struct r4300_core* r4300, uint32_t cause_ip);

void gen_interrupt(struct r4300_core* r4300);
void r4300_check_interrupt(struct r4300_core* r4300, uint32_t cause_ip, int set_cause);

void translate_event_queue(struct cp0* cp0, unsigned int base);
void remove_event(struct interrupt_queue* q, int type);
void add_interrupt_event_count(struct cp0* cp0, int type, unsigned int count);
void add_interrupt_event(struct cp0* cp0, int type, unsigned int delay);
unsigned int get_event(const struct interrupt_queue* q, int type);
int get_next_event_type(const struct interrupt_queue* q);
unsigned int add_random_interrupt_time(struct r4300_core* r4300);

int save_eventqueue_infos(const struct cp0* cp0, char *buf);
void load_eventqueue_infos(struct cp0* cp0, const char *buf);

void reset_hard_handler(void* opaque);

void compare_int_handler(void* opaque);
void check_int_handler(void* opaque);
void special_int_handler(void* opaque);
void nmi_int_handler(void* opaque);

#define VI_INT      0x001
#define COMPARE_INT 0x002
#define CHECK_INT   0x004
#define SI_INT      0x008
#define PI_INT      0x010
#define SPECIAL_INT 0x020
#define AI_INT      0x040
#define SP_INT      0x080
#define DP_INT      0x100
#define HW2_INT     0x200
#define NMI_INT     0x400

#endif /* M64P_DEVICE_R4300_INTERRUPT_H */
