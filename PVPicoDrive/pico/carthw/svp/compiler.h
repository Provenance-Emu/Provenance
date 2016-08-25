int  ssp_drc_entry(ssp1601_t *ssp, int cycles);
void ssp_drc_next(void);
void ssp_drc_next_patch(void);
void ssp_drc_end(void);

void ssp_hle_800(void);
void ssp_hle_902(void);
void ssp_hle_07_6d6(void);
void ssp_hle_07_030(void);
void ssp_hle_07_036(void);
void ssp_hle_11_12c(void);
void ssp_hle_11_384(void);
void ssp_hle_11_38a(void);

int  ssp1601_dyn_startup(void);
void ssp1601_dyn_exit(void);
void ssp1601_dyn_reset(ssp1601_t *ssp);
void ssp1601_dyn_run(int cycles);

