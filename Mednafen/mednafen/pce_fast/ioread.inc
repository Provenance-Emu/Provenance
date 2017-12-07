 A &= 0x1FFF;

#if HAVE_COMPUTED_GOTO
 const void * const IOReadHandlers[0x20] =
 {
  &&VDC_00, &&VDC_01, &&VDC_02, &&VDC_03,
  &&VCE_00, &&VCE_01, &&VCE_02, &&VCE_03,
  &&PSG_00, &&PSG_01, &&PSG_02, &&PSG_03,
  &&TIMER_00, &&TIMER_01, &&TIMER_02, &&TIMER_03,
  &&INPUT_00, &&INPUT_01, &&INPUT_02, &&INPUT_03,
  &&IRQ_00, &&IRQ_01, &&IRQ_02, &&IRQ_03,
  &&CDROM_00, &&CDROM_01, &&CDROM_02, &&CDROM_03,
  &&EXP_00, &&EXP_01, &&EXP_02, &&EXP_03
 };

 goto *IOReadHandlers[((A & 0x1C00) >> 8) | (A & 0x3)];
 {
 #define PCEF_CASEL(label, caseval) label
#else
 #define PCEF_CASEL(label, caseval) case (caseval)

 switch(((A & 0x1C00) >> 8) | (A & 0x3))
 {
#endif
//
//
//

#if IOREAD_SGX==1
  PCEF_CASEL(VDC_00, 0x00):
  PCEF_CASEL(VDC_01, 0x01):
  PCEF_CASEL(VDC_02, 0x02):
  PCEF_CASEL(VDC_03, 0x03):
	  HuC6280_StealCycle();
	  return(VDC_Read(A & 0x1F, TRUE));
#else

 PCEF_CASEL(VDC_00, 0x00):
        HuC6280_StealCycle();
        return(VDC_Read(0, FALSE));

 PCEF_CASEL(VDC_01, 0x01):
        HuC6280_StealCycle();
        return(VDC_Read(1, FALSE));

 PCEF_CASEL(VDC_02, 0x02):
        HuC6280_StealCycle();
        return(VDC_Read(2, FALSE));

 PCEF_CASEL(VDC_03, 0x03):
        HuC6280_StealCycle();
        return(VDC_Read(3, FALSE));
#endif

 PCEF_CASEL(VCE_00, 0x04):
 PCEF_CASEL(VCE_01, 0x05):
 PCEF_CASEL(VCE_02, 0x06):
 PCEF_CASEL(VCE_03, 0x07):
        HuC6280_StealCycle();
        return(VCE_Read(A));

 PCEF_CASEL(PSG_00, 0x08):
 PCEF_CASEL(PSG_01, 0x09):
 PCEF_CASEL(PSG_02, 0x0A):
 PCEF_CASEL(PSG_03, 0x0B):
        if(HuCPU.in_block_move)
         return(0);
        return(PCEIODataBuffer);


 PCEF_CASEL(TIMER_00, 0x0C):
 PCEF_CASEL(TIMER_01, 0x0D):
 PCEF_CASEL(TIMER_02, 0x0E):
 PCEF_CASEL(TIMER_03, 0x0F):
        if(HuCPU.in_block_move)
         return(0);
        {
         uint8 ret = HuC6280_TimerRead(A);
         PCEIODataBuffer = ret;
         return(ret);
        }

 PCEF_CASEL(INPUT_00, 0x10):
 PCEF_CASEL(INPUT_01, 0x11):
 PCEF_CASEL(INPUT_02, 0x12):
 PCEF_CASEL(INPUT_03, 0x13):
               if(HuCPU.in_block_move)
                return(0);
               {
                uint8 ret = INPUT_Read(A);
                PCEIODataBuffer = ret;
                return(ret);
               }

 PCEF_CASEL(IRQ_00, 0x14):
 PCEF_CASEL(IRQ_01, 0x15):
 PCEF_CASEL(IRQ_02, 0x16):
 PCEF_CASEL(IRQ_03, 0x17):
               if(HuCPU.in_block_move)
                return(0);
               {
                uint8 ret = HuC6280_IRQStatusRead(A);
                PCEIODataBuffer = ret;
                return(ret);
               }

 PCEF_CASEL(CDROM_00, 0x18):
 PCEF_CASEL(CDROM_01, 0x19):
 PCEF_CASEL(CDROM_02, 0x1A):
 PCEF_CASEL(CDROM_03, 0x1B):
               if(!PCE_IsCD)
                return(0xFF);

               if((A & 0x1E00) == 0x1A00)
               {
                if(arcade_card)
                 return(arcade_card->Read(A & 0x1FFF));
                else
                 return(0);
               }
               else
	       {
                return(PCECD_Read(HuCPU.timestamp * 3, A));
	       }

 PCEF_CASEL(EXP_00, 0x1C):
 PCEF_CASEL(EXP_01, 0x1D):
 PCEF_CASEL(EXP_02, 0x1E):
 PCEF_CASEL(EXP_03, 0x1F):
               if(IsHES)
                return(ReadIBP(A));
	       return(0xFF);

 }
 #undef PCEF_CASEL
 //printf("Meow: %08x, %02x:%04x\n", A, A >> 13, A & 0x1FFF);
