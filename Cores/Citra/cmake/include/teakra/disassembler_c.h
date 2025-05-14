#pragma once

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

bool Teakra_Disasm_NeedExpansion(uint16_t opcode);

size_t Teakra_Disasm_Do(char* dst, size_t dstlen,
	uint16_t opcode, uint16_t expansion /*= 0*/);

#ifdef __cplusplus
}
#endif
