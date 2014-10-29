#ifdef SMPCORE_CPP

template<uint8 (SMP::*op)(uint8), int n>
alwaysinline void SMP::op_adjust_reg() {
  op_io();
  regs.r[n] = (this->*op)(regs.r[n]);
}

template<uint8 (SMP::*op)(uint8)>
alwaysinline void SMP::op_adjust_dp() {
  dp = op_readpc();
  rd = op_readdp(dp);
  rd = (this->*op)(rd);
  op_writedp(dp, rd);
}

template<uint8 (SMP::*op)(uint8)>
alwaysinline void SMP::op_adjust_dpx() {
  dp = op_readpc();
  op_io();
  rd = op_readdp(dp + regs.x);
  rd = (this->*op)(rd);
  op_writedp(dp + regs.x, rd);
}

template<uint8 (SMP::*op)(uint8)>
alwaysinline void SMP::op_adjust_addr() {
  dp  = op_readpc() << 0;
  dp |= op_readpc() << 8;
  rd  = op_readaddr(dp);
  rd  = (this->*op)(rd);
  op_writeaddr(dp, rd);
}

template<int op>
alwaysinline void SMP::op_adjust_addr_a() {
  dp  = op_readpc() << 0;
  dp |= op_readpc() << 8;
  rd  = op_readaddr(dp);
  regs.p.n = ((regs.a - rd) & 0x80);
  regs.p.z = ((regs.a - rd) == 0);
  op_readaddr(dp);
  op_writeaddr(dp, (op ? rd | regs.a : rd & ~regs.a));
}

template<int adjust>
alwaysinline void SMP::op_adjustw_dp() {
  dp  = op_readpc();
  rd  = op_readdp(dp) << 0;
  rd += adjust;
  op_writedp(dp++, rd);
  rd += op_readdp(dp) << 8;
  op_writedp(dp, rd >> 8);
  regs.p.n = (rd & 0x8000);
  regs.p.z = (rd == 0);
}

#endif
