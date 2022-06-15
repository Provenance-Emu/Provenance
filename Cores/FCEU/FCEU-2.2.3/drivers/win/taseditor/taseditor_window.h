// Specification file for TASEDITOR_WINDOW class

enum TASEDITOR_WINDOW_ITEMS
{
	WINDOWITEMS_PIANO_ROLL,
	WINDOWITEMS_PLAYBACK_MARKER,
	WINDOWITEMS_PLAYBACK_MARKER_EDIT,
	WINDOWITEMS_SELECTION_MARKER,
	WINDOWITEMS_SELECTION_MARKER_EDIT,
	WINDOWITEMS_PLAYBACK_BOX,
	WINDOWITEMS_PROGRESS_BUTTON,
	WINDOWITEMS_REWIND_FULL,
	WINDOWITEMS_REWIND,
	WINDOWITEMS_PAUSE,
	WINDOWITEMS_FORWARD,
	WINDOWITEMS_FORWARD_FULL,
	WINDOWITEMS_PROGRESS_BAR,
	WINDOWITEMS_FOLLOW_CURSOR,
	WINDOWITEMS_TURBO_SEEK,
	WINDOWITEMS_AUTORESTORE_PLAYBACK,
	WINDOWITEMS_RECORDER_BOX,
	WINDOWITEMS_RECORDING,
	WINDOWITEMS_RECORD_ALL,
	WINDOWITEMS_RECORD_1P,
	WINDOWITEMS_RECORD_2P,
	WINDOWITEMS_RECORD_3P,
	WINDOWITEMS_RECORD_4P,
	WINDOWITEMS_SUPERIMPOSE,
	WINDOWITEMS_USE_PATTERN,
	WINDOWITEMS_SPLICER_BOX,
	WINDOWITEMS_SELECTION_TEXT,
	WINDOWITEMS_CLIPBOARD_TEXT,
	WINDOWITEMS_LUA_BOX,
	WINDOWITEMS_RUN_MANUAL,
	WINDOWITEMS_RUN_AUTO,
	WINDOWITEMS_BRANCHES_BUTTON,
	WINDOWITEMS_BOOKMARKS_BOX,
	WINDOWITEMS_BOOKMARKS_LIST,
	WINDOWITEMS_BRANCHES_BITMAP,
	WINDOWITEMS_HISTORY_BOX,
	WINDOWITEMS_HISTORY_LIST,
	WINDOWITEMS_PREVIOUS_MARKER,
	WINDOWITEMS_SIMILAR,
	WINDOWITEMS_MORE,
	WINDOWITEMS_NEXT_MARKER,
	// ---
	TASEDITOR_WINDOW_TOTAL_ITEMS
};


#define TOOLTIP_TEXT_MAX_LEN 127
#define TOOLTIPS_AUTOPOP_TIMEOUT 30000

#define PATTERNS_MENU_POS 5
#define PATTERNS_MAX_VISIBLE_NAME 50

struct WindowItemData
{
	int number;
	int id;
	int x;
	int y;
	int width;
	int height;
	char tooltipTextBase[TOOLTIP_TEXT_MAX_LEN];
	char tooltipText[TOOLTIP_TEXT_MAX_LEN];
	bool isStaticRect;
	int hotkeyEmuCmd;
	HWND tooltipHWND;
};

class TASEDITOR_WINDOW
{
public:
	TASEDITOR_WINDOW();
	void init();
	void exit();
	void reset();
	void update();
	void redraw();

	void resizeWindowItems();
	void handleWindowMovingOrResizing();
	void changeBookmarksListHeight(int newHeight);

	void updateTooltips();
	void updateCaption();
	void updateCheckedItems();

	void updateRecentProjectsMenu();
	void updateRecentProjectsArray(const char* addString);
	void removeRecentProject(unsigned int which);
	void loadRecentProject(int slot);

	void updatePatternsMenu();
	void recheckPatternsMenu();

	HWND hwndTASEditor, hwndFindNote;
	bool TASEditorIsInFocus;
	bool isReadyForResizing;
	int minWidth;
	int minHeight;

	bool mustUpdateMouseCursor;

private:
	void calculateItems();

	HMENU hMainMenu, hPatternsMenu;
	HICON hTaseditorIcon;

};
