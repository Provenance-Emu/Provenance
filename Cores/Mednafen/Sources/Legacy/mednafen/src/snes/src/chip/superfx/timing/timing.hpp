unsigned cache_access_speed;
unsigned memory_access_speed;
uint8 r15_NOT_modified;	// stores 0 and 1 only.

void add_clocks(unsigned clocks);

void rombuffer_sync();
void rombuffer_update();
uint8 rombuffer_read();

void rambuffer_sync();
uint8 rambuffer_read(uint16 addr);
void rambuffer_write(uint16 addr, uint8 data);

void r14_modify(uint16);
void r15_modify(uint16);

void update_speed();
void timing_reset();
