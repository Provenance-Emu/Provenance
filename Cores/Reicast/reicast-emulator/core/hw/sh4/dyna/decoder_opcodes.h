#pragma once
#if FEAT_SHREC != DYNAREC_NONE
#define sh4dec(str) void dec_##str (u32 op)
#else
#define sh4dec(str) static void dec_##str (u32 op) { }
#endif

sh4dec(i1000_1011_iiii_iiii);
sh4dec(i1000_1111_iiii_iiii);
sh4dec(i1000_1001_iiii_iiii);
sh4dec(i1000_1101_iiii_iiii);
sh4dec(i1010_iiii_iiii_iiii);
sh4dec(i0000_nnnn_0010_0011);
sh4dec(i0100_nnnn_0010_1011);
sh4dec(i1011_iiii_iiii_iiii);
sh4dec(i0000_nnnn_0000_0011);
sh4dec(i0100_nnnn_0000_1011);
sh4dec(i0000_0000_0000_1011);
sh4dec(i0000_0000_0010_1011);
sh4dec(i1100_0011_iiii_iiii);
sh4dec(i0000_0000_0001_1011);
//sh4dec(i0100_nnnn_0000_0111);
sh4dec(i0100_nnnn_0000_1110);
sh4dec(i0011_nnnn_mmmm_1000);
sh4dec(i0011_nnnn_mmmm_1100);
sh4dec(i0111_nnnn_iiii_iiii);
sh4dec(i0000_0000_0000_1001);
sh4dec(i1111_0011_1111_1101);
sh4dec(i1111_1011_1111_1101);
sh4dec(i0100_nnnn_0010_0100);
sh4dec(i0100_nnnn_0010_0101);
