// Specification file for TASEDITOR_CONFIG class

#define GREENZONE_CAPACITY_MIN 1
#define GREENZONE_CAPACITY_MAX 50000	// this limitation is here just because we're running in 32-bit OS, so there's 2GB limit of RAM
#define GREENZONE_CAPACITY_DEFAULT 10000

#define UNDO_LEVELS_MIN 1
#define UNDO_LEVELS_MAX 1000			// this limitation is here just because we're running in 32-bit OS, so there's 2GB limit of RAM
#define UNDO_LEVELS_DEFAULT 100

#define AUTOSAVE_PERIOD_MIN 0			// 0 = auto-save immediately after every change in the project
#define AUTOSAVE_PERIOD_MAX 1440		// 24 hours
#define AUTOSAVE_PERIOD_DEFAULT 15		// in minutes

enum GREENZONE_SAVING_MODES
{
	GREENZONE_SAVING_MODE_ALL,
	GREENZONE_SAVING_MODE_16TH,
	GREENZONE_SAVING_MODE_MARKED,
	GREENZONE_SAVING_MODE_NO,

	// ...
	GREENZONE_SAVING_MODES_TOTAL
};

#define AUTHOR_NAME_MAX_LEN 100

class TASEDITOR_CONFIG
{
public:
	TASEDITOR_CONFIG();

	// vars saved in fceux.cfg file
	int windowX;
	int windowY;
	int windowWidth;
	int windowHeight;
	int savedWindowX;
	int savedWindowY;
	int savedWindowWidth;
	int savedWindowHeight;
	bool windowIsMaximized;

	int findnoteWindowX;
	int findnoteWindowY;
	bool findnoteMatchCase;
	bool findnoteSearchUp;

	bool followPlaybackCursor;
	bool turboSeek;
	bool autoRestoreLastPlaybackPosition;
	int superimpose;
	bool recordingUsePattern;
	bool enableLuaAutoFunction;

	bool displayBranchesTree;
	bool displayBranchScreenshots;
	bool displayBranchDescriptions;
	bool enableHotChanges;
	bool followUndoContext;
	bool followMarkerNoteContext;

	int greenzoneCapacity;
	int maxUndoLevels;

	bool enableGreenzoning;
	bool autofirePatternSkipsLag;
	bool autoAdjustInputAccordingToLag;
	bool drawInputByDragging;
	bool combineConsecutiveRecordingsAndDraws;
	bool use1PKeysForAllSingleRecordings;
	bool useInputKeysForColumnSet;
	bool bindMarkersToInput;
	bool emptyNewMarkerNotes;
	bool oldControlSchemeForBranching;
	bool branchesRestoreEntireMovie;
	bool HUDInBranchScreenshots;
	bool autopauseAtTheEndOfMovie;

	int lastExportedInputType;
	bool lastExportedSubtitlesStatus;

	bool projectSavingOptions_SaveInBinary;
	bool projectSavingOptions_SaveMarkers;
	bool projectSavingOptions_SaveBookmarks;
	bool projectSavingOptions_SaveHistory;
	bool projectSavingOptions_SavePianoRoll;
	bool projectSavingOptions_SaveSelection;
	int projectSavingOptions_GreenzoneSavingMode;

	bool saveCompact_SaveInBinary;
	bool saveCompact_SaveMarkers;
	bool saveCompact_SaveBookmarks;
	bool saveCompact_SaveHistory;
	bool saveCompact_SavePianoRoll;
	bool saveCompact_SaveSelection;
	int saveCompact_GreenzoneSavingMode;
	
	bool autosaveEnabled;
	int autosavePeriod;
	bool autosaveSilent;

	bool tooltipsEnabled;

	int currentPattern;

	char lastAuthorName[AUTHOR_NAME_MAX_LEN];

private:

};
