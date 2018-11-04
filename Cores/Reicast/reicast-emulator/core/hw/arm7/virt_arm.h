#include "types.h"


void virt_arm_reset();
void virt_arm_init();
u32 DYNACALL virt_arm_op(u32 opcode);
u32& virt_arm_reg(u32 id);