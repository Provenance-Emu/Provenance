extern char* MovieToLoad;	//Contains the filename of the savestate specified in the command line arguments
extern char* StateToLoad;	//Contains the filename of the movie file specified in the command line arguments
extern char* ConfigToLoad;	//Contains the filename of the config file specified in the command line arguments
extern char* LuaToLoad;		//Contains the filename of the lua script specified in the command line arguments
extern char* PaletteToLoad; //Contains the filename of the palette file specified in the command line arguments
extern char* AviToLoad;		//Contains the filename of the Avi to be captured specified in the command line arguments
extern char* DumpInput;
extern char* PlayInput;
extern bool replayReadOnlySetting;
extern int replayStopFrameSetting;
extern int PauseAfterLoad;
extern int AVICapture;		//This initiates AVI capture mode with a frame number, on that frame number the AVI will stop, FCEUX will close, and a special return value will be set
char *ParseArgies(int argc, char *argv[]);
