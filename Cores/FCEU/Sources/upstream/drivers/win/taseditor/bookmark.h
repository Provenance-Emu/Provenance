// Specification file for Bookmark class

#define FLASH_PHASE_MAX 11
#define FLASH_PHASE_BUTTONHELD 6

enum FLASH_TYPES
{
	FLASH_TYPE_SET = 0,
	FLASH_TYPE_JUMP = 1,
	FLASH_TYPE_DEPLOY = 2,
};

#define SCREENSHOT_WIDTH 256
#define SCREENSHOT_HEIGHT 240
#define SCREENSHOT_SIZE SCREENSHOT_WIDTH * SCREENSHOT_HEIGHT

class BOOKMARK
{
public:
	BOOKMARK();
	void init();
	void free();

	bool isDifferentFromCurrentMovie();

	void set();
	void handleJump();
	void handleDeploy();

	void save(EMUFILE *os);
	bool load(EMUFILE *is);
	bool skipLoad(EMUFILE *is);

	// saved vars
	bool notEmpty;
	SNAPSHOT snapshot;
	std::vector<uint8> savestate;
	std::vector<uint8> savedScreenshot;

	// not saved vars
	int flashPhase;
	int flashType;
	int floatingPhase;

private:

};
