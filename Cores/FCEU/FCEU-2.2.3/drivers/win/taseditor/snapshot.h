// Specification file for Snapshot class

#include "inputlog.h"

#define SNAPSHOT_DESCRIPTION_MAX_LEN 100

class SNAPSHOT
{
public:
	SNAPSHOT();
	void init(MovieData& md, LAGLOG& lagLog, bool hotChanges, int enforceInputType = -1);
	void reinit(MovieData& md, LAGLOG& lagLog, bool hotChanges, int frameOfChanges);	// used when combining consecutive Recordings

	bool areMarkersDifferentFromCurrentMarkers();
	void copyToCurrentMarkers();

	void compressData();
	bool isAlreadyCompressed();

	void save(EMUFILE *os);
	bool load(EMUFILE *is);
	bool skipLoad(EMUFILE *is);

	// saved data
	INPUTLOG inputlog;
	LAGLOG laglog;
	MARKERS markers;
	int keyFrame;						// for jumping when making undo
	int startFrame;					// for consecutive Draws and "Related items highlighting"
	int endFrame;						// for consecutive Draws and "Related items highlighting"
	int consecutivenessTag;				// for consecutive Recordings and Draws
	uint32 recordedJoypadDifferenceBits;		// for consecutive Recordings: bit 0 = Commands, bit 1 = Joypad 1, bit 2 = Joypad 2, bit 3 = Joypad 3, bit 4 = Joypad 4
	int modificationType;
	char description[SNAPSHOT_DESCRIPTION_MAX_LEN];

private:

};

