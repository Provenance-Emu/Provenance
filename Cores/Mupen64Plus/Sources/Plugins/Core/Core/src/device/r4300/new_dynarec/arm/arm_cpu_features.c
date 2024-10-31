/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - arm_cpu_features.c                                      *
 *   Mupen64Plus homepage: https://mupen64plus.org/                        *
 *   Copyright (C) 2015 Gilles Siberlin                                    *
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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "api/callbacks.h"
#include "arm_cpu_features.h"

arm_cpu_features_t arm_cpu_features;

const char procfile[] = "/proc/cpuinfo";

static unsigned char check_arm_cpu_feature(const char* feature)
{
    unsigned char status = 0;
    FILE *pFile = fopen(procfile, "r");
    
    if (pFile != NULL)
    {
        char line[1024];
        
        while (fgets(line , sizeof(line) , pFile) != NULL)
        {
            if (strncmp(line, "Features\t: ", 11))
                continue;

            if (strstr(line + 11, feature) != NULL)
                status = 1;
            
            break;
        }
        fclose(pFile);
    }
    return status;
}

static unsigned char get_arm_cpu_implementer(void)
{
    unsigned char implementer = 0;
    FILE *pFile = fopen(procfile, "r");
    
    if (pFile != NULL)
    {
        char line[1024];
        
        while (fgets(line , sizeof(line) , pFile) != NULL)
        {
            if (strncmp(line, "CPU implementer\t: ", 18))
                continue;
            
            sscanf(line+18, "0x%02hhx", &implementer);
            
            break;
        }
        fclose(pFile);
    }
    return implementer;
}

static unsigned short get_arm_cpu_part(void)
{
    unsigned short part = 0;
    FILE *pFile = fopen(procfile, "r");
    
    if (pFile != NULL)
    {
        char line[1024];
        
        while (fgets(line , sizeof(line) , pFile) != NULL)
        {
            if (strncmp(line, "CPU part\t: ", 11))
                continue;
            
            sscanf(line+11, "0x%03hx", &part);
            
            break;
        }
        fclose(pFile);
    }
    return part;
}

void detect_arm_cpu_features(void)
{
    arm_cpu_features.SWP      = check_arm_cpu_feature("swp");
    arm_cpu_features.Half     = check_arm_cpu_feature("half");
    arm_cpu_features.Thumb    = check_arm_cpu_feature("thumb");
    arm_cpu_features.FastMult = check_arm_cpu_feature("fastmult");
    arm_cpu_features.VFP      = check_arm_cpu_feature("vfp");
    arm_cpu_features.EDSP     = check_arm_cpu_feature("edsp");
    arm_cpu_features.ThumbEE  = check_arm_cpu_feature("thumbee");
    arm_cpu_features.NEON     = check_arm_cpu_feature("neon");
    arm_cpu_features.VFPv3    = check_arm_cpu_feature("vfpv3");
    arm_cpu_features.TLS      = check_arm_cpu_feature("tls");
    arm_cpu_features.VFPv4    = check_arm_cpu_feature("vfpv4");
    arm_cpu_features.IDIVa    = check_arm_cpu_feature("idiva");
    arm_cpu_features.IDIVt    = check_arm_cpu_feature("idivt");
    
    // Qualcomm Krait supports IDIVa but it doesn't report it. Check for krait.
    if (get_arm_cpu_implementer() == 0x51 && get_arm_cpu_part() == 0x6F)
        arm_cpu_features.IDIVa = arm_cpu_features.IDIVt = 1;
}

void print_arm_cpu_features(void)
{
    char buffer[1024];

    strcpy(buffer, "ARM CPU Features:");

    if (arm_cpu_features.SWP)      strcat(buffer, " SWP");
    if (arm_cpu_features.Half)     strcat(buffer, ", Half");
    if (arm_cpu_features.Thumb)    strcat(buffer, ", Thumb");
    if (arm_cpu_features.FastMult) strcat(buffer, ", FastMult");
    if (arm_cpu_features.VFP)      strcat(buffer, ", VFP");
    if (arm_cpu_features.EDSP)     strcat(buffer, ", ESDP");
    if (arm_cpu_features.ThumbEE)  strcat(buffer, ", ThumbEE");
    if (arm_cpu_features.NEON)     strcat(buffer, ", NEON");
    if (arm_cpu_features.VFPv3)    strcat(buffer, ", VFPv3");
    if (arm_cpu_features.TLS)      strcat(buffer, ", TLS");
    if (arm_cpu_features.VFPv4)    strcat(buffer, ", VFPv4");
    if (arm_cpu_features.IDIVa)    strcat(buffer, ", IDIVa");
    if (arm_cpu_features.IDIVt)    strcat(buffer, ", IDIVt");

    DebugMessage(M64MSG_INFO, "%s", buffer);
}


