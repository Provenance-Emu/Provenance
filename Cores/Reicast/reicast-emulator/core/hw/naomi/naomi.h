/*
**	naomi.h
*/

#pragma once

void naomi_reg_Init();
void naomi_reg_Term();
void naomi_reg_Reset(bool Manual);

void Update_naomi();

u32  ReadMem_naomi(u32 Addr, u32 sz);
void WriteMem_naomi(u32 Addr, u32 data, u32 sz);

void NaomiBoardIDWrite(const u16 Data);
void NaomiBoardIDWriteControl(const u16 Data);
u16 NaomiBoardIDRead();





















