#ifndef SH2_DYNAREC_H
#define SH2_DYNAREC_H

void sh2_dynarec_init(void);
int verify_dirty(pointer addr);
void invalidate_all_pages(void);

void YabauseDynarecOneFrameExec(int, int);

#endif
