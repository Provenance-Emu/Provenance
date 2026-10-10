#ifndef LCDDEF_H
#define LCDDEF_H

namespace gambatte {

enum { lcdc_bgen = 0x01,
       lcdc_objen = 0x02,
       lcdc_obj2x = 0x04,
       lcdc_tdsel = 0x10,
       lcdc_we = 0x20,
       lcdc_en = 0x80 };

enum { lcdstat_lycflag = 0x04,
       lcdstat_m0irqen = 0x08,
       lcdstat_m1irqen = 0x10,
       lcdstat_m2irqen = 0x20,
       lcdstat_lycirqen = 0x40 };

}

#endif
