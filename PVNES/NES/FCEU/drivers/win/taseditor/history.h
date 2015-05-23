// Specification file for History class

#define UNDO_HINT_TIME 200						// in milliseconds

#define SAVING_HISTORY_PROGRESSBAR_UPDATE_RATE 10
#define TIME_BETWEEN_AUTOCOMPRESSIONS 500		// in milliseconds

#define HISTORY_LIST_WIDTH 500

enum MOD_TYPES
{
	MODTYPE_INIT,
	MODTYPE_UNDEFINED,
	MODTYPE_SET,
	MODTYPE_UNSET,
	MODTYPE_PATTERN,
	MODTYPE_INSERT,
	MODTYPE_INSERTNUM,
	MODTYPE_DELETE,
	MODTYPE_TRUNCATE,
	MODTYPE_CLEAR,
	MODTYPE_CUT,
	MODTYPE_PASTE,
	MODTYPE_PASTEINSERT,
	MODTYPE_CLONE,
	MODTYPE_RECORD,
	MODTYPE_IMPORT,
	MODTYPE_BOOKMARK_0,
	MODTYPE_BOOKMARK_1,
	MODTYPE_BOOKMARK_2,
	MODTYPE_BOOKMARK_3,
	MODTYPE_BOOKMARK_4,
	MODTYPE_BOOKMARK_5,
	MODTYPE_BOOKMARK_6,
	MODTYPE_BOOKMARK_7,
	MODTYPE_BOOKMARK_8,
	MODTYPE_BOOKMARK_9,
	MODTYPE_BRANCH_0,
	MODTYPE_BRANCH_1,
	MODTYPE_BRANCH_2,
	MODTYPE_BRANCH_3,
	MODTYPE_BRANCH_4,
	MODTYPE_BRANCH_5,
	MODTYPE_BRANCH_6,
	MODTYPE_BRANCH_7,
	MODTYPE_BRANCH_8,
	MODTYPE_BRANCH_9,
	MODTYPE_BRANCH_MARKERS_0,
	MODTYPE_BRANCH_MARKERS_1,
	MODTYPE_BRANCH_MARKERS_2,
	MODTYPE_BRANCH_MARKERS_3,
	MODTYPE_BRANCH_MARKERS_4,
	MODTYPE_BRANCH_MARKERS_5,
	MODTYPE_BRANCH_MARKERS_6,
	MODTYPE_BRANCH_MARKERS_7,
	MODTYPE_BRANCH_MARKERS_8,
	MODTYPE_BRANCH_MARKERS_9,
	MODTYPE_MARKER_SET,
	MODTYPE_MARKER_REMOVE,
	MODTYPE_MARKER_PATTERN,
	MODTYPE_MARKER_RENAME,
	MODTYPE_MARKER_DRAG,
	MODTYPE_MARKER_SWAP,
	MODTYPE_MARKER_SHIFT,
	MODTYPE_LUA_MARKER_SET,
	MODTYPE_LUA_MARKER_REMOVE,
	MODTYPE_LUA_MARKER_RENAME,
	MODTYPE_LUA_CHANGE,

	MODTYPES_TOTAL
};

enum CATEGORIES_OF_OPERATIONS
{
	CATEGORY_OTHER,
	CATEGORY_INPUT_CHANGE,
	CATEGORY_MARKERS_CHANGE,
	CATEGORY_INPUT_MARKERS_CHANGE,

	CATEGORIES_OF_OPERATIONS_TOTAL
};

#define HISTORY_NORMAL_COLOR 0x000000
#define HISTORY_NORMAL_BG_COLOR 0xFFFFFF
#define HISTORY_RELATED_BG_COLOR 0xF9DDE6

#define WM_MOUSEWHEEL_RESENT WM_APP+123

#define HISTORY_ID_LEN 8

class HISTORY
{
public:
	HISTORY();
	void init();
	void free();
	void reset();
	void update();		// called every frame

	void updateHistoryLogSize();

	void save(EMUFILE *os, bool reallySave = true);
	bool load(EMUFILE *is, unsigned int offset);

	void undo();
	void redo();

	int registerChanges(int mod_type, int start = 0, int end =-1, int size = 0, const char* comment = NULL, int consecutivenessTag = 0, RowsSelection* frameset = NULL);
	int registerAdjustLag(int start, int size);
	void registerMarkersChange(int modificationType, int start = 0, int end =-1, const char* comment = 0);
	void registerBookmarkSet(int slot, BOOKMARK& backup—opy, int oldCurrentBranch);
	int registerBranching(int slot, bool markersWereChanged);
	void registerRecording(int frameOfChange, uint32 joypadDifferenceBits);
	int registerImport(MovieData& md, char* filename);
	int registerLuaChanges(const char* name, int start, bool insertionOrDeletionWasDone);

	int getCategoryOfOperation(int modificationType);

	SNAPSHOT& getCurrentSnapshot();
	SNAPSHOT& getNextToCurrentSnapshot();
	int getUndoHint();
	char* getItemDesc(int pos);

	void getDispInfo(NMLVDISPINFO* nmlvDispInfo);
	LONG handleCustomDraw(NMLVCUSTOMDRAW* msg);
	void handleSingleClick(int rowIndex);

	void redrawList();
	void updateList();

	bool isCursorOverHistoryList();

	HWND hwndHistoryList;

private:
	int jumpInTime(int newPos);

	void addItemToHistoryLog(SNAPSHOT &snap, int currentBranch = 0);
	void addItemToHistoryLog(SNAPSHOT &snap, int currentBranch, BOOKMARK &bookm);

	// saved variables
	std::vector<SNAPSHOT> snapshots;
	std::vector<BOOKMARK> bookmarkBackups;
	std::vector<int8> currentBranchNumberBackups;
	int historyCursorPos;
	int historyTotalItems;

	// not saved variables
	int historyStartPos;
	int historySize;

	int undoHintPos, oldUndoHintPos;
	int undoHintTimer;
	bool showUndoHint, oldShowUndoHint;
	int nextAutocompressTime;

};

