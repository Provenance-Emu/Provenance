// Specification file for Markers_manager class

#include "markers.h"

#define MARKERS_ID_LEN 8
// constants for "Find Similar Note" algorithm (may need finetuning)
#define KEYWORD_MIN_LEN 2
#define MAX_NUM_KEYWORDS (MAX_NOTE_LEN / (KEYWORD_MIN_LEN+1)) + 1
#define KEYWORD_WEIGHT_BASE 2.0
#define KEYWORD_WEIGHT_FACTOR -1.0
#define KEYWORD_CASEINSENTITIVE_BONUS_PER_CHAR 1.0		// these two should be small, because they also work when keyword is inside another keyword, giving irrelevant results
#define KEYWORD_CASESENTITIVE_BONUS_PER_CHAR 1.0
#define KEYWORD_SEQUENCE_BONUS_PER_CHAR 5.0
#define KEYWORD_PENALTY_FOR_STRANGERS 0.2
#define KEYWORDS_LINE_MIN_SEQUENCE 1
#define MIN_PRIORITY_TRESHOLD 5.0

enum MARKER_NOTE_EDIT_MODES
{
	MARKER_NOTE_EDIT_NONE, 
	MARKER_NOTE_EDIT_UPPER, 
	MARKER_NOTE_EDIT_LOWER
};

class MARKERS_MANAGER
{
public:
	MARKERS_MANAGER();
	void init();
	void free();
	void reset();
	void update();

	void save(EMUFILE *os, bool really_save = true);
	bool load(EMUFILE *is, unsigned int offset);

	int getMarkersArraySize();
	bool setMarkersArraySize(int newSize);

	int getMarkerAtFrame(int frame);
	int getMarkerAboveFrame(int startFrame);
	int getMarkerAboveFrame(MARKERS& targetMarkers, int startFrame);		// special version of the function
	int getMarkerFrameNumber(int markerID);

	int setMarkerAtFrame(int frame);
	void removeMarkerFromFrame(int frame);
	void toggleMarkerAtFrame(int frame);

	bool eraseMarker(int frame, int numFrames = 1);
	bool insertEmpty(int at, int numFrames);

	int getNotesSize();
	std::string getNoteCopy(int index);
	std::string getNoteCopy(MARKERS& targetMarkers, int index);		// special version of the function
	void setNote(int index, const char* newText);

	void makeCopyOfCurrentMarkersTo(MARKERS& destination);
	void restoreMarkersFromCopy(MARKERS& source);

	bool checkMarkersDiff(MARKERS& theirMarkers);

	void findSimilarNote();
	void findNextSimilarNote();

	void updateEditedMarkerNote();

	// not saved vars
	int markerNoteEditMode;
	char findNoteString[MAX_NOTE_LEN];
	int currentIterationOfFindSimilar;

private:
	// saved vars
	MARKERS markers;

};
