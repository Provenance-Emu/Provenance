// Specification file for Greenzone class

#include "laglog.h"

#define GREENZONE_ID_LEN 10

#define TIME_BETWEEN_CLEANINGS 10000	// in milliseconds
// Greenzone cleaning masks
#define EVERY16TH 0xFFFFFFF0
#define EVERY8TH 0xFFFFFFF8
#define EVERY4TH 0xFFFFFFFC
#define EVERY2ND 0xFFFFFFFE

#define PROGRESSBAR_UPDATE_RATE 1000	// progressbar is updated after every 1000 savestates loaded from FM3 file

class GREENZONE
{
public:
	GREENZONE();
	void init();
	void reset();
	void free();
	void update();

	void save(EMUFILE *os, int save_type = GREENZONE_SAVING_MODE_ALL);
	bool load(EMUFILE *is, unsigned int offset);

	bool loadSavestateOfFrame(unsigned int frame);

	void runGreenzoneCleaning();

	void ungreenzoneSelectedFrames();

	void invalidate(int after);
	void invalidateAndUpdatePlayback(int after);

	int findFirstGreenzonedFrame(int startingFrame = 0);

	int getSize();
	std::vector<uint8>& getSavestateOfFrame(int frame);
	void writeSavestateForFrame(int frame, std::vector<uint8>& savestate);
	bool isSavestateEmpty(unsigned int frame);

	// saved data
	LAGLOG lagLog;

private:
	void collectCurrentState();
	bool clearSavestateOfFrame(unsigned int frame);
	bool clearSavestateAndFreeMemory(unsigned int frame);

	void adjustUp();
	void adjustDown();

	// saved data
	int greenzoneSize;
	std::vector<std::vector<uint8>> savestates;

	// not saved data
	int nextCleaningTime;
	
};
