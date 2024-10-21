
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "types.h"
#include "snspcdisasm.h"

typedef enum
{
    SNDSPC_INST_NONE,

    SNDSPC_INST_MOV,
	SNDSPC_INST_ADC,
	SNDSPC_INST_SBC,
	SNDSPC_INST_CMP,
	SNDSPC_INST_AND,
	SNDSPC_INST_OR,
	SNDSPC_INST_EOR,
	SNDSPC_INST_INC,
	SNDSPC_INST_DEC,
	SNDSPC_INST_ASL,
	SNDSPC_INST_LSR,
	SNDSPC_INST_ROL,
	SNDSPC_INST_ROR,
	SNDSPC_INST_XCN,
	SNDSPC_INST_MOVW,
	SNDSPC_INST_INCW,
	SNDSPC_INST_DECW,
	SNDSPC_INST_ADDW,
	SNDSPC_INST_SUBW,
	SNDSPC_INST_CMPW,
	SNDSPC_INST_MUL,
	SNDSPC_INST_DIV,
	SNDSPC_INST_DAA,
	SNDSPC_INST_DAS,
	SNDSPC_INST_BRA,
	SNDSPC_INST_BEQ,
	SNDSPC_INST_BNE,
	SNDSPC_INST_BCS,
	SNDSPC_INST_BCC,
	SNDSPC_INST_BVS,
	SNDSPC_INST_BVC,
	SNDSPC_INST_BMI,
	SNDSPC_INST_BPL,
	SNDSPC_INST_BBS,
	SNDSPC_INST_BBC,
	SNDSPC_INST_CBNE,
	SNDSPC_INST_DBNZ,
	SNDSPC_INST_JMP,
	SNDSPC_INST_CALL,
	SNDSPC_INST_PCALL,
	SNDSPC_INST_TCALL,
	SNDSPC_INST_BRK,
	SNDSPC_INST_RET,
	SNDSPC_INST_RETI,
	SNDSPC_INST_PUSH,
	SNDSPC_INST_POP,
	SNDSPC_INST_SET1,
	SNDSPC_INST_CLR1,
	SNDSPC_INST_TSET1,
	SNDSPC_INST_TCLR1,
	SNDSPC_INST_AND1,
	SNDSPC_INST_OR1,
	SNDSPC_INST_EOR1,
	SNDSPC_INST_NOT1,
	SNDSPC_INST_MOV1,
	SNDSPC_INST_CLRC,
	SNDSPC_INST_SETC,
	SNDSPC_INST_NOTC,
	SNDSPC_INST_CLRV,
	SNDSPC_INST_CLRP,
	SNDSPC_INST_SETP,
	SNDSPC_INST_EI,
	SNDSPC_INST_DI,
	SNDSPC_INST_NOP,
	SNDSPC_INST_SLEEP,
	SNDSPC_INST_STOP,
    
    SNDSPC_INST_NUM

} SNDSPCInstE;

typedef enum
{
    SNDSPC_OPERAND_NONE,
    SNDSPC_OPERAND_A,                  
    SNDSPC_OPERAND_X,                  
    SNDSPC_OPERAND_Y,                  
    SNDSPC_OPERAND_PSW,                
    SNDSPC_OPERAND_YA,                 
    SNDSPC_OPERAND_PC,                 
    SNDSPC_OPERAND_SP,                 
    
    SNDSPC_OPERAND_IMM,        
    SNDSPC_OPERAND_DP,        
    SNDSPC_OPERAND_DP_IX,        
    SNDSPC_OPERAND_DP_IX_INDIRECT,        
    SNDSPC_OPERAND_DP_INDIRECT_IY,        
    SNDSPC_OPERAND_IX,  
    SNDSPC_OPERAND_IY,  
    SNDSPC_OPERAND_IX_INC,  
    SNDSPC_OPERAND_ABS,  
    SNDSPC_OPERAND_ABS_IX,  
    SNDSPC_OPERAND_ABS_IY,  
    SNDSPC_OPERAND_IX_INDIRECT,  
    SNDSPC_OPERAND_REL,        


	SNDSPC_OPERAND_DP0,        
	SNDSPC_OPERAND_DP1,        
	SNDSPC_OPERAND_DP2,        
	SNDSPC_OPERAND_DP3,        
	SNDSPC_OPERAND_DP4,        
	SNDSPC_OPERAND_DP5,        
	SNDSPC_OPERAND_DP6,        
	SNDSPC_OPERAND_DP7,        

	SNDSPC_OPERAND_C,        
    SNDSPC_OPERAND_DP_IY,        
    SNDSPC_OPERAND_MEMBIT,        
    SNDSPC_OPERAND_NOTMEMBIT,        
    SNDSPC_OPERAND_UPAGE,        

    
    SNDSPC_OPERAND_NUM
} SNDSPCOperandE;



typedef struct SNDOpStream_T
{
    Uint32  uStartPC;
    Uint32  uPC;
    Uint8   *pOpcode;
} SNDOpStreamT;

typedef struct
{
    Uint8			uOpcode;    // opcode
    SNDSPCInstE		eInst;      // instruction type
    SNDSPCOperandE	eOperand0;   // operand type
    SNDSPCOperandE	eOperand1;   // operand type
	Uint8			bSwap;		// swap operands?
} SNDSPCInstDefT;


typedef struct 
{
    SNDSPCInstE eInst;
    char *pName;
} SNDSPCMnemonicT;


//
//
//

//static Bool _SNDSPC_bInitialized = FALSE;
//static SNDInstDefT *_SNDSPC_InstMatrix[0x100];                    

static SNDSPCInstDefT _SNDSPC_InstDefs[]=
{
// loads                                                            
    {0xE8, SNDSPC_INST_MOV, SNDSPC_OPERAND_A, SNDSPC_OPERAND_IMM                  },
    {0xE6, SNDSPC_INST_MOV, SNDSPC_OPERAND_A, SNDSPC_OPERAND_IX             },
    {0xBF, SNDSPC_INST_MOV, SNDSPC_OPERAND_A, SNDSPC_OPERAND_IX_INC         },
    {0xE4, SNDSPC_INST_MOV, SNDSPC_OPERAND_A, SNDSPC_OPERAND_DP                   },
    {0xF4, SNDSPC_INST_MOV, SNDSPC_OPERAND_A, SNDSPC_OPERAND_DP_IX                },
    {0xE5, SNDSPC_INST_MOV, SNDSPC_OPERAND_A, SNDSPC_OPERAND_ABS                  },
    {0xF5, SNDSPC_INST_MOV, SNDSPC_OPERAND_A, SNDSPC_OPERAND_ABS_IX               },
    {0xF6, SNDSPC_INST_MOV, SNDSPC_OPERAND_A, SNDSPC_OPERAND_ABS_IY               },
    {0xE7, SNDSPC_INST_MOV, SNDSPC_OPERAND_A, SNDSPC_OPERAND_DP_IX_INDIRECT       },
    {0xF7, SNDSPC_INST_MOV, SNDSPC_OPERAND_A, SNDSPC_OPERAND_DP_INDIRECT_IY        },

    {0xCD, SNDSPC_INST_MOV, SNDSPC_OPERAND_X, SNDSPC_OPERAND_IMM                  },
    {0xF8, SNDSPC_INST_MOV, SNDSPC_OPERAND_X, SNDSPC_OPERAND_DP                   },
    {0xF9, SNDSPC_INST_MOV, SNDSPC_OPERAND_X, SNDSPC_OPERAND_DP_IY                },
    {0xE9, SNDSPC_INST_MOV, SNDSPC_OPERAND_X, SNDSPC_OPERAND_ABS                  },

    {0x8D, SNDSPC_INST_MOV, SNDSPC_OPERAND_Y, SNDSPC_OPERAND_IMM                  },
    {0xEB, SNDSPC_INST_MOV, SNDSPC_OPERAND_Y, SNDSPC_OPERAND_DP                   },
    {0xFB, SNDSPC_INST_MOV, SNDSPC_OPERAND_Y, SNDSPC_OPERAND_DP_IX                },
    {0xEC, SNDSPC_INST_MOV, SNDSPC_OPERAND_Y, SNDSPC_OPERAND_ABS                  },

// stores
    {0xC6, SNDSPC_INST_MOV, SNDSPC_OPERAND_IX         ,SNDSPC_OPERAND_A     },
    {0xAF, SNDSPC_INST_MOV, SNDSPC_OPERAND_IX_INC     ,SNDSPC_OPERAND_A     },
    {0xC4, SNDSPC_INST_MOV, SNDSPC_OPERAND_DP               ,SNDSPC_OPERAND_A     },
    {0xD4, SNDSPC_INST_MOV, SNDSPC_OPERAND_DP_IX            ,SNDSPC_OPERAND_A     },
    {0xC5, SNDSPC_INST_MOV, SNDSPC_OPERAND_ABS              ,SNDSPC_OPERAND_A     },
    {0xD5, SNDSPC_INST_MOV, SNDSPC_OPERAND_ABS_IX           ,SNDSPC_OPERAND_A     },
    {0xD6, SNDSPC_INST_MOV, SNDSPC_OPERAND_ABS_IY           ,SNDSPC_OPERAND_A     },
    {0xC7, SNDSPC_INST_MOV, SNDSPC_OPERAND_DP_IX_INDIRECT   ,SNDSPC_OPERAND_A     },
    {0xD7, SNDSPC_INST_MOV, SNDSPC_OPERAND_DP_INDIRECT_IY   ,SNDSPC_OPERAND_A      },

    {0xD8, SNDSPC_INST_MOV, SNDSPC_OPERAND_DP               ,SNDSPC_OPERAND_X     },
    {0xD9, SNDSPC_INST_MOV, SNDSPC_OPERAND_DP_IY            ,SNDSPC_OPERAND_X     },
    {0xC9, SNDSPC_INST_MOV, SNDSPC_OPERAND_ABS              ,SNDSPC_OPERAND_X     },

    {0xCB, SNDSPC_INST_MOV, SNDSPC_OPERAND_DP               ,SNDSPC_OPERAND_Y     },
    {0xDB, SNDSPC_INST_MOV, SNDSPC_OPERAND_DP_IX            ,SNDSPC_OPERAND_Y     },
    {0xCC, SNDSPC_INST_MOV, SNDSPC_OPERAND_ABS              ,SNDSPC_OPERAND_Y     },

// move intraregister
    {0x7D, SNDSPC_INST_MOV, SNDSPC_OPERAND_A                ,SNDSPC_OPERAND_X     },
    {0xDD, SNDSPC_INST_MOV, SNDSPC_OPERAND_A                ,SNDSPC_OPERAND_Y     },
    {0x5D, SNDSPC_INST_MOV, SNDSPC_OPERAND_X                ,SNDSPC_OPERAND_A     },
    {0xFD, SNDSPC_INST_MOV, SNDSPC_OPERAND_Y                ,SNDSPC_OPERAND_A     },
    {0x9D, SNDSPC_INST_MOV, SNDSPC_OPERAND_X                ,SNDSPC_OPERAND_SP     },
    {0xBD, SNDSPC_INST_MOV, SNDSPC_OPERAND_SP               ,SNDSPC_OPERAND_X     },
    {0xFA, SNDSPC_INST_MOV, SNDSPC_OPERAND_DP               ,SNDSPC_OPERAND_DP     , TRUE},
    {0x8F, SNDSPC_INST_MOV, SNDSPC_OPERAND_DP               ,SNDSPC_OPERAND_IMM    , TRUE },



    {0x88, SNDSPC_INST_ADC, SNDSPC_OPERAND_A, SNDSPC_OPERAND_IMM                  },
    {0x86, SNDSPC_INST_ADC, SNDSPC_OPERAND_A, SNDSPC_OPERAND_IX             },
    {0x84, SNDSPC_INST_ADC, SNDSPC_OPERAND_A, SNDSPC_OPERAND_DP                   },
    {0x94, SNDSPC_INST_ADC, SNDSPC_OPERAND_A, SNDSPC_OPERAND_DP_IX                },
    {0x85, SNDSPC_INST_ADC, SNDSPC_OPERAND_A, SNDSPC_OPERAND_ABS                  },
    {0x95, SNDSPC_INST_ADC, SNDSPC_OPERAND_A, SNDSPC_OPERAND_ABS_IX               },
    {0x96, SNDSPC_INST_ADC, SNDSPC_OPERAND_A, SNDSPC_OPERAND_ABS_IY               },
    {0x87, SNDSPC_INST_ADC, SNDSPC_OPERAND_A, SNDSPC_OPERAND_DP_IX_INDIRECT       },
    {0x97, SNDSPC_INST_ADC, SNDSPC_OPERAND_A, SNDSPC_OPERAND_DP_INDIRECT_IY        },
    {0x99, SNDSPC_INST_ADC, SNDSPC_OPERAND_IX, SNDSPC_OPERAND_IY                  },
    {0x89, SNDSPC_INST_ADC, SNDSPC_OPERAND_DP, SNDSPC_OPERAND_DP                  , TRUE },
    {0x98, SNDSPC_INST_ADC, SNDSPC_OPERAND_DP, SNDSPC_OPERAND_IMM                  , TRUE},

    {0xA8, SNDSPC_INST_SBC, SNDSPC_OPERAND_A, SNDSPC_OPERAND_IMM                  },
    {0xA6, SNDSPC_INST_SBC, SNDSPC_OPERAND_A, SNDSPC_OPERAND_IX             },
    {0xA4, SNDSPC_INST_SBC, SNDSPC_OPERAND_A, SNDSPC_OPERAND_DP                   },
    {0xB4, SNDSPC_INST_SBC, SNDSPC_OPERAND_A, SNDSPC_OPERAND_DP_IX                },
    {0xA5, SNDSPC_INST_SBC, SNDSPC_OPERAND_A, SNDSPC_OPERAND_ABS                  },
    {0xB5, SNDSPC_INST_SBC, SNDSPC_OPERAND_A, SNDSPC_OPERAND_ABS_IX               },
    {0xB6, SNDSPC_INST_SBC, SNDSPC_OPERAND_A, SNDSPC_OPERAND_ABS_IY               },
    {0xA7, SNDSPC_INST_SBC, SNDSPC_OPERAND_A, SNDSPC_OPERAND_DP_IX_INDIRECT       },
    {0xB7, SNDSPC_INST_SBC, SNDSPC_OPERAND_A, SNDSPC_OPERAND_DP_INDIRECT_IY        },
    {0xB9, SNDSPC_INST_SBC, SNDSPC_OPERAND_IX, SNDSPC_OPERAND_IY                  },
    {0xA9, SNDSPC_INST_SBC, SNDSPC_OPERAND_DP, SNDSPC_OPERAND_DP                   , TRUE},
    {0xB8, SNDSPC_INST_SBC, SNDSPC_OPERAND_DP, SNDSPC_OPERAND_IMM                  , TRUE},

    {0x68, SNDSPC_INST_CMP, SNDSPC_OPERAND_A, SNDSPC_OPERAND_IMM                  },
    {0x66, SNDSPC_INST_CMP, SNDSPC_OPERAND_A, SNDSPC_OPERAND_IX             },
    {0x64, SNDSPC_INST_CMP, SNDSPC_OPERAND_A, SNDSPC_OPERAND_DP                   },
    {0x74, SNDSPC_INST_CMP, SNDSPC_OPERAND_A, SNDSPC_OPERAND_DP_IX                },
    {0x65, SNDSPC_INST_CMP, SNDSPC_OPERAND_A, SNDSPC_OPERAND_ABS                  },
    {0x75, SNDSPC_INST_CMP, SNDSPC_OPERAND_A, SNDSPC_OPERAND_ABS_IX               },
    {0x76, SNDSPC_INST_CMP, SNDSPC_OPERAND_A, SNDSPC_OPERAND_ABS_IY               },
    {0x67, SNDSPC_INST_CMP, SNDSPC_OPERAND_A, SNDSPC_OPERAND_DP_IX_INDIRECT       },
    {0x77, SNDSPC_INST_CMP, SNDSPC_OPERAND_A, SNDSPC_OPERAND_DP_INDIRECT_IY        },
    {0x79, SNDSPC_INST_CMP, SNDSPC_OPERAND_IX, SNDSPC_OPERAND_IY                  },
    {0x69, SNDSPC_INST_CMP, SNDSPC_OPERAND_DP, SNDSPC_OPERAND_DP                   , TRUE},
    {0x78, SNDSPC_INST_CMP, SNDSPC_OPERAND_DP, SNDSPC_OPERAND_IMM                  , TRUE},

    {0xC8, SNDSPC_INST_CMP, SNDSPC_OPERAND_X, SNDSPC_OPERAND_IMM                  },
    {0x3E, SNDSPC_INST_CMP, SNDSPC_OPERAND_X, SNDSPC_OPERAND_DP                   },
    {0x1E, SNDSPC_INST_CMP, SNDSPC_OPERAND_X, SNDSPC_OPERAND_ABS                  },

    {0xAD, SNDSPC_INST_CMP, SNDSPC_OPERAND_Y, SNDSPC_OPERAND_IMM                  },
    {0x7E, SNDSPC_INST_CMP, SNDSPC_OPERAND_Y, SNDSPC_OPERAND_DP                   },
    {0x5E, SNDSPC_INST_CMP, SNDSPC_OPERAND_Y, SNDSPC_OPERAND_ABS                  },






    {0x28, SNDSPC_INST_AND, SNDSPC_OPERAND_A, SNDSPC_OPERAND_IMM                  },
    {0x26, SNDSPC_INST_AND, SNDSPC_OPERAND_A, SNDSPC_OPERAND_IX             },
    {0x24, SNDSPC_INST_AND, SNDSPC_OPERAND_A, SNDSPC_OPERAND_DP                   },
    {0x34, SNDSPC_INST_AND, SNDSPC_OPERAND_A, SNDSPC_OPERAND_DP_IX                },
    {0x25, SNDSPC_INST_AND, SNDSPC_OPERAND_A, SNDSPC_OPERAND_ABS                  },
    {0x35, SNDSPC_INST_AND, SNDSPC_OPERAND_A, SNDSPC_OPERAND_ABS_IX               },
    {0x36, SNDSPC_INST_AND, SNDSPC_OPERAND_A, SNDSPC_OPERAND_ABS_IY               },
    {0x27, SNDSPC_INST_AND, SNDSPC_OPERAND_A, SNDSPC_OPERAND_DP_IX_INDIRECT       },
    {0x37, SNDSPC_INST_AND, SNDSPC_OPERAND_A, SNDSPC_OPERAND_DP_INDIRECT_IY        },
    {0x39, SNDSPC_INST_AND, SNDSPC_OPERAND_IX, SNDSPC_OPERAND_IY                  },
    {0x29, SNDSPC_INST_AND, SNDSPC_OPERAND_DP, SNDSPC_OPERAND_DP                   , TRUE},
    {0x38, SNDSPC_INST_AND, SNDSPC_OPERAND_DP, SNDSPC_OPERAND_IMM                 , TRUE },

    {0x08, SNDSPC_INST_OR , SNDSPC_OPERAND_A, SNDSPC_OPERAND_IMM                  },
    {0x06, SNDSPC_INST_OR , SNDSPC_OPERAND_A, SNDSPC_OPERAND_IX             },
    {0x04, SNDSPC_INST_OR , SNDSPC_OPERAND_A, SNDSPC_OPERAND_DP                   },
    {0x14, SNDSPC_INST_OR , SNDSPC_OPERAND_A, SNDSPC_OPERAND_DP_IX                },
    {0x05, SNDSPC_INST_OR , SNDSPC_OPERAND_A, SNDSPC_OPERAND_ABS                  },
    {0x15, SNDSPC_INST_OR , SNDSPC_OPERAND_A, SNDSPC_OPERAND_ABS_IX               },
    {0x16, SNDSPC_INST_OR , SNDSPC_OPERAND_A, SNDSPC_OPERAND_ABS_IY               },
    {0x07, SNDSPC_INST_OR , SNDSPC_OPERAND_A, SNDSPC_OPERAND_DP_IX_INDIRECT       },
    {0x17, SNDSPC_INST_OR , SNDSPC_OPERAND_A, SNDSPC_OPERAND_DP_INDIRECT_IY        },
    {0x19, SNDSPC_INST_OR , SNDSPC_OPERAND_IX, SNDSPC_OPERAND_IY                  },
    {0x09, SNDSPC_INST_OR , SNDSPC_OPERAND_DP, SNDSPC_OPERAND_DP                   , TRUE},
    {0x18, SNDSPC_INST_OR , SNDSPC_OPERAND_DP, SNDSPC_OPERAND_IMM                 , TRUE },

    {0x48, SNDSPC_INST_EOR, SNDSPC_OPERAND_A, SNDSPC_OPERAND_IMM                  },
    {0x46, SNDSPC_INST_EOR, SNDSPC_OPERAND_A, SNDSPC_OPERAND_IX             },
    {0x44, SNDSPC_INST_EOR, SNDSPC_OPERAND_A, SNDSPC_OPERAND_DP                   },
    {0x54, SNDSPC_INST_EOR, SNDSPC_OPERAND_A, SNDSPC_OPERAND_DP_IX                },
    {0x45, SNDSPC_INST_EOR, SNDSPC_OPERAND_A, SNDSPC_OPERAND_ABS                  },
    {0x55, SNDSPC_INST_EOR, SNDSPC_OPERAND_A, SNDSPC_OPERAND_ABS_IX               },
    {0x56, SNDSPC_INST_EOR, SNDSPC_OPERAND_A, SNDSPC_OPERAND_ABS_IY               },
    {0x47, SNDSPC_INST_EOR, SNDSPC_OPERAND_A, SNDSPC_OPERAND_DP_IX_INDIRECT       },
    {0x57, SNDSPC_INST_EOR, SNDSPC_OPERAND_A, SNDSPC_OPERAND_DP_INDIRECT_IY        },
    {0x59, SNDSPC_INST_EOR, SNDSPC_OPERAND_IX, SNDSPC_OPERAND_IY                  },
    {0x49, SNDSPC_INST_EOR, SNDSPC_OPERAND_DP, SNDSPC_OPERAND_DP                   , TRUE},
    {0x58, SNDSPC_INST_EOR, SNDSPC_OPERAND_DP, SNDSPC_OPERAND_IMM                  , TRUE},


    {0xBC, SNDSPC_INST_INC, SNDSPC_OPERAND_A, SNDSPC_OPERAND_NONE       },
    {0xAB, SNDSPC_INST_INC, SNDSPC_OPERAND_DP, SNDSPC_OPERAND_NONE       },
    {0xBB, SNDSPC_INST_INC, SNDSPC_OPERAND_DP_IX, SNDSPC_OPERAND_NONE       },
    {0xAC, SNDSPC_INST_INC, SNDSPC_OPERAND_ABS, SNDSPC_OPERAND_NONE       },
    {0x3D, SNDSPC_INST_INC, SNDSPC_OPERAND_X, SNDSPC_OPERAND_NONE       },
    {0xFC, SNDSPC_INST_INC, SNDSPC_OPERAND_Y, SNDSPC_OPERAND_NONE       },

    {0x9C, SNDSPC_INST_DEC, SNDSPC_OPERAND_A, SNDSPC_OPERAND_NONE       },
    {0x8B, SNDSPC_INST_DEC, SNDSPC_OPERAND_DP, SNDSPC_OPERAND_NONE       },
    {0x9B, SNDSPC_INST_DEC, SNDSPC_OPERAND_DP_IX, SNDSPC_OPERAND_NONE       },
    {0x8C, SNDSPC_INST_DEC, SNDSPC_OPERAND_ABS, SNDSPC_OPERAND_NONE       },
    {0x1D, SNDSPC_INST_DEC, SNDSPC_OPERAND_X, SNDSPC_OPERAND_NONE       },
    {0xDC, SNDSPC_INST_DEC, SNDSPC_OPERAND_Y, SNDSPC_OPERAND_NONE       },

    {0x1C, SNDSPC_INST_ASL, SNDSPC_OPERAND_A, SNDSPC_OPERAND_NONE       },
    {0x0B, SNDSPC_INST_ASL, SNDSPC_OPERAND_DP, SNDSPC_OPERAND_NONE       },
    {0x1B, SNDSPC_INST_ASL, SNDSPC_OPERAND_DP_IX, SNDSPC_OPERAND_NONE       },
    {0xCC, SNDSPC_INST_ASL, SNDSPC_OPERAND_ABS, SNDSPC_OPERAND_NONE       },

    {0x5C, SNDSPC_INST_LSR, SNDSPC_OPERAND_A, SNDSPC_OPERAND_NONE       },
    {0x4B, SNDSPC_INST_LSR, SNDSPC_OPERAND_DP, SNDSPC_OPERAND_NONE       },
    {0x5B, SNDSPC_INST_LSR, SNDSPC_OPERAND_DP_IX, SNDSPC_OPERAND_NONE       },
    {0x4C, SNDSPC_INST_LSR, SNDSPC_OPERAND_ABS, SNDSPC_OPERAND_NONE       },

    {0x3C, SNDSPC_INST_ROL, SNDSPC_OPERAND_A, SNDSPC_OPERAND_NONE       },
    {0x2B, SNDSPC_INST_ROL, SNDSPC_OPERAND_DP, SNDSPC_OPERAND_NONE       },
    {0x3B, SNDSPC_INST_ROL, SNDSPC_OPERAND_DP_IX, SNDSPC_OPERAND_NONE       },
    {0x2C, SNDSPC_INST_ROL, SNDSPC_OPERAND_ABS, SNDSPC_OPERAND_NONE       },

    {0x7C, SNDSPC_INST_ROR, SNDSPC_OPERAND_A, SNDSPC_OPERAND_NONE       },
    {0x6B, SNDSPC_INST_ROR, SNDSPC_OPERAND_DP, SNDSPC_OPERAND_NONE       },
    {0x7B, SNDSPC_INST_ROR, SNDSPC_OPERAND_DP_IX, SNDSPC_OPERAND_NONE       },
    {0x6C, SNDSPC_INST_ROR, SNDSPC_OPERAND_ABS, SNDSPC_OPERAND_NONE       },

    {0x9F, SNDSPC_INST_XCN, SNDSPC_OPERAND_A, SNDSPC_OPERAND_NONE       },

    {0xBA, SNDSPC_INST_MOVW, SNDSPC_OPERAND_YA, SNDSPC_OPERAND_DP       },
    {0xDA, SNDSPC_INST_MOVW, SNDSPC_OPERAND_DP, SNDSPC_OPERAND_YA       },

    {0x3A, SNDSPC_INST_INCW, SNDSPC_OPERAND_DP, SNDSPC_OPERAND_NONE       },
    {0x1A, SNDSPC_INST_DECW, SNDSPC_OPERAND_DP, SNDSPC_OPERAND_NONE       },
    {0x7A, SNDSPC_INST_ADDW, SNDSPC_OPERAND_YA, SNDSPC_OPERAND_DP       },
    {0x9A, SNDSPC_INST_SUBW, SNDSPC_OPERAND_YA, SNDSPC_OPERAND_DP       },
    {0x5A, SNDSPC_INST_CMPW, SNDSPC_OPERAND_YA, SNDSPC_OPERAND_DP       },


    {0xCF, SNDSPC_INST_MUL, SNDSPC_OPERAND_YA, SNDSPC_OPERAND_NONE       },
    {0x9E, SNDSPC_INST_DIV, SNDSPC_OPERAND_YA, SNDSPC_OPERAND_X       },

    {0xDF, SNDSPC_INST_DAA, SNDSPC_OPERAND_A, SNDSPC_OPERAND_NONE       },
    {0xBE, SNDSPC_INST_DAS, SNDSPC_OPERAND_A, SNDSPC_OPERAND_NONE       },

    {0x2F, SNDSPC_INST_BRA, SNDSPC_OPERAND_REL, SNDSPC_OPERAND_NONE       },
    {0xF0, SNDSPC_INST_BEQ, SNDSPC_OPERAND_REL, SNDSPC_OPERAND_NONE       },
    {0xD0, SNDSPC_INST_BNE, SNDSPC_OPERAND_REL, SNDSPC_OPERAND_NONE       },
    {0xB0, SNDSPC_INST_BCS, SNDSPC_OPERAND_REL, SNDSPC_OPERAND_NONE       },
    {0x90, SNDSPC_INST_BCC, SNDSPC_OPERAND_REL, SNDSPC_OPERAND_NONE       },
    {0x70, SNDSPC_INST_BVS, SNDSPC_OPERAND_REL, SNDSPC_OPERAND_NONE       },
    {0x50, SNDSPC_INST_BVC, SNDSPC_OPERAND_REL, SNDSPC_OPERAND_NONE       },
    {0x30, SNDSPC_INST_BMI, SNDSPC_OPERAND_REL, SNDSPC_OPERAND_NONE       },
    {0x10, SNDSPC_INST_BPL, SNDSPC_OPERAND_REL, SNDSPC_OPERAND_NONE       },

    {0x2E, SNDSPC_INST_CBNE, SNDSPC_OPERAND_DP, SNDSPC_OPERAND_REL       },
    {0xDE, SNDSPC_INST_CBNE, SNDSPC_OPERAND_DP_IX, SNDSPC_OPERAND_REL       },

    {0x6E, SNDSPC_INST_DBNZ, SNDSPC_OPERAND_DP, SNDSPC_OPERAND_REL       },
    {0xFE, SNDSPC_INST_DBNZ, SNDSPC_OPERAND_Y, SNDSPC_OPERAND_REL       },

    {0x5F, SNDSPC_INST_JMP, SNDSPC_OPERAND_ABS, SNDSPC_OPERAND_NONE       },
    {0x1F, SNDSPC_INST_JMP, SNDSPC_OPERAND_ABS_IX, SNDSPC_OPERAND_NONE       },

    {0x3F, SNDSPC_INST_CALL, SNDSPC_OPERAND_ABS, SNDSPC_OPERAND_NONE       },
    {0x4F, SNDSPC_INST_PCALL, SNDSPC_OPERAND_UPAGE, SNDSPC_OPERAND_NONE       },
    {0x0F, SNDSPC_INST_BRK, SNDSPC_OPERAND_NONE, SNDSPC_OPERAND_NONE       },

    {0x6F, SNDSPC_INST_RET, SNDSPC_OPERAND_NONE, SNDSPC_OPERAND_NONE       },
    {0x7F, SNDSPC_INST_RETI, SNDSPC_OPERAND_NONE, SNDSPC_OPERAND_NONE       },

    {0x2D, SNDSPC_INST_PUSH, SNDSPC_OPERAND_A, SNDSPC_OPERAND_NONE       },
    {0x4D, SNDSPC_INST_PUSH, SNDSPC_OPERAND_X, SNDSPC_OPERAND_NONE       },
    {0x6D, SNDSPC_INST_PUSH, SNDSPC_OPERAND_Y, SNDSPC_OPERAND_NONE       },
    {0x0D, SNDSPC_INST_PUSH, SNDSPC_OPERAND_PSW, SNDSPC_OPERAND_NONE       },

    {0xAE, SNDSPC_INST_POP, SNDSPC_OPERAND_A, SNDSPC_OPERAND_NONE       },
    {0xCE, SNDSPC_INST_POP, SNDSPC_OPERAND_X, SNDSPC_OPERAND_NONE       },
    {0xEE, SNDSPC_INST_POP, SNDSPC_OPERAND_Y, SNDSPC_OPERAND_NONE       },
    {0x8E, SNDSPC_INST_POP, SNDSPC_OPERAND_PSW, SNDSPC_OPERAND_NONE       },


    {0x0E, SNDSPC_INST_TSET1, SNDSPC_OPERAND_ABS, SNDSPC_OPERAND_NONE       },
    {0x4E, SNDSPC_INST_TCLR1, SNDSPC_OPERAND_ABS, SNDSPC_OPERAND_NONE       },

    {0x4A, SNDSPC_INST_AND1, SNDSPC_OPERAND_C, SNDSPC_OPERAND_MEMBIT       },
    {0x6A, SNDSPC_INST_AND1, SNDSPC_OPERAND_C, SNDSPC_OPERAND_NOTMEMBIT       },
    {0x0A, SNDSPC_INST_OR1,  SNDSPC_OPERAND_C, SNDSPC_OPERAND_MEMBIT       },
    {0x2A, SNDSPC_INST_OR1,  SNDSPC_OPERAND_C, SNDSPC_OPERAND_NOTMEMBIT       },

    {0x8A, SNDSPC_INST_EOR1,  SNDSPC_OPERAND_C, SNDSPC_OPERAND_MEMBIT       },
    {0xEA, SNDSPC_INST_NOT1,  SNDSPC_OPERAND_MEMBIT, SNDSPC_OPERAND_NONE      },

    {0xAA, SNDSPC_INST_MOV1,  SNDSPC_OPERAND_C, SNDSPC_OPERAND_MEMBIT      },
    {0xCA, SNDSPC_INST_MOV1,  SNDSPC_OPERAND_MEMBIT, SNDSPC_OPERAND_C      },


    {0x60, SNDSPC_INST_CLRC,  SNDSPC_OPERAND_NONE, SNDSPC_OPERAND_NONE      },
    {0x80, SNDSPC_INST_SETC,  SNDSPC_OPERAND_NONE, SNDSPC_OPERAND_NONE      },
    {0xED, SNDSPC_INST_NOTC,  SNDSPC_OPERAND_NONE, SNDSPC_OPERAND_NONE      },
    {0xE0, SNDSPC_INST_CLRV,  SNDSPC_OPERAND_NONE, SNDSPC_OPERAND_NONE      },
    {0x20, SNDSPC_INST_CLRP,  SNDSPC_OPERAND_NONE, SNDSPC_OPERAND_NONE      },
    {0x40, SNDSPC_INST_SETP,  SNDSPC_OPERAND_NONE, SNDSPC_OPERAND_NONE      },
    {0xA0, SNDSPC_INST_EI,    SNDSPC_OPERAND_NONE, SNDSPC_OPERAND_NONE      },
    {0xC0, SNDSPC_INST_DI,    SNDSPC_OPERAND_NONE, SNDSPC_OPERAND_NONE      },

    {0x00, SNDSPC_INST_NOP,    SNDSPC_OPERAND_NONE, SNDSPC_OPERAND_NONE      },
    {0xEF, SNDSPC_INST_SLEEP,    SNDSPC_OPERAND_NONE, SNDSPC_OPERAND_NONE      },
    {0xFF, SNDSPC_INST_STOP,    SNDSPC_OPERAND_NONE, SNDSPC_OPERAND_NONE      },



	{0x02, SNDSPC_INST_SET1,    SNDSPC_OPERAND_DP0, SNDSPC_OPERAND_NONE      },
	{0x22, SNDSPC_INST_SET1,    SNDSPC_OPERAND_DP1, SNDSPC_OPERAND_NONE      },
	{0x42, SNDSPC_INST_SET1,    SNDSPC_OPERAND_DP2, SNDSPC_OPERAND_NONE      },
	{0x62, SNDSPC_INST_SET1,    SNDSPC_OPERAND_DP3, SNDSPC_OPERAND_NONE      },
	{0x82, SNDSPC_INST_SET1,    SNDSPC_OPERAND_DP4, SNDSPC_OPERAND_NONE      },
	{0xA2, SNDSPC_INST_SET1,    SNDSPC_OPERAND_DP5, SNDSPC_OPERAND_NONE      },
	{0xC2, SNDSPC_INST_SET1,    SNDSPC_OPERAND_DP6, SNDSPC_OPERAND_NONE      },
	{0xE2, SNDSPC_INST_SET1,    SNDSPC_OPERAND_DP7, SNDSPC_OPERAND_NONE      },

	{0x12, SNDSPC_INST_CLR1,    SNDSPC_OPERAND_DP0, SNDSPC_OPERAND_NONE      },
	{0x32, SNDSPC_INST_CLR1,    SNDSPC_OPERAND_DP1, SNDSPC_OPERAND_NONE      },
	{0x52, SNDSPC_INST_CLR1,    SNDSPC_OPERAND_DP2, SNDSPC_OPERAND_NONE      },
	{0x72, SNDSPC_INST_CLR1,    SNDSPC_OPERAND_DP3, SNDSPC_OPERAND_NONE      },
	{0x92, SNDSPC_INST_CLR1,    SNDSPC_OPERAND_DP4, SNDSPC_OPERAND_NONE      },
	{0xB2, SNDSPC_INST_CLR1,    SNDSPC_OPERAND_DP5, SNDSPC_OPERAND_NONE      },
	{0xD2, SNDSPC_INST_CLR1,    SNDSPC_OPERAND_DP6, SNDSPC_OPERAND_NONE      },
	{0xF2, SNDSPC_INST_CLR1,    SNDSPC_OPERAND_DP7, SNDSPC_OPERAND_NONE      },

	{0x03, SNDSPC_INST_BBS,    SNDSPC_OPERAND_DP0, SNDSPC_OPERAND_REL      },
	{0x23, SNDSPC_INST_BBS,    SNDSPC_OPERAND_DP1, SNDSPC_OPERAND_REL      },
	{0x43, SNDSPC_INST_BBS,    SNDSPC_OPERAND_DP2, SNDSPC_OPERAND_REL      },
	{0x63, SNDSPC_INST_BBS,    SNDSPC_OPERAND_DP3, SNDSPC_OPERAND_REL      },
	{0x83, SNDSPC_INST_BBS,    SNDSPC_OPERAND_DP4, SNDSPC_OPERAND_REL      },
	{0xA3, SNDSPC_INST_BBS,    SNDSPC_OPERAND_DP5, SNDSPC_OPERAND_REL      },
	{0xC3, SNDSPC_INST_BBS,    SNDSPC_OPERAND_DP6, SNDSPC_OPERAND_REL      },
	{0xE3, SNDSPC_INST_BBS,    SNDSPC_OPERAND_DP7, SNDSPC_OPERAND_REL      },

	{0x13, SNDSPC_INST_BBC,    SNDSPC_OPERAND_DP0, SNDSPC_OPERAND_REL      },
	{0x33, SNDSPC_INST_BBC,    SNDSPC_OPERAND_DP1, SNDSPC_OPERAND_REL      },
	{0x53, SNDSPC_INST_BBC,    SNDSPC_OPERAND_DP2, SNDSPC_OPERAND_REL      },
	{0x73, SNDSPC_INST_BBC,    SNDSPC_OPERAND_DP3, SNDSPC_OPERAND_REL      },
	{0x93, SNDSPC_INST_BBC,    SNDSPC_OPERAND_DP4, SNDSPC_OPERAND_REL      },
	{0xB3, SNDSPC_INST_BBC,    SNDSPC_OPERAND_DP5, SNDSPC_OPERAND_REL      },
	{0xD3, SNDSPC_INST_BBC,    SNDSPC_OPERAND_DP6, SNDSPC_OPERAND_REL      },
	{0xF3, SNDSPC_INST_BBC,    SNDSPC_OPERAND_DP7, SNDSPC_OPERAND_REL      },









//    {0xx2, SNDSPC_INST_SET1, SNDSPC_OPERAND_DP, SNDSPC_OPERAND_NONE       },
//    {0xy2, SNDSPC_INST_CLR1, SNDSPC_OPERAND_X, SNDSPC_OPERAND_NONE       },


//    {0xn1, SNDSPC_INST_TCALL, SNDSPC_OPERAND_UPAGE, SNDSPC_OPERAND_NONE       },
//    {0xx3, SNDSPC_INST_BBS, SNDSPC_OPERAND_DBP, SNDSPC_OPERAND_REL       },
//    {0xy3, SNDSPC_INST_BBC, SNDSPC_OPERAND_DBP, SNDSPC_OPERAND_REL       },



    {0x00, SNDSPC_INST_NONE, SNDSPC_OPERAND_NONE, SNDSPC_OPERAND_NONE }
};

static Char *_SNDSPC_pMnemonics[]=
{
    ""   ,

    "mov",
	"adc",
	"sbc",
	"cmp",
	"and",
	"or",
	"eor",
	"inc",
	"dec",
	"asl",
	"lsr",
	"rol",
	"ror",
	"xcn",
	"movw",
	"incw",
	"decw",
	"addw",
	"subw",
	"cmpw",
	"mul",
	"div",
	"daa",
	"das",
	"bra",
	"beq",
	"bne",
	"bcs",
	"bcc",
	"bvs",
	"bvc",
	"bmi",
	"bpl",
	"bbs",
	"bbc",
	"cbne",
	"dbnz",
	"jmp",
	"call",
	"pcall",
	"tcall",
	"brk",
	"ret",
	"reti",
	"push",
	"pop",
	"set1",
	"clr1",
	"tset1",
	"tclr1",
	"and1",
	"or1",
	"eor1",
	"not1",
	"mov1",
	"clrc",
	"setc",
	"notc",
	"clrv",
	"clrp",
	"setp",
	"ei",
	"di",
	"nop",
	"sleep",
	"stop",
};    




//
//
//


static void _SNDOpStreamOpen(SNDOpStreamT *pOpStream, Uint8 *pOpcode, Uint32 PC)
{
    pOpStream->pOpcode  = pOpcode;
    pOpStream->uStartPC = 
    pOpStream->uPC      = PC;
}

static Int32 _SNDOpStreamClose(SNDOpStreamT *pOpStream)
{
    return pOpStream->uPC - pOpStream->uStartPC;
}

static Uint8 _SNDOpStreamFetch8(SNDOpStreamT *pOpStream)
{
    Uint8 uByte;

    // fetch byte
    uByte = *pOpStream->pOpcode;

    // increment pc
    pOpStream->pOpcode++;
    pOpStream->uPC++;
    
    return uByte;
}

static Uint16 _SNDOpStreamFetch16(SNDOpStreamT *pOpStream)
{
    return _SNDOpStreamFetch8(pOpStream) | (_SNDOpStreamFetch8(pOpStream) << 8);
}






static SNDSPCInstDefT *_SNDGetInstDef(Uint8 uOpcode)
{
    SNDSPCInstDefT *pInstDef;
    
    pInstDef = _SNDSPC_InstDefs;
    
    while (pInstDef->eInst != SNDSPC_INST_NONE)
    {
        if (pInstDef->uOpcode == uOpcode)
        {
            return pInstDef;
        }
    
        pInstDef++;
    }
    return NULL;
}



static void _SNDGetOperand(SNDOpStreamT *pOpStream, Char *strOperand, SNDSPCOperandE eOperand)
{

    switch (eOperand)
    {
        case SNDSPC_OPERAND_NONE:
            strcpy(strOperand, "");
            break;
        case SNDSPC_OPERAND_A:                  // A
            sprintf(strOperand, "A");
            break;

        case SNDSPC_OPERAND_X:                  // A
            sprintf(strOperand, "X");
            break;
        case SNDSPC_OPERAND_Y:                  // A
            sprintf(strOperand, "Y");
            break;
        case SNDSPC_OPERAND_PSW:                  // A
            sprintf(strOperand, "PSW");
            break;
        case SNDSPC_OPERAND_YA:                  // A
            sprintf(strOperand, "YA");
            break;
        case SNDSPC_OPERAND_PC:                  // A
            sprintf(strOperand, "PC");
            break;
        case SNDSPC_OPERAND_SP:                  // A
            sprintf(strOperand, "SP");
            break;
        case SNDSPC_OPERAND_IMM:                  // A
            sprintf(strOperand, "#$%02X", _SNDOpStreamFetch8(pOpStream));
            break;
        case SNDSPC_OPERAND_DP:                 //  $xx
            sprintf(strOperand, "$%02X", _SNDOpStreamFetch8(pOpStream));
            break;
        case SNDSPC_OPERAND_DP_IX:              //  $xx,X
            sprintf(strOperand, "$%02X+X", _SNDOpStreamFetch8(pOpStream));
            break;
        case SNDSPC_OPERAND_ABS:                // $xxxx
            sprintf(strOperand, "$%04X", _SNDOpStreamFetch16(pOpStream));
            break;
        case SNDSPC_OPERAND_ABS_IX:             // $xxxx,X
            sprintf(strOperand, "$%04X+X", _SNDOpStreamFetch16(pOpStream));
            break;
        case SNDSPC_OPERAND_ABS_IY:             // $xxxx,Y
            sprintf(strOperand, "$%04X+Y", _SNDOpStreamFetch16(pOpStream));
            break;
        case SNDSPC_OPERAND_DP_IX_INDIRECT:     // ($xx,X)
            sprintf(strOperand, "($%02X+X)", _SNDOpStreamFetch8(pOpStream));
            break;
        case SNDSPC_OPERAND_DP_INDIRECT_IY:     // ($xx),Y
            sprintf(strOperand, "($%02X)+Y", _SNDOpStreamFetch8(pOpStream));
            break;
        case SNDSPC_OPERAND_REL:              // relative branch
            sprintf(strOperand, "$%04X", pOpStream->uPC + (Int8)_SNDOpStreamFetch8(pOpStream));
            break;
        case SNDSPC_OPERAND_IX:                  // A
            sprintf(strOperand, "(X)");
            break;
		case SNDSPC_OPERAND_IX_INC:                  // A
			sprintf(strOperand, "(X+)");
			break;
        case SNDSPC_OPERAND_IY:                  // A
            sprintf(strOperand, "(Y)");
            break;

		case SNDSPC_OPERAND_DP0:                  // A
		case SNDSPC_OPERAND_DP1:                  // A
		case SNDSPC_OPERAND_DP2:                  // A
		case SNDSPC_OPERAND_DP3:                  // A
		case SNDSPC_OPERAND_DP4:                  // A
		case SNDSPC_OPERAND_DP5:                  // A
		case SNDSPC_OPERAND_DP6:                  // A
		case SNDSPC_OPERAND_DP7:                  // A
            sprintf(strOperand, "$%02X.%d", _SNDOpStreamFetch8(pOpStream), eOperand - SNDSPC_OPERAND_DP0);
            break;

    default:
            //assert(0);
            sprintf(strOperand, "?%d?", eOperand);
    }

}


static void _SNDisasm(SNDOpStreamT *pOpStream, Char *pStr)
{
    SNDSPCInstDefT *pInstDef;
    Uint8 uOpcode;
    char *pMnemonic;
    char strOperand0[32];
    char strOperand1[32];

    // fetch instruction opcode    
    uOpcode = _SNDOpStreamFetch8(pOpStream);
    
    // get inst corresponding to opcode
    pInstDef = _SNDGetInstDef(uOpcode);
    
    if (pInstDef)
    {
        pMnemonic = _SNDSPC_pMnemonics[pInstDef->eInst];
        
		if (!pInstDef->bSwap)
		{
			_SNDGetOperand(pOpStream, strOperand0, pInstDef->eOperand0);
			_SNDGetOperand(pOpStream, strOperand1, pInstDef->eOperand1);
		} else
		{
			_SNDGetOperand(pOpStream, strOperand1, pInstDef->eOperand1);
			_SNDGetOperand(pOpStream, strOperand0, pInstDef->eOperand0);
		}
        
    } else
    {
        pMnemonic = "DB";
        sprintf(strOperand0, "$%02X", uOpcode);
        strcpy(strOperand1, "");
    }
    
    if (strlen(strOperand1) > 0)
    {
        // construct disasm string
        sprintf(pStr, "%s %s,%s", pMnemonic, strOperand0, strOperand1); 
    } else
    {
        // construct disasm string
        sprintf(pStr, "%s %s", pMnemonic, strOperand0); 
    }
}



Int32 SNSPCDisasm(Char *pStr, Uint8 *pOpcode, Uint32 PC)
{
    SNDOpStreamT OpStream;
    
    // open opcode stream
    _SNDOpStreamOpen(&OpStream, pOpcode, PC);

    _SNDisasm(&OpStream, pStr);

    // close opcode stream
    return _SNDOpStreamClose(&OpStream);
}





























