#ifndef CONFIG_H_HF128
#define CONFIG_H_HF128

#include "../common/configSys.h"

Config *InitConfig(void);
void UpdateEMUCore(Config *);
int LoadCPalette(const std::string &file);

// hotkey definitions
// TODO: encapsulate this in an improved data structure
enum HOTKEY { HK_CHEAT_MENU=0, HK_BIND_STATE, HK_LOAD_LUA, HK_TOGGLE_BG,
	HK_SAVE_STATE, HK_FDS_SELECT, HK_LOAD_STATE, HK_FDS_EJECT ,
	HK_VS_INSERT_COIN, HK_VS_TOGGLE_DIPSWITCH,
	HK_TOGGLE_FRAME_DISPLAY, HK_TOGGLE_SUBTITLE, HK_RESET, HK_SCREENSHOT,
	HK_PAUSE, HK_DECREASE_SPEED, HK_INCREASE_SPEED, HK_FRAME_ADVANCE, HK_TURBO,
	HK_TOGGLE_INPUT_DISPLAY, HK_MOVIE_TOGGLE_RW, HK_MUTE_CAPTURE, HK_QUIT, 
    HK_FA_LAG_SKIP, HK_LAG_COUNTER_DISPLAY,
	HK_SELECT_STATE_0, HK_SELECT_STATE_1, HK_SELECT_STATE_2, HK_SELECT_STATE_3,
	HK_SELECT_STATE_4, HK_SELECT_STATE_5, HK_SELECT_STATE_6, HK_SELECT_STATE_7,
	HK_SELECT_STATE_8, HK_SELECT_STATE_9, 
	HK_SELECT_STATE_NEXT, HK_SELECT_STATE_PREV, HK_VOLUME_DOWN, HK_VOLUME_UP,
	HK_MAX};


static const char* HotkeyStrings[HK_MAX] = {
		"CheatMenu",
		"BindState",
		"LoadLua",
		"ToggleBG",
		"SaveState",
		"FDSSelect",
		"LoadState",
		"FDSEject",
		"VSInsertCoin",
		"VSToggleDip",
		"MovieToggleFrameDisplay",
		"SubtitleDisplay",
		"Reset",
		"Screenshot",
		"Pause",
		"DecreaseSpeed",
		"IncreaseSpeed",
		"FrameAdvance",
		"Turbo",
		"ToggleInputDisplay",
		"ToggleMovieRW",
		"MuteCapture",
		"Quit",
		"FrameAdvanceLagSkip",
		"LagCounterDisplay",
		"SelectState0", "SelectState1", "SelectState2", "SelectState3",
		"SelectState4", "SelectState5", "SelectState6", "SelectState7", 
		"SelectState8", "SelectState9", "SelectStateNext", "SelectStatePrev",
		"VolumeDown", "VolumeUp" };
#endif

