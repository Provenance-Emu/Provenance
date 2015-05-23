void KeyboardClose(void);
int KeyboardInitialize(void);
void KeyboardUpdate(void);
unsigned int *GetKeyboard(void);
unsigned int *GetKeyboard_nr(void);
unsigned int *GetKeyboard_jd(void);
#define KEYBACKACCESS_OLDSTYLE 1
#define KEYBACKACCESS_TASEDITOR 2
void KeyboardSetBackgroundAccessBit(int bit);
void KeyboardClearBackgroundAccessBit(int bit);
void KeyboardSetBackgroundAccess(bool on);
