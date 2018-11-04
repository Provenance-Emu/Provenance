case 0xbc: {
  op_io();
  regs.B.a = op_inc(regs.B.a);
  break;
}

case 0x3d: {
  op_io();
  regs.x = op_inc(regs.x);
  break;
}

case 0xfc: {
  op_io();
  regs.B.y = op_inc(regs.B.y);
  break;
}

case 0x9c: {
  op_io();
  regs.B.a = op_dec(regs.B.a);
  break;
}

case 0x1d: {
  op_io();
  regs.x = op_dec(regs.x);
  break;
}

case 0xdc: {
  op_io();
  regs.B.y = op_dec(regs.B.y);
  break;
}

case 0x1c: {
  op_io();
  regs.B.a = op_asl(regs.B.a);
  break;
}

case 0x5c: {
  op_io();
  regs.B.a = op_lsr(regs.B.a);
  break;
}

case 0x3c: {
  op_io();
  regs.B.a = op_rol(regs.B.a);
  break;
}

case 0x7c: {
  op_io();
  regs.B.a = op_ror(regs.B.a);
    break;
}

case 0xab: {
  dp = op_readpc();
  rd = op_readdp(dp);
  rd = op_inc(rd);
  op_writedp(dp, rd);
  break;
}

case 0x8b: {
  dp = op_readpc();
  rd = op_readdp(dp);
  rd = op_dec(rd);
  op_writedp(dp, rd);
  break;
}

case 0x0b: {
  dp = op_readpc();
  rd = op_readdp(dp);
  rd = op_asl(rd);
  op_writedp(dp, rd);
  break;
}

case 0x4b: {
  dp = op_readpc();
  rd = op_readdp(dp);
  rd = op_lsr(rd);
  op_writedp(dp, rd);
  break;
}

case 0x2b: {
  dp = op_readpc();
  rd = op_readdp(dp);
  rd = op_rol(rd);
  op_writedp(dp, rd);
  break;
}

case 0x6b: {
  dp = op_readpc();
  rd = op_readdp(dp);
  rd = op_ror(rd);
  op_writedp(dp, rd);
  break;
}

case 0xbb: {
  dp = op_readpc();
  op_io();
  rd = op_readdp(dp + regs.x);
  rd = op_inc(rd);
  op_writedp(dp + regs.x, rd);
  break;
}

case 0x9b: {
  dp = op_readpc();
  op_io();
  rd = op_readdp(dp + regs.x);
  rd = op_dec(rd);
  op_writedp(dp + regs.x, rd);
  break;
}

case 0x1b: {
  dp = op_readpc();
  op_io();
  rd = op_readdp(dp + regs.x);
  rd = op_asl(rd);
  op_writedp(dp + regs.x, rd);
  break;
}

case 0x5b: {
  dp = op_readpc();
  op_io();
  rd = op_readdp(dp + regs.x);
  rd = op_lsr(rd);
  op_writedp(dp + regs.x, rd);
  break;
}

case 0x3b: {
  dp = op_readpc();
  op_io();
  rd = op_readdp(dp + regs.x);
  rd = op_rol(rd);
  op_writedp(dp + regs.x, rd);
  break;
}

case 0x7b: {
  dp = op_readpc();
  op_io();
  rd = op_readdp(dp + regs.x);
  rd = op_ror(rd);
  op_writedp(dp + regs.x, rd);
  break;
}

case 0xac: {
  dp  = op_readpc();
  dp |= op_readpc() << 8;
  rd = op_readaddr(dp);
  rd = op_inc(rd);
  op_writeaddr(dp, rd);
  break;
}

case 0x8c: {
  dp  = op_readpc();
  dp |= op_readpc() << 8;
  rd = op_readaddr(dp);
  rd = op_dec(rd);
  op_writeaddr(dp, rd);
  break;
}

case 0x0c: {
  dp  = op_readpc();
  dp |= op_readpc() << 8;
  rd = op_readaddr(dp);
  rd = op_asl(rd);
  op_writeaddr(dp, rd);
  break;
}

case 0x4c: {
  dp  = op_readpc();
  dp |= op_readpc() << 8;
  rd = op_readaddr(dp);
  rd = op_lsr(rd);
  op_writeaddr(dp, rd);
  break;
}

case 0x2c: {
  dp  = op_readpc();
  dp |= op_readpc() << 8;
  rd = op_readaddr(dp);
  rd = op_rol(rd);
  op_writeaddr(dp, rd);
  break;
}

case 0x6c: {
  dp  = op_readpc();
  dp |= op_readpc() << 8;
  rd = op_readaddr(dp);
  rd = op_ror(rd);
  op_writeaddr(dp, rd);
  break;
}

case 0x0e: {
  dp  = op_readpc();
  dp |= op_readpc() << 8;
  rd = op_readaddr(dp);
  regs.p.n = !!((regs.B.a - rd) & 0x80);
  regs.p.z = ((regs.B.a - rd) == 0);
  op_readaddr(dp);
  op_writeaddr(dp, rd | regs.B.a);
  break;
}

case 0x4e: {
  dp  = op_readpc();
  dp |= op_readpc() << 8;
  rd = op_readaddr(dp);
  regs.p.n = !!((regs.B.a - rd) & 0x80);
  regs.p.z = ((regs.B.a - rd) == 0);
  op_readaddr(dp);
  op_writeaddr(dp, rd &~ regs.B.a);
  break;
}

case 0x3a: {
  dp = op_readpc();
  rd = op_readdp(dp);
  rd++;
  op_writedp(dp++, rd);
  rd += op_readdp(dp) << 8;
  op_writedp(dp, rd >> 8);
  regs.p.n = !!(rd & 0x8000);
  regs.p.z = (rd == 0);
  break;
}

case 0x1a: {
  dp = op_readpc();
  rd = op_readdp(dp);
  rd--;
  op_writedp(dp++, rd);
  rd += op_readdp(dp) << 8;
  op_writedp(dp, rd >> 8);
  regs.p.n = !!(rd & 0x8000);
  regs.p.z = (rd == 0);
  break;
}

