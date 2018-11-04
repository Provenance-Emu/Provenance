#pragma once
#include "shil.h"
#include "../sh4_if.h"

#define mkbet(c,s,v) ((c<<3)|(s<<1)|v)
#define BET_GET_CLS(x) (x>>3)

enum BlockEndType
{
	BET_CLS_Static=0,
	BET_CLS_Dynamic=1,
	BET_CLS_COND=2,

	BET_SCL_Jump=0,
	BET_SCL_Call=1,
	BET_SCL_Ret=2,
	BET_SCL_Intr=3,
	

	BET_StaticJump=mkbet(BET_CLS_Static,BET_SCL_Jump,0),    //BranchBlock is jump target
	BET_StaticCall=mkbet(BET_CLS_Static,BET_SCL_Call,0),    //BranchBlock is jump target, NextBlock is ret hint
	BET_StaticIntr=mkbet(BET_CLS_Static,BET_SCL_Intr,0),    //(pending inttr!=0) -> Intr else NextBlock

	BET_DynamicJump=mkbet(BET_CLS_Dynamic,BET_SCL_Jump,0),  //pc+2 is jump target
	BET_DynamicCall=mkbet(BET_CLS_Dynamic,BET_SCL_Call,0),  //pc+2 is jump target, NextBlock is ret hint
	BET_DynamicRet=mkbet(BET_CLS_Dynamic,BET_SCL_Ret,0),    //pr is jump target
	BET_DynamicIntr=mkbet(BET_CLS_Dynamic,BET_SCL_Intr,0),  //(pending inttr!=0) -> Intr else Dynamic

	BET_Cond_0=mkbet(BET_CLS_COND,BET_SCL_Jump,0),          //sr.T==0 -> BranchBlock else NextBlock
	BET_Cond_1=mkbet(BET_CLS_COND,BET_SCL_Jump,1),          //sr.T==1 -> BranchBlock else NextBlock
};

struct RuntimeBlockInfo;
void dec_DecodeBlock(RuntimeBlockInfo* rbi,u32 max_cycles);

