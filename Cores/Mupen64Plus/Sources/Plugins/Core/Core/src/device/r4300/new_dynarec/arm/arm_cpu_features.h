/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - arm_cpu_features.h                                      *
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

#ifndef M64P_DEVICE_R4300_NEW_DYNAREC_ARM_ARM_CPU_FEATURES_H
#define M64P_DEVICE_R4300_NEW_DYNAREC_ARM_ARM_CPU_FEATURES_H

typedef struct
{
    unsigned char SWP;
    unsigned char Half;
    unsigned char Thumb;
    unsigned char FastMult;
    unsigned char VFP;
    unsigned char EDSP;
    unsigned char ThumbEE;
    unsigned char NEON;
    unsigned char VFPv3;
    unsigned char TLS;
    unsigned char VFPv4;
    unsigned char IDIVa;
    unsigned char IDIVt;
}arm_cpu_features_t;

extern arm_cpu_features_t arm_cpu_features;
void detect_arm_cpu_features(void);
void print_arm_cpu_features(void);

#endif /* M64P_DEVICE_R4300_NEW_DYNAREC_ARM_ARM_CPU_FEATURES_H */
