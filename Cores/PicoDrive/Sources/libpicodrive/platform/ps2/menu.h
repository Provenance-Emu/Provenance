
void menu_loop(void);
int  menu_loop_tray(void);
void menu_romload_prepare(const char *rom_name);
void menu_romload_end(void);


#define CONFIGURABLE_KEYS (PBTN_UP|PBTN_LEFT|PBTN_RIGHT|PBTN_DOWN|PBTN_L|PBTN_R|PBTN_TRIANGLE|PBTN_CIRCLE|PBTN_X|PBTN_SQUARE|PBTN_START| \
	PBTN_NUB_UP|PBTN_NUB_RIGHT|PBTN_NUB_DOWN|PBTN_NUB_LEFT|PBTN_NOTE)

