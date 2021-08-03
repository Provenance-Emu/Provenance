 enum : unsigned { which = 1 };
 enum : bool { EmulateICache = true };
 enum : bool { DebugMode = SH7095_DEBUG_MODE };
 enum : bool { CacheBypassHack = false };

#ifdef MDFN_ENABLE_DEV_BUILD
 assert(!ResumeTableP[DebugMode] || DebugMode == DM_Setting);
#endif
 //if(this != &CPU[1])
 // __builtin_unreachable();

 if(MDFN_UNLIKELY(timestamp >= bound_timestamp))
  return;

 if(ResumePoint)
 {
  //printf("Resume: 0x%016llx\n", (unsigned long long)(uintptr_t)ResumePoint);
  const void* const tmp = ResumePoint;
  ResumePoint = nullptr;
  goto *tmp;
 }

 do
 {
  if(DebugMode)
  {
   if(MDFN_LIKELY(ResumeTableP[DebugMode]))
    DBG_CPUHandler<1>();
  }

  //
  // Ideally, we would place SPEPRecover: after the FRT event check, but doing
  // so causes gcc(multiple versions) to produce inconceivably awful code under certain conditions
  // (such as disabling all the SS_DBG stuff at compile-time) because it thinks it's an important loop
  // or something?(even with all our branch hinting!)
  //
  SPEPRecover:;

  if(MDFN_UNLIKELY(timestamp >= FRT_WDT_NextTS))
  {
   FRT_WDT_Update();
   FRT_WDT_Recalc_NET();
  }

  instr = (uint16)Pipe_ID;
  //
  #include "sh7095_ops.inc"
  //
 } while(timestamp < bound_timestamp);

