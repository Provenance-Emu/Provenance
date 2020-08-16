//--
//mbg merge 7/18/06 had to make these extern
extern int CheatWindow,CheatStyle; //bbit edited: this line added
extern HWND hCheat;

void RedoCheatsLB(HWND hwndDlg);

void ConfigCheats(HWND hParent);
void DoGGConv();
void SetGGConvFocus(int address,int compare);
void UpdateCheatList();
void UpdateCheatsAdded();

extern unsigned int FrozenAddressCount;
extern std::vector<uint16> FrozenAddresses;
//void ConfigAddCheat(HWND wnd); //bbit edited:commented out this line
