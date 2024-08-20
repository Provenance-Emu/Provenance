#include "RSP.h"
#include "GBI.h"

void RSP_LoadMatrix( f32 mtx[4][4], u32 address )
{
    f32 recip = FIXED2FLOATRECIP16;
#if defined (WIN32_ASM)
    __asm {
        mov     esi, dword ptr [RDRAM];
        add     esi, dword ptr [address];
        mov     edi, dword ptr [mtx];

        mov     ecx, 4
LoadLoop:
        fild    word ptr [esi+02h]
        movzx   eax, word ptr [esi+22h]
        mov     dword ptr [edi], eax
        fild    dword ptr [edi]
        fmul    dword ptr [recip]
        fadd
        fstp    dword ptr [edi]

        fild    word ptr [esi+00h]
        movzx   eax, word ptr [esi+20h]
        mov     dword ptr [edi+04h], eax
        fild    dword ptr [edi+04h]
        fmul    dword ptr [recip]
        fadd
        fstp    dword ptr [edi+04h]

        fild    word ptr [esi+06h]
        movzx   eax, word ptr [esi+26h]
        mov     dword ptr [edi+08h], eax
        fild    dword ptr [edi+08h]
        fmul    dword ptr [recip]
        fadd
        fstp    dword ptr [edi+08h]

        fild    word ptr [esi+04h]
        movzx   eax, word ptr [esi+24h]
        mov     dword ptr [edi+0Ch], eax
        fild    dword ptr [edi+0Ch]
        fmul    dword ptr [recip]
        fadd
        fstp    dword ptr [edi+0Ch]

        add     esi, 08h
        add     edi, 10h
        loop    LoadLoop
    }
#else // WIN32_ASM
    __asm__ __volatile__(
    ".intel_syntax noprefix"                     "\n\t"
    "LoadLoop:"                                  "\n\t"
    "    fild    word ptr [esi+0x02]"            "\n\t"
    "    movzx   eax, word ptr [esi+0x22]"       "\n\t"
    "    mov     dword ptr [edi], eax"           "\n\t"
    "    fild    dword ptr [edi]"                "\n\t"
    "    fmul    %0"                             "\n\t"
    "    fadd"                                   "\n\t"
    "    fstp    dword ptr [edi]"                "\n\t"

    "    fild    word ptr [esi+0x00]"            "\n\t"
    "    movzx   eax, word ptr [esi+0x20]"       "\n\t"
    "    mov     dword ptr [edi+0x04], eax"      "\n\t"
    "    fild    dword ptr [edi+0x04]"           "\n\t"
    "    fmul    %0"                             "\n\t"
    "    fadd"                                   "\n\t"
    "    fstp    dword ptr [edi+0x04]"           "\n\t"

    "    fild    word ptr [esi+0x06]"            "\n\t"
    "    movzx   eax, word ptr [esi+0x26]"       "\n\t"
    "    mov     dword ptr [edi+0x08], eax"      "\n\t"
    "    fild    dword ptr [edi+0x08]"           "\n\t"
    "    fmul    %0"                             "\n\t"
    "    fadd"                                   "\n\t"
    "    fstp    dword ptr [edi+0x08]"           "\n\t"

    "    fild    word ptr [esi+0x04]"            "\n\t"
    "    movzx   eax, word ptr [esi+0x24]"       "\n\t"
    "    mov     dword ptr [edi+0x0C], eax"      "\n\t"
    "    fild    dword ptr [edi+0x0C]"           "\n\t"
    "    fmul    %0"                             "\n\t"
    "    fadd"                                   "\n\t"
    "    fstp    dword ptr [edi+0x0C]"           "\n\t"

    "    add     esi, 0x08"                      "\n\t"
    "    add     edi, 0x10"                      "\n\t"
    "    loop    LoadLoop"                       "\n\t"
    ".att_syntax prefix"                         "\n\t"
    : /* no output */
    : "f"(recip), "S"((int)RDRAM+address), "D"(mtx), "c"(4)
    : "memory" );
#endif // WIN32_ASM
}
