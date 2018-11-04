#include <nds.h>

//Partial code from dsCard.cpp: http://www.ezflash.cn/zip/512triplecardsrc.rar
//Original author: aladdin
//Copyright: EZFlash Group

//Original header below

/**************************************************************************************************************
 * 此文件为 dsCard.cpp 文件的第二版 
 * 日期：2006年11月27日11点33分  第一版 version 1.0
 * 作者：aladdin
 * CopyRight : EZFlash Group
 * 
 **************************************************************************************************************/


#define FlashBase    	0x08000000
void		OpenNorWrite()
{
    *(vuint16 *)0x9fe0000 = 0xd200;
    *(vuint16 *)0x8000000 = 0x1500;
    *(vuint16 *)0x8020000 = 0xd200;
    *(vuint16 *)0x8040000 = 0x1500;
    *(vuint16 *)0x9C40000 = 0x1500;
    *(vuint16 *)0x9fc0000 = 0x1500;
}


void		CloseNorWrite()
{
    *(vuint16 *)0x9fe0000 = 0xd200;
    *(vuint16 *)0x8000000 = 0x1500;
    *(vuint16 *)0x8020000 = 0xd200;
    *(vuint16 *)0x8040000 = 0x1500;
    *(vuint16 *)0x9C40000 = 0xd200;
    *(vuint16 *)0x9fc0000 = 0x1500;
}
uint32   ReadNorFlashID()
{
        vuint16 id1,id2,id3,id4;
        uint32 ID = 0;
        //check intel 512M 3in1 card
        *((vuint16 *)(FlashBase+0)) = 0xFF ;
        *((vuint16 *)(FlashBase+0x1000*2)) = 0xFF ;
        *((vuint16 *)(FlashBase+0)) = 0x90 ;
        *((vuint16 *)(FlashBase+0x1000*2)) = 0x90 ;
        id1 = *((vuint16 *)(FlashBase+0)) ;
        id2 = *((vuint16 *)(FlashBase+0x1000*2)) ;
        id3 = *((vuint16 *)(FlashBase+1*2)) ;
        id4 = *((vuint16 *)(FlashBase+0x1001*2)) ;
        if(id3==0x8810)
            id3=0x8816;
        if(id4==0x8810)
            id4=0x8816;
        //_consolePrintf("id1=%x\,id2=%x,id3=%x,id4=%xn",id1,id2,id3,id4);
        if( (id1==0x89)&& (id2==0x89) &&(id3==0x8816) && (id4==0x8816))
        {
            ID = 0x89168916;
            return ID;
        }
        //256M
        *((vuint16 *)(FlashBase+0x555*2)) = 0xAA ;
        *((vuint16 *)(FlashBase+0x2AA*2)) = 0x55 ;
        *((vuint16 *)(FlashBase+0x555*2)) = 0x90 ;

        *((vuint16 *)(FlashBase+0x1555*2)) = 0xAA ;
        *((vuint16 *)(FlashBase+0x12AA*2)) = 0x55 ;
        *((vuint16 *)(FlashBase+0x1555*2)) = 0x90 ;

        id1 = *((vuint16 *)(FlashBase+0x2)) ;
        id2 = *((vuint16 *)(FlashBase+0x2002)) ;
        if( (id1!=0x227E)|| (id2!=0x227E))
            return 0;
        
        id1 = *((vuint16 *)(FlashBase+0xE*2)) ;
        id2 = *((vuint16 *)(FlashBase+0x100e*2)) ;
        if(id1==0x2218 && id2==0x2218)			//H6H6
        {
            ID = 0x227E2218;
            return 0x227E2218;
        }
            
        if(id1==0x2202 && id2==0x2202)			//VZ064
        {
            ID = 0x227E2202;
            return 0x227E2202;
        }
        if(id1==0x2202 && id2==0x2220)			//VZ064
        {
            ID = 0x227E2202;
            return 0x227E2202;
        }
        if(id1==0x2202 && id2==0x2215)			//VZ064
        {
            ID = 0x227E2202;
            return 0x227E2202;
        }
        
            
        return 0;
            
}
