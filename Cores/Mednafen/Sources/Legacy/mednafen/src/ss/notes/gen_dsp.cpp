// g++ -Wall -O2 -o gen_dsp gen_dsp.cpp && ./gen_dsp
#include <stdio.h>
#include <algorithm>

int main(int argc, char* argv[])
{
 FILE* gen = fopen("../scu_dsp_gentab.inc", "wb");
 FILE* misc = fopen("../scu_dsp_misctab.inc", "wb");
 FILE* mvi = fopen("../scu_dsp_mvitab.inc", "wb");
 FILE* dma = fopen("../scu_dsp_dmatab.inc", "wb");
 FILE* jmp = fopen("../scu_dsp_jmptab.inc", "wb");

 for(int looped = 0; looped < 2; looped++)
 {
  //
  // General
  //
  fprintf(gen, "{ /* looped=%u */\n", looped);
  for(int alu_op = 0; alu_op < 16; alu_op++)
  {
   fprintf(gen, " { /* alu_op=0x%02x */\n", alu_op);
   for(int x_op = 0; x_op < 8; x_op++)
   {
    fprintf(gen, "  { /* x_op=0x%02x */\n", x_op);
    for(int y_op = 0; y_op < 8; y_op++)
    {
     fprintf(gen, "   { /* y_op=0x%02x */\n     ", y_op);
     for(int d1_op_s = 0; d1_op_s < (4/* + 15*/); d1_op_s++)
     {
      static const unsigned alu_map[16] = { 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x00, 0x08, 0x09, 0x0A, 0x0B, 0x00, 0x00, 0x00, 0x0F };
      static const unsigned x_map[8] = { 0x00, 0x00, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07 };
      static const unsigned d1s_map[16] = { 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x00, 0x09, 0x0A, 0x00, 0x00, 0x00, 0x00, 0x00 };
      const int d1_op = std::min<int>(3, d1_op_s);
      const int d1_s = std::max<int>(0, d1_op_s - 3);
      //char label_name[256];
      //snprintf(label_name, sizeof(label_name), "gen_%01x%01x%01x%01x%01x", looped, alu_op, x_op, y_op, d1_op);
      //printf("GENSIN(%s, %s, 0x%01x, 0x%01x, 0x%01x, 0x%01x)\n", label_name, looped ? "true" : "false", alu_op, x_op, y_op, d1_op);
      //fprintf(stderr, "&&%s, ", label_name);
      //fprintf(stderr, "GeneralInstr<%s, 0x%01x,0x%01x,0x%01x,0x%01x,0x%01x>, ", looped ? "true" : "false", alu_map[alu_op], x_map[x_op], y_op, d1_op, d1s_map[d1_s]);
      fprintf(gen, "GeneralInstr<%s, 0x%01x,0x%01x,0x%01x,0x%01x>, ", looped ? "true" : "false", alu_map[alu_op], x_map[x_op], y_op, d1_op);
     }
     fprintf(gen, "\n   },\n\n");
    }
    fprintf(gen, "  },\n");
   }
   fprintf(gen, " },\n");
  }
  fprintf(gen, "},\n");
  //
  // MVI
  //
  fprintf(mvi, "{ /* looped=%u */\n", looped);
  for(unsigned dest = 0; dest < 16; dest++)
  {
   fprintf(mvi, " {\n  ");
   for(unsigned cond = 0; cond < 128; cond++)
   {
    fprintf(mvi, "MVIInstr<%s, 0x%01x, 0x%02x>, ", looped ? "true" : "false", dest, (cond < 0x40) ? 0x00 : cond );
   }
   fprintf(mvi, "\n },\n");
  }
  fprintf(mvi, " },\n");

  //
  // DMA
  //
  fprintf(dma, "{ /* looped=%u */\n", looped);
  for(unsigned hfd = 0; hfd < 8; hfd++)
  {
   fprintf(dma, " {\n  ");
   for(unsigned ram = 0; ram < 8; ram++)
   {
    fprintf(dma, "DMAInstr<%s, 0x%01x, 0x%01x, 0x%01x, 0x%02x>, ", looped ? "true" : "false", (hfd >> 2) & 0x1, (hfd >> 1) & 0x1, (hfd >> 0) & 0x1, ram);
   }
   fprintf(dma, "\n },\n");
  }
  fprintf(dma, " },\n");

  //
  // JMP
  //
  fprintf(jmp, "{ /* looped=%u */\n", looped);
  for(unsigned cond = 0; cond < 128; cond++)
  {
   fprintf(jmp, "JMPInstr<%s, 0x%02x>, ", looped ? "true" : "false", (cond < 0x40) ? 0x00 : cond );
  }
  fprintf(jmp, " },\n");

  //
  // Misc
  //
  fprintf(misc, "{ /* looped=%u */ ", looped);
  for(unsigned op = 0; op < 4; op++)
  {
   fprintf(misc, "MiscInstr<%s, %u>, ", looped ? "true" : "false", op);
  }
  fprintf(misc, " },\n");
 }

 fclose(jmp);
 fclose(dma);
 fclose(mvi);
 fclose(misc);
 fclose(gen);
 return 0;
}
