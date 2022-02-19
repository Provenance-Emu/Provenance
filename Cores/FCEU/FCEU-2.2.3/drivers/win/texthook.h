#define NETWORK_ERROR -1
#define NETWORK_OK     0

extern int TextHookerScanline;
extern int TextHooker;
extern uint8 hScroll;
extern uint8 vScroll;
extern int callTextHooker;
extern int TextHookerPosX;
extern int TextHookerPosY;

void TextHookerDoBlit();
void UpdateTextHooker();
void KillTextHooker();
void DoTextHooker();
void TextHookerCheck();
