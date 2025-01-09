
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "types.h"
#include "sndisasm.h"

typedef enum
{
    SND_INST_NONE,

    SND_INST_ADC,
    SND_INST_AND,
    SND_INST_ASL,
    SND_INST_BCC,
    SND_INST_BCS,
    SND_INST_BEQ,
    SND_INST_BIT,
    SND_INST_BMI,
    SND_INST_BNE,
    SND_INST_BPL,
    SND_INST_BRA,
    SND_INST_BRK,
    SND_INST_BRL,
    SND_INST_BVC,
    SND_INST_BVS,
    SND_INST_CLC,
    SND_INST_CLD,
    SND_INST_CLI,
    SND_INST_CLV,
    SND_INST_CMP,
    SND_INST_COP,
    SND_INST_CPX,
    SND_INST_CPY,
    SND_INST_DEC,
    SND_INST_DEX,
    SND_INST_DEY,
    SND_INST_EOR,
    SND_INST_INC,
    SND_INST_INX,
    SND_INST_INY,
    SND_INST_JMP,
    SND_INST_JSR,
    SND_INST_LDA,
    SND_INST_LDX,
    SND_INST_LDY,
    SND_INST_LSR,
    SND_INST_MVN,
    SND_INST_MVP,
    SND_INST_NOP,
    SND_INST_ORA,
    SND_INST_PEA,
    SND_INST_PEI,
    SND_INST_PER,
    SND_INST_PHA,
    SND_INST_PHB,
    SND_INST_PHD,
    SND_INST_PHK,
    SND_INST_PHP,
    SND_INST_PHX,
    SND_INST_PHY,
    SND_INST_PLA,
    SND_INST_PLB,
    SND_INST_PLD,
    SND_INST_PLP,
    SND_INST_PLX,
    SND_INST_PLY,
    SND_INST_REP,
    SND_INST_ROL,
    SND_INST_ROR,
    SND_INST_RTI,
    SND_INST_RTL,
    SND_INST_RTS,
    SND_INST_SBC,
    SND_INST_SEC,
    SND_INST_SED,
    SND_INST_SEI,
    SND_INST_SEP,
    SND_INST_STA,
    SND_INST_STP,
    SND_INST_STX,
    SND_INST_STY,
    SND_INST_STZ,
    SND_INST_TAX,
    SND_INST_TAY,
    SND_INST_TCD,
    SND_INST_TCS,
    SND_INST_TDC,
    SND_INST_TRB,
    SND_INST_TSB,
    SND_INST_TSC,
    SND_INST_TSX,
    SND_INST_TXA,
    SND_INST_TXS,
    SND_INST_TXY,
    SND_INST_TYA,
    SND_INST_TYX,
    SND_INST_WAI,
    SND_INST_WDM,
    SND_INST_XBA,
    SND_INST_XCE,
    
    SND_INST_NUM

} SNDInstE;

typedef enum
{
    SND_OPERAND_NONE,
    SND_OPERAND_A,                  // A
    SND_OPERAND_PCREL,              // relative branch
    SND_OPERAND_PCRELLONG,          // long jump
    SND_OPERAND_PCREL_INDIRECT,     // 
        
    SND_OPERAND_SR      ,           // $xx,S
    SND_OPERAND_SR_IY   ,           // ($xx,S),Y

    SND_OPERAND_DP_IX_INDIRECT,     // ($xx,X)
    SND_OPERAND_DP,                 //  $xx
    SND_OPERAND_DP_IX,              //  $xx,X
    SND_OPERAND_DP_IY,              //  $xx,Y
    SND_OPERAND_DP_INDIRECT,        // ($xx)
    SND_OPERAND_DP_INDIRECT_IY,     // ($xx),Y
    SND_OPERAND_DP_INDIRECTLONG,    // [$xx]
    SND_OPERAND_DP_INDIRECTLONG_IY, // [$xx],Y

    SND_OPERAND_IMMEDIATEA,         // #$xx or #$xxxx
    SND_OPERAND_IMMEDIATEX,         // #$xx or #$xxxx
    SND_OPERAND_IMMEDIATE8,         // #$xx
	SND_OPERAND_SEPREP8,         // #$xx
    
    SND_OPERAND_ABS,                // $xxxx
    SND_OPERAND_ABS_INDIRECT,       // ($xxxx)
    SND_OPERAND_ABS_INDIRECTLONG,   // [$xxxx]
    SND_OPERAND_ABS_IX_INDIRECT,    // ($xxxx,X)
    SND_OPERAND_ABS_IX,             // $xxxx,X
    SND_OPERAND_ABS_IY,             // $xxxx,Y
    SND_OPERAND_ABSLONG,            // $xxxxxxx
    SND_OPERAND_ABSLONG_IX,         // $xxxxxxx,X

    SND_OPERAND_MV,                 // $xx,$xx

    SND_OPERAND_NUM
} SNDOperandE;



typedef struct SNDOpStream_T
{
    Uint32  uStartPC;
    Uint32  uPC;
    Uint8   *pOpcode;
} SNDOpStreamT;

typedef struct
{
    Uint8       uOpcode;    // opcode
    SNDInstE    eInst;      // instruction type
    SNDOperandE eOperand;   // operand type
} SNDInstDefT;


typedef struct 
{
    SNDInstE eInst;
    char *pName;
} SNDMnemonicT;


//
//
//

//static Bool _SND_bInitialized = FALSE;
//static SNDInstDefT *_SND_InstMatrix[0x100];

static SNDInstDefT _SND_InstDefs[]=
{
    {0x61, SND_INST_ADC, SND_OPERAND_DP_IX_INDIRECT     },
    {0x63, SND_INST_ADC, SND_OPERAND_SR                 },
    {0x65, SND_INST_ADC, SND_OPERAND_DP                 },
    {0x67, SND_INST_ADC, SND_OPERAND_DP_INDIRECTLONG    },
    {0x69, SND_INST_ADC, SND_OPERAND_IMMEDIATEA          },
    {0x6D, SND_INST_ADC, SND_OPERAND_ABS                },
    {0x6F, SND_INST_ADC, SND_OPERAND_ABSLONG            },
    {0x71, SND_INST_ADC, SND_OPERAND_DP_INDIRECT_IY     },
    {0x72, SND_INST_ADC, SND_OPERAND_DP_INDIRECT        },
    {0x73, SND_INST_ADC, SND_OPERAND_SR_IY              },
    {0x75, SND_INST_ADC, SND_OPERAND_DP_IX              },
    {0x77, SND_INST_ADC, SND_OPERAND_DP_INDIRECTLONG_IY },
    {0x79, SND_INST_ADC, SND_OPERAND_ABS_IY             },
    {0x7D, SND_INST_ADC, SND_OPERAND_ABS_IX             },
    {0x7F, SND_INST_ADC, SND_OPERAND_ABSLONG_IX         },

    {0xE1, SND_INST_SBC, SND_OPERAND_DP_IX_INDIRECT     },
    {0xE3, SND_INST_SBC, SND_OPERAND_SR                 },
    {0xE5, SND_INST_SBC, SND_OPERAND_DP                 },
    {0xE7, SND_INST_SBC, SND_OPERAND_DP_INDIRECTLONG    },
    {0xE9, SND_INST_SBC, SND_OPERAND_IMMEDIATEA          },
    {0xED, SND_INST_SBC, SND_OPERAND_ABS                },
    {0xEF, SND_INST_SBC, SND_OPERAND_ABSLONG            },
    {0xF1, SND_INST_SBC, SND_OPERAND_DP_INDIRECT_IY     },
    {0xF2, SND_INST_SBC, SND_OPERAND_DP_INDIRECT        },
    {0xF3, SND_INST_SBC, SND_OPERAND_SR_IY              },
    {0xF5, SND_INST_SBC, SND_OPERAND_DP_IX              },
    {0xF7, SND_INST_SBC, SND_OPERAND_DP_INDIRECTLONG_IY },
    {0xF9, SND_INST_SBC, SND_OPERAND_ABS_IY             },
    {0xFD, SND_INST_SBC, SND_OPERAND_ABS_IX             },
    {0xFF, SND_INST_SBC, SND_OPERAND_ABSLONG_IX         },

    {0x21, SND_INST_AND, SND_OPERAND_DP_IX_INDIRECT     },
    {0x23, SND_INST_AND, SND_OPERAND_SR                 },
    {0x25, SND_INST_AND, SND_OPERAND_DP                 },
    {0x27, SND_INST_AND, SND_OPERAND_DP_INDIRECTLONG    },
    {0x29, SND_INST_AND, SND_OPERAND_IMMEDIATEA          },
    {0x2D, SND_INST_AND, SND_OPERAND_ABS                },
    {0x2F, SND_INST_AND, SND_OPERAND_ABSLONG            },
    {0x31, SND_INST_AND, SND_OPERAND_DP_INDIRECT_IY     },
    {0x32, SND_INST_AND, SND_OPERAND_DP_INDIRECT        },
    {0x33, SND_INST_AND, SND_OPERAND_SR_IY              },
    {0x35, SND_INST_AND, SND_OPERAND_DP_IX              },
    {0x37, SND_INST_AND, SND_OPERAND_DP_INDIRECTLONG_IY },
    {0x39, SND_INST_AND, SND_OPERAND_ABS_IY             },
    {0x3D, SND_INST_AND, SND_OPERAND_ABS_IX             },
    {0x3F, SND_INST_AND, SND_OPERAND_ABSLONG_IX         },

    {0x41, SND_INST_EOR, SND_OPERAND_DP_IX_INDIRECT     },
    {0x43, SND_INST_EOR, SND_OPERAND_SR                 },
    {0x45, SND_INST_EOR, SND_OPERAND_DP                 },
    {0x47, SND_INST_EOR, SND_OPERAND_DP_INDIRECTLONG    },
    {0x49, SND_INST_EOR, SND_OPERAND_IMMEDIATEA          },
    {0x4D, SND_INST_EOR, SND_OPERAND_ABS                },
    {0x4F, SND_INST_EOR, SND_OPERAND_ABSLONG            },
    {0x51, SND_INST_EOR, SND_OPERAND_DP_INDIRECT_IY     },
    {0x52, SND_INST_EOR, SND_OPERAND_DP_INDIRECT        },
    {0x53, SND_INST_EOR, SND_OPERAND_SR_IY              },
    {0x55, SND_INST_EOR, SND_OPERAND_DP_IX              },
    {0x57, SND_INST_EOR, SND_OPERAND_DP_INDIRECTLONG_IY },
    {0x59, SND_INST_EOR, SND_OPERAND_ABS_IY             },
    {0x5D, SND_INST_EOR, SND_OPERAND_ABS_IX             },
    {0x5F, SND_INST_EOR, SND_OPERAND_ABSLONG_IX         },

    {0x01, SND_INST_ORA, SND_OPERAND_DP_IX_INDIRECT     },
    {0x03, SND_INST_ORA, SND_OPERAND_SR                 },
    {0x05, SND_INST_ORA, SND_OPERAND_DP                 },
    {0x07, SND_INST_ORA, SND_OPERAND_DP_INDIRECTLONG    },
    {0x09, SND_INST_ORA, SND_OPERAND_IMMEDIATEA          },
    {0x0D, SND_INST_ORA, SND_OPERAND_ABS                },
    {0x0F, SND_INST_ORA, SND_OPERAND_ABSLONG            },
    {0x11, SND_INST_ORA, SND_OPERAND_DP_INDIRECT_IY     },
    {0x12, SND_INST_ORA, SND_OPERAND_DP_INDIRECT        },
    {0x13, SND_INST_ORA, SND_OPERAND_SR_IY              },
    {0x15, SND_INST_ORA, SND_OPERAND_DP_IX              },
    {0x17, SND_INST_ORA, SND_OPERAND_DP_INDIRECTLONG_IY },
    {0x19, SND_INST_ORA, SND_OPERAND_ABS_IY             },
    {0x1D, SND_INST_ORA, SND_OPERAND_ABS_IX             },
    {0x1F, SND_INST_ORA, SND_OPERAND_ABSLONG_IX         },

    {0xC1, SND_INST_CMP, SND_OPERAND_DP_IX_INDIRECT     },
    {0xC3, SND_INST_CMP, SND_OPERAND_SR                 },
    {0xC5, SND_INST_CMP, SND_OPERAND_DP                 },
    {0xC7, SND_INST_CMP, SND_OPERAND_DP_INDIRECTLONG    },
    {0xC9, SND_INST_CMP, SND_OPERAND_IMMEDIATEA          },
    {0xCD, SND_INST_CMP, SND_OPERAND_ABS                },
    {0xCF, SND_INST_CMP, SND_OPERAND_ABSLONG            },
    {0xD1, SND_INST_CMP, SND_OPERAND_DP_INDIRECT_IY     },
    {0xD2, SND_INST_CMP, SND_OPERAND_DP_INDIRECT        },
    {0xD3, SND_INST_CMP, SND_OPERAND_SR_IY              },
    {0xD5, SND_INST_CMP, SND_OPERAND_DP_IX              },
    {0xD7, SND_INST_CMP, SND_OPERAND_DP_INDIRECTLONG_IY },
    {0xD9, SND_INST_CMP, SND_OPERAND_ABS_IY             },
    {0xDD, SND_INST_CMP, SND_OPERAND_ABS_IX             },
    {0xDF, SND_INST_CMP, SND_OPERAND_ABSLONG_IX         },



    {0xA1, SND_INST_LDA, SND_OPERAND_DP_IX_INDIRECT     },
    {0xA3, SND_INST_LDA, SND_OPERAND_SR                 },
    {0xA5, SND_INST_LDA, SND_OPERAND_DP                 },
    {0xA7, SND_INST_LDA, SND_OPERAND_DP_INDIRECTLONG    },
    {0xA9, SND_INST_LDA, SND_OPERAND_IMMEDIATEA          },
    {0xAD, SND_INST_LDA, SND_OPERAND_ABS                },
    {0xAF, SND_INST_LDA, SND_OPERAND_ABSLONG            },
    {0xB1, SND_INST_LDA, SND_OPERAND_DP_INDIRECT_IY     },
    {0xB2, SND_INST_LDA, SND_OPERAND_DP_INDIRECT        },
    {0xB3, SND_INST_LDA, SND_OPERAND_SR_IY              },
    {0xB5, SND_INST_LDA, SND_OPERAND_DP_IX              },
    {0xB7, SND_INST_LDA, SND_OPERAND_DP_INDIRECTLONG_IY },
    {0xB9, SND_INST_LDA, SND_OPERAND_ABS_IY             },
    {0xBD, SND_INST_LDA, SND_OPERAND_ABS_IX             },
    {0xBF, SND_INST_LDA, SND_OPERAND_ABSLONG_IX         },

    {0x81, SND_INST_STA, SND_OPERAND_DP_IX_INDIRECT     },
    {0x83, SND_INST_STA, SND_OPERAND_SR                 },
    {0x85, SND_INST_STA, SND_OPERAND_DP                 },
    {0x87, SND_INST_STA, SND_OPERAND_DP_INDIRECTLONG    },
    ///{0x89, SND_INST_STA, SND_OPERAND_IMMEDIATEA          },
    {0x8D, SND_INST_STA, SND_OPERAND_ABS                },
    {0x8F, SND_INST_STA, SND_OPERAND_ABSLONG            },
    {0x91, SND_INST_STA, SND_OPERAND_DP_INDIRECT_IY     },
    {0x92, SND_INST_STA, SND_OPERAND_DP_INDIRECT        },
    {0x93, SND_INST_STA, SND_OPERAND_SR_IY              },
    {0x95, SND_INST_STA, SND_OPERAND_DP_IX              },
    {0x97, SND_INST_STA, SND_OPERAND_DP_INDIRECTLONG_IY },
    {0x99, SND_INST_STA, SND_OPERAND_ABS_IY             },
    {0x9D, SND_INST_STA, SND_OPERAND_ABS_IX             },
    {0x9F, SND_INST_STA, SND_OPERAND_ABSLONG_IX         },

    {0x06, SND_INST_ASL, SND_OPERAND_DP                 },
    {0x0A, SND_INST_ASL, SND_OPERAND_A                  },
    {0x0E, SND_INST_ASL, SND_OPERAND_ABS                },
    {0x16, SND_INST_ASL, SND_OPERAND_DP_IX              },
    {0x1E, SND_INST_ASL, SND_OPERAND_ABS_IX             },

    {0x46, SND_INST_LSR, SND_OPERAND_DP                 },
    {0x4A, SND_INST_LSR, SND_OPERAND_A                  },
    {0x4E, SND_INST_LSR, SND_OPERAND_ABS                },
    {0x56, SND_INST_LSR, SND_OPERAND_DP_IX              },
    {0x5E, SND_INST_LSR, SND_OPERAND_ABS_IX             },

    {0x26, SND_INST_ROL, SND_OPERAND_DP                 },
    {0x2A, SND_INST_ROL, SND_OPERAND_A                  },
    {0x2E, SND_INST_ROL, SND_OPERAND_ABS                },
    {0x36, SND_INST_ROL, SND_OPERAND_DP_IX              },
    {0x3E, SND_INST_ROL, SND_OPERAND_ABS_IX             },

    {0x66, SND_INST_ROR, SND_OPERAND_DP                 },
    {0x6A, SND_INST_ROR, SND_OPERAND_A                  },
    {0x6E, SND_INST_ROR, SND_OPERAND_ABS                },
    {0x76, SND_INST_ROR, SND_OPERAND_DP_IX              },
    {0x7E, SND_INST_ROR, SND_OPERAND_ABS_IX             },

    {0x3A, SND_INST_DEC, SND_OPERAND_A                  },
    {0xC6, SND_INST_DEC, SND_OPERAND_DP                 },
    {0xCE, SND_INST_DEC, SND_OPERAND_ABS                },
    {0xD6, SND_INST_DEC, SND_OPERAND_DP_IX              },
    {0xDE, SND_INST_DEC, SND_OPERAND_ABS_IX             },

    {0x1A, SND_INST_INC, SND_OPERAND_A                  },
    {0xE6, SND_INST_INC, SND_OPERAND_DP                 },
    {0xEE, SND_INST_INC, SND_OPERAND_ABS                },
    {0xF6, SND_INST_INC, SND_OPERAND_DP_IX              },
    {0xFE, SND_INST_INC, SND_OPERAND_ABS_IX             },

    {0xCA, SND_INST_DEX, SND_OPERAND_NONE               },
    {0x88, SND_INST_DEY, SND_OPERAND_NONE               },

    {0xE8, SND_INST_INX, SND_OPERAND_NONE               },
    {0xC8, SND_INST_INY, SND_OPERAND_NONE               },

    {0x24, SND_INST_BIT, SND_OPERAND_DP                 },
    {0x2C, SND_INST_BIT, SND_OPERAND_ABS                },
    {0x34, SND_INST_BIT, SND_OPERAND_DP_IX              },
    {0x3C, SND_INST_BIT, SND_OPERAND_ABS_IX             },
    {0x89, SND_INST_BIT, SND_OPERAND_IMMEDIATEA          },

    {0x90, SND_INST_BCC, SND_OPERAND_PCREL              },
    {0xB0, SND_INST_BCS, SND_OPERAND_PCREL              },
    {0xF0, SND_INST_BEQ, SND_OPERAND_PCREL              },
    {0x30, SND_INST_BMI, SND_OPERAND_PCREL              },
    {0xD0, SND_INST_BNE, SND_OPERAND_PCREL              },
    {0x10, SND_INST_BPL, SND_OPERAND_PCREL              },
    {0x80, SND_INST_BRA, SND_OPERAND_PCREL              },
    {0x50, SND_INST_BVC, SND_OPERAND_PCREL              },
    {0x70, SND_INST_BVS, SND_OPERAND_PCREL              },

    {0x82, SND_INST_BRL, SND_OPERAND_PCRELLONG          },

    {0x00, SND_INST_BRK, SND_OPERAND_IMMEDIATE8         },

    {0x18, SND_INST_CLC, SND_OPERAND_NONE               },
    {0xD8, SND_INST_CLD, SND_OPERAND_NONE               },
    {0x58, SND_INST_CLI, SND_OPERAND_NONE               },
    {0xB8, SND_INST_CLV, SND_OPERAND_NONE               },

    {0x02, SND_INST_COP, SND_OPERAND_IMMEDIATE8         },

    {0xE0, SND_INST_CPX, SND_OPERAND_IMMEDIATEX         },
    {0xE4, SND_INST_CPX, SND_OPERAND_DP                 },
    {0xEC, SND_INST_CPX, SND_OPERAND_ABS                },

    {0xC0, SND_INST_CPY, SND_OPERAND_IMMEDIATEX         },
    {0xC4, SND_INST_CPY, SND_OPERAND_DP                 },
    {0xCC, SND_INST_CPY, SND_OPERAND_ABS                },


    {0x4C, SND_INST_JMP, SND_OPERAND_ABS                },
    {0x5C, SND_INST_JMP, SND_OPERAND_ABSLONG            },
    {0x6C, SND_INST_JMP, SND_OPERAND_ABS_INDIRECT       },
    {0x7C, SND_INST_JMP, SND_OPERAND_ABS_IX_INDIRECT    },
    {0xDC, SND_INST_JMP, SND_OPERAND_ABS_INDIRECTLONG   },

    {0x20, SND_INST_JSR, SND_OPERAND_ABS                },
    {0x22, SND_INST_JSR, SND_OPERAND_ABSLONG            },
    {0xFC, SND_INST_JSR, SND_OPERAND_ABS_IX_INDIRECT    },


    {0xA2, SND_INST_LDX, SND_OPERAND_IMMEDIATEX         },
    {0xA6, SND_INST_LDX, SND_OPERAND_DP                 },
    {0xAE, SND_INST_LDX, SND_OPERAND_ABS                },
    {0xB6, SND_INST_LDX, SND_OPERAND_DP_IY              },
    {0xBE, SND_INST_LDX, SND_OPERAND_ABS_IY             },

    {0xA0, SND_INST_LDY, SND_OPERAND_IMMEDIATEX         },
    {0xA4, SND_INST_LDY, SND_OPERAND_DP                 },
    {0xAC, SND_INST_LDY, SND_OPERAND_ABS                },
    {0xB4, SND_INST_LDY, SND_OPERAND_DP_IX              },
    {0xBC, SND_INST_LDY, SND_OPERAND_ABS_IX             },

    {0x86, SND_INST_STX, SND_OPERAND_DP                 },
    {0x8E, SND_INST_STX, SND_OPERAND_ABS                },
    {0x96, SND_INST_STX, SND_OPERAND_DP_IY              },

    {0x84, SND_INST_STY, SND_OPERAND_DP                 },
    {0x8C, SND_INST_STY, SND_OPERAND_ABS                },
    {0x94, SND_INST_STY, SND_OPERAND_DP_IX              },

    {0x64, SND_INST_STZ, SND_OPERAND_DP                 },
    {0x74, SND_INST_STZ, SND_OPERAND_DP_IX              },
    {0x9C, SND_INST_STZ, SND_OPERAND_ABS                },
    {0x9E, SND_INST_STZ, SND_OPERAND_ABS_IX             },

    {0xEA, SND_INST_NOP, SND_OPERAND_NONE               },

    {0xF4, SND_INST_PEA, SND_OPERAND_ABS                },
    {0xD4, SND_INST_PEI, SND_OPERAND_DP_INDIRECT        },
    {0x62, SND_INST_PER, SND_OPERAND_PCREL_INDIRECT     },
    {0x48, SND_INST_PHA, SND_OPERAND_NONE               },
    {0x8B, SND_INST_PHB, SND_OPERAND_NONE               },
    {0x0B, SND_INST_PHD, SND_OPERAND_NONE               },
    {0x4B, SND_INST_PHK, SND_OPERAND_NONE               },
    {0x08, SND_INST_PHP, SND_OPERAND_NONE               },
    {0xDA, SND_INST_PHX, SND_OPERAND_NONE               },
    {0x5A, SND_INST_PHY, SND_OPERAND_NONE               },
    {0x68, SND_INST_PLA, SND_OPERAND_NONE               },
    {0xAB, SND_INST_PLB, SND_OPERAND_NONE               },
    {0x2B, SND_INST_PLD, SND_OPERAND_NONE               },
    {0x28, SND_INST_PLP, SND_OPERAND_NONE               },
    {0xFA, SND_INST_PLX, SND_OPERAND_NONE               },
    {0x7A, SND_INST_PLY, SND_OPERAND_NONE               },

    {0xC2, SND_INST_REP, SND_OPERAND_SEPREP8         },

    {0x40, SND_INST_RTI, SND_OPERAND_NONE               },
    {0x6B, SND_INST_RTL, SND_OPERAND_NONE               },
    {0x60, SND_INST_RTS, SND_OPERAND_NONE               },

    {0x38, SND_INST_SEC, SND_OPERAND_NONE               },
    {0xF8, SND_INST_SED, SND_OPERAND_NONE               },
    {0x78, SND_INST_SEI, SND_OPERAND_NONE               },
    {0xE2, SND_INST_SEP, SND_OPERAND_SEPREP8         },

    {0xDB, SND_INST_STP, SND_OPERAND_NONE               },

    {0xAA, SND_INST_TAX, SND_OPERAND_NONE               },
    {0xA8, SND_INST_TAY, SND_OPERAND_NONE               },
    {0x5B, SND_INST_TCD, SND_OPERAND_NONE               },
    {0x1B, SND_INST_TCS, SND_OPERAND_NONE               },
    {0x7B, SND_INST_TDC, SND_OPERAND_NONE               },

    {0x14, SND_INST_TRB, SND_OPERAND_DP                 },
    {0x1C, SND_INST_TRB, SND_OPERAND_ABS                },
    {0x04, SND_INST_TSB, SND_OPERAND_DP                 },
    {0x0C, SND_INST_TSB, SND_OPERAND_ABS                },

    {0x3B, SND_INST_TSC, SND_OPERAND_NONE               },

    {0xBA, SND_INST_TSX, SND_OPERAND_NONE               },
    {0x8A, SND_INST_TXA, SND_OPERAND_NONE               },
    {0x9A, SND_INST_TXS, SND_OPERAND_NONE               },
    {0x9B, SND_INST_TXY, SND_OPERAND_NONE               },
    {0x98, SND_INST_TYA, SND_OPERAND_NONE               },
    {0xBB, SND_INST_TYX, SND_OPERAND_NONE               },

    {0xCB, SND_INST_WAI, SND_OPERAND_NONE               },
    {0x42, SND_INST_WDM, SND_OPERAND_NONE               },
    {0xEB, SND_INST_XBA, SND_OPERAND_NONE               },
    {0xFB, SND_INST_XCE, SND_OPERAND_NONE               },

    {0x54, SND_INST_MVN, SND_OPERAND_MV                },
	{0x44, SND_INST_MVP, SND_OPERAND_MV                },

    {0x00, SND_INST_NONE, SND_OPERAND_NONE              }
};

static Char *_SND_pMnemonics[]=
{
    ""   ,
    "adc", // SND_INST_ADC  
    "and", // SND_INST_AND  
    "asl", // SND_INST_ASL  
    "bcc", // SND_INST_BCC  
    "bcs", // SND_INST_BCS  
    "beq", // SND_INST_BEQ  
    "bit", // SND_INST_BIT  
    "bmi", // SND_INST_BMI  
    "bne", // SND_INST_BNE  
    "bpl", // SND_INST_BPL  
    "bra", // SND_INST_BRA  
    "brk", // SND_INST_BRK  
    "brl", // SND_INST_BRL  
    "bvc", // SND_INST_BVC  
    "bvs", // SND_INST_BVS  
    "clc", // SND_INST_CLC  
    "cld", // SND_INST_CLD  
    "cli", // SND_INST_CLI  
    "clv", // SND_INST_CLV  
    "cmp", // SND_INST_CMP  
    "cop", // SND_INST_COP  
    "cpx", // SND_INST_CPX  
    "cpy", // SND_INST_CPY  
    "dec", // SND_INST_DEC  
    "dex", // SND_INST_DEX  
    "dey", // SND_INST_DEY  
    "eor", // SND_INST_EOR  
    "inc", // SND_INST_INC  
    "inx", // SND_INST_INX  
    "iny", // SND_INST_INY  
    "jmp", // SND_INST_JMP  
    "jsr", // SND_INST_JSR  
    "lda", // SND_INST_LDA  
    "ldx", // SND_INST_LDX  
    "ldy", // SND_INST_LDY  
    "lsr", // SND_INST_LSR  
    "mvn", // SND_INST_MVN  
    "mvp", // SND_INST_MVP
    "nop", // SND_INST_NOP  
    "ora", // SND_INST_ORA  
    "pea", // SND_INST_PEA  
    "pei", // SND_INST_PEI  
    "per", // SND_INST_PER  
    "pha", // SND_INST_PHA  
    "phb", // SND_INST_PHB  
    "phd", // SND_INST_PHD  
    "phk", // SND_INST_PHK  
    "php", // SND_INST_PHP  
    "phx", // SND_INST_PHX  
    "phy", // SND_INST_PHY  
    "pla", // SND_INST_PLA  
    "plb", // SND_INST_PLB  
    "pld", // SND_INST_PLD  
    "plp", // SND_INST_PLP  
    "plx", // SND_INST_PLX  
    "ply", // SND_INST_PLY  
    "rep", // SND_INST_REP  
    "rol", // SND_INST_ROL  
    "ror", // SND_INST_ROR  
    "rti", // SND_INST_RTI  
    "rtl", // SND_INST_RTL  
    "rts", // SND_INST_RTS  
    "sbc", // SND_INST_SBC  
    "sec", // SND_INST_SEC  
    "sed", // SND_INST_SED  
    "sei", // SND_INST_SEI  
    "sep", // SND_INST_SEP  
    "sta", // SND_INST_STA  
    "stp", // SND_INST_STP  
    "stx", // SND_INST_STX  
    "sty", // SND_INST_STY  
    "stz", // SND_INST_STZ  
    "tax", // SND_INST_TAX  
    "tay", // SND_INST_TAY  
    "tcd", // SND_INST_TCD  
    "tcs", // SND_INST_TCS  
    "tdc", // SND_INST_TDC  
    "trb", // SND_INST_TRB  
    "tsb", // SND_INST_TSB  
    "tsc", // SND_INST_TSC  
    "tsx", // SND_INST_TSX  
    "txa", // SND_INST_TXA  
    "txs", // SND_INST_TXS  
    "txy", // SND_INST_TXY  
    "tya", // SND_INST_TYA  
    "tyx", // SND_INST_TYX  
    "wai", // SND_INST_WAI  
    "wdm", // SND_INST_WDM  
    "xba", // SND_INST_XBA  
    "xce", // SND_INST_XCE  
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


static Uint32 _SNDOpStreamFetch24(SNDOpStreamT *pOpStream)
{
    return _SNDOpStreamFetch8(pOpStream) | (_SNDOpStreamFetch8(pOpStream) << 8) | (_SNDOpStreamFetch8(pOpStream) << 16);
}




static SNDInstDefT *_SNDGetInstDef(Uint8 uOpcode)
{
    SNDInstDefT *pInstDef;
    
    pInstDef = _SND_InstDefs;
    
    while (pInstDef->eInst != SND_INST_NONE)
    {
        if (pInstDef->uOpcode == uOpcode)
        {
            return pInstDef;
        }
    
        pInstDef++;
    }
    return NULL;
}




static void _SNDisasm(SNDOpStreamT *pOpStream, Char *pStr, Uint8 *pFlags)
{
    SNDInstDefT *pInstDef;
    Uint8 uOpcode;
    char *pMnemonic;
    char strOperand[32];

    // fetch instruction opcode    
    uOpcode = _SNDOpStreamFetch8(pOpStream);
    
    // get inst corresponding to opcode
    pInstDef = _SNDGetInstDef(uOpcode);
    
    if (pInstDef)
    {
        Uint8 uImm8 = 0;
        pMnemonic = _SND_pMnemonics[pInstDef->eInst];
        
        switch (pInstDef->eInst)
        {
            case SND_INST_SEP:
                uImm8 = _SNDOpStreamFetch8(pOpStream);
                *pFlags |= uImm8;
                break;
            case SND_INST_REP:
                uImm8 = _SNDOpStreamFetch8(pOpStream);
                *pFlags &= ~uImm8;
                break;
            default:
                break;                
        }

        switch (pInstDef->eOperand)
        {
            case SND_OPERAND_NONE:
                strcpy(strOperand, "");
                break;
            case SND_OPERAND_A:                  // A
                sprintf(strOperand, "A");
                break;
            case SND_OPERAND_PCREL:              // relative branch
                sprintf(strOperand, "$%06X", pOpStream->uPC + (Int8)_SNDOpStreamFetch8(pOpStream));
                break;
            case SND_OPERAND_PCRELLONG:          // long jump
                sprintf(strOperand, "+$%04X", (Int16)_SNDOpStreamFetch16(pOpStream));
                break;
            case SND_OPERAND_PCREL_INDIRECT:     // 
                sprintf(strOperand, "($%04X)", (pOpStream->uPC + _SNDOpStreamFetch16(pOpStream) + 2) & 0xFFFF);
                break;
            case SND_OPERAND_SR:                // $xx,S
                sprintf(strOperand, "$%02X,S", _SNDOpStreamFetch8(pOpStream));
                break;
            case SND_OPERAND_SR_IY:              // ($xx,S),Y
                sprintf(strOperand, "($%02X,S),Y", _SNDOpStreamFetch8(pOpStream));
                break;
            case SND_OPERAND_DP_IX_INDIRECT:     // ($xx,X)
                sprintf(strOperand, "($%02X,X)", _SNDOpStreamFetch8(pOpStream));
                break;
            case SND_OPERAND_DP:                 //  $xx
                sprintf(strOperand, "$%02X", _SNDOpStreamFetch8(pOpStream));
                break;
            case SND_OPERAND_DP_IX:              //  $xx,X
                sprintf(strOperand, "$%02X,X", _SNDOpStreamFetch8(pOpStream));
                break;
            case SND_OPERAND_DP_IY:              //  $xx,Y
                sprintf(strOperand, "$%02X,Y", _SNDOpStreamFetch8(pOpStream));
                break;
            case SND_OPERAND_DP_INDIRECT:        // ($xx)
                sprintf(strOperand, "($%02X)", _SNDOpStreamFetch8(pOpStream));
                break;
            case SND_OPERAND_DP_INDIRECT_IY:     // ($xx),Y
                sprintf(strOperand, "($%02X),Y", _SNDOpStreamFetch8(pOpStream));
                break;
            case SND_OPERAND_DP_INDIRECTLONG:    // [$xx]
                sprintf(strOperand, "[$%02X]", _SNDOpStreamFetch8(pOpStream));
                break;
            case SND_OPERAND_DP_INDIRECTLONG_IY: // [$xx],Y
                sprintf(strOperand, "[$%02X],Y", _SNDOpStreamFetch8(pOpStream));
                break;
            case SND_OPERAND_IMMEDIATEA:          // #$xx
                if (*pFlags & 0x20)
                {
                    sprintf(strOperand, "#$%02X", _SNDOpStreamFetch8(pOpStream));
                } else
                {
                    sprintf(strOperand, "#$%04X", _SNDOpStreamFetch16(pOpStream));
                }
                break;

            case SND_OPERAND_IMMEDIATEX:          // #$xx
                if (*pFlags & 0x10)
                {
                    sprintf(strOperand, "#$%02X", _SNDOpStreamFetch8(pOpStream));
                } else
                {
                    sprintf(strOperand, "#$%04X", _SNDOpStreamFetch16(pOpStream));
                }
                break;

			case SND_OPERAND_SEPREP8:          // #$xx
				sprintf(strOperand, "#$%02X", uImm8);
				break;

            case SND_OPERAND_IMMEDIATE8:          // #$xx
                sprintf(strOperand, "#$%02X", _SNDOpStreamFetch8(pOpStream));
                break;

            case SND_OPERAND_MV:    // $xx, $xx
				{	
					Uint8 uDest= _SNDOpStreamFetch8(pOpStream);
					Uint8 uSrc = _SNDOpStreamFetch8(pOpStream);
					sprintf(strOperand, "$%02X,$%02X", uSrc, uDest);
				}
                break;

            case SND_OPERAND_ABS:                // $xxxx
                sprintf(strOperand, "$%04X", _SNDOpStreamFetch16(pOpStream));
                break;
            case SND_OPERAND_ABS_INDIRECT:       // ($xxxx)
                sprintf(strOperand, "($%04X)", _SNDOpStreamFetch16(pOpStream));
                break;
            case SND_OPERAND_ABS_INDIRECTLONG:   // [$xxxx]
                sprintf(strOperand, "[$%04X]", _SNDOpStreamFetch16(pOpStream));
                break;
            case SND_OPERAND_ABS_IX_INDIRECT:    // ($xxxx,X)
                sprintf(strOperand, "($%04X,X)", _SNDOpStreamFetch16(pOpStream));
                break;
            case SND_OPERAND_ABS_IX:             // $xxxx,X
                sprintf(strOperand, "$%04X,X", _SNDOpStreamFetch16(pOpStream));
                break;
            case SND_OPERAND_ABS_IY:             // $xxxx,Y
                sprintf(strOperand, "$%04X,Y", _SNDOpStreamFetch16(pOpStream));
                break;
            case SND_OPERAND_ABSLONG:            // $xxxxxxx
                sprintf(strOperand, "$%06X", _SNDOpStreamFetch24(pOpStream));
                break;
            case SND_OPERAND_ABSLONG_IX:         // $xxxxxxx,X
                sprintf(strOperand, "$%06X,X", _SNDOpStreamFetch24(pOpStream));
                break;

        default:
                strcpy(strOperand, "");
        }
    } else
    {
        pMnemonic = "DB";
        sprintf(strOperand, "$%02X", uOpcode);
    }

    // construct disasm string
    sprintf(pStr, "%s %s", pMnemonic, strOperand); 
}



Int32 SNDisasm(Char *pStr, Uint8 *pOpcode, Uint32 PC, Uint8 *pFlags)
{
    SNDOpStreamT OpStream;
    
    // open opcode stream
    _SNDOpStreamOpen(&OpStream, pOpcode, PC);

    _SNDisasm(&OpStream, pStr, pFlags);

    // close opcode stream
    return _SNDOpStreamClose(&OpStream);
}





























