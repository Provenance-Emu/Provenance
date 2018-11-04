/*
 *	disasm.h,	a horribly static yet (hopefully) correct disassembler
 *
 */
#pragma once

namespace ARM
{
	
	
	
	inline static void armdis_cc(u32 cond, char *ccbuff)	// Length is always 8 for our static'{n,m}ess
	{
		switch(cond)
		{	
		case EQ:	sprintf(ccbuff, "EQ");	return;
		case NE:	sprintf(ccbuff, "NE");	return;
		case CS:	sprintf(ccbuff, "CS");	return;
		case CC:	sprintf(ccbuff, "CC");	return;
		case MI:	sprintf(ccbuff, "MI");	return;
		case PL:	sprintf(ccbuff, "PL");	return;
		case VS:	sprintf(ccbuff, "VS");	return;
		case VC:	sprintf(ccbuff, "VC");	return;

		case HI:	sprintf(ccbuff, "HI");	return;
		case LS:	sprintf(ccbuff, "LS");	return;

		case GE:	sprintf(ccbuff, "GE");	return;
		case LT:	sprintf(ccbuff, "LT");	return;
		case GT:	sprintf(ccbuff, "GT");	return;
		case LE:	sprintf(ccbuff, "LE");	return;

		case AL:	return;		// sprintf(ccbuff, "AL");	-- ALways doesn't need to be specified

		case UC:				// 
		default:	return;		// DIE
		}
	}


	inline static void armdis_dp(u32 dpop, char *dpbuff)		// Length is always 8 ...
	{
		switch(dpop)
		{
		case DP_AND:	sprintf(dpbuff, "AND");	return;
		case DP_EOR:	sprintf(dpbuff, "EOR");	return;
		case DP_SUB:	sprintf(dpbuff, "SUB");	return;
		case DP_RSB:	sprintf(dpbuff, "RSB");	return;
		case DP_ADD:	sprintf(dpbuff, "ADD");	return;
		case DP_ADC:	sprintf(dpbuff, "ADC");	return;
		case DP_SBC:	sprintf(dpbuff, "SBC");	return;
		case DP_RSC:	sprintf(dpbuff, "RSC");	return;
		case DP_TST:	sprintf(dpbuff, "TST");	return;
		case DP_TEQ:	sprintf(dpbuff, "TEQ");	return;
		case DP_CMP:	sprintf(dpbuff, "CMP");	return;
		case DP_CMN:	sprintf(dpbuff, "CMN");	return;
		case DP_ORR:	sprintf(dpbuff, "ORR");	return;
		case DP_MOV:	sprintf(dpbuff, "MOV");	return;
		case DP_BIC:	sprintf(dpbuff, "BIC");	return;
		case DP_MVN:	sprintf(dpbuff, "MVN");	return;
		}
	}



	inline static void armdis(u32 op, char *disbuf, u32 len=512)
	{
		char ipref[8]={0}, isuff[8]={0}, icond[8]={0} ;


		//	u32 uOP = ((op>>12)&0xFF00) | ((op>>4)&255) ;

		u32 uCC = ((op>>28) & 0x0F) ;		// 

		u32 uO1 = ((op>>25) & 0x07) ;		// 
		u32 uO2 = ((op>> 4) & 0x01) ;		// 
		u32 uC1 = ((op>>21) & 0x0F) ;		// 
		u32 uC2 = ((op>> 5) & 0x07) ;		// 
		u32 uSB = ((op>>20) & 0x01) ;		// Sign Change Bit


		/*
		if (uCC == UC) {

			printf ("DBG armdis has UC instruction %X\n", op);
			sprintf (disbuf, "UNCONDITIONAL / UNHANDLED INSTRUCTION");
			return;

		}


		if (uCC != AL) {
			armdis_cc(uCC,isuff);
		}


		if (uO1 == 0) 
		{

			if (uO2 == 0) {

				if ((uC1 & 0xC) == 8) {
					printf ("DBG armdis 0:0 10xx misc instruction \n", uCC);
					sprintf (disbuf, "UNHANDLED INSTRUCTION 0:");
					return;
				}

				// DP imm.shift			



			}

			else if (uO2 == 1) {

				sprintf (disbuf, "UNHANDLED INSTRUCTION 0:");
			}

		}
		else if (uO1 == 1) {

			sprintf (disbuf, "UNHANDLED INSTRUCTION 1:");
		}
		else if (uO1 == 2) {

			sprintf (disbuf, "UNHANDLED INSTRUCTION 2:");
		}
		else if (uO1 == 3) {

			sprintf (disbuf, "UNHANDLED INSTRUCTION 3:");
		}
		else if (uO1 == 4) {

			sprintf (disbuf, "UNHANDLED INSTRUCTION 4:");
		}
		else if (uO1 == 5) {

			sprintf (disbuf, "UNHANDLED INSTRUCTION 5:");
		}
		else if (uO1 == 6) {

			sprintf (disbuf, "UNHANDLED INSTRUCTION 6:");
		}
		else if (uO1 == 7) {

			sprintf (disbuf, "UNHANDLED INSTRUCTION 7:");
		}
		else if (uO1 == 8) {

			sprintf (disbuf, "UNHANDLED INSTRUCTION 8:");
		}
		else if (uO1 == 9) {

			sprintf (disbuf, "UNHANDLED INSTRUCTION 9:");
		}
		else if (uO1 == 10) {

			sprintf (disbuf, "UNHANDLED INSTRUCTION 10:");
		}
		else if (uO1 == 11) {

			sprintf (disbuf, "UNHANDLED INSTRUCTION 11:");
		}
		else if (uO1 == 12) {

			sprintf (disbuf, "UNHANDLED INSTRUCTION 12:");
		}
		else if (uO1 == 13) {

			sprintf (disbuf, "UNHANDLED INSTRUCTION 13:");
		}
		else if (uO1 == 14) {

			sprintf (disbuf, "UNHANDLED INSTRUCTION 14:");
		}
		else if (uO1 == 15)	{

			sprintf (disbuf, "UNHANDLED INSTRUCTION 15:");
		}
		else {

			sprintf (disbuf, "INVALID INSTRUCTION");
		}
		*/
		if (!uC1 && uO1==5) {
		 //B
			char tmp[20];
			tmp[0]='\0';
			armdis_cc(uCC, tmp);
			sprintf(disbuf, "B%s %08X", tmp, (op&0xffffff)<<2);
		} else {
			armdis_dp(uC1, disbuf);
			char tmp[20];
			tmp[0]='\0';
			armdis_cc(uCC, tmp);
			if (tmp[0]) {
				strcat(disbuf, ".\0");
				strcat(disbuf, tmp);
			}
			if (uSB) strcat(disbuf, ".S\0");
			bool shifter=false;
			switch (uO1) {
				case 0:
					// reg_reg
					sprintf(tmp,"\tr%d, r%d", (op>>12)&0x0f, (op)&0x0f);
					shifter=true;
					break;
				case 1:
					// reg_imm
					sprintf(tmp,"\tr%d, %04X", (op>>16)&0x0f, (op)&0xffff);
					break;
				default:
					shifter=true;
					sprintf(tmp, " 0x%0X", uO1);
			}
			strcat(disbuf, tmp);
			char* ShiftOpStr[]={"LSL","LSR","ASR","ROR"};
			u32 shiftop=(op>>5)&0x3;
			u32 shiftoptype=(op>>4)&0x1;
			u32 shiftopreg=(op>>8)&0xf;
			u32 shiftopimm=(op>>7)&0x1f;
			if (shifter) {
				if (!shiftop && !shiftoptype && !shiftopimm)
				{
					//nothing
				} else {
					if ((shiftop==1) || (shiftop==2)) if (!shiftoptype) if (!shiftopimm) shiftopimm=32;
					sprintf(tmp, " ,%s %s%d", ShiftOpStr[shiftop], (shiftoptype)?" r":" #", (shiftoptype)?shiftopreg:shiftopimm);
					strcat(disbuf, tmp);
				}
			}
		}
	}







};

