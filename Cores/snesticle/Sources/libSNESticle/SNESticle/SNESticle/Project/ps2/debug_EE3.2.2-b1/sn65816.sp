# 1 "../../Source/ps2/sn65816.S"
# 1 "<built-in>"
# 1 "<command line>"
# 1 "../../Source/ps2/sn65816.S"


# 1 "../../Source/common/sncpudefs.h" 1
# 4 "../../Source/ps2/sn65816.S" 2
# 1 "../../Source/ps2/ps2reg.h" 1
# 5 "../../Source/ps2/sn65816.S" 2


                .file 1 "sn65816.S"
        .text
        .p2align 3
        .globl SNCPUExecute_ASM
        .globl _SNCPU_OpTable

                .set noreorder
# 495 "../../Source/ps2/sn65816.S"
_SNCPU_Write8:
                srl $8,$17,(13)

                beq $8,$0,_SNCPU_Write8ZeroBank
        sll $8,$8,4

        addu $8,$8,$16

        lh $10,(52 +12)($8)
        lw $9,(52 +0)($8)

        bgez $10,_SNCPU_Write8Trap
        andi $10,$10,0xFF

        addu $8,$9,$17
                subu $2, $2, $10

                jr $31
        sb $24, 0($8)


_SNCPU_Write8ZeroBank:
        lw $8,(52 +0)($16)
        addiu $2,$2,-(8)
        addu $8,$8,$17
                jr $31
        sb $24, 0($8)

_SNCPU_Write8Trap:
        lw $9,(52 +8)($8)
                subu $2, $2, $10


                sw $31,0x54($29)
                sw $24,0x78($29)
        sw $11, 0x60($29) ; sw $25, 0x64($29) ; sw $15, 0x68($29) ; sw $30, 0x6C($29) ; sw $3, 0x70($29) ; sh $4, 0($16) ; sh $5, 2($16) ; sh $6, 4($16) ; sh $7, 6($16) ; sh $13, 10($16) ; sw $14, 16($16) ; sb $12, 8($16) ; sw $2, 20($16)


                move $4, $16
                move $5, $17
                jalr $9
        andi $6,$24, 0xFF


                lw $31,0x54($29)
                lw $24,0x78($29)
        lw $11, 0x60($29) ; lwu $25, 0x64($29) ; lwu $15, 0x68($29) ; lwu $30, 0x6C($29) ; lwu $3, 0x70($29) ; lhu $4, 0($16) ; lhu $5, 2($16) ; lhu $6, 4($16) ; lhu $7, 6($16) ; lhu $13, 10($16) ; lwu $14, 16($16) ; lbu $12, 8($16) ; lw $2,20($16)

                jr $31
        nop
# 563 "../../Source/ps2/sn65816.S"
_SNCPU_Write16_Slow:
                sw $31, 0x50($29)

                jal _SNCPU_Write8
        addiu $17,$17,0

        srl $24,$24,8
                jal _SNCPU_Write8
        addiu $17,$17,1

                lw $31, 0x50($29)
        addiu $17,$17,-1

        jr $31
        nop

_SNCPU_Write16:

_SNCPU_Write16_Fast:
        addiu $9,$17,1
                srl $10,$17,(13)

        srl $9,$9,(13)
        sll $8,$10,4

                bne $9,$10,_SNCPU_Write16_Slow
        addu $8,$8,$16

        lh $10,(52 +12)($8)
        lw $9,(52 +0)($8)

        bgez $10,_SNCPU_Write16Trap
        andi $10,$10,0xFF

        addu $8,$9,$17
        srl $9,$24,8
                subu $2, $2, $10

        sb $24, 0($8)
                subu $2, $2, $10

                jr $31
        sb $9, 1($8)


_SNCPU_Write16Trap:
        lw $9,(52 +8)($8)
                subu $2, $2, $10
                subu $2, $2, $10


                sw $31,0x54($29)
                sw $24,0x78($29)
        sw $11, 0x60($29) ; sw $25, 0x64($29) ; sw $15, 0x68($29) ; sw $30, 0x6C($29) ; sw $3, 0x70($29) ; sh $4, 0($16) ; sh $5, 2($16) ; sh $6, 4($16) ; sh $7, 6($16) ; sh $13, 10($16) ; sw $14, 16($16) ; sb $12, 8($16) ; sw $2, 20($16)

        sw $9, 0x5C($29)


                move $4, $16
                addiu $5, $17, 0
                jalr $9
        andi $6,$24, 0xFF

                lw $24,0x78($29)
        lw $9, 0x5C($29)



                move $4, $16
                addiu $5, $17, 1
        srl $6,$24,8
                jalr $9
        andi $6,$6, 0xFF


                lw $31,0x54($29)
                lw $24,0x78($29)
        lw $11, 0x60($29) ; lwu $25, 0x64($29) ; lwu $15, 0x68($29) ; lwu $30, 0x6C($29) ; lwu $3, 0x70($29) ; lhu $4, 0($16) ; lhu $5, 2($16) ; lhu $6, 4($16) ; lhu $7, 6($16) ; lhu $13, 10($16) ; lwu $14, 16($16) ; lbu $12, 8($16) ; lw $2,20($16)

                jr $31
        nop
# 666 "../../Source/ps2/sn65816.S"
_SNCPU_Read8:
                srl $8,$17,(13)

        beq $8,$0,_SNCPU_Read8ZeroBank
        sll $8,$8,4

        addu $8,$8,$16

        lw $9,(52 +0)($8)
        lbu $10,(52 +12)($8)

        beq $9,$0,_SNCPU_Read8Trap
                subu $2, $2, $10

        addu $8,$9,$17

                jr $31
        lbu $24, 0($8)


_SNCPU_Read8ZeroBank:
        lw $8,(52 +0)($16)
        addiu $2,$2,-(8)
        addu $8,$8,$17
                jr $31
        lbu $24, 0($8)


_SNCPU_Read8Trap:
        lw $9,(52 +4)($8)


                sw $31,0x54($29)
        sw $11, 0x60($29) ; sw $25, 0x64($29) ; sw $15, 0x68($29) ; sw $30, 0x6C($29) ; sw $3, 0x70($29) ; sh $4, 0($16) ; sh $5, 2($16) ; sh $6, 4($16) ; sh $7, 6($16) ; sh $13, 10($16) ; sw $14, 16($16) ; sb $12, 8($16) ; sw $2, 20($16)


                move $4, $16
                jalr $9
                move $5, $17

        andi $24, $2, 0xFF

                lw $31,0x54($29)
        lw $11, 0x60($29) ; lwu $25, 0x64($29) ; lwu $15, 0x68($29) ; lwu $30, 0x6C($29) ; lwu $3, 0x70($29) ; lhu $4, 0($16) ; lhu $5, 2($16) ; lhu $6, 4($16) ; lhu $7, 6($16) ; lhu $13, 10($16) ; lwu $14, 16($16) ; lbu $12, 8($16) ; lw $2,20($16)

                jr $31
        nop
# 733 "../../Source/ps2/sn65816.S"
_SNCPU_Read16_Slow:
                sw $31, 0x50($29)

                jal _SNCPU_Read8
        addiu $17,$17,0
        sb $24,0x78($29)


                jal _SNCPU_Read8
        addiu $17,$17,1
        sb $24,0x79($29)

                lw $31, 0x50($29)
        lhu $24,0x78($29)

        jr $31
        addiu $17,$17,-1



_SNCPU_Read16:
_SNCPU_Read16_Fast:
        addiu $9,$17,1
                srl $10,$17,(13)

        srl $9,$9,(13)
        sll $8,$10,4

                bne $9,$10,_SNCPU_Read16_Slow
        addu $8,$8,$16

        lw $9,(52 +0)($8)
        lbu $10,(52 +12)($8)

        beq $9,$0,_SNCPU_Read16Trap
                subu $2, $2, $10

        addu $8,$9,$17
                subu $2, $2, $10

        lwr $24, 0($8)
        lwl $24, 3($8)

                jr $31
        andi $24,$24,0xFFFF


_SNCPU_Read16Trap:
        lw $9,(52 +4)($8)
                subu $2, $2, $10


                sw $31,0x54($29)
        sw $11, 0x60($29) ; sw $25, 0x64($29) ; sw $15, 0x68($29) ; sw $30, 0x6C($29) ; sw $3, 0x70($29) ; sh $4, 0($16) ; sh $5, 2($16) ; sh $6, 4($16) ; sh $7, 6($16) ; sh $13, 10($16) ; sw $14, 16($16) ; sb $12, 8($16) ; sw $2, 20($16)

        sw $9, 0x5C($29)


                move $4, $16
                jalr $9
                addiu $5, $17,0
        sb $2,0x78($29)

        lw $9, 0x5C($29)


                move $4, $16
                jalr $9
                addiu $5, $17,1
        sb $2,0x79($29)

                lw $31,0x54($29)
        lhu $24,0x78($29)
        lw $11, 0x60($29) ; lwu $25, 0x64($29) ; lwu $15, 0x68($29) ; lwu $30, 0x6C($29) ; lwu $3, 0x70($29) ; lhu $4, 0($16) ; lhu $5, 2($16) ; lhu $6, 4($16) ; lhu $7, 6($16) ; lhu $13, 10($16) ; lwu $14, 16($16) ; lbu $12, 8($16) ; lw $2,20($16)

                jr $31
        nop
# 831 "../../Source/ps2/sn65816.S"
_SNCPU_Read24:
                sw $31, 0x50($29)
        sw $0,0x78($29)

                jal _SNCPU_Read8
        addiu $17,$17,0
        sb $24,0x78($29)

                jal _SNCPU_Read8
        addiu $17,$17,1
        sb $24,0x79($29)

                jal _SNCPU_Read8
        addiu $17,$17,1
        sb $24,0x7A($29)

                lw $31, 0x50($29)
        lw $24,0x78($29)

        jr $31
        addiu $17,$17,-2
# 875 "../../Source/ps2/sn65816.S"
_SNCPU_Fetch8:
_SNCPU_Fetch8Fast:
                bltz $11,_SNCPU_Fetch8Update
                addiu $11,$11,-1

                lbu $24,0($3)
        addiu $3,$3,1

                jr $31
        subu $2,$2,$30


_SNCPU_Fetch8Update:
                lwu $8,0x58($29)

        subu $3, $3, $8

        sh $3,12($16)
        lwu $3,12($16)

                srl $8,$3,(13)
        sll $8,$8,4
        addu $8,$8,$16

        lw $9,(52 +0)($8)
        lbu $30,(52 +12)($8)

        beq $9,$0,_SNCPU_Fetch8Trap
        sw $9,0x58($29)

        andi $11, $3, ((1<<(13)) - 1)
        xori $11, $11, ((1<<(13)) - 1)

                j _SNCPU_Fetch8Fast
        addu $3,$9,$3

_SNCPU_Fetch8Trap:
                lui $11,0xC000
        move $17, $3
                j _SNCPU_Read8
        addiu $3,$3,1



_SNCPU_Fetch8Slow:
                move $17, $3

                j _SNCPU_Read8
        addiu $3,$3,1
# 949 "../../Source/ps2/sn65816.S"
_SNCPU_Fetch16:

_SNCPU_Fetch16Fast:
                blez $11,_SNCPU_Fetch16Trap
                addiu $11,$11,-2

        subu $2,$2,$30

        lwr $24, 0($3)
        lwl $24, 3($3)

        addiu $3,$3,2
        subu $2,$2,$30


                jr $31
        andi $24,$24,0xFFFF


_SNCPU_Fetch16Trap:
                sw $31, 0x50($29)

        jal _SNCPU_Fetch8
                addiu $11,$11,2

        jal _SNCPU_Fetch8
        sb $24,0x78($29)

        lw $31, 0x50($29)
        sb $24,0x79($29)

        jr $31
        lhu $24,0x78($29)



_SNCPU_Fetch16Slow:
                move $17, $3

                j _SNCPU_Read16
        addiu $3,$3,2
# 1013 "../../Source/ps2/sn65816.S"
_SNCPU_Fetch24:
_SNCPU_Fetch24Fast:
                addiu $11,$11,-1

                blez $11,_SNCPU_Fetch24Trap
                addiu $11,$11,-2

        subu $2,$2,$30

        lwr $24, 0($3)
        lwl $24, 3($3)

        addiu $3,$3,3
        subu $2,$2,$30
        sll $24,$24,8
        subu $2,$2,$30

                jr $31
        srl $24,$24,8

_SNCPU_Fetch24Trap:
                sw $31, 0x50($29)
        sw $0, 0x78($29)

        jal _SNCPU_Fetch8
                addiu $11,$11,3

        jal _SNCPU_Fetch8
        sb $24,0x78($29)

        jal _SNCPU_Fetch8
        sb $24,0x79($29)

        lw $31, 0x50($29)
        sb $24,0x7A($29)

        jr $31
        lw $24,0x78($29)



_SNCPU_Fetch24Slow:
                move $17, $3

                j _SNCPU_Read24
        addiu $3,$3,3
# 1081 "../../Source/ps2/sn65816.S"
_SNCPU_ComposeFlags:
                andi $12, $12, (0x01 | 0x02 |0x80) ^ 0xFFFF
        andi $20, $20,1

        srl $8,$18,8
        or $12, $12, $20

        andi $8,$8,0x80
        andi $19,$19,0xFFFF

        or $12,$12,$8

        or $9,$12,0x02

                jr $31
        movz $12,$9,$19
# 1118 "../../Source/ps2/sn65816.S"
_SNCPU_DecomposeFlags:
                andi $19, $12, 0x02
                andi $20, $12, 0x01
                sll $18, $12, 8
        xori $19, $19, 0x02

        andi $8,$12, 0x10
        andi $9,$5, 0xFF
        andi $10,$6, 0xFF
        movn $5,$9,$8
                j _SNCPU_UpdateOpTable
        movn $6,$10,$8
# 1163 "../../Source/ps2/sn65816.S"
_SNCPU_UpdateOpTable:
                lbu $8, 9($16)
                andi $9, $12, 0x30

        bne $8,$0, _E1
        li $25,0xFFFF


_E0:
                la $15, _SNCPU_OpTable
                sll $9,$9, 4 + 2

                jr $31
        addu $15,$15,$9



_E1:
                la $15, _SNCPU_OpTable
        li $25,0x00FF
        li $13,0x0000
        addiu $15,$15, 0x400*4
        ori $12,$12, 0x20 | 0x10
        andi $7,0x00FF
                jr $31
        ori $7,0x0100
# 1198 "../../Source/ps2/sn65816.S"
_SNCPU_ADC8:
        andi $12,$12,0x40 ^ 0xFF
                move $8,$23
        addu $23,$23,$22
        addu $23,$23,$20
        xor $9,$8,$22
        xor $10,$8,$23
        nor $9,$9,$0
        and $9,$9,$10
        srl $9,$9,1
        andi $9,$9,0x40
        or $12,$12,$9

                andi $9,$12,0x08
        bne $9,$0,_SNCPU_ADC8_DECIMAL
                nop

                jr $31
                nop


_SNCPU_ADC16:
        andi $12,$12,0x40 ^ 0xFF
                move $8,$23
        addu $23,$23,$22
        addu $23,$23,$20
        xor $9,$8,$22
        xor $10,$8,$23
        nor $9,$9,$0
        and $9,$9,$10
        srl $9,$9,9
        andi $9,$9,0x40
        or $12,$12,$9

                andi $9,$12,0x08
        bne $9,$0,_SNCPU_ADC16_DECIMAL
                nop

                jr $31
                nop



_SNCPU_SBC8:
        andi $12,$12,0x40 ^ 0xFF
                move $8,$23
        addu $23,$23,$22
        addu $23,$23,$20
        xor $9,$8,$22
        xor $10,$8,$23
        nor $9,$9,$0
        and $9,$9,$10
        srl $9,$9,1
        andi $9,$9,0x40
        or $12,$12,$9

                andi $9,$12,0x08
        bne $9,$0,_SNCPU_SBC8_DECIMAL
                nop

                jr $31
                nop

_SNCPU_SBC16:
        andi $12,$12,0x40 ^ 0xFF
                move $8,$23
        addu $23,$23,$22
        addu $23,$23,$20
        xor $9,$8,$22
        xor $10,$8,$23
        nor $9,$9,$0
        and $9,$9,$10
        srl $9,$9,9
        andi $9,$9,0x40
        or $12,$12,$9

                andi $9,$12,0x08
        bne $9,$0,_SNCPU_SBC16_DECIMAL
                nop

                jr $31
                nop
# 1343 "../../Source/ps2/sn65816.S"
_SNCPU_ADC8_DECIMAL:
                move $23,$8
        andi $10,$20,1

        andi $8,$22,(0xF<<0) ; andi $9,$23,(0xF<<0) ; addu $10,$10,$8 ; addu $10,$10,$9 ; srl $8,$10,0 ; sltiu $8,$8,10 ; addiu $9,$10,-(10<<0) ; andi $9,$9,(0xFFFF >> (12-0)) ; addiu $9,$9,(0x10 << 0) ; movz $10,$9,$8 ;
        andi $8,$22,(0xF<<4) ; andi $9,$23,(0xF<<4) ; addu $10,$10,$8 ; addu $10,$10,$9 ; srl $8,$10,4 ; sltiu $8,$8,10 ; addiu $9,$10,-(10<<4) ; andi $9,$9,(0xFFFF >> (12-4)) ; addiu $9,$9,(0x10 << 4) ; movz $10,$9,$8 ;

                jr $31
        move $23,$10

_SNCPU_ADC16_DECIMAL:
                move $23,$8
        andi $10,$20,1

        andi $8,$22,(0xF<<0) ; andi $9,$23,(0xF<<0) ; addu $10,$10,$8 ; addu $10,$10,$9 ; srl $8,$10,0 ; sltiu $8,$8,10 ; addiu $9,$10,-(10<<0) ; andi $9,$9,(0xFFFF >> (12-0)) ; addiu $9,$9,(0x10 << 0) ; movz $10,$9,$8 ;
        andi $8,$22,(0xF<<4) ; andi $9,$23,(0xF<<4) ; addu $10,$10,$8 ; addu $10,$10,$9 ; srl $8,$10,4 ; sltiu $8,$8,10 ; addiu $9,$10,-(10<<4) ; andi $9,$9,(0xFFFF >> (12-4)) ; addiu $9,$9,(0x10 << 4) ; movz $10,$9,$8 ;
        andi $8,$22,(0xF<<8) ; andi $9,$23,(0xF<<8) ; addu $10,$10,$8 ; addu $10,$10,$9 ; srl $8,$10,8 ; sltiu $8,$8,10 ; addiu $9,$10,-(10<<8) ; andi $9,$9,(0xFFFF >> (12-8)) ; addiu $9,$9,(0x10 << 8) ; movz $10,$9,$8 ;
        andi $8,$22,(0xF<<12) ; andi $9,$23,(0xF<<12) ; addu $10,$10,$8 ; addu $10,$10,$9 ; srl $8,$10,12 ; sltiu $8,$8,10 ; addiu $9,$10,-(5<<12) ; addiu $9,$9,-(5<<12) ; andi $9,$9,(0xFFFF >> (12-12)) ; addiu $9,$9,(0x4 << 12) ; addiu $9,$9,(0x4 << 12) ; addiu $9,$9,(0x4 << 12) ; addiu $9,$9,(0x4 << 12) ; movz $10,$9,$8 ;

                jr $31
        move $23,$10


_SNCPU_SBC8_DECIMAL:
                move $23,$8
        andi $10,$20,1

                xori $23,$23,0x00FF
                addiu $10,$10,-1

        andi $8,$22,(0xF<<0) ; andi $9,$23,(0xF<<0) ; addu $10,$10,$8 ; subu $10,$10,$9 ; srl $8,$10,0 ; sltiu $8,$8,10 ; addiu $9,$10,(10<<0) ; andi $9,$9,(0xFFFF >> (12-0)) ; addiu $9,$9,-(0x10 << 0) ; movz $10,$9,$8 ;
        andi $8,$22,(0xF<<4) ; andi $9,$23,(0xF<<4) ; addu $10,$10,$8 ; subu $10,$10,$9 ; srl $8,$10,4 ; sltiu $8,$8,10 ; addiu $9,$10,(10<<4) ; andi $9,$9,(0xFFFF >> (12-4)) ; addiu $9,$9,-(0x10 << 4) ; movz $10,$9,$8 ;

                xori $10,$10,0x100

                jr $31
        move $23,$10



_SNCPU_SBC16_DECIMAL:
                move $23,$8
        andi $10,$20,1

                xori $23,$23,0xFFFF
                addiu $10,$10,-1

        andi $8,$22,(0xF<<0) ; andi $9,$23,(0xF<<0) ; addu $10,$10,$8 ; subu $10,$10,$9 ; srl $8,$10,0 ; sltiu $8,$8,10 ; addiu $9,$10,(10<<0) ; andi $9,$9,(0xFFFF >> (12-0)) ; addiu $9,$9,-(0x10 << 0) ; movz $10,$9,$8 ;
        andi $8,$22,(0xF<<4) ; andi $9,$23,(0xF<<4) ; addu $10,$10,$8 ; subu $10,$10,$9 ; srl $8,$10,4 ; sltiu $8,$8,10 ; addiu $9,$10,(10<<4) ; andi $9,$9,(0xFFFF >> (12-4)) ; addiu $9,$9,-(0x10 << 4) ; movz $10,$9,$8 ;
        andi $8,$22,(0xF<<8) ; andi $9,$23,(0xF<<8) ; addu $10,$10,$8 ; subu $10,$10,$9 ; srl $8,$10,8 ; sltiu $8,$8,10 ; addiu $9,$10,(10<<8) ; andi $9,$9,(0xFFFF >> (12-8)) ; addiu $9,$9,-(0x10 << 8) ; movz $10,$9,$8 ;
        andi $8,$22,(0xF<<12) ; andi $9,$23,(0xF<<12) ; addu $10,$10,$8 ; subu $10,$10,$9 ; srl $8,$10,12 ; sltiu $8,$8,10 ; addiu $9,$10,(5<<12) ; addiu $9,$9,(5<<12) ; andi $9,$9,(0xFFFF >> (12-12)) ; addiu $9,$9,-(0x4 << 12) ; addiu $9,$9,-(0x4 << 12) ; addiu $9,$9,-(0x4 << 12) ; addiu $9,$9,-(0x4 << 12) ; movz $10,$9,$8 ;

                li $8,0x10000
                xor $10,$10,$8

                jr $31
        move $23,$10
# 1423 "../../Source/ps2/sn65816.S"
SNCPUExecute_ASM:
                addiu $29,$29,-0x80
        sd $16,0x00($29)
        sd $17,0x08($29)
        sd $18,0x10($29)
        sd $19,0x18($29)
        sd $20,0x20($29)
        sd $21,0x28($29)
        sd $22,0x30($29)
        sd $23,0x38($29)
        sd $31,0x40($29)
        sd $30,0x48($29)

                move $16, $4






                lw $11, 0x60($29) ; lwu $25, 0x64($29) ; lwu $15, 0x68($29) ; lwu $30, 0x6C($29) ; lwu $3, 0x70($29) ; lhu $4, 0($16) ; lhu $5, 2($16) ; lhu $6, 4($16) ; lhu $7, 6($16) ; lhu $13, 10($16) ; lwu $14, 16($16) ; lbu $12, 8($16) ; lw $2,20($16);


        jal _SNCPU_DecomposeFlags
        nop


                lwu $3, 12($16)
                sw $0,0x58($29)
        move $30,$0
                lui $11,0xC000
# 1463 "../../Source/ps2/sn65816.S"
_SNCPUExecute_Loop:

                bltz $11,_SNCPU_ExecuteFetchUpdate
                addiu $11,$11,-1

                lbu $24,0($3)

                blez $2, _SNCPUExecute_Done
        addiu $3,$3,1


                sll $8, $24, 2

        addu $8, $8, $15

        lw $8, 0x00($8)
        subu $2,$2,$30

        jr $8
        nop


_SNCPU_ExecuteFetchUpdate:
                blez $2, _SNCPUExecute_Done
        addiu $3,$3,1


                jal _SNCPU_Fetch8Update
        addiu $3,$3,-1


                sll $8, $24, 2
        addu $8, $8, $15
        lw $8, 0x00($8)
        jr $8
        nop
# 1523 "../../Source/ps2/sn65816.S"
_SNCPUExecute_Abort:
# 1532 "../../Source/ps2/sn65816.S"
_SNCPUExecute_Done:
        addiu $3,$3,-1

                lw $8,0x58($29)
        subu $3, $3, $8
                sh $3, 12($16)

        jal _SNCPU_ComposeFlags
        nop

                sw $11, 0x60($29) ; sw $25, 0x64($29) ; sw $15, 0x68($29) ; sw $30, 0x6C($29) ; sw $3, 0x70($29) ; sh $4, 0($16) ; sh $5, 2($16) ; sh $6, 4($16) ; sh $7, 6($16) ; sh $13, 10($16) ; sw $14, 16($16) ; sb $12, 8($16) ; sw $2, 20($16);






        ld $30,0x48($29)
        ld $31,0x40($29)
        ld $23,0x38($29)
        ld $22,0x30($29)
        ld $21,0x28($29)
        ld $20,0x20($29)
        ld $19,0x18($29)
        ld $18,0x10($29)
        ld $17,0x08($29)
        ld $16,0x00($29)
                jr $31
                addiu $29,$29,0x80






        op_0x0e2: op_0x1e2: op_0x2e2: op_0x3e2:;
                jal _SNCPU_Fetch8 ; nop ; move $21,$24;
        or $12,$12,$21;

                la $15, _SNCPU_OpTable


        andi $8,$21,0x01
        or $20, $20, $8


        sll $9,$21,8
        or $18, $18, $9


        andi $10,$21,0x02
        movn $19, $0, $10

        andi $8,$12, 0x10
        andi $9,$5, 0xFF
        andi $10,$6, 0xFF
        movn $5,$9,$8
        movn $6,$10,$8

                andi $9, $12, 0x30

                sll $9,$9, 4 + 2

        addu $15,$15,$9


        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))



        op_0x0c2: op_0x1c2: op_0x2c2: op_0x3c2:;
                jal _SNCPU_Fetch8 ; nop ; move $21,$24;
        xori $21,$21,0xFF;
        and $12,$12,$21;

                la $15, _SNCPU_OpTable


        and $20, $20, $21


        sll $9,$21,8
        and $18, $18, $9


        andi $10,$21,0x02
        movz $19, $15, $10

                andi $9, $12, 0x30

                sll $9,$9, 4 + 2

        addu $15,$15,$9

        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))




        op_0x4e2:;
                jal _SNCPU_Fetch8 ; nop ; move $21,$24;


        or $12,$12,$21;


        andi $8,$21,0x01
        or $20, $20, $8


        sll $9,$21,8
        or $18, $18, $9


        andi $10,$21,0x02
        movn $19, $0, $10

        andi $8,$12, 0x10
        andi $9,$5, 0xFF
        andi $10,$6, 0xFF
        movn $5,$9,$8
        movn $6,$10,$8

                jal _SNCPU_UpdateOpTable
        nop


        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))



        op_0x4c2:;
                jal _SNCPU_Fetch8 ; nop ; move $21,$24;


        or $12,$12,$21;
        xor $12,$12,$21;


        andi $8,$21,0x01
        or $20, $20, $8
        xor $20, $20, $8


        sll $9,$21,8
        or $18, $18, $9
        xor $18, $18, $9


        andi $10,$21,0x02
        movn $19, $21, $10

                jal _SNCPU_UpdateOpTable
        nop

        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))




        op_0x010: op_0x110: op_0x210: op_0x310: op_0x410:;

        andi $22,$18,0x8000;
                jal _SNCPU_Fetch8 ; nop ; move $21,$24

        bne $22,$0,_SNCPUExecute_Loop

        sll $21,$21,24
        sra $21,$21,24

                subu $11,$11,$21 ; lui $9,0xC000 ; sltiu $8, $11,(1<<(13)) ; addu $3,$3,$21 ; movz $11,$9,$8;
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))



        op_0x030: op_0x130: op_0x230: op_0x330: op_0x430:;

        andi $22,$18,0x8000;
                jal _SNCPU_Fetch8 ; nop ; move $21,$24

        beq $22,$0,_SNCPUExecute_Loop;

        sll $21,$21,24
        sra $21,$21,24

                subu $11,$11,$21 ; lui $9,0xC000 ; sltiu $8, $11,(1<<(13)) ; addu $3,$3,$21 ; movz $11,$9,$8;
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))

        op_0x0f0: op_0x1f0: op_0x2f0: op_0x3f0: op_0x4f0:;

        andi $19,$19,0xFFFF ; sltiu $22,$19,1 ;;
                jal _SNCPU_Fetch8 ; nop ; move $21,$24

        beq $22,$0,_SNCPUExecute_Loop;

        sll $21,$21,24
        sra $21,$21,24

                subu $11,$11,$21 ; lui $9,0xC000 ; sltiu $8, $11,(1<<(13)) ; addu $3,$3,$21 ; movz $11,$9,$8;
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))

        op_0x0d0: op_0x1d0: op_0x2d0: op_0x3d0: op_0x4d0:;

        andi $19,$19,0xFFFF ; sltiu $22,$19,1 ;;
                jal _SNCPU_Fetch8 ; nop ; move $21,$24

        bne $22,$0,_SNCPUExecute_Loop;

        sll $21,$21,24
        sra $21,$21,24

                subu $11,$11,$21 ; lui $9,0xC000 ; sltiu $8, $11,(1<<(13)) ; addu $3,$3,$21 ; movz $11,$9,$8;
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


        op_0x090: op_0x190: op_0x290: op_0x390: op_0x490:;

        andi $22,$20,1;
                jal _SNCPU_Fetch8 ; nop ; move $21,$24

        bne $22,$0,_SNCPUExecute_Loop;

        sll $21,$21,24
        sra $21,$21,24

                subu $11,$11,$21 ; lui $9,0xC000 ; sltiu $8, $11,(1<<(13)) ; addu $3,$3,$21 ; movz $11,$9,$8;
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))

        op_0x0b0: op_0x1b0: op_0x2b0: op_0x3b0: op_0x4b0:;

        andi $22,$20,1;
                jal _SNCPU_Fetch8 ; nop ; move $21,$24

        beq $22,$0,_SNCPUExecute_Loop;

        sll $21,$21,24
        sra $21,$21,24

                subu $11,$11,$21 ; lui $9,0xC000 ; sltiu $8, $11,(1<<(13)) ; addu $3,$3,$21 ; movz $11,$9,$8;
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))

        op_0x050: op_0x150: op_0x250: op_0x350: op_0x450:;

        andi $22,$12,0x40;
                jal _SNCPU_Fetch8 ; nop ; move $21,$24

        bne $22,$0,_SNCPUExecute_Loop;

        sll $21,$21,24
        sra $21,$21,24

                subu $11,$11,$21 ; lui $9,0xC000 ; sltiu $8, $11,(1<<(13)) ; addu $3,$3,$21 ; movz $11,$9,$8;
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))

        op_0x070: op_0x170: op_0x270: op_0x370: op_0x470:;

        andi $22,$12,0x40;
                jal _SNCPU_Fetch8 ; nop ; move $21,$24

        beq $22,$0,_SNCPUExecute_Loop;

        sll $21,$21,24
        sra $21,$21,24

                subu $11,$11,$21 ; lui $9,0xC000 ; sltiu $8, $11,(1<<(13)) ; addu $3,$3,$21 ; movz $11,$9,$8;
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


        op_0x080: op_0x180: op_0x280: op_0x380: op_0x480:;

                jal _SNCPU_Fetch8 ; nop ; move $21,$24

        sll $21,$21,24
        sra $21,$21,24

                subu $11,$11,$21 ; lui $9,0xC000 ; sltiu $8, $11,(1<<(13)) ; addu $3,$3,$21 ; movz $11,$9,$8;
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))






        op_0x082: op_0x182: op_0x282: op_0x382: op_0x482:;


                jal _SNCPU_Fetch16 ; nop ; move $21,$24

        sll $21,$21,16
        sra $21,$21,16

                subu $11,$11,$21 ; lui $9,0xC000 ; sltiu $8, $11,(1<<(13)) ; addu $3,$3,$21 ; movz $11,$9,$8;
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


        op_0x054: op_0x254:;


        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        jal _SNCPU_Fetch8 ; nop ; move $22,$24

        sll $21,$21,16
        sll $22,$22,16

        move $14,$21

        or $21,$21,$6
        or $22,$22,$5

        jal _SNCPU_Read8 ; move $17, $22 ; move $23,$24
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $23

        addiu $5,$5,1
        addiu $6,$6,1
        andi $5,$5,0xFFFF
        andi $6,$6,0xFFFF

        addiu $8,$3,-3
        addiu $9,$11, 3
        movn $3,$8,$4
        movn $11,$9,$4

        addiu $4,$4,-1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(2 * (6))


        op_0x154: op_0x354: op_0x454:;


        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        jal _SNCPU_Fetch8 ; nop ; move $22,$24

        sll $21,$21,16
        sll $22,$22,16

        move $14,$21

        or $21,$21,$6
        or $22,$22,$5

        jal _SNCPU_Read8 ; move $17, $22 ; move $23,$24
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $23

        addiu $5,$5,1
        addiu $6,$6,1
        andi $5,$5,0xFF
        andi $6,$6,0xFF

        addiu $8,$3,-3
        addiu $9,$11, 3
        movn $3,$8,$4
        movn $11,$9,$4

        addiu $4,$4,-1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(2 * (6))


        op_0x044: op_0x244:;


        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        jal _SNCPU_Fetch8 ; nop ; move $22,$24

        sll $21,$21,16
        sll $22,$22,16

        move $14,$21

        or $21,$21,$6
        or $22,$22,$5

        jal _SNCPU_Read8 ; move $17, $22 ; move $23,$24
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $23

        addiu $5,$5,-1
        addiu $6,$6,-1
        andi $5,$5,0xFFFF
        andi $6,$6,0xFFFF

        addiu $8,$3,-3
        addiu $9,$11, 3
        movn $3,$8,$4
        movn $11,$9,$4

        addiu $4,$4,-1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(2 * (6))


        op_0x144: op_0x344: op_0x444:;


        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        jal _SNCPU_Fetch8 ; nop ; move $22,$24

        sll $21,$21,16
        sll $22,$22,16

        move $14,$21

        or $21,$21,$6
        or $22,$22,$5

        jal _SNCPU_Read8 ; move $17, $22 ; move $23,$24
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $23

        addiu $5,$5,-1
        addiu $6,$6,-1
        andi $5,$5,0xFF
        andi $6,$6,0xFF

        addiu $8,$3,-3
        addiu $9,$11, 3
        movn $3,$8,$4
        movn $11,$9,$4

        addiu $4,$4,-1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(2 * (6))


        op_0x0cb: op_0x1cb: op_0x2cb: op_0x3cb: op_0x4cb:;
                lbu $8,49($16)

                andi $9,$8,0x04
                ori $8,$8,0x02
                xori $8,$8,0x02

                bne $9,$0, _WAI_SkipIRQ
                nop


        addiu $3,$3,-1
        addiu $11,$11,1

                ori $8,$8,0x02

_WAI_SkipIRQ:

                sb $8,49($16)

        j _SNCPUExecute_Loop ; addiu $2,$2, -(2 * (6))





        op_0x042: op_0x142: op_0x242: op_0x342: op_0x442:;



        op_0x0db: op_0x1db: op_0x2db: op_0x3db: op_0x4db:;



        j _SNCPUExecute_Abort ; nop

        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))



# 1 "../../XML/op65816_mips.h" 1

op_0x0ea:
op_0x1ea:
op_0x2ea:
op_0x3ea:
op_0x4ea:
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x078:
op_0x178:
op_0x278:
op_0x378:
op_0x478:
        ori $12,$12,0x04
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x058:
op_0x158:
op_0x258:
op_0x358:
op_0x458:
        andi $12,$12,0x04^0xFFFF
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x0b8:
op_0x1b8:
op_0x2b8:
op_0x3b8:
op_0x4b8:
        andi $12,$12,0x40 ^ 0xFFFF ; or $12,$12,(0) << 6
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x018:
op_0x118:
op_0x218:
op_0x318:
op_0x418:
        ori $20,$0,1&(0)
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x038:
op_0x138:
op_0x238:
op_0x338:
op_0x438:
        ori $20,$0,1&(1)
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x0d8:
op_0x1d8:
op_0x2d8:
op_0x3d8:
op_0x4d8:
        andi $12,$12,0x08^0xFFFF
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x0f8:
op_0x1f8:
op_0x2f8:
op_0x3f8:
op_0x4f8:
        ori $12,$12,0x08
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x0fb:
op_0x1fb:
op_0x2fb:
op_0x3fb:
op_0x4fb:
        lbu $22,9($16)
        andi $21,$20,1
        andi $20,$22,1
        jal _SNCPU_UpdateOpTable ; sb $21,9($16)
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x05b:
op_0x15b:
op_0x25b:
op_0x35b:
op_0x45b:
        andi $21,$4,0xFFFF
        move $13,$21
        sll $19,$21,0
        sll $18,$21,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x07b:
op_0x17b:
op_0x27b:
op_0x37b:
op_0x47b:
        move $21,$13
        andi $4,$21,0xFFFF
        sll $19,$21,0
        sll $18,$21,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x03b:
op_0x13b:
op_0x23b:
op_0x33b:
op_0x43b:
        andi $21,$7,0xFFFF
        andi $4,$21,0xFFFF
        sll $19,$21,0
        sll $18,$21,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x01b:
op_0x11b:
op_0x21b:
op_0x31b:
        andi $21,$4,0xFFFF
        andi $7,$21,0xFFFF
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x41b:
        andi $21,$4,0xFF
        andi $8,$21,0xFF ; andi $7,$7,0xFF00 ; or $7,$7,$8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x08a:
op_0x18a:
        andi $21,$5,0xFFFF
        andi $4,$21,0xFFFF
        sll $18,$21,0
        sll $19,$21,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x28a:
op_0x38a:
op_0x48a:
        andi $21,$5,0xFF
        andi $8,$21,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $18,$21,8
        sll $19,$21,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x098:
op_0x198:
        andi $21,$6,0xFFFF
        andi $4,$21,0xFFFF
        sll $18,$21,0
        sll $19,$21,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x298:
op_0x398:
op_0x498:
        andi $21,$6,0xFF
        andi $8,$21,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $18,$21,8
        sll $19,$21,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x0a8:
op_0x2a8:
        andi $21,$4,0xFFFF
        andi $6,$21,0xFFFF
        sll $18,$21,0
        sll $19,$21,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x1a8:
op_0x3a8:
op_0x4a8:
        andi $21,$4,0xFF
        andi $6,$21,0xFF
        sll $18,$21,8
        sll $19,$21,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x0aa:
op_0x2aa:
        andi $21,$4,0xFFFF
        andi $5,$21,0xFFFF
        sll $18,$21,0
        sll $19,$21,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x1aa:
op_0x3aa:
op_0x4aa:
        andi $21,$4,0xFF
        andi $5,$21,0xFF
        sll $18,$21,8
        sll $19,$21,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x09b:
op_0x29b:
        andi $21,$5,0xFFFF
        andi $6,$21,0xFFFF
        sll $18,$21,0
        sll $19,$21,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x19b:
op_0x39b:
op_0x49b:
        andi $21,$5,0xFFFF
        andi $6,$21,0xFFFF
        sll $18,$21,8
        sll $19,$21,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x0bb:
op_0x2bb:
        andi $21,$6,0xFFFF
        andi $5,$21,0xFFFF
        sll $18,$21,0
        sll $19,$21,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x1bb:
op_0x3bb:
op_0x4bb:
        andi $21,$6,0xFFFF
        andi $5,$21,0xFFFF
        sll $18,$21,8
        sll $19,$21,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x09a:
op_0x19a:
op_0x29a:
op_0x39a:
        andi $21,$5,0xFFFF
        andi $7,$21,0xFFFF
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x49a:
        andi $21,$5,0xFF
        andi $8,$21,0xFF ; andi $7,$7,0xFF00 ; or $7,$7,$8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x0ba:
op_0x2ba:
        andi $21,$7,0xFFFF
        andi $5,$21,0xFFFF
        sll $18,$21,0
        sll $19,$21,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x1ba:
op_0x3ba:
op_0x4ba:
        andi $21,$7,0xFF
        andi $5,$21,0xFF
        sll $18,$21,8
        sll $19,$21,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x0ca:
op_0x2ca:
        andi $22,$5,0xFFFF
        addiu $22,$22,-(1)
        andi $5,$22,0xFFFF
        sll $19,$22,0
        sll $18,$22,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x1ca:
op_0x3ca:
op_0x4ca:
        andi $22,$5,0xFF
        addiu $22,$22,-(1)
        andi $5,$22,0xFF
        sll $19,$22,8
        sll $18,$22,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x088:
op_0x288:
        andi $22,$6,0xFFFF
        addiu $22,$22,-(1)
        andi $6,$22,0xFFFF
        sll $19,$22,0
        sll $18,$22,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x188:
op_0x388:
op_0x488:
        andi $22,$6,0xFF
        addiu $22,$22,-(1)
        andi $6,$22,0xFF
        sll $19,$22,8
        sll $18,$22,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x0e8:
op_0x2e8:
        andi $22,$5,0xFFFF
        addiu $22,$22,1
        andi $5,$22,0xFFFF
        sll $19,$22,0
        sll $18,$22,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x1e8:
op_0x3e8:
op_0x4e8:
        andi $22,$5,0xFF
        addiu $22,$22,1
        andi $5,$22,0xFF
        sll $19,$22,8
        sll $18,$22,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x0c8:
op_0x2c8:
        andi $22,$6,0xFFFF
        addiu $22,$22,1
        andi $6,$22,0xFFFF
        sll $19,$22,0
        sll $18,$22,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x1c8:
op_0x3c8:
op_0x4c8:
        andi $22,$6,0xFF
        addiu $22,$22,1
        andi $6,$22,0xFF
        sll $19,$22,8
        sll $18,$22,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x061:
op_0x161:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        jal _SNCPU_ADC16 ; nop
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x261:
op_0x361:
op_0x461:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        jal _SNCPU_ADC8 ; nop
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x063:
op_0x163:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$7
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        jal _SNCPU_ADC16 ; nop
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x263:
op_0x363:
op_0x463:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$7
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        jal _SNCPU_ADC8 ; nop
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x065:
op_0x165:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        jal _SNCPU_ADC16 ; nop
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x265:
op_0x365:
op_0x465:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        jal _SNCPU_ADC8 ; nop
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x067:
op_0x167:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read24 ; move $17, $21 ; move $21,$24
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        jal _SNCPU_ADC16 ; nop
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x267:
op_0x367:
op_0x467:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read24 ; move $17, $21 ; move $21,$24
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        jal _SNCPU_ADC8 ; nop
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x069:
op_0x169:
        jal _SNCPU_Fetch16 ; nop ; move $22,$24
        andi $23,$4,0xFFFF
        jal _SNCPU_ADC16 ; nop
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x269:
op_0x369:
op_0x469:
        jal _SNCPU_Fetch8 ; nop ; move $22,$24
        andi $23,$4,0xFF
        jal _SNCPU_ADC8 ; nop
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x06d:
op_0x16d:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        jal _SNCPU_ADC16 ; nop
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x26d:
op_0x36d:
op_0x46d:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        jal _SNCPU_ADC8 ; nop
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x06f:
op_0x16f:
        jal _SNCPU_Fetch24 ; nop ; move $21,$24
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        jal _SNCPU_ADC16 ; nop
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x26f:
op_0x36f:
op_0x46f:
        jal _SNCPU_Fetch24 ; nop ; move $21,$24
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        jal _SNCPU_ADC8 ; nop
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x071:
op_0x171:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$6
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        jal _SNCPU_ADC16 ; nop
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x271:
op_0x371:
op_0x471:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$6
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        jal _SNCPU_ADC8 ; nop
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x072:
op_0x172:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        jal _SNCPU_ADC16 ; nop
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x272:
op_0x372:
op_0x472:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        jal _SNCPU_ADC8 ; nop
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x073:
op_0x173:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$7
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$6
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        jal _SNCPU_ADC16 ; nop
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x273:
op_0x373:
op_0x473:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$7
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$6
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        jal _SNCPU_ADC8 ; nop
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x075:
op_0x175:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        jal _SNCPU_ADC16 ; nop
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x275:
op_0x375:
op_0x475:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        jal _SNCPU_ADC8 ; nop
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x077:
op_0x177:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read24 ; move $17, $21 ; move $21,$24
        addu $21,$21,$6
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        jal _SNCPU_ADC16 ; nop
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x277:
op_0x377:
op_0x477:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read24 ; move $17, $21 ; move $21,$24
        addu $21,$21,$6
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        jal _SNCPU_ADC8 ; nop
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x079:
op_0x179:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$6
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        jal _SNCPU_ADC16 ; nop
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x279:
op_0x379:
op_0x479:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$6
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        jal _SNCPU_ADC8 ; nop
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x07d:
op_0x17d:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$5
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        jal _SNCPU_ADC16 ; nop
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x27d:
op_0x37d:
op_0x47d:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$5
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        jal _SNCPU_ADC8 ; nop
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x07f:
op_0x17f:
        jal _SNCPU_Fetch24 ; nop ; move $21,$24
        addu $21,$21,$5
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        jal _SNCPU_ADC16 ; nop
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x27f:
op_0x37f:
op_0x47f:
        jal _SNCPU_Fetch24 ; nop ; move $21,$24
        addu $21,$21,$5
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        jal _SNCPU_ADC8 ; nop
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0e1:
op_0x1e1:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        xori $22,$22,0xFFFF
        andi $23,$4,0xFFFF
        jal _SNCPU_SBC16 ; nop
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x2e1:
op_0x3e1:
op_0x4e1:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        xori $22,$22,0xFF
        andi $23,$4,0xFF
        jal _SNCPU_SBC8 ; nop
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0e3:
op_0x1e3:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$7
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        xori $22,$22,0xFFFF
        andi $23,$4,0xFFFF
        jal _SNCPU_SBC16 ; nop
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x2e3:
op_0x3e3:
op_0x4e3:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$7
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        xori $22,$22,0xFF
        andi $23,$4,0xFF
        jal _SNCPU_SBC8 ; nop
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0e5:
op_0x1e5:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        xori $22,$22,0xFFFF
        andi $23,$4,0xFFFF
        jal _SNCPU_SBC16 ; nop
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x2e5:
op_0x3e5:
op_0x4e5:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        xori $22,$22,0xFF
        andi $23,$4,0xFF
        jal _SNCPU_SBC8 ; nop
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0e7:
op_0x1e7:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read24 ; move $17, $21 ; move $21,$24
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        xori $22,$22,0xFFFF
        andi $23,$4,0xFFFF
        jal _SNCPU_SBC16 ; nop
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x2e7:
op_0x3e7:
op_0x4e7:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read24 ; move $17, $21 ; move $21,$24
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        xori $22,$22,0xFF
        andi $23,$4,0xFF
        jal _SNCPU_SBC8 ; nop
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0e9:
op_0x1e9:
        jal _SNCPU_Fetch16 ; nop ; move $22,$24
        xori $22,$22,0xFFFF
        andi $23,$4,0xFFFF
        jal _SNCPU_SBC16 ; nop
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x2e9:
op_0x3e9:
op_0x4e9:
        jal _SNCPU_Fetch8 ; nop ; move $22,$24
        xori $22,$22,0xFF
        andi $23,$4,0xFF
        jal _SNCPU_SBC8 ; nop
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0ed:
op_0x1ed:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        xori $22,$22,0xFFFF
        andi $23,$4,0xFFFF
        jal _SNCPU_SBC16 ; nop
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x2ed:
op_0x3ed:
op_0x4ed:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        xori $22,$22,0xFF
        andi $23,$4,0xFF
        jal _SNCPU_SBC8 ; nop
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0ef:
op_0x1ef:
        jal _SNCPU_Fetch24 ; nop ; move $21,$24
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        xori $22,$22,0xFFFF
        andi $23,$4,0xFFFF
        jal _SNCPU_SBC16 ; nop
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x2ef:
op_0x3ef:
op_0x4ef:
        jal _SNCPU_Fetch24 ; nop ; move $21,$24
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        xori $22,$22,0xFF
        andi $23,$4,0xFF
        jal _SNCPU_SBC8 ; nop
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0f1:
op_0x1f1:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$6
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        xori $22,$22,0xFFFF
        andi $23,$4,0xFFFF
        jal _SNCPU_SBC16 ; nop
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x2f1:
op_0x3f1:
op_0x4f1:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$6
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        xori $22,$22,0xFF
        andi $23,$4,0xFF
        jal _SNCPU_SBC8 ; nop
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0f2:
op_0x1f2:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        xori $22,$22,0xFFFF
        andi $23,$4,0xFFFF
        jal _SNCPU_SBC16 ; nop
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x2f2:
op_0x3f2:
op_0x4f2:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        xori $22,$22,0xFF
        andi $23,$4,0xFF
        jal _SNCPU_SBC8 ; nop
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0f3:
op_0x1f3:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$7
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$6
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        xori $22,$22,0xFFFF
        andi $23,$4,0xFFFF
        jal _SNCPU_SBC16 ; nop
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x2f3:
op_0x3f3:
op_0x4f3:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$7
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$6
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        xori $22,$22,0xFF
        andi $23,$4,0xFF
        jal _SNCPU_SBC8 ; nop
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0f5:
op_0x1f5:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        xori $22,$22,0xFFFF
        andi $23,$4,0xFFFF
        jal _SNCPU_SBC16 ; nop
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x2f5:
op_0x3f5:
op_0x4f5:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        xori $22,$22,0xFF
        andi $23,$4,0xFF
        jal _SNCPU_SBC8 ; nop
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0f7:
op_0x1f7:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read24 ; move $17, $21 ; move $21,$24
        addu $21,$21,$6
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        xori $22,$22,0xFFFF
        andi $23,$4,0xFFFF
        jal _SNCPU_SBC16 ; nop
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x2f7:
op_0x3f7:
op_0x4f7:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read24 ; move $17, $21 ; move $21,$24
        addu $21,$21,$6
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        xori $22,$22,0xFF
        andi $23,$4,0xFF
        jal _SNCPU_SBC8 ; nop
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0f9:
op_0x1f9:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$6
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        xori $22,$22,0xFFFF
        andi $23,$4,0xFFFF
        jal _SNCPU_SBC16 ; nop
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x2f9:
op_0x3f9:
op_0x4f9:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$6
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        xori $22,$22,0xFF
        andi $23,$4,0xFF
        jal _SNCPU_SBC8 ; nop
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0fd:
op_0x1fd:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$5
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        xori $22,$22,0xFFFF
        andi $23,$4,0xFFFF
        jal _SNCPU_SBC16 ; nop
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x2fd:
op_0x3fd:
op_0x4fd:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$5
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        xori $22,$22,0xFF
        andi $23,$4,0xFF
        jal _SNCPU_SBC8 ; nop
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0ff:
op_0x1ff:
        jal _SNCPU_Fetch24 ; nop ; move $21,$24
        addu $21,$21,$5
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        xori $22,$22,0xFFFF
        andi $23,$4,0xFFFF
        jal _SNCPU_SBC16 ; nop
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x2ff:
op_0x3ff:
op_0x4ff:
        jal _SNCPU_Fetch24 ; nop ; move $21,$24
        addu $21,$21,$5
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        xori $22,$22,0xFF
        andi $23,$4,0xFF
        jal _SNCPU_SBC8 ; nop
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0a9:
op_0x1a9:
        jal _SNCPU_Fetch16 ; nop ; move $22,$24
        andi $4,$22,0xFFFF
        sll $19,$22,0
        sll $18,$22,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x2a9:
op_0x3a9:
op_0x4a9:
        jal _SNCPU_Fetch8 ; nop ; move $22,$24
        andi $8,$22,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$22,8
        sll $18,$22,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0ad:
op_0x1ad:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $4,$22,0xFFFF
        sll $19,$22,0
        sll $18,$22,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x2ad:
op_0x3ad:
op_0x4ad:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $8,$22,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$22,8
        sll $18,$22,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0af:
op_0x1af:
        jal _SNCPU_Fetch24 ; nop ; move $21,$24
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $4,$22,0xFFFF
        sll $19,$22,0
        sll $18,$22,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x2af:
op_0x3af:
op_0x4af:
        jal _SNCPU_Fetch24 ; nop ; move $21,$24
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $8,$22,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$22,8
        sll $18,$22,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0bf:
op_0x1bf:
        jal _SNCPU_Fetch24 ; nop ; move $21,$24
        addu $21,$21,$5
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $4,$22,0xFFFF
        sll $19,$22,0
        sll $18,$22,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x2bf:
op_0x3bf:
op_0x4bf:
        jal _SNCPU_Fetch24 ; nop ; move $21,$24
        addu $21,$21,$5
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $8,$22,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$22,8
        sll $18,$22,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0a1:
op_0x1a1:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $4,$22,0xFFFF
        sll $19,$22,0
        sll $18,$22,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x2a1:
op_0x3a1:
op_0x4a1:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $8,$22,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$22,8
        sll $18,$22,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0a3:
op_0x1a3:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$7
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $4,$22,0xFFFF
        sll $19,$22,0
        sll $18,$22,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x2a3:
op_0x3a3:
op_0x4a3:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$7
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $8,$22,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$22,8
        sll $18,$22,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0a5:
op_0x1a5:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $4,$22,0xFFFF
        sll $19,$22,0
        sll $18,$22,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x2a5:
op_0x3a5:
op_0x4a5:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $8,$22,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$22,8
        sll $18,$22,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0a7:
op_0x1a7:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read24 ; move $17, $21 ; move $21,$24
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $4,$22,0xFFFF
        sll $19,$22,0
        sll $18,$22,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x2a7:
op_0x3a7:
op_0x4a7:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read24 ; move $17, $21 ; move $21,$24
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $8,$22,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$22,8
        sll $18,$22,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0b1:
op_0x1b1:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$6
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $4,$22,0xFFFF
        sll $19,$22,0
        sll $18,$22,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x2b1:
op_0x3b1:
op_0x4b1:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$6
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $8,$22,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$22,8
        sll $18,$22,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0b2:
op_0x1b2:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $4,$22,0xFFFF
        sll $19,$22,0
        sll $18,$22,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x2b2:
op_0x3b2:
op_0x4b2:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $8,$22,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$22,8
        sll $18,$22,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0b3:
op_0x1b3:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$7
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$6
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $4,$22,0xFFFF
        sll $19,$22,0
        sll $18,$22,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x2b3:
op_0x3b3:
op_0x4b3:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$7
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$6
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $8,$22,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$22,8
        sll $18,$22,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0b5:
op_0x1b5:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $4,$22,0xFFFF
        sll $19,$22,0
        sll $18,$22,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x2b5:
op_0x3b5:
op_0x4b5:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $8,$22,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$22,8
        sll $18,$22,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0b7:
op_0x1b7:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read24 ; move $17, $21 ; move $21,$24
        addu $21,$21,$6
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $4,$22,0xFFFF
        sll $19,$22,0
        sll $18,$22,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x2b7:
op_0x3b7:
op_0x4b7:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read24 ; move $17, $21 ; move $21,$24
        addu $21,$21,$6
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $8,$22,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$22,8
        sll $18,$22,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0b9:
op_0x1b9:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$6
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $4,$22,0xFFFF
        sll $19,$22,0
        sll $18,$22,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x2b9:
op_0x3b9:
op_0x4b9:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$6
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $8,$22,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$22,8
        sll $18,$22,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0bd:
op_0x1bd:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$5
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $4,$22,0xFFFF
        sll $19,$22,0
        sll $18,$22,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x2bd:
op_0x3bd:
op_0x4bd:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$5
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $8,$22,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$22,8
        sll $18,$22,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x08d:
op_0x18d:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        andi $22,$4,0xFFFF
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x28d:
op_0x38d:
op_0x48d:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        andi $22,$4,0xFF
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x08f:
op_0x18f:
        jal _SNCPU_Fetch24 ; nop ; move $21,$24
        andi $22,$4,0xFFFF
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x28f:
op_0x38f:
op_0x48f:
        jal _SNCPU_Fetch24 ; nop ; move $21,$24
        andi $22,$4,0xFF
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x09f:
op_0x19f:
        jal _SNCPU_Fetch24 ; nop ; move $21,$24
        addu $21,$21,$5
        andi $22,$4,0xFFFF
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x29f:
op_0x39f:
op_0x49f:
        jal _SNCPU_Fetch24 ; nop ; move $21,$24
        addu $21,$21,$5
        andi $22,$4,0xFF
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x081:
op_0x181:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        andi $22,$4,0xFFFF
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x281:
op_0x381:
op_0x481:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        andi $22,$4,0xFF
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x083:
op_0x183:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$7
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        andi $22,$4,0xFFFF
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x283:
op_0x383:
op_0x483:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$7
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        andi $22,$4,0xFF
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x085:
op_0x185:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        andi $22,$4,0xFFFF
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x285:
op_0x385:
op_0x485:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        andi $22,$4,0xFF
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x087:
op_0x187:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read24 ; move $17, $21 ; move $21,$24
        andi $22,$4,0xFFFF
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x287:
op_0x387:
op_0x487:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read24 ; move $17, $21 ; move $21,$24
        andi $22,$4,0xFF
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x091:
op_0x191:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$6
        addiu $2,$2, -(1 * (6))
        andi $22,$4,0xFFFF
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x291:
op_0x391:
op_0x491:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$6
        addiu $2,$2, -(1 * (6))
        andi $22,$4,0xFF
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x092:
op_0x192:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        andi $22,$4,0xFFFF
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x292:
op_0x392:
op_0x492:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        andi $22,$4,0xFF
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x093:
op_0x193:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$7
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$6
        andi $22,$4,0xFFFF
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x293:
op_0x393:
op_0x493:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$7
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$6
        andi $22,$4,0xFF
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x095:
op_0x195:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        andi $22,$4,0xFFFF
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x295:
op_0x395:
op_0x495:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        andi $22,$4,0xFF
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x097:
op_0x197:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read24 ; move $17, $21 ; move $21,$24
        addu $21,$21,$6
        andi $22,$4,0xFFFF
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x297:
op_0x397:
op_0x497:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read24 ; move $17, $21 ; move $21,$24
        addu $21,$21,$6
        andi $22,$4,0xFF
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x099:
op_0x199:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$6
        addiu $2,$2, -(1 * (6))
        andi $22,$4,0xFFFF
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x299:
op_0x399:
op_0x499:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$6
        addiu $2,$2, -(1 * (6))
        andi $22,$4,0xFF
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x09d:
op_0x19d:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$5
        addiu $2,$2, -(1 * (6))
        andi $22,$4,0xFFFF
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x29d:
op_0x39d:
op_0x49d:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$5
        addiu $2,$2, -(1 * (6))
        andi $22,$4,0xFF
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x086:
op_0x286:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        andi $22,$5,0xFFFF
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x186:
op_0x386:
op_0x486:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        andi $22,$5,0xFF
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x08e:
op_0x28e:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        andi $22,$5,0xFFFF
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x18e:
op_0x38e:
op_0x48e:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        andi $22,$5,0xFF
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x096:
op_0x296:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$6
        and $21,$21,$25
        andi $22,$5,0xFFFF
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x196:
op_0x396:
op_0x496:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$6
        and $21,$21,$25
        andi $22,$5,0xFF
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x084:
op_0x284:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        andi $22,$6,0xFFFF
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x184:
op_0x384:
op_0x484:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        andi $22,$6,0xFF
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x08c:
op_0x28c:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        andi $22,$6,0xFFFF
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x18c:
op_0x38c:
op_0x48c:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        andi $22,$6,0xFF
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x094:
op_0x294:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        andi $22,$6,0xFFFF
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x194:
op_0x394:
op_0x494:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        andi $22,$6,0xFF
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x064:
op_0x164:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        li $22,0
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x264:
op_0x364:
op_0x464:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        li $22,0
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x074:
op_0x174:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        li $22,0
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x274:
op_0x374:
op_0x474:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        li $22,0
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x09c:
op_0x19c:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        li $22,0
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x29c:
op_0x39c:
op_0x49c:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        li $22,0
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x09e:
op_0x19e:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$5
        addiu $2,$2, -(1 * (6))
        li $22,0
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x29e:
op_0x39e:
op_0x49e:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$5
        addiu $2,$2, -(1 * (6))
        li $22,0
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0a2:
op_0x2a2:
        jal _SNCPU_Fetch16 ; nop ; move $22,$24
        andi $5,$22,0xFFFF
        sll $19,$22,0
        sll $18,$22,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x1a2:
op_0x3a2:
op_0x4a2:
        jal _SNCPU_Fetch8 ; nop ; move $22,$24
        andi $5,$22,0xFF
        sll $19,$22,8
        sll $18,$22,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0a6:
op_0x2a6:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $5,$22,0xFFFF
        sll $19,$22,0
        sll $18,$22,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x1a6:
op_0x3a6:
op_0x4a6:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $5,$22,0xFF
        sll $19,$22,8
        sll $18,$22,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0ae:
op_0x2ae:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $5,$22,0xFFFF
        sll $19,$22,0
        sll $18,$22,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x1ae:
op_0x3ae:
op_0x4ae:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $5,$22,0xFF
        sll $19,$22,8
        sll $18,$22,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0b6:
op_0x2b6:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$6
        and $21,$21,$25
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $5,$22,0xFFFF
        sll $19,$22,0
        sll $18,$22,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x1b6:
op_0x3b6:
op_0x4b6:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$6
        and $21,$21,$25
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $5,$22,0xFF
        sll $19,$22,8
        sll $18,$22,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0be:
op_0x2be:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$6
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $5,$22,0xFFFF
        sll $19,$22,0
        sll $18,$22,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x1be:
op_0x3be:
op_0x4be:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$6
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $5,$22,0xFF
        sll $19,$22,8
        sll $18,$22,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0a0:
op_0x2a0:
        jal _SNCPU_Fetch16 ; nop ; move $22,$24
        andi $6,$22,0xFFFF
        sll $19,$22,0
        sll $18,$22,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x1a0:
op_0x3a0:
op_0x4a0:
        jal _SNCPU_Fetch8 ; nop ; move $22,$24
        andi $6,$22,0xFF
        sll $19,$22,8
        sll $18,$22,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0a4:
op_0x2a4:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $6,$22,0xFFFF
        sll $19,$22,0
        sll $18,$22,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x1a4:
op_0x3a4:
op_0x4a4:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $6,$22,0xFF
        sll $19,$22,8
        sll $18,$22,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0ac:
op_0x2ac:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $6,$22,0xFFFF
        sll $19,$22,0
        sll $18,$22,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x1ac:
op_0x3ac:
op_0x4ac:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $6,$22,0xFF
        sll $19,$22,8
        sll $18,$22,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0b4:
op_0x2b4:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $6,$22,0xFFFF
        sll $19,$22,0
        sll $18,$22,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x1b4:
op_0x3b4:
op_0x4b4:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $6,$22,0xFF
        sll $19,$22,8
        sll $18,$22,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0bc:
op_0x2bc:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$5
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $6,$22,0xFFFF
        sll $19,$22,0
        sll $18,$22,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x1bc:
op_0x3bc:
op_0x4bc:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$5
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $6,$22,0xFF
        sll $19,$22,8
        sll $18,$22,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x021:
op_0x121:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        and $23,$23,$22
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x221:
op_0x321:
op_0x421:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        and $23,$23,$22
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x023:
op_0x123:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$7
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        and $23,$23,$22
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x223:
op_0x323:
op_0x423:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$7
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        and $23,$23,$22
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x025:
op_0x125:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        and $23,$23,$22
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x225:
op_0x325:
op_0x425:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        and $23,$23,$22
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x027:
op_0x127:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read24 ; move $17, $21 ; move $21,$24
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        and $23,$23,$22
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x227:
op_0x327:
op_0x427:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read24 ; move $17, $21 ; move $21,$24
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        and $23,$23,$22
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x029:
op_0x129:
        jal _SNCPU_Fetch16 ; nop ; move $22,$24
        andi $23,$4,0xFFFF
        and $23,$23,$22
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x229:
op_0x329:
op_0x429:
        jal _SNCPU_Fetch8 ; nop ; move $22,$24
        andi $23,$4,0xFF
        and $23,$23,$22
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x02d:
op_0x12d:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        and $23,$23,$22
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x22d:
op_0x32d:
op_0x42d:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        and $23,$23,$22
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x02f:
op_0x12f:
        jal _SNCPU_Fetch24 ; nop ; move $21,$24
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        and $23,$23,$22
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x22f:
op_0x32f:
op_0x42f:
        jal _SNCPU_Fetch24 ; nop ; move $21,$24
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        and $23,$23,$22
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x031:
op_0x131:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$6
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        and $23,$23,$22
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x231:
op_0x331:
op_0x431:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$6
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        and $23,$23,$22
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x032:
op_0x132:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        and $23,$23,$22
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x232:
op_0x332:
op_0x432:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        and $23,$23,$22
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x033:
op_0x133:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$7
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$6
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        and $23,$23,$22
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x233:
op_0x333:
op_0x433:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$7
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$6
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        and $23,$23,$22
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x035:
op_0x135:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        and $23,$23,$22
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x235:
op_0x335:
op_0x435:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        and $23,$23,$22
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x037:
op_0x137:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read24 ; move $17, $21 ; move $21,$24
        addu $21,$21,$6
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        and $23,$23,$22
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x237:
op_0x337:
op_0x437:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read24 ; move $17, $21 ; move $21,$24
        addu $21,$21,$6
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        and $23,$23,$22
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x039:
op_0x139:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$6
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        and $23,$23,$22
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x239:
op_0x339:
op_0x439:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$6
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        and $23,$23,$22
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x03d:
op_0x13d:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$5
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        and $23,$23,$22
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x23d:
op_0x33d:
op_0x43d:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$5
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        and $23,$23,$22
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x03f:
op_0x13f:
        jal _SNCPU_Fetch24 ; nop ; move $21,$24
        addu $21,$21,$5
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        and $23,$23,$22
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x23f:
op_0x33f:
op_0x43f:
        jal _SNCPU_Fetch24 ; nop ; move $21,$24
        addu $21,$21,$5
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        and $23,$23,$22
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x041:
op_0x141:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        xor $23,$23,$22
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x241:
op_0x341:
op_0x441:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        xor $23,$23,$22
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x043:
op_0x143:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$7
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        xor $23,$23,$22
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x243:
op_0x343:
op_0x443:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$7
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        xor $23,$23,$22
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x045:
op_0x145:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        xor $23,$23,$22
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x245:
op_0x345:
op_0x445:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        xor $23,$23,$22
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x047:
op_0x147:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read24 ; move $17, $21 ; move $21,$24
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        xor $23,$23,$22
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x247:
op_0x347:
op_0x447:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read24 ; move $17, $21 ; move $21,$24
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        xor $23,$23,$22
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x049:
op_0x149:
        jal _SNCPU_Fetch16 ; nop ; move $22,$24
        andi $23,$4,0xFFFF
        xor $23,$23,$22
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x249:
op_0x349:
op_0x449:
        jal _SNCPU_Fetch8 ; nop ; move $22,$24
        andi $23,$4,0xFF
        xor $23,$23,$22
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x04d:
op_0x14d:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        xor $23,$23,$22
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x24d:
op_0x34d:
op_0x44d:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        xor $23,$23,$22
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x04f:
op_0x14f:
        jal _SNCPU_Fetch24 ; nop ; move $21,$24
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        xor $23,$23,$22
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x24f:
op_0x34f:
op_0x44f:
        jal _SNCPU_Fetch24 ; nop ; move $21,$24
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        xor $23,$23,$22
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x051:
op_0x151:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$6
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        xor $23,$23,$22
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x251:
op_0x351:
op_0x451:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$6
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        xor $23,$23,$22
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x052:
op_0x152:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        xor $23,$23,$22
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x252:
op_0x352:
op_0x452:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        xor $23,$23,$22
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x053:
op_0x153:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$7
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$6
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        xor $23,$23,$22
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x253:
op_0x353:
op_0x453:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$7
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$6
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        xor $23,$23,$22
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x055:
op_0x155:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        xor $23,$23,$22
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x255:
op_0x355:
op_0x455:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        xor $23,$23,$22
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x057:
op_0x157:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read24 ; move $17, $21 ; move $21,$24
        addu $21,$21,$6
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        xor $23,$23,$22
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x257:
op_0x357:
op_0x457:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read24 ; move $17, $21 ; move $21,$24
        addu $21,$21,$6
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        xor $23,$23,$22
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x059:
op_0x159:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$6
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        xor $23,$23,$22
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x259:
op_0x359:
op_0x459:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$6
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        xor $23,$23,$22
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x05d:
op_0x15d:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$5
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        xor $23,$23,$22
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x25d:
op_0x35d:
op_0x45d:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$5
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        xor $23,$23,$22
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x05f:
op_0x15f:
        jal _SNCPU_Fetch24 ; nop ; move $21,$24
        addu $21,$21,$5
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        xor $23,$23,$22
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x25f:
op_0x35f:
op_0x45f:
        jal _SNCPU_Fetch24 ; nop ; move $21,$24
        addu $21,$21,$5
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        xor $23,$23,$22
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x003:
op_0x103:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$7
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        or $23,$23,$22
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x203:
op_0x303:
op_0x403:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$7
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        or $23,$23,$22
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x005:
op_0x105:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        or $23,$23,$22
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x205:
op_0x305:
op_0x405:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        or $23,$23,$22
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x007:
op_0x107:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read24 ; move $17, $21 ; move $21,$24
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        or $23,$23,$22
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x207:
op_0x307:
op_0x407:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read24 ; move $17, $21 ; move $21,$24
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        or $23,$23,$22
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x009:
op_0x109:
        jal _SNCPU_Fetch16 ; nop ; move $22,$24
        andi $23,$4,0xFFFF
        or $23,$23,$22
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x209:
op_0x309:
op_0x409:
        jal _SNCPU_Fetch8 ; nop ; move $22,$24
        andi $23,$4,0xFF
        or $23,$23,$22
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x00d:
op_0x10d:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        or $23,$23,$22
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x20d:
op_0x30d:
op_0x40d:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        or $23,$23,$22
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x00f:
op_0x10f:
        jal _SNCPU_Fetch24 ; nop ; move $21,$24
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        or $23,$23,$22
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x20f:
op_0x30f:
op_0x40f:
        jal _SNCPU_Fetch24 ; nop ; move $21,$24
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        or $23,$23,$22
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x011:
op_0x111:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$6
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        or $23,$23,$22
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x211:
op_0x311:
op_0x411:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$6
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        or $23,$23,$22
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x012:
op_0x112:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        or $23,$23,$22
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x212:
op_0x312:
op_0x412:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        or $23,$23,$22
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x013:
op_0x113:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$7
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$6
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        or $23,$23,$22
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x213:
op_0x313:
op_0x413:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$7
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$6
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        or $23,$23,$22
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x015:
op_0x115:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        or $23,$23,$22
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x215:
op_0x315:
op_0x415:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        or $23,$23,$22
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x017:
op_0x117:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read24 ; move $17, $21 ; move $21,$24
        addu $21,$21,$6
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        or $23,$23,$22
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x217:
op_0x317:
op_0x417:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read24 ; move $17, $21 ; move $21,$24
        addu $21,$21,$6
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        or $23,$23,$22
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x001:
op_0x101:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        or $23,$23,$22
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x201:
op_0x301:
op_0x401:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        or $23,$23,$22
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x019:
op_0x119:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$6
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        or $23,$23,$22
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x219:
op_0x319:
op_0x419:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$6
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        or $23,$23,$22
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x01d:
op_0x11d:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$5
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        or $23,$23,$22
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x21d:
op_0x31d:
op_0x41d:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$5
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        or $23,$23,$22
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x01f:
op_0x11f:
        jal _SNCPU_Fetch24 ; nop ; move $21,$24
        addu $21,$21,$5
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        or $23,$23,$22
        andi $4,$23,0xFFFF
        sll $19,$23,0
        sll $18,$23,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x21f:
op_0x31f:
op_0x41f:
        jal _SNCPU_Fetch24 ; nop ; move $21,$24
        addu $21,$21,$5
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        or $23,$23,$22
        andi $8,$23,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$23,8
        sll $18,$23,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0c1:
op_0x1c1:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        subu $23,$23,$22
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        xori $23,$23,1
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x2c1:
op_0x3c1:
op_0x4c1:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        subu $23,$23,$22
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        xori $23,$23,1
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0c3:
op_0x1c3:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$7
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        subu $23,$23,$22
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        xori $23,$23,1
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x2c3:
op_0x3c3:
op_0x4c3:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$7
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        subu $23,$23,$22
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        xori $23,$23,1
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0c5:
op_0x1c5:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        subu $23,$23,$22
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        xori $23,$23,1
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x2c5:
op_0x3c5:
op_0x4c5:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        subu $23,$23,$22
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        xori $23,$23,1
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0c7:
op_0x1c7:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read24 ; move $17, $21 ; move $21,$24
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        subu $23,$23,$22
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        xori $23,$23,1
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x2c7:
op_0x3c7:
op_0x4c7:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read24 ; move $17, $21 ; move $21,$24
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        subu $23,$23,$22
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        xori $23,$23,1
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0c9:
op_0x1c9:
        jal _SNCPU_Fetch16 ; nop ; move $22,$24
        andi $23,$4,0xFFFF
        subu $23,$23,$22
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        xori $23,$23,1
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x2c9:
op_0x3c9:
op_0x4c9:
        jal _SNCPU_Fetch8 ; nop ; move $22,$24
        andi $23,$4,0xFF
        subu $23,$23,$22
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        xori $23,$23,1
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0cd:
op_0x1cd:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        subu $23,$23,$22
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        xori $23,$23,1
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x2cd:
op_0x3cd:
op_0x4cd:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        subu $23,$23,$22
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        xori $23,$23,1
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0cf:
op_0x1cf:
        jal _SNCPU_Fetch24 ; nop ; move $21,$24
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        subu $23,$23,$22
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        xori $23,$23,1
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x2cf:
op_0x3cf:
op_0x4cf:
        jal _SNCPU_Fetch24 ; nop ; move $21,$24
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        subu $23,$23,$22
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        xori $23,$23,1
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0d1:
op_0x1d1:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$6
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        subu $23,$23,$22
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        xori $23,$23,1
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x2d1:
op_0x3d1:
op_0x4d1:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$6
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        subu $23,$23,$22
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        xori $23,$23,1
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0d2:
op_0x1d2:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        subu $23,$23,$22
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        xori $23,$23,1
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x2d2:
op_0x3d2:
op_0x4d2:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        subu $23,$23,$22
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        xori $23,$23,1
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0d3:
op_0x1d3:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$7
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$6
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        subu $23,$23,$22
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        xori $23,$23,1
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x2d3:
op_0x3d3:
op_0x4d3:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$7
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$6
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        subu $23,$23,$22
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        xori $23,$23,1
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0d5:
op_0x1d5:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        subu $23,$23,$22
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        xori $23,$23,1
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x2d5:
op_0x3d5:
op_0x4d5:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        subu $23,$23,$22
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        xori $23,$23,1
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0d7:
op_0x1d7:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read24 ; move $17, $21 ; move $21,$24
        addu $21,$21,$6
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        subu $23,$23,$22
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        xori $23,$23,1
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x2d7:
op_0x3d7:
op_0x4d7:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read24 ; move $17, $21 ; move $21,$24
        addu $21,$21,$6
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        subu $23,$23,$22
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        xori $23,$23,1
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0d9:
op_0x1d9:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$6
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        subu $23,$23,$22
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        xori $23,$23,1
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x2d9:
op_0x3d9:
op_0x4d9:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$6
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        subu $23,$23,$22
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        xori $23,$23,1
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0dd:
op_0x1dd:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$5
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        subu $23,$23,$22
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        xori $23,$23,1
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x2dd:
op_0x3dd:
op_0x4dd:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$5
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        subu $23,$23,$22
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        xori $23,$23,1
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0df:
op_0x1df:
        jal _SNCPU_Fetch24 ; nop ; move $21,$24
        addu $21,$21,$5
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        subu $23,$23,$22
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        xori $23,$23,1
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x2df:
op_0x3df:
op_0x4df:
        jal _SNCPU_Fetch24 ; nop ; move $21,$24
        addu $21,$21,$5
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        subu $23,$23,$22
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        xori $23,$23,1
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0e0:
op_0x2e0:
        jal _SNCPU_Fetch16 ; nop ; move $22,$24
        andi $23,$5,0xFFFF
        subu $23,$23,$22
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        xori $23,$23,1
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x1e0:
op_0x3e0:
op_0x4e0:
        jal _SNCPU_Fetch8 ; nop ; move $22,$24
        andi $23,$5,0xFF
        subu $23,$23,$22
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        xori $23,$23,1
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0e4:
op_0x2e4:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$5,0xFFFF
        subu $23,$23,$22
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        xori $23,$23,1
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x1e4:
op_0x3e4:
op_0x4e4:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$5,0xFF
        subu $23,$23,$22
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        xori $23,$23,1
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0ec:
op_0x2ec:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$5,0xFFFF
        subu $23,$23,$22
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        xori $23,$23,1
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x1ec:
op_0x3ec:
op_0x4ec:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$5,0xFF
        subu $23,$23,$22
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        xori $23,$23,1
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0c0:
op_0x2c0:
        jal _SNCPU_Fetch16 ; nop ; move $22,$24
        andi $23,$6,0xFFFF
        subu $23,$23,$22
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        xori $23,$23,1
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x1c0:
op_0x3c0:
op_0x4c0:
        jal _SNCPU_Fetch8 ; nop ; move $22,$24
        andi $23,$6,0xFF
        subu $23,$23,$22
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        xori $23,$23,1
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0c4:
op_0x2c4:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$6,0xFFFF
        subu $23,$23,$22
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        xori $23,$23,1
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x1c4:
op_0x3c4:
op_0x4c4:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$6,0xFF
        subu $23,$23,$22
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        xori $23,$23,1
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0cc:
op_0x2cc:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$6,0xFFFF
        subu $23,$23,$22
        sll $19,$23,0
        sll $18,$23,0
        srl $23,$23,16
        xori $23,$23,1
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x1cc:
op_0x3cc:
op_0x4cc:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$6,0xFF
        subu $23,$23,$22
        sll $19,$23,8
        sll $18,$23,8
        srl $23,$23,8
        xori $23,$23,1
        andi $20,$23,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x020:
op_0x120:
op_0x220:
op_0x320:
op_0x420:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        lwu $8,0x58($29) ; subu $23, $3, $8
        addiu $23,$23,-(1)
        addiu $17, $7, 0 ; jal _SNCPU_Write8 ; srl $24, $23,8 ; addiu $17, $7, -1 ; jal _SNCPU_Write8 ; srl $24, $23,0 ; addiu $7,$7,-2 ;
        sh $21,12($16) ; sw $0, 0x58($29) ; lui $11,0xC000 ; lwu $3,12($16)
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x04c:
op_0x14c:
op_0x24c:
op_0x34c:
op_0x44c:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        sh $21,12($16) ; sw $0, 0x58($29) ; lui $11,0xC000 ; lwu $3,12($16)
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x022:
op_0x122:
op_0x222:
op_0x322:
op_0x422:
        jal _SNCPU_Fetch24 ; nop ; move $21,$24
        lwu $8,0x58($29) ; subu $23, $3, $8
        addiu $23,$23,-(1)
        addiu $17, $7, 0 ; jal _SNCPU_Write8 ; srl $24, $23,16 ; addiu $17, $7, -1 ; jal _SNCPU_Write8 ; srl $24, $23,8 ; addiu $17, $7, -2 ; jal _SNCPU_Write8 ; srl $24, $23,0 ; addiu $7,$7,-3 ;
        move $3,$21 ; sw $0, 0x58($29) ; lui $11,0xC000 ; sw $3,12($16)
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x05c:
op_0x15c:
op_0x25c:
op_0x35c:
op_0x45c:
        jal _SNCPU_Fetch24 ; nop ; move $21,$24
        move $3,$21 ; sw $0, 0x58($29) ; lui $11,0xC000 ; sw $3,12($16)
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x06c:
op_0x16c:
op_0x26c:
op_0x36c:
op_0x46c:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        andi $21,$21,0xFFFF
        sh $21,12($16) ; sw $0, 0x58($29) ; lui $11,0xC000 ; lwu $3,12($16)
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0dc:
op_0x1dc:
op_0x2dc:
op_0x3dc:
op_0x4dc:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        jal _SNCPU_Read24 ; move $17, $21 ; move $21,$24
        move $3,$21 ; sw $0, 0x58($29) ; lui $11,0xC000 ; sw $3,12($16)
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0fc:
op_0x1fc:
op_0x2fc:
op_0x3fc:
op_0x4fc:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        addu $21,$21,$5
        andi $21,$21,0xFFFF
        lwu $8,0x58($29) ; subu $22, $3, $8
        srl $22,$22,16
        sll $22,$22,16
        or $21,$21,$22
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        andi $21,$21,0xFFFF
        lwu $8,0x58($29) ; subu $23, $3, $8
        addiu $23,$23,-(1)
        addiu $17, $7, 0 ; jal _SNCPU_Write8 ; srl $24, $23,8 ; addiu $17, $7, -1 ; jal _SNCPU_Write8 ; srl $24, $23,0 ; addiu $7,$7,-2 ;
        sh $21,12($16) ; sw $0, 0x58($29) ; lui $11,0xC000 ; lwu $3,12($16)
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x07c:
op_0x17c:
op_0x27c:
op_0x37c:
op_0x47c:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        addu $21,$21,$5
        andi $21,$21,0xFFFF
        lwu $8,0x58($29) ; subu $22, $3, $8
        srl $22,$22,16
        sll $22,$22,16
        or $21,$21,$22
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        andi $21,$21,0xFFFF
        sh $21,12($16) ; sw $0, 0x58($29) ; lui $11,0xC000 ; lwu $3,12($16)
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x060:
op_0x160:
op_0x260:
op_0x360:
op_0x460:
        jal _SNCPU_Read16 ; addiu $17, $7,1 ; addiu $7,$7,2 ; move $21,$24
        addiu $21,$21,1
        sh $21,12($16) ; sw $0, 0x58($29) ; lui $11,0xC000 ; lwu $3,12($16)
        j _SNCPUExecute_Loop ; addiu $2,$2, -(3 * (6))


op_0x06b:
op_0x16b:
op_0x26b:
op_0x36b:
op_0x46b:
        jal _SNCPU_Read24 ; addiu $17, $7,1 ; addiu $7,$7,3 ; move $21,$24
        addiu $21,$21,1
        move $3,$21 ; sw $0, 0x58($29) ; lui $11,0xC000 ; sw $3,12($16)
        j _SNCPUExecute_Loop ; addiu $2,$2, -(2 * (6))


op_0x040:
op_0x140:
op_0x240:
op_0x340:
        jal _SNCPU_Read8 ; addiu $17, $7,1 ; addiu $7,$7,1 ; move $21,$24
        ; jal _SNCPU_DecomposeFlags ; move $12,$21
        jal _SNCPU_Read24 ; addiu $17, $7,1 ; addiu $7,$7,3 ; move $21,$24
        move $3,$21 ; sw $0, 0x58($29) ; lui $11,0xC000 ; sw $3,12($16)
        j _SNCPUExecute_Loop ; addiu $2,$2, -(2 * (6))


op_0x440:
        jal _SNCPU_Read8 ; addiu $17, $7,1 ; addiu $7,$7,1 ; move $21,$24
        ; jal _SNCPU_DecomposeFlags ; move $12,$21
        jal _SNCPU_Read16 ; addiu $17, $7,1 ; addiu $7,$7,2 ; move $21,$24
        sh $21,12($16) ; sw $0, 0x58($29) ; lui $11,0xC000 ; lwu $3,12($16)
        j _SNCPUExecute_Loop ; addiu $2,$2, -(2 * (6))


op_0x03a:
op_0x13a:
        andi $22,$4,0xFFFF
        addiu $22,$22,-(1)
        andi $4,$22,0xFFFF
        sll $19,$22,0
        sll $18,$22,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x23a:
op_0x33a:
op_0x43a:
        andi $22,$4,0xFF
        addiu $22,$22,-(1)
        andi $8,$22,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$22,8
        sll $18,$22,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x01a:
op_0x11a:
        andi $22,$4,0xFFFF
        addiu $22,$22,1
        andi $4,$22,0xFFFF
        sll $19,$22,0
        sll $18,$22,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x21a:
op_0x31a:
op_0x41a:
        andi $22,$4,0xFF
        addiu $22,$22,1
        andi $8,$22,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$22,8
        sll $18,$22,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x00a:
op_0x10a:
        andi $22,$4,0xFFFF
        sll $22,$22,1
        andi $4,$22,0xFFFF
        sll $19,$22,0
        sll $18,$22,0
        srl $22,$22,16
        andi $20,$22,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x20a:
op_0x30a:
op_0x40a:
        andi $22,$4,0xFF
        sll $22,$22,1
        andi $8,$22,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$22,8
        sll $18,$22,8
        srl $22,$22,8
        andi $20,$22,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x04a:
op_0x14a:
        andi $22,$4,0xFFFF
        andi $20,$22,1
        srl $22,$22,1
        andi $4,$22,0xFFFF
        sll $19,$22,0
        sll $18,$22,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x24a:
op_0x34a:
op_0x44a:
        andi $22,$4,0xFF
        andi $20,$22,1
        srl $22,$22,1
        andi $8,$22,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$22,8
        sll $18,$22,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x02a:
op_0x12a:
        andi $22,$4,0xFFFF
        andi $23,$20,1
        sll $22,$22,1
        or $22,$22,$23
        andi $4,$22,0xFFFF
        sll $19,$22,0
        sll $18,$22,0
        srl $22,$22,16
        andi $20,$22,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x22a:
op_0x32a:
op_0x42a:
        andi $22,$4,0xFF
        andi $23,$20,1
        sll $22,$22,1
        or $22,$22,$23
        andi $8,$22,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$22,8
        sll $18,$22,8
        srl $22,$22,8
        andi $20,$22,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x06a:
op_0x16a:
        andi $22,$4,0xFFFF
        andi $23,$20,1
        sll $23,$23,16
        andi $20,$22,1
        or $22,$22,$23
        srl $22,$22,1
        andi $4,$22,0xFFFF
        sll $19,$22,0
        sll $18,$22,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x26a:
op_0x36a:
op_0x46a:
        andi $22,$4,0xFF
        andi $23,$20,1
        sll $23,$23,8
        andi $20,$22,1
        or $22,$22,$23
        srl $22,$22,1
        andi $8,$22,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $19,$22,8
        sll $18,$22,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x0c6:
op_0x1c6:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        addiu $22,$22,-(1)
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        sll $19,$22,0
        sll $18,$22,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x2c6:
op_0x3c6:
op_0x4c6:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        addiu $22,$22,-(1)
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        sll $19,$22,8
        sll $18,$22,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x0ce:
op_0x1ce:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        addiu $22,$22,-(1)
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        sll $19,$22,0
        sll $18,$22,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x2ce:
op_0x3ce:
op_0x4ce:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        addiu $22,$22,-(1)
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        sll $19,$22,8
        sll $18,$22,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x0d6:
op_0x1d6:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        addiu $22,$22,-(1)
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        sll $19,$22,0
        sll $18,$22,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x2d6:
op_0x3d6:
op_0x4d6:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        addiu $22,$22,-(1)
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        sll $19,$22,8
        sll $18,$22,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x0de:
op_0x1de:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$5
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        addiu $22,$22,-(1)
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        sll $19,$22,0
        sll $18,$22,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(2 * (6))


op_0x2de:
op_0x3de:
op_0x4de:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$5
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        addiu $22,$22,-(1)
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        sll $19,$22,8
        sll $18,$22,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(2 * (6))


op_0x0e6:
op_0x1e6:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        addiu $22,$22,1
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        sll $19,$22,0
        sll $18,$22,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x2e6:
op_0x3e6:
op_0x4e6:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        addiu $22,$22,1
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        sll $19,$22,8
        sll $18,$22,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x0ee:
op_0x1ee:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        addiu $22,$22,1
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        sll $19,$22,0
        sll $18,$22,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x2ee:
op_0x3ee:
op_0x4ee:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        addiu $22,$22,1
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        sll $19,$22,8
        sll $18,$22,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x0f6:
op_0x1f6:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        addiu $22,$22,1
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        sll $19,$22,0
        sll $18,$22,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x2f6:
op_0x3f6:
op_0x4f6:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        addiu $22,$22,1
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        sll $19,$22,8
        sll $18,$22,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x0fe:
op_0x1fe:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$5
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        addiu $22,$22,1
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        sll $19,$22,0
        sll $18,$22,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(2 * (6))


op_0x2fe:
op_0x3fe:
op_0x4fe:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$5
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        addiu $22,$22,1
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        sll $19,$22,8
        sll $18,$22,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(2 * (6))


op_0x006:
op_0x106:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        sll $22,$22,1
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        sll $19,$22,0
        sll $18,$22,0
        srl $22,$22,16
        andi $20,$22,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x206:
op_0x306:
op_0x406:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        sll $22,$22,1
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        sll $19,$22,8
        sll $18,$22,8
        srl $22,$22,8
        andi $20,$22,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x00e:
op_0x10e:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        sll $22,$22,1
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        sll $19,$22,0
        sll $18,$22,0
        srl $22,$22,16
        andi $20,$22,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x20e:
op_0x30e:
op_0x40e:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        sll $22,$22,1
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        sll $19,$22,8
        sll $18,$22,8
        srl $22,$22,8
        andi $20,$22,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x016:
op_0x116:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        sll $22,$22,1
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        sll $19,$22,0
        sll $18,$22,0
        srl $22,$22,16
        andi $20,$22,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x216:
op_0x316:
op_0x416:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        sll $22,$22,1
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        sll $19,$22,8
        sll $18,$22,8
        srl $22,$22,8
        andi $20,$22,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x01e:
op_0x11e:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$5
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        sll $22,$22,1
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        sll $19,$22,0
        sll $18,$22,0
        srl $22,$22,16
        andi $20,$22,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(2 * (6))


op_0x21e:
op_0x31e:
op_0x41e:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$5
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        sll $22,$22,1
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        sll $19,$22,8
        sll $18,$22,8
        srl $22,$22,8
        andi $20,$22,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(2 * (6))


op_0x046:
op_0x146:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $20,$22,1
        srl $22,$22,1
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        sll $19,$22,0
        sll $18,$22,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x246:
op_0x346:
op_0x446:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $20,$22,1
        srl $22,$22,1
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        sll $19,$22,8
        sll $18,$22,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x04e:
op_0x14e:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $20,$22,1
        srl $22,$22,1
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        sll $19,$22,0
        sll $18,$22,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x24e:
op_0x34e:
op_0x44e:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $20,$22,1
        srl $22,$22,1
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        sll $19,$22,8
        sll $18,$22,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x056:
op_0x156:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $20,$22,1
        srl $22,$22,1
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        sll $19,$22,0
        sll $18,$22,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x256:
op_0x356:
op_0x456:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $20,$22,1
        srl $22,$22,1
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        sll $19,$22,8
        sll $18,$22,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x05e:
op_0x15e:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$5
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $20,$22,1
        srl $22,$22,1
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        sll $19,$22,0
        sll $18,$22,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(2 * (6))


op_0x25e:
op_0x35e:
op_0x45e:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$5
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $20,$22,1
        srl $22,$22,1
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        sll $19,$22,8
        sll $18,$22,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(2 * (6))


op_0x026:
op_0x126:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$20,1
        sll $22,$22,1
        or $22,$22,$23
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        sll $19,$22,0
        sll $18,$22,0
        srl $22,$22,16
        andi $20,$22,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x226:
op_0x326:
op_0x426:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$20,1
        sll $22,$22,1
        or $22,$22,$23
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        sll $19,$22,8
        sll $18,$22,8
        srl $22,$22,8
        andi $20,$22,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x02e:
op_0x12e:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$20,1
        sll $22,$22,1
        or $22,$22,$23
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        sll $19,$22,0
        sll $18,$22,0
        srl $22,$22,16
        andi $20,$22,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x22e:
op_0x32e:
op_0x42e:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$20,1
        sll $22,$22,1
        or $22,$22,$23
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        sll $19,$22,8
        sll $18,$22,8
        srl $22,$22,8
        andi $20,$22,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x036:
op_0x136:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$20,1
        sll $22,$22,1
        or $22,$22,$23
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        sll $19,$22,0
        sll $18,$22,0
        srl $22,$22,16
        andi $20,$22,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x236:
op_0x336:
op_0x436:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$20,1
        sll $22,$22,1
        or $22,$22,$23
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        sll $19,$22,8
        sll $18,$22,8
        srl $22,$22,8
        andi $20,$22,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x03e:
op_0x13e:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$5
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$20,1
        sll $22,$22,1
        or $22,$22,$23
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        sll $19,$22,0
        sll $18,$22,0
        srl $22,$22,16
        andi $20,$22,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(2 * (6))


op_0x23e:
op_0x33e:
op_0x43e:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$5
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$20,1
        sll $22,$22,1
        or $22,$22,$23
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        sll $19,$22,8
        sll $18,$22,8
        srl $22,$22,8
        andi $20,$22,1
        j _SNCPUExecute_Loop ; addiu $2,$2, -(2 * (6))


op_0x066:
op_0x166:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$20,1
        sll $23,$23,16
        andi $20,$22,1
        or $22,$22,$23
        srl $22,$22,1
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        sll $19,$22,0
        sll $18,$22,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x266:
op_0x366:
op_0x466:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$20,1
        sll $23,$23,8
        andi $20,$22,1
        or $22,$22,$23
        srl $22,$22,1
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        sll $19,$22,8
        sll $18,$22,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x06e:
op_0x16e:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$20,1
        sll $23,$23,16
        andi $20,$22,1
        or $22,$22,$23
        srl $22,$22,1
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        sll $19,$22,0
        sll $18,$22,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x26e:
op_0x36e:
op_0x46e:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$20,1
        sll $23,$23,8
        andi $20,$22,1
        or $22,$22,$23
        srl $22,$22,1
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        sll $19,$22,8
        sll $18,$22,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x076:
op_0x176:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$20,1
        sll $23,$23,16
        andi $20,$22,1
        or $22,$22,$23
        srl $22,$22,1
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        sll $19,$22,0
        sll $18,$22,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x276:
op_0x376:
op_0x476:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$20,1
        sll $23,$23,8
        andi $20,$22,1
        or $22,$22,$23
        srl $22,$22,1
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        sll $19,$22,8
        sll $18,$22,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x07e:
op_0x17e:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$5
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$20,1
        sll $23,$23,16
        andi $20,$22,1
        or $22,$22,$23
        srl $22,$22,1
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        sll $19,$22,0
        sll $18,$22,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(2 * (6))


op_0x27e:
op_0x37e:
op_0x47e:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$5
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$20,1
        sll $23,$23,8
        andi $20,$22,1
        or $22,$22,$23
        srl $22,$22,1
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        sll $19,$22,8
        sll $18,$22,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(2 * (6))


op_0x024:
op_0x124:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        and $23,$23,$22
        sll $19,$23,0
        sll $18,$22,0
        srl $22,$22,14
        andi $8,$22,1 ; andi $12,$12,0x40 ^ 0xFFFF ; sll $8,$8,6 ; or $12,$12,$8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x224:
op_0x324:
op_0x424:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        and $23,$23,$22
        sll $19,$23,8
        sll $18,$22,8
        srl $22,$22,6
        andi $8,$22,1 ; andi $12,$12,0x40 ^ 0xFFFF ; sll $8,$8,6 ; or $12,$12,$8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x02c:
op_0x12c:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        and $23,$23,$22
        sll $19,$23,0
        sll $18,$22,0
        srl $22,$22,14
        andi $8,$22,1 ; andi $12,$12,0x40 ^ 0xFFFF ; sll $8,$8,6 ; or $12,$12,$8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x22c:
op_0x32c:
op_0x42c:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        and $23,$23,$22
        sll $19,$23,8
        sll $18,$22,8
        srl $22,$22,6
        andi $8,$22,1 ; andi $12,$12,0x40 ^ 0xFFFF ; sll $8,$8,6 ; or $12,$12,$8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x034:
op_0x134:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        and $23,$23,$22
        sll $19,$23,0
        sll $18,$22,0
        srl $22,$22,14
        andi $8,$22,1 ; andi $12,$12,0x40 ^ 0xFFFF ; sll $8,$8,6 ; or $12,$12,$8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x234:
op_0x334:
op_0x434:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        addiu $2,$2, -(1 * (6))
        addu $21,$21,$5
        and $21,$21,$25
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        and $23,$23,$22
        sll $19,$23,8
        sll $18,$22,8
        srl $22,$22,6
        andi $8,$22,1 ; andi $12,$12,0x40 ^ 0xFFFF ; sll $8,$8,6 ; or $12,$12,$8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x03c:
op_0x13c:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$5
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        and $23,$23,$22
        sll $19,$23,0
        sll $18,$22,0
        srl $22,$22,14
        andi $8,$22,1 ; andi $12,$12,0x40 ^ 0xFFFF ; sll $8,$8,6 ; or $12,$12,$8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x23c:
op_0x33c:
op_0x43c:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        addu $21,$21,$5
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        and $23,$23,$22
        sll $19,$23,8
        sll $18,$22,8
        srl $22,$22,6
        andi $8,$22,1 ; andi $12,$12,0x40 ^ 0xFFFF ; sll $8,$8,6 ; or $12,$12,$8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x089:
op_0x189:
        jal _SNCPU_Fetch16 ; nop ; move $22,$24
        andi $23,$4,0xFFFF
        and $23,$23,$22
        sll $19,$23,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x289:
op_0x389:
op_0x489:
        jal _SNCPU_Fetch8 ; nop ; move $22,$24
        andi $23,$4,0xFF
        and $23,$23,$22
        sll $19,$23,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x014:
op_0x114:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        and $23,$23,$22
        sll $19,$23,0
        andi $23,$4,0xFFFF
        or $22,$22,$23
        xor $22,$22,$23
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x214:
op_0x314:
op_0x414:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        and $23,$23,$22
        sll $19,$23,8
        andi $23,$4,0xFF
        or $22,$22,$23
        xor $22,$22,$23
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x01c:
op_0x11c:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        and $23,$23,$22
        sll $19,$23,0
        andi $23,$4,0xFFFF
        or $22,$22,$23
        xor $22,$22,$23
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x21c:
op_0x31c:
op_0x41c:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        and $23,$23,$22
        sll $19,$23,8
        andi $23,$4,0xFF
        or $22,$22,$23
        xor $22,$22,$23
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x004:
op_0x104:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        and $23,$23,$22
        sll $19,$23,0
        andi $23,$4,0xFFFF
        or $22,$22,$23
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x204:
op_0x304:
op_0x404:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        and $23,$23,$22
        sll $19,$23,8
        andi $23,$4,0xFF
        or $22,$22,$23
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x00c:
op_0x10c:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read16 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFFFF
        and $23,$23,$22
        sll $19,$23,0
        andi $23,$4,0xFFFF
        or $22,$22,$23
        move $17, $21 ; jal _SNCPU_Write16 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x20c:
op_0x30c:
op_0x40c:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        or $21,$21,$14
        jal _SNCPU_Read8 ; move $17, $21 ; move $22,$24
        andi $23,$4,0xFF
        and $23,$23,$22
        sll $19,$23,8
        andi $23,$4,0xFF
        or $22,$22,$23
        move $17, $21 ; jal _SNCPU_Write8 ; move $24, $22
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x062:
op_0x162:
op_0x262:
op_0x362:
op_0x462:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        lwu $8,0x58($29) ; subu $22, $3, $8
        addu $21,$21,$22
        addiu $17, $7, 0 ; jal _SNCPU_Write8 ; srl $24, $21,8 ; addiu $17, $7, -1 ; jal _SNCPU_Write8 ; srl $24, $21,0 ; addiu $7,$7,-2 ;
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x0f4:
op_0x1f4:
op_0x2f4:
op_0x3f4:
op_0x4f4:
        jal _SNCPU_Fetch16 ; nop ; move $21,$24
        addiu $17, $7, 0 ; jal _SNCPU_Write8 ; srl $24, $21,8 ; addiu $17, $7, -1 ; jal _SNCPU_Write8 ; srl $24, $21,0 ; addiu $7,$7,-2 ;
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x0d4:
op_0x1d4:
op_0x2d4:
op_0x3d4:
op_0x4d4:
        jal _SNCPU_Fetch8 ; nop ; move $21,$24
        addu $21,$21,$13
        andi $21,$21,0xFFFF
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        or $21,$21,$14
        addiu $17, $7, 0 ; jal _SNCPU_Write8 ; srl $24, $21,8 ; addiu $17, $7, -1 ; jal _SNCPU_Write8 ; srl $24, $21,0 ; addiu $7,$7,-2 ;
        j _SNCPUExecute_Loop ; addiu $2,$2, -(0 * (6))


op_0x04b:
op_0x14b:
op_0x24b:
op_0x34b:
op_0x44b:
        lwu $8,0x58($29) ; subu $21, $3, $8
        srl $21,$21,16
        addiu $17, $7, 0 ; jal _SNCPU_Write8 ; srl $24, $21,0 ; addiu $7,$7,-1 ;
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x008:
op_0x108:
op_0x208:
op_0x308:
op_0x408:
        jal _SNCPU_ComposeFlags ; nop ; move $21,$12
        addiu $17, $7, 0 ; jal _SNCPU_Write8 ; srl $24, $21,0 ; addiu $7,$7,-1 ;
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x028:
op_0x128:
op_0x228:
op_0x328:
op_0x428:
        jal _SNCPU_Read8 ; addiu $17, $7,1 ; addiu $7,$7,1 ; move $21,$24
        ; jal _SNCPU_DecomposeFlags ; move $12,$21
        j _SNCPUExecute_Loop ; addiu $2,$2, -(2 * (6))


op_0x048:
op_0x148:
        andi $21,$4,0xFFFF
        addiu $17, $7, 0 ; jal _SNCPU_Write8 ; srl $24, $21,8 ; addiu $17, $7, -1 ; jal _SNCPU_Write8 ; srl $24, $21,0 ; addiu $7,$7,-2 ;
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x248:
op_0x348:
op_0x448:
        andi $21,$4,0xFF
        addiu $17, $7, 0 ; jal _SNCPU_Write8 ; srl $24, $21,0 ; addiu $7,$7,-1 ;
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x068:
op_0x168:
        jal _SNCPU_Read16 ; addiu $17, $7,1 ; addiu $7,$7,2 ; move $21,$24
        andi $4,$21,0xFFFF
        sll $18,$21,0
        sll $19,$21,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(2 * (6))


op_0x268:
op_0x368:
op_0x468:
        jal _SNCPU_Read8 ; addiu $17, $7,1 ; addiu $7,$7,1 ; move $21,$24
        andi $8,$21,0xFF ; andi $4,$4,0xFF00 ; or $4,$4,$8
        sll $18,$21,8
        sll $19,$21,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(2 * (6))


op_0x0da:
op_0x2da:
        andi $21,$5,0xFFFF
        addiu $17, $7, 0 ; jal _SNCPU_Write8 ; srl $24, $21,8 ; addiu $17, $7, -1 ; jal _SNCPU_Write8 ; srl $24, $21,0 ; addiu $7,$7,-2 ;
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x1da:
op_0x3da:
op_0x4da:
        andi $21,$5,0xFF
        addiu $17, $7, 0 ; jal _SNCPU_Write8 ; srl $24, $21,0 ; addiu $7,$7,-1 ;
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x0fa:
op_0x2fa:
        jal _SNCPU_Read16 ; addiu $17, $7,1 ; addiu $7,$7,2 ; move $21,$24
        andi $5,$21,0xFFFF
        sll $18,$21,0
        sll $19,$21,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(2 * (6))


op_0x1fa:
op_0x3fa:
op_0x4fa:
        jal _SNCPU_Read8 ; addiu $17, $7,1 ; addiu $7,$7,1 ; move $21,$24
        andi $5,$21,0xFF
        sll $18,$21,8
        sll $19,$21,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(2 * (6))


op_0x05a:
op_0x25a:
        andi $21,$6,0xFFFF
        addiu $17, $7, 0 ; jal _SNCPU_Write8 ; srl $24, $21,8 ; addiu $17, $7, -1 ; jal _SNCPU_Write8 ; srl $24, $21,0 ; addiu $7,$7,-2 ;
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x15a:
op_0x35a:
op_0x45a:
        andi $21,$6,0xFF
        addiu $17, $7, 0 ; jal _SNCPU_Write8 ; srl $24, $21,0 ; addiu $7,$7,-1 ;
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x07a:
op_0x27a:
        jal _SNCPU_Read16 ; addiu $17, $7,1 ; addiu $7,$7,2 ; move $21,$24
        andi $6,$21,0xFFFF
        sll $18,$21,0
        sll $19,$21,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(2 * (6))


op_0x17a:
op_0x37a:
op_0x47a:
        jal _SNCPU_Read8 ; addiu $17, $7,1 ; addiu $7,$7,1 ; move $21,$24
        andi $6,$21,0xFF
        sll $18,$21,8
        sll $19,$21,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(2 * (6))


op_0x00b:
op_0x10b:
op_0x20b:
op_0x30b:
op_0x40b:
        move $21,$13
        addiu $17, $7, 0 ; jal _SNCPU_Write8 ; srl $24, $21,8 ; addiu $17, $7, -1 ; jal _SNCPU_Write8 ; srl $24, $21,0 ; addiu $7,$7,-2 ;
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x02b:
op_0x12b:
op_0x22b:
op_0x32b:
op_0x42b:
        jal _SNCPU_Read16 ; addiu $17, $7,1 ; addiu $7,$7,2 ; move $21,$24
        move $13,$21
        sll $18,$21,0
        sll $19,$21,0
        j _SNCPUExecute_Loop ; addiu $2,$2, -(2 * (6))


op_0x08b:
op_0x18b:
op_0x28b:
op_0x38b:
op_0x48b:
        move $21,$14
        srl $21,$21,16
        addiu $17, $7, 0 ; jal _SNCPU_Write8 ; srl $24, $21,0 ; addiu $7,$7,-1 ;
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x0ab:
op_0x1ab:
op_0x2ab:
op_0x3ab:
op_0x4ab:
        jal _SNCPU_Read8 ; addiu $17, $7,1 ; addiu $7,$7,1 ; move $21,$24
        sll $18,$21,8
        sll $19,$21,8
        sll $21,$21,16
        move $14,$21
        j _SNCPUExecute_Loop ; addiu $2,$2, -(2 * (6))


op_0x0eb:
op_0x1eb:
op_0x2eb:
op_0x3eb:
op_0x4eb:
        andi $21,$4,0xFFFF
        andi $22,$4,0xFFFF
        srl $21,$21,8
        sll $22,$22,8
        or $22,$22,$21
        andi $4,$22,0xFFFF
        sll $18,$21,8
        sll $19,$21,8
        j _SNCPUExecute_Loop ; addiu $2,$2, -(2 * (6))


op_0x000:
op_0x100:
op_0x200:
op_0x300:
        lwu $8,0x58($29) ; subu $23, $3, $8
        addiu $23,$23,1
        addiu $17, $7, 0 ; jal _SNCPU_Write8 ; srl $24, $23,16 ; addiu $17, $7, -1 ; jal _SNCPU_Write8 ; srl $24, $23,8 ; addiu $17, $7, -2 ; jal _SNCPU_Write8 ; srl $24, $23,0 ; addiu $7,$7,-3 ;
        jal _SNCPU_ComposeFlags ; nop ; move $21,$12
        addiu $17, $7, 0 ; jal _SNCPU_Write8 ; srl $24, $21,0 ; addiu $7,$7,-1 ;
        andi $12,$12,0x08^0xFFFF
        ori $12,$12,0x04
        li $21,65510
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        move $3,$21 ; sw $0, 0x58($29) ; lui $11,0xC000 ; sw $3,12($16)
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x002:
op_0x102:
op_0x202:
op_0x302:
op_0x402:
        lwu $8,0x58($29) ; subu $23, $3, $8
        addiu $23,$23,1
        addiu $17, $7, 0 ; jal _SNCPU_Write8 ; srl $24, $23,16 ; addiu $17, $7, -1 ; jal _SNCPU_Write8 ; srl $24, $23,8 ; addiu $17, $7, -2 ; jal _SNCPU_Write8 ; srl $24, $23,0 ; addiu $7,$7,-3 ;
        jal _SNCPU_ComposeFlags ; nop ; move $21,$12
        addiu $17, $7, 0 ; jal _SNCPU_Write8 ; srl $24, $21,0 ; addiu $7,$7,-1 ;
        andi $12,$12,0x08^0xFFFF
        ori $12,$12,0x04
        li $21,65508
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        move $3,$21 ; sw $0, 0x58($29) ; lui $11,0xC000 ; sw $3,12($16)
        j _SNCPUExecute_Loop ; addiu $2,$2, -(1 * (6))


op_0x400:
        lwu $8,0x58($29) ; subu $23, $3, $8
        addiu $23,$23,1
        addiu $17, $7, 0 ; jal _SNCPU_Write8 ; srl $24, $23,8 ; addiu $17, $7, -1 ; jal _SNCPU_Write8 ; srl $24, $23,0 ; addiu $7,$7,-2 ;
        jal _SNCPU_ComposeFlags ; nop ; move $21,$12
        addiu $17, $7, 0 ; jal _SNCPU_Write8 ; srl $24, $21,0 ; addiu $7,$7,-1 ;
        andi $12,$12,0x08^0xFFFF
        ori $12,$12,0x04
        li $21,65526
        jal _SNCPU_Read16 ; move $17, $21 ; move $21,$24
        move $3,$21 ; sw $0, 0x58($29) ; lui $11,0xC000 ; sw $3,12($16)
        j _SNCPUExecute_Loop ; addiu $2,$2, -(2 * (6))

_SNCPU_OpTable:
.word op_0x000
.word op_0x001
.word op_0x002
.word op_0x003
.word op_0x004
.word op_0x005
.word op_0x006
.word op_0x007
.word op_0x008
.word op_0x009
.word op_0x00a
.word op_0x00b
.word op_0x00c
.word op_0x00d
.word op_0x00e
.word op_0x00f
.word op_0x010
.word op_0x011
.word op_0x012
.word op_0x013
.word op_0x014
.word op_0x015
.word op_0x016
.word op_0x017
.word op_0x018
.word op_0x019
.word op_0x01a
.word op_0x01b
.word op_0x01c
.word op_0x01d
.word op_0x01e
.word op_0x01f
.word op_0x020
.word op_0x021
.word op_0x022
.word op_0x023
.word op_0x024
.word op_0x025
.word op_0x026
.word op_0x027
.word op_0x028
.word op_0x029
.word op_0x02a
.word op_0x02b
.word op_0x02c
.word op_0x02d
.word op_0x02e
.word op_0x02f
.word op_0x030
.word op_0x031
.word op_0x032
.word op_0x033
.word op_0x034
.word op_0x035
.word op_0x036
.word op_0x037
.word op_0x038
.word op_0x039
.word op_0x03a
.word op_0x03b
.word op_0x03c
.word op_0x03d
.word op_0x03e
.word op_0x03f
.word op_0x040
.word op_0x041
.word op_0x042
.word op_0x043
.word op_0x044
.word op_0x045
.word op_0x046
.word op_0x047
.word op_0x048
.word op_0x049
.word op_0x04a
.word op_0x04b
.word op_0x04c
.word op_0x04d
.word op_0x04e
.word op_0x04f
.word op_0x050
.word op_0x051
.word op_0x052
.word op_0x053
.word op_0x054
.word op_0x055
.word op_0x056
.word op_0x057
.word op_0x058
.word op_0x059
.word op_0x05a
.word op_0x05b
.word op_0x05c
.word op_0x05d
.word op_0x05e
.word op_0x05f
.word op_0x060
.word op_0x061
.word op_0x062
.word op_0x063
.word op_0x064
.word op_0x065
.word op_0x066
.word op_0x067
.word op_0x068
.word op_0x069
.word op_0x06a
.word op_0x06b
.word op_0x06c
.word op_0x06d
.word op_0x06e
.word op_0x06f
.word op_0x070
.word op_0x071
.word op_0x072
.word op_0x073
.word op_0x074
.word op_0x075
.word op_0x076
.word op_0x077
.word op_0x078
.word op_0x079
.word op_0x07a
.word op_0x07b
.word op_0x07c
.word op_0x07d
.word op_0x07e
.word op_0x07f
.word op_0x080
.word op_0x081
.word op_0x082
.word op_0x083
.word op_0x084
.word op_0x085
.word op_0x086
.word op_0x087
.word op_0x088
.word op_0x089
.word op_0x08a
.word op_0x08b
.word op_0x08c
.word op_0x08d
.word op_0x08e
.word op_0x08f
.word op_0x090
.word op_0x091
.word op_0x092
.word op_0x093
.word op_0x094
.word op_0x095
.word op_0x096
.word op_0x097
.word op_0x098
.word op_0x099
.word op_0x09a
.word op_0x09b
.word op_0x09c
.word op_0x09d
.word op_0x09e
.word op_0x09f
.word op_0x0a0
.word op_0x0a1
.word op_0x0a2
.word op_0x0a3
.word op_0x0a4
.word op_0x0a5
.word op_0x0a6
.word op_0x0a7
.word op_0x0a8
.word op_0x0a9
.word op_0x0aa
.word op_0x0ab
.word op_0x0ac
.word op_0x0ad
.word op_0x0ae
.word op_0x0af
.word op_0x0b0
.word op_0x0b1
.word op_0x0b2
.word op_0x0b3
.word op_0x0b4
.word op_0x0b5
.word op_0x0b6
.word op_0x0b7
.word op_0x0b8
.word op_0x0b9
.word op_0x0ba
.word op_0x0bb
.word op_0x0bc
.word op_0x0bd
.word op_0x0be
.word op_0x0bf
.word op_0x0c0
.word op_0x0c1
.word op_0x0c2
.word op_0x0c3
.word op_0x0c4
.word op_0x0c5
.word op_0x0c6
.word op_0x0c7
.word op_0x0c8
.word op_0x0c9
.word op_0x0ca
.word op_0x0cb
.word op_0x0cc
.word op_0x0cd
.word op_0x0ce
.word op_0x0cf
.word op_0x0d0
.word op_0x0d1
.word op_0x0d2
.word op_0x0d3
.word op_0x0d4
.word op_0x0d5
.word op_0x0d6
.word op_0x0d7
.word op_0x0d8
.word op_0x0d9
.word op_0x0da
.word op_0x0db
.word op_0x0dc
.word op_0x0dd
.word op_0x0de
.word op_0x0df
.word op_0x0e0
.word op_0x0e1
.word op_0x0e2
.word op_0x0e3
.word op_0x0e4
.word op_0x0e5
.word op_0x0e6
.word op_0x0e7
.word op_0x0e8
.word op_0x0e9
.word op_0x0ea
.word op_0x0eb
.word op_0x0ec
.word op_0x0ed
.word op_0x0ee
.word op_0x0ef
.word op_0x0f0
.word op_0x0f1
.word op_0x0f2
.word op_0x0f3
.word op_0x0f4
.word op_0x0f5
.word op_0x0f6
.word op_0x0f7
.word op_0x0f8
.word op_0x0f9
.word op_0x0fa
.word op_0x0fb
.word op_0x0fc
.word op_0x0fd
.word op_0x0fe
.word op_0x0ff
.word op_0x100
.word op_0x101
.word op_0x102
.word op_0x103
.word op_0x104
.word op_0x105
.word op_0x106
.word op_0x107
.word op_0x108
.word op_0x109
.word op_0x10a
.word op_0x10b
.word op_0x10c
.word op_0x10d
.word op_0x10e
.word op_0x10f
.word op_0x110
.word op_0x111
.word op_0x112
.word op_0x113
.word op_0x114
.word op_0x115
.word op_0x116
.word op_0x117
.word op_0x118
.word op_0x119
.word op_0x11a
.word op_0x11b
.word op_0x11c
.word op_0x11d
.word op_0x11e
.word op_0x11f
.word op_0x120
.word op_0x121
.word op_0x122
.word op_0x123
.word op_0x124
.word op_0x125
.word op_0x126
.word op_0x127
.word op_0x128
.word op_0x129
.word op_0x12a
.word op_0x12b
.word op_0x12c
.word op_0x12d
.word op_0x12e
.word op_0x12f
.word op_0x130
.word op_0x131
.word op_0x132
.word op_0x133
.word op_0x134
.word op_0x135
.word op_0x136
.word op_0x137
.word op_0x138
.word op_0x139
.word op_0x13a
.word op_0x13b
.word op_0x13c
.word op_0x13d
.word op_0x13e
.word op_0x13f
.word op_0x140
.word op_0x141
.word op_0x142
.word op_0x143
.word op_0x144
.word op_0x145
.word op_0x146
.word op_0x147
.word op_0x148
.word op_0x149
.word op_0x14a
.word op_0x14b
.word op_0x14c
.word op_0x14d
.word op_0x14e
.word op_0x14f
.word op_0x150
.word op_0x151
.word op_0x152
.word op_0x153
.word op_0x154
.word op_0x155
.word op_0x156
.word op_0x157
.word op_0x158
.word op_0x159
.word op_0x15a
.word op_0x15b
.word op_0x15c
.word op_0x15d
.word op_0x15e
.word op_0x15f
.word op_0x160
.word op_0x161
.word op_0x162
.word op_0x163
.word op_0x164
.word op_0x165
.word op_0x166
.word op_0x167
.word op_0x168
.word op_0x169
.word op_0x16a
.word op_0x16b
.word op_0x16c
.word op_0x16d
.word op_0x16e
.word op_0x16f
.word op_0x170
.word op_0x171
.word op_0x172
.word op_0x173
.word op_0x174
.word op_0x175
.word op_0x176
.word op_0x177
.word op_0x178
.word op_0x179
.word op_0x17a
.word op_0x17b
.word op_0x17c
.word op_0x17d
.word op_0x17e
.word op_0x17f
.word op_0x180
.word op_0x181
.word op_0x182
.word op_0x183
.word op_0x184
.word op_0x185
.word op_0x186
.word op_0x187
.word op_0x188
.word op_0x189
.word op_0x18a
.word op_0x18b
.word op_0x18c
.word op_0x18d
.word op_0x18e
.word op_0x18f
.word op_0x190
.word op_0x191
.word op_0x192
.word op_0x193
.word op_0x194
.word op_0x195
.word op_0x196
.word op_0x197
.word op_0x198
.word op_0x199
.word op_0x19a
.word op_0x19b
.word op_0x19c
.word op_0x19d
.word op_0x19e
.word op_0x19f
.word op_0x1a0
.word op_0x1a1
.word op_0x1a2
.word op_0x1a3
.word op_0x1a4
.word op_0x1a5
.word op_0x1a6
.word op_0x1a7
.word op_0x1a8
.word op_0x1a9
.word op_0x1aa
.word op_0x1ab
.word op_0x1ac
.word op_0x1ad
.word op_0x1ae
.word op_0x1af
.word op_0x1b0
.word op_0x1b1
.word op_0x1b2
.word op_0x1b3
.word op_0x1b4
.word op_0x1b5
.word op_0x1b6
.word op_0x1b7
.word op_0x1b8
.word op_0x1b9
.word op_0x1ba
.word op_0x1bb
.word op_0x1bc
.word op_0x1bd
.word op_0x1be
.word op_0x1bf
.word op_0x1c0
.word op_0x1c1
.word op_0x1c2
.word op_0x1c3
.word op_0x1c4
.word op_0x1c5
.word op_0x1c6
.word op_0x1c7
.word op_0x1c8
.word op_0x1c9
.word op_0x1ca
.word op_0x1cb
.word op_0x1cc
.word op_0x1cd
.word op_0x1ce
.word op_0x1cf
.word op_0x1d0
.word op_0x1d1
.word op_0x1d2
.word op_0x1d3
.word op_0x1d4
.word op_0x1d5
.word op_0x1d6
.word op_0x1d7
.word op_0x1d8
.word op_0x1d9
.word op_0x1da
.word op_0x1db
.word op_0x1dc
.word op_0x1dd
.word op_0x1de
.word op_0x1df
.word op_0x1e0
.word op_0x1e1
.word op_0x1e2
.word op_0x1e3
.word op_0x1e4
.word op_0x1e5
.word op_0x1e6
.word op_0x1e7
.word op_0x1e8
.word op_0x1e9
.word op_0x1ea
.word op_0x1eb
.word op_0x1ec
.word op_0x1ed
.word op_0x1ee
.word op_0x1ef
.word op_0x1f0
.word op_0x1f1
.word op_0x1f2
.word op_0x1f3
.word op_0x1f4
.word op_0x1f5
.word op_0x1f6
.word op_0x1f7
.word op_0x1f8
.word op_0x1f9
.word op_0x1fa
.word op_0x1fb
.word op_0x1fc
.word op_0x1fd
.word op_0x1fe
.word op_0x1ff
.word op_0x200
.word op_0x201
.word op_0x202
.word op_0x203
.word op_0x204
.word op_0x205
.word op_0x206
.word op_0x207
.word op_0x208
.word op_0x209
.word op_0x20a
.word op_0x20b
.word op_0x20c
.word op_0x20d
.word op_0x20e
.word op_0x20f
.word op_0x210
.word op_0x211
.word op_0x212
.word op_0x213
.word op_0x214
.word op_0x215
.word op_0x216
.word op_0x217
.word op_0x218
.word op_0x219
.word op_0x21a
.word op_0x21b
.word op_0x21c
.word op_0x21d
.word op_0x21e
.word op_0x21f
.word op_0x220
.word op_0x221
.word op_0x222
.word op_0x223
.word op_0x224
.word op_0x225
.word op_0x226
.word op_0x227
.word op_0x228
.word op_0x229
.word op_0x22a
.word op_0x22b
.word op_0x22c
.word op_0x22d
.word op_0x22e
.word op_0x22f
.word op_0x230
.word op_0x231
.word op_0x232
.word op_0x233
.word op_0x234
.word op_0x235
.word op_0x236
.word op_0x237
.word op_0x238
.word op_0x239
.word op_0x23a
.word op_0x23b
.word op_0x23c
.word op_0x23d
.word op_0x23e
.word op_0x23f
.word op_0x240
.word op_0x241
.word op_0x242
.word op_0x243
.word op_0x244
.word op_0x245
.word op_0x246
.word op_0x247
.word op_0x248
.word op_0x249
.word op_0x24a
.word op_0x24b
.word op_0x24c
.word op_0x24d
.word op_0x24e
.word op_0x24f
.word op_0x250
.word op_0x251
.word op_0x252
.word op_0x253
.word op_0x254
.word op_0x255
.word op_0x256
.word op_0x257
.word op_0x258
.word op_0x259
.word op_0x25a
.word op_0x25b
.word op_0x25c
.word op_0x25d
.word op_0x25e
.word op_0x25f
.word op_0x260
.word op_0x261
.word op_0x262
.word op_0x263
.word op_0x264
.word op_0x265
.word op_0x266
.word op_0x267
.word op_0x268
.word op_0x269
.word op_0x26a
.word op_0x26b
.word op_0x26c
.word op_0x26d
.word op_0x26e
.word op_0x26f
.word op_0x270
.word op_0x271
.word op_0x272
.word op_0x273
.word op_0x274
.word op_0x275
.word op_0x276
.word op_0x277
.word op_0x278
.word op_0x279
.word op_0x27a
.word op_0x27b
.word op_0x27c
.word op_0x27d
.word op_0x27e
.word op_0x27f
.word op_0x280
.word op_0x281
.word op_0x282
.word op_0x283
.word op_0x284
.word op_0x285
.word op_0x286
.word op_0x287
.word op_0x288
.word op_0x289
.word op_0x28a
.word op_0x28b
.word op_0x28c
.word op_0x28d
.word op_0x28e
.word op_0x28f
.word op_0x290
.word op_0x291
.word op_0x292
.word op_0x293
.word op_0x294
.word op_0x295
.word op_0x296
.word op_0x297
.word op_0x298
.word op_0x299
.word op_0x29a
.word op_0x29b
.word op_0x29c
.word op_0x29d
.word op_0x29e
.word op_0x29f
.word op_0x2a0
.word op_0x2a1
.word op_0x2a2
.word op_0x2a3
.word op_0x2a4
.word op_0x2a5
.word op_0x2a6
.word op_0x2a7
.word op_0x2a8
.word op_0x2a9
.word op_0x2aa
.word op_0x2ab
.word op_0x2ac
.word op_0x2ad
.word op_0x2ae
.word op_0x2af
.word op_0x2b0
.word op_0x2b1
.word op_0x2b2
.word op_0x2b3
.word op_0x2b4
.word op_0x2b5
.word op_0x2b6
.word op_0x2b7
.word op_0x2b8
.word op_0x2b9
.word op_0x2ba
.word op_0x2bb
.word op_0x2bc
.word op_0x2bd
.word op_0x2be
.word op_0x2bf
.word op_0x2c0
.word op_0x2c1
.word op_0x2c2
.word op_0x2c3
.word op_0x2c4
.word op_0x2c5
.word op_0x2c6
.word op_0x2c7
.word op_0x2c8
.word op_0x2c9
.word op_0x2ca
.word op_0x2cb
.word op_0x2cc
.word op_0x2cd
.word op_0x2ce
.word op_0x2cf
.word op_0x2d0
.word op_0x2d1
.word op_0x2d2
.word op_0x2d3
.word op_0x2d4
.word op_0x2d5
.word op_0x2d6
.word op_0x2d7
.word op_0x2d8
.word op_0x2d9
.word op_0x2da
.word op_0x2db
.word op_0x2dc
.word op_0x2dd
.word op_0x2de
.word op_0x2df
.word op_0x2e0
.word op_0x2e1
.word op_0x2e2
.word op_0x2e3
.word op_0x2e4
.word op_0x2e5
.word op_0x2e6
.word op_0x2e7
.word op_0x2e8
.word op_0x2e9
.word op_0x2ea
.word op_0x2eb
.word op_0x2ec
.word op_0x2ed
.word op_0x2ee
.word op_0x2ef
.word op_0x2f0
.word op_0x2f1
.word op_0x2f2
.word op_0x2f3
.word op_0x2f4
.word op_0x2f5
.word op_0x2f6
.word op_0x2f7
.word op_0x2f8
.word op_0x2f9
.word op_0x2fa
.word op_0x2fb
.word op_0x2fc
.word op_0x2fd
.word op_0x2fe
.word op_0x2ff
.word op_0x300
.word op_0x301
.word op_0x302
.word op_0x303
.word op_0x304
.word op_0x305
.word op_0x306
.word op_0x307
.word op_0x308
.word op_0x309
.word op_0x30a
.word op_0x30b
.word op_0x30c
.word op_0x30d
.word op_0x30e
.word op_0x30f
.word op_0x310
.word op_0x311
.word op_0x312
.word op_0x313
.word op_0x314
.word op_0x315
.word op_0x316
.word op_0x317
.word op_0x318
.word op_0x319
.word op_0x31a
.word op_0x31b
.word op_0x31c
.word op_0x31d
.word op_0x31e
.word op_0x31f
.word op_0x320
.word op_0x321
.word op_0x322
.word op_0x323
.word op_0x324
.word op_0x325
.word op_0x326
.word op_0x327
.word op_0x328
.word op_0x329
.word op_0x32a
.word op_0x32b
.word op_0x32c
.word op_0x32d
.word op_0x32e
.word op_0x32f
.word op_0x330
.word op_0x331
.word op_0x332
.word op_0x333
.word op_0x334
.word op_0x335
.word op_0x336
.word op_0x337
.word op_0x338
.word op_0x339
.word op_0x33a
.word op_0x33b
.word op_0x33c
.word op_0x33d
.word op_0x33e
.word op_0x33f
.word op_0x340
.word op_0x341
.word op_0x342
.word op_0x343
.word op_0x344
.word op_0x345
.word op_0x346
.word op_0x347
.word op_0x348
.word op_0x349
.word op_0x34a
.word op_0x34b
.word op_0x34c
.word op_0x34d
.word op_0x34e
.word op_0x34f
.word op_0x350
.word op_0x351
.word op_0x352
.word op_0x353
.word op_0x354
.word op_0x355
.word op_0x356
.word op_0x357
.word op_0x358
.word op_0x359
.word op_0x35a
.word op_0x35b
.word op_0x35c
.word op_0x35d
.word op_0x35e
.word op_0x35f
.word op_0x360
.word op_0x361
.word op_0x362
.word op_0x363
.word op_0x364
.word op_0x365
.word op_0x366
.word op_0x367
.word op_0x368
.word op_0x369
.word op_0x36a
.word op_0x36b
.word op_0x36c
.word op_0x36d
.word op_0x36e
.word op_0x36f
.word op_0x370
.word op_0x371
.word op_0x372
.word op_0x373
.word op_0x374
.word op_0x375
.word op_0x376
.word op_0x377
.word op_0x378
.word op_0x379
.word op_0x37a
.word op_0x37b
.word op_0x37c
.word op_0x37d
.word op_0x37e
.word op_0x37f
.word op_0x380
.word op_0x381
.word op_0x382
.word op_0x383
.word op_0x384
.word op_0x385
.word op_0x386
.word op_0x387
.word op_0x388
.word op_0x389
.word op_0x38a
.word op_0x38b
.word op_0x38c
.word op_0x38d
.word op_0x38e
.word op_0x38f
.word op_0x390
.word op_0x391
.word op_0x392
.word op_0x393
.word op_0x394
.word op_0x395
.word op_0x396
.word op_0x397
.word op_0x398
.word op_0x399
.word op_0x39a
.word op_0x39b
.word op_0x39c
.word op_0x39d
.word op_0x39e
.word op_0x39f
.word op_0x3a0
.word op_0x3a1
.word op_0x3a2
.word op_0x3a3
.word op_0x3a4
.word op_0x3a5
.word op_0x3a6
.word op_0x3a7
.word op_0x3a8
.word op_0x3a9
.word op_0x3aa
.word op_0x3ab
.word op_0x3ac
.word op_0x3ad
.word op_0x3ae
.word op_0x3af
.word op_0x3b0
.word op_0x3b1
.word op_0x3b2
.word op_0x3b3
.word op_0x3b4
.word op_0x3b5
.word op_0x3b6
.word op_0x3b7
.word op_0x3b8
.word op_0x3b9
.word op_0x3ba
.word op_0x3bb
.word op_0x3bc
.word op_0x3bd
.word op_0x3be
.word op_0x3bf
.word op_0x3c0
.word op_0x3c1
.word op_0x3c2
.word op_0x3c3
.word op_0x3c4
.word op_0x3c5
.word op_0x3c6
.word op_0x3c7
.word op_0x3c8
.word op_0x3c9
.word op_0x3ca
.word op_0x3cb
.word op_0x3cc
.word op_0x3cd
.word op_0x3ce
.word op_0x3cf
.word op_0x3d0
.word op_0x3d1
.word op_0x3d2
.word op_0x3d3
.word op_0x3d4
.word op_0x3d5
.word op_0x3d6
.word op_0x3d7
.word op_0x3d8
.word op_0x3d9
.word op_0x3da
.word op_0x3db
.word op_0x3dc
.word op_0x3dd
.word op_0x3de
.word op_0x3df
.word op_0x3e0
.word op_0x3e1
.word op_0x3e2
.word op_0x3e3
.word op_0x3e4
.word op_0x3e5
.word op_0x3e6
.word op_0x3e7
.word op_0x3e8
.word op_0x3e9
.word op_0x3ea
.word op_0x3eb
.word op_0x3ec
.word op_0x3ed
.word op_0x3ee
.word op_0x3ef
.word op_0x3f0
.word op_0x3f1
.word op_0x3f2
.word op_0x3f3
.word op_0x3f4
.word op_0x3f5
.word op_0x3f6
.word op_0x3f7
.word op_0x3f8
.word op_0x3f9
.word op_0x3fa
.word op_0x3fb
.word op_0x3fc
.word op_0x3fd
.word op_0x3fe
.word op_0x3ff
.word op_0x400
.word op_0x401
.word op_0x402
.word op_0x403
.word op_0x404
.word op_0x405
.word op_0x406
.word op_0x407
.word op_0x408
.word op_0x409
.word op_0x40a
.word op_0x40b
.word op_0x40c
.word op_0x40d
.word op_0x40e
.word op_0x40f
.word op_0x410
.word op_0x411
.word op_0x412
.word op_0x413
.word op_0x414
.word op_0x415
.word op_0x416
.word op_0x417
.word op_0x418
.word op_0x419
.word op_0x41a
.word op_0x41b
.word op_0x41c
.word op_0x41d
.word op_0x41e
.word op_0x41f
.word op_0x420
.word op_0x421
.word op_0x422
.word op_0x423
.word op_0x424
.word op_0x425
.word op_0x426
.word op_0x427
.word op_0x428
.word op_0x429
.word op_0x42a
.word op_0x42b
.word op_0x42c
.word op_0x42d
.word op_0x42e
.word op_0x42f
.word op_0x430
.word op_0x431
.word op_0x432
.word op_0x433
.word op_0x434
.word op_0x435
.word op_0x436
.word op_0x437
.word op_0x438
.word op_0x439
.word op_0x43a
.word op_0x43b
.word op_0x43c
.word op_0x43d
.word op_0x43e
.word op_0x43f
.word op_0x440
.word op_0x441
.word op_0x442
.word op_0x443
.word op_0x444
.word op_0x445
.word op_0x446
.word op_0x447
.word op_0x448
.word op_0x449
.word op_0x44a
.word op_0x44b
.word op_0x44c
.word op_0x44d
.word op_0x44e
.word op_0x44f
.word op_0x450
.word op_0x451
.word op_0x452
.word op_0x453
.word op_0x454
.word op_0x455
.word op_0x456
.word op_0x457
.word op_0x458
.word op_0x459
.word op_0x45a
.word op_0x45b
.word op_0x45c
.word op_0x45d
.word op_0x45e
.word op_0x45f
.word op_0x460
.word op_0x461
.word op_0x462
.word op_0x463
.word op_0x464
.word op_0x465
.word op_0x466
.word op_0x467
.word op_0x468
.word op_0x469
.word op_0x46a
.word op_0x46b
.word op_0x46c
.word op_0x46d
.word op_0x46e
.word op_0x46f
.word op_0x470
.word op_0x471
.word op_0x472
.word op_0x473
.word op_0x474
.word op_0x475
.word op_0x476
.word op_0x477
.word op_0x478
.word op_0x479
.word op_0x47a
.word op_0x47b
.word op_0x47c
.word op_0x47d
.word op_0x47e
.word op_0x47f
.word op_0x480
.word op_0x481
.word op_0x482
.word op_0x483
.word op_0x484
.word op_0x485
.word op_0x486
.word op_0x487
.word op_0x488
.word op_0x489
.word op_0x48a
.word op_0x48b
.word op_0x48c
.word op_0x48d
.word op_0x48e
.word op_0x48f
.word op_0x490
.word op_0x491
.word op_0x492
.word op_0x493
.word op_0x494
.word op_0x495
.word op_0x496
.word op_0x497
.word op_0x498
.word op_0x499
.word op_0x49a
.word op_0x49b
.word op_0x49c
.word op_0x49d
.word op_0x49e
.word op_0x49f
.word op_0x4a0
.word op_0x4a1
.word op_0x4a2
.word op_0x4a3
.word op_0x4a4
.word op_0x4a5
.word op_0x4a6
.word op_0x4a7
.word op_0x4a8
.word op_0x4a9
.word op_0x4aa
.word op_0x4ab
.word op_0x4ac
.word op_0x4ad
.word op_0x4ae
.word op_0x4af
.word op_0x4b0
.word op_0x4b1
.word op_0x4b2
.word op_0x4b3
.word op_0x4b4
.word op_0x4b5
.word op_0x4b6
.word op_0x4b7
.word op_0x4b8
.word op_0x4b9
.word op_0x4ba
.word op_0x4bb
.word op_0x4bc
.word op_0x4bd
.word op_0x4be
.word op_0x4bf
.word op_0x4c0
.word op_0x4c1
.word op_0x4c2
.word op_0x4c3
.word op_0x4c4
.word op_0x4c5
.word op_0x4c6
.word op_0x4c7
.word op_0x4c8
.word op_0x4c9
.word op_0x4ca
.word op_0x4cb
.word op_0x4cc
.word op_0x4cd
.word op_0x4ce
.word op_0x4cf
.word op_0x4d0
.word op_0x4d1
.word op_0x4d2
.word op_0x4d3
.word op_0x4d4
.word op_0x4d5
.word op_0x4d6
.word op_0x4d7
.word op_0x4d8
.word op_0x4d9
.word op_0x4da
.word op_0x4db
.word op_0x4dc
.word op_0x4dd
.word op_0x4de
.word op_0x4df
.word op_0x4e0
.word op_0x4e1
.word op_0x4e2
.word op_0x4e3
.word op_0x4e4
.word op_0x4e5
.word op_0x4e6
.word op_0x4e7
.word op_0x4e8
.word op_0x4e9
.word op_0x4ea
.word op_0x4eb
.word op_0x4ec
.word op_0x4ed
.word op_0x4ee
.word op_0x4ef
.word op_0x4f0
.word op_0x4f1
.word op_0x4f2
.word op_0x4f3
.word op_0x4f4
.word op_0x4f5
.word op_0x4f6
.word op_0x4f7
.word op_0x4f8
.word op_0x4f9
.word op_0x4fa
.word op_0x4fb
.word op_0x4fc
.word op_0x4fd
.word op_0x4fe
.word op_0x4ff

# 1992 "../../Source/ps2/sn65816.S" 2
