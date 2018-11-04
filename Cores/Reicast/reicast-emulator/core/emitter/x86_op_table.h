
//auto generated
//Opcode data lists :)

#define MA_1(x) {x}
#define MA_2(x,y) {x,y}
#define MA_3(x,y,z) {x,y,z}
#define MA_4(x,y,z,l) {x,y,z,l}

const x86_opcode all_opcodes[] = 
{
	#include "generated_descriptors.h"
};

const x86_opcode* x86_opcode_list[op_count+1]=
{
	#include "generated_indexes.h"
};
