/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - cheat.c                                                 *
 *   Mupen64Plus homepage: http://code.google.com/p/mupen64plus/           *
 *   Copyright (C) 2009 Richard Goedeken                                   *
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

// gameshark and xploder64 reference: http://doc.kodewerx.net/hacking_n64.html 

#include <SDL.h>
#include <SDL_thread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "api/callbacks.h"
#include "api/config.h"
#include "api/m64p_types.h"
#include "cheat.h"
#include "eventloop.h"
#include "list.h"
#include "main.h"
#include "memory/memory.h"
#include "osal/preproc.h"
#include "r4300/r4300_core.h"
#include "rom.h"

#define __STDC_FORMAT_MACROS
#include <inttypes.h>

// local definitions
#define CHEAT_CODE_MAGIC_VALUE 0xDEAD0000
#define ARRAY_SIZE(x) (sizeof(x)/sizeof(x[0]))

typedef struct cheat_code {
    unsigned int address;
    int value;
    int old_value;
    struct list_head list;
} cheat_code_t;

typedef struct cheat {
    char *name;
    int enabled;
    int was_enabled;
    struct list_head cheat_codes;
    struct list_head list;
} cheat_t;

// local variables
static LIST_HEAD(active_cheats);
static SDL_mutex *cheat_mutex = NULL;

// private functions
static unsigned short read_address_16bit(unsigned int address)
{
    return *(unsigned short *)(((unsigned char*)g_rdram + ((address & 0xFFFFFF)^S16)));
}

static unsigned char read_address_8bit(unsigned int address)
{
    return *(unsigned char *)(((unsigned char*)g_rdram + ((address & 0xFFFFFF)^S8)));
}

static void update_address_16bit(unsigned int address, unsigned short new_value)
{
    *(unsigned short *)(((unsigned char*)g_rdram + ((address & 0xFFFFFF)^S16))) = new_value;
    address &= 0xfeffffff;  // mask out bit 24 which is used by GS codes to specify 8/16 bits
    invalidate_r4300_cached_code(address, 2);
}

static void update_address_8bit(unsigned int address, unsigned char new_value)
{
    *(unsigned char *)(((unsigned char*)g_rdram + ((address & 0xFFFFFF)^S8))) = new_value;
    invalidate_r4300_cached_code(address, 1);
}

static int address_equal_to_8bit(unsigned int address, unsigned char value)
{
    unsigned char value_read;
    value_read = *(unsigned char *)(((unsigned char*)g_rdram + ((address & 0xFFFFFF)^S8)));
    return value_read == value;
}

static int address_equal_to_16bit(unsigned int address, unsigned short value)
{
    unsigned short value_read;
    value_read = *(unsigned short *)(((unsigned char*)g_rdram + ((address & 0xFFFFFF)^S16)));
    return value_read == value;
}

// individual application - returns 0 if we are supposed to skip the next cheat
// (only really used on conditional codes)
static int execute_cheat(unsigned int address, unsigned short value, int *old_value)
{
    switch (address & 0xFF000000)
    {
        case 0x80000000:
        case 0x88000000:
        case 0xA0000000:
        case 0xA8000000:
        case 0xF0000000:
            // if pointer to old value is valid and uninitialized, write current value to it
            if(old_value && (*old_value == CHEAT_CODE_MAGIC_VALUE))
                *old_value = (int) read_address_8bit(address);
            update_address_8bit(address,(unsigned char) value);
            return 1;
        case 0x81000000:
        case 0x89000000:
        case 0xA1000000:
        case 0xA9000000:
        case 0xF1000000:
            // if pointer to old value is valid and uninitialized, write current value to it
            if(old_value && (*old_value == CHEAT_CODE_MAGIC_VALUE))
                *old_value = (int) read_address_16bit(address);
            update_address_16bit(address,value);
            return 1;
        case 0xD0000000:
        case 0xD8000000:
            return address_equal_to_8bit(address,(unsigned char) value);
        case 0xD1000000:
        case 0xD9000000:
            return address_equal_to_16bit(address,value);
        case 0xD2000000:
        case 0xDB000000:
            return !(address_equal_to_8bit(address,(unsigned char) value));
        case 0xD3000000:
        case 0xDA000000:
            return !(address_equal_to_16bit(address,value));
        case 0xEE000000:
            // most likely, this doesnt do anything.
            execute_cheat(0xF1000318, 0x0040, NULL);
            execute_cheat(0xF100031A, 0x0000, NULL);
            return 1;
        default:
            return 1;
    }
}

static cheat_t *find_or_create_cheat(const char *name)
{
    cheat_t *cheat;
    int found = 0;

    list_for_each_entry_t(cheat, &active_cheats, cheat_t, list) {
        if (strcmp(cheat->name, name) == 0) {
            found = 1;
            break;
        }
    }

    if (found)
    {
        /* delete any pre-existing cheat codes */
        cheat_code_t *code, *safe;

        list_for_each_entry_safe_t(code, safe, &cheat->cheat_codes, cheat_code_t, list) {
             list_del(&code->list);
             free(code);
        }

        cheat->enabled = 0;
        cheat->was_enabled = 0;
    }
    else
    {
        cheat = malloc(sizeof(*cheat));
        cheat->name = strdup(name);
        cheat->enabled = 0;
        cheat->was_enabled = 0;
        INIT_LIST_HEAD(&cheat->cheat_codes);
        list_add_tail(&cheat->list, &active_cheats);
    }

    return cheat;
}


// public functions
void cheat_init(void)
{
    cheat_mutex = SDL_CreateMutex();
}

void cheat_uninit(void)
{
    if (cheat_mutex != NULL)
        SDL_DestroyMutex(cheat_mutex);
    cheat_mutex = NULL;
}

void cheat_apply_cheats(int entry)
{
    cheat_t *cheat;
    cheat_code_t *code;
    int cond_failed;

    if (list_empty(&active_cheats))
        return;

    if (cheat_mutex == NULL || SDL_LockMutex(cheat_mutex) != 0)
    {
        DebugMessage(M64MSG_ERROR, "Internal error: failed to lock mutex in cheat_apply_cheats()");
        return;
    }

    list_for_each_entry_t(cheat, &active_cheats, cheat_t, list) {
        if (cheat->enabled)
        {
            cheat->was_enabled = 1;
            switch(entry)
            {
                case ENTRY_BOOT:
                    list_for_each_entry_t(code, &cheat->cheat_codes, cheat_code_t, list) {
                        // code should only be written once at boot time
                        if((code->address & 0xF0000000) == 0xF0000000)
                            execute_cheat(code->address, code->value, &code->old_value);
                    }
                    break;
                case ENTRY_VI:
                    /* a cheat starts without failed preconditions */
                    cond_failed = 0;

                    list_for_each_entry_t(code, &cheat->cheat_codes, cheat_code_t, list) {
                        /* conditional cheat codes */
                        if((code->address & 0xF0000000) == 0xD0000000)
                        {
                            /* if code needs GS button pressed and it's not, skip it */
                            if(((code->address & 0xFF000000) == 0xD8000000 ||
                                (code->address & 0xFF000000) == 0xD9000000 ||
                                (code->address & 0xFF000000) == 0xDA000000 ||
                                (code->address & 0xFF000000) == 0xDB000000) &&
                               !event_gameshark_active())
                                /* if condition false, skip next code non-test code */
                                cond_failed = 1;

                            /* if condition false, skip next code non-test code */
                            if (!execute_cheat(code->address, code->value, NULL))
                                cond_failed = 1;
                        }
                        else {
                            /* preconditions were false for this non-test code
                             * reset the condition state and skip the cheat
                             */
                            if (cond_failed) {
                                cond_failed = 0;
                                continue;
                            }

                            switch (code->address & 0xFF000000) {
                            /* GS button triggers cheat code */
                            case 0x88000000:
                            case 0x89000000:
                            case 0xA8000000:
                            case 0xA9000000:
                                if(event_gameshark_active())
                                    execute_cheat(code->address, code->value, NULL);
                                break;
                            /* normal cheat code */
                            default:
                                /* exclude boot-time cheat codes */
                                if((code->address & 0xF0000000) != 0xF0000000)
                                    execute_cheat(code->address, code->value, &code->old_value);
                                break;
                            }
                        }
                    }
                    break;
                default:
                    break;
            }
        }
        // if cheat was enabled, but is now disabled, restore old memory values
        else if (cheat->was_enabled)
        {
            cheat->was_enabled = 0;
            switch(entry)
            {
                case ENTRY_VI:
                    list_for_each_entry_t(code, &cheat->cheat_codes, cheat_code_t, list) {
                        // set memory back to old value and clear saved copy of old value
                        if(code->old_value != CHEAT_CODE_MAGIC_VALUE)
                        {
                            execute_cheat(code->address, code->old_value, NULL);
                            code->old_value = CHEAT_CODE_MAGIC_VALUE;
                        }
                    }
                    break;
                default:
                    break;
            }
        }
    }

    SDL_UnlockMutex(cheat_mutex);
}


void cheat_delete_all(void)
{
    cheat_t *cheat, *safe_cheat;
    cheat_code_t *code, *safe_code;

    if (list_empty(&active_cheats))
        return;

    if (cheat_mutex == NULL || SDL_LockMutex(cheat_mutex) != 0)
    {
        DebugMessage(M64MSG_ERROR, "Internal error: failed to lock mutex in cheat_delete_all()");
        return;
    }

    list_for_each_entry_safe_t(cheat, safe_cheat, &active_cheats, cheat_t, list) {
        free(cheat->name);

        list_for_each_entry_safe_t(code, safe_code, &cheat->cheat_codes, cheat_code_t, list) {
            list_del(&code->list);
            free(code);
        }
        list_del(&cheat->list);
        free(cheat);
    }

    SDL_UnlockMutex(cheat_mutex);
}

int cheat_set_enabled(const char *name, int enabled)
{
    cheat_t *cheat = NULL;

    if (list_empty(&active_cheats))
        return 0;

    if (cheat_mutex == NULL || SDL_LockMutex(cheat_mutex) != 0)
    {
        DebugMessage(M64MSG_ERROR, "Internal error: failed to lock mutex in cheat_set_enabled()");
        return 0;
    }

    list_for_each_entry_t(cheat, &active_cheats, cheat_t, list) {
        if (strcmp(name, cheat->name) == 0)
        {
            cheat->enabled = enabled;
            SDL_UnlockMutex(cheat_mutex);
            return 1;
        }
    }

    SDL_UnlockMutex(cheat_mutex);
    return 0;
}

int cheat_add_new(const char *name, m64p_cheat_code *code_list, int num_codes)
{
    cheat_t *cheat;
    int i, j;

    if (cheat_mutex == NULL || SDL_LockMutex(cheat_mutex) != 0)
    {
        DebugMessage(M64MSG_ERROR, "Internal error: failed to lock mutex in cheat_add_new()");
        return 0;
    }

    /* create a new cheat function or erase the codes in an existing cheat function */
    cheat = find_or_create_cheat(name);
    if (cheat == NULL)
    {
        SDL_UnlockMutex(cheat_mutex);
        return 0;
    }

    cheat->enabled = 1; /* default for new cheats is enabled */

    for (i = 0; i < num_codes; i++)
    {
        /* if this is a 'patch' code, convert it and dump out all of the individual codes */
        if ((code_list[i].address & 0xFFFF0000) == 0x50000000 && i < num_codes - 1)
        {
            int code_count = ((code_list[i].address & 0xFF00) >> 8);
            int incr_addr = code_list[i].address & 0xFF;
            int incr_value = code_list[i].value;
            int cur_addr = code_list[i+1].address;
            int cur_value = code_list[i+1].value;
            i += 1;
            for (j = 0; j < code_count; j++)
            {
                cheat_code_t *code = malloc(sizeof(*code));
                code->address = cur_addr;
                code->value = cur_value;
                code->old_value = CHEAT_CODE_MAGIC_VALUE;
                list_add_tail(&code->list, &cheat->cheat_codes);
                cur_addr += incr_addr;
                cur_value += incr_value;
            }
        }
        else
        { /* just a normal code */
            cheat_code_t *code = malloc(sizeof(*code));
            code->address = code_list[i].address;
            code->value = code_list[i].value;
            code->old_value = CHEAT_CODE_MAGIC_VALUE;
            list_add_tail(&code->list, &cheat->cheat_codes);
        }
    }

    SDL_UnlockMutex(cheat_mutex);
    return 1;
}

static char *strtok_compat(char *str, const char *delim, char **saveptr)
{
    char *p;

    if (str == NULL)
        str = *saveptr;

    if (str == NULL)
        return NULL;

    str += strspn(str, delim);
    if ((p = strpbrk(str, delim)) != NULL) {
        *saveptr = p + 1;
        *p = '\0';
    } else {
        *saveptr = NULL;
    }
    return str;
}

static int cheat_parse_hacks_code(char *code, m64p_cheat_code **hack)
{
    char *saveptr = NULL;
    char *input, *token;
    int num_codes;
    m64p_cheat_code *hackbuf;
    int ret;

    *hack = NULL;

    /* count number of possible cheatcodes */
    input = code;
    num_codes = 0;
    while ((strchr(input, ','))) {
        input++;
        num_codes++;
    }
    num_codes++;

    /* allocate buffer */
    hackbuf = malloc(sizeof(*hackbuf) * num_codes);
    if (!hackbuf)
        return 0;

    /* parse cheatcodes */
    input = code;
    num_codes = 0;
    while ((token = strtok_compat(input, ",", &saveptr))) {
        input = NULL;

        ret = sscanf(token, "%08" SCNx32 " %04X", &hackbuf[num_codes].address,
                     &hackbuf[num_codes].value);
        if (ret == 2)
            num_codes++;
    }

    if (num_codes == 0)
        free(hackbuf);
    else
        *hack = hackbuf;

    return num_codes;
}

int cheat_add_hacks(void)
{
    char *cheat_raw = NULL;
    char *saveptr = NULL;
    char *input, *token;
    unsigned int i = 0;
    int num_codes;
    char cheatname[32];
    m64p_cheat_code *hack;

    if (!ROM_PARAMS.cheats)
        return 0;

    /* copy ini entry for tokenizing */
    cheat_raw = strdup(ROM_PARAMS.cheats);
    if (!cheat_raw)
        goto out;

    /* split into cheats for the cheat engine */
    input = cheat_raw;
    while ((token = strtok_compat(input, ";", &saveptr))) {
        input = NULL;

        snprintf(cheatname, sizeof(cheatname), "HACK%u", i);
        cheatname[sizeof(cheatname) - 1] = '\0';

        /* parse and add cheat */
        num_codes = cheat_parse_hacks_code(token, &hack);
        if (num_codes <= 0)
            continue;

        cheat_add_new(cheatname, hack, num_codes);
        free(hack);
        i++;
    }

out:
    free(cheat_raw);
    return 0;
}
