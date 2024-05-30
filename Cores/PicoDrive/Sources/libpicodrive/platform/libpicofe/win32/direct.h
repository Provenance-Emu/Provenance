#ifdef __cplusplus
extern "C" {
#endif

int  DirectInit(void);
void DirectExit(void);

int  DirectScreen(const void *emu_screen);
int  DirectClear(unsigned int colour);
int  DirectPresent(void);


#ifdef __cplusplus
}
#endif
