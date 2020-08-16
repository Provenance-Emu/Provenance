// Specification file for InputLog class

enum INPUT_TYPES
{
	INPUT_TYPE_1P,
	INPUT_TYPE_2P,
	INPUT_TYPE_FOURSCORE,

	// ...
	INPUT_TYPES_TOTAL
};

#define BUTTONS_PER_JOYSTICK 8
#define BYTES_PER_JOYSTICK 1			// 1 byte per 1 joystick (8 buttons)

#define HOTCHANGE_BITS_PER_VALUE 4		// any HotChange value takes 4 bits
#define HOTCHANGE_BITMASK 0xF			// "1111"
#define HOTCHANGE_MAX_VALUE 0xF			// "1111" max
#define HOTCHANGE_VALUES_PER_BYTE 2		// hence 2 HotChange values fit into 1 byte
#define BYTE_VALUE_CONTAINING_MAX_HOTCHANGES ((HOTCHANGE_MAX_VALUE << HOTCHANGE_BITS_PER_VALUE) | HOTCHANGE_MAX_VALUE)	// "0xFF"
#define BYTE_VALUE_CONTAINING_MAX_HOTCHANGE_HI (HOTCHANGE_MAX_VALUE << HOTCHANGE_BITS_PER_VALUE)						// "0xF0"
#define BYTE_VALUE_CONTAINING_MAX_HOTCHANGE_LO HOTCHANGE_MAX_VALUE														// "0x0F"
#define HOTCHANGE_BYTES_PER_JOY (BYTES_PER_JOYSTICK * HOTCHANGE_BITS_PER_VALUE)	// 4 bytes per 8 buttons

class INPUTLOG
{
public:
	INPUTLOG();
	void init(MovieData& md, bool hotchanges, int force_input_type = -1);
	void reinit(MovieData& md, bool hotchanges, int frame_of_change);		// used when combining consecutive Recordings
	void toMovie(MovieData& md, int start = 0, int end = -1);

	void save(EMUFILE *os);
	bool load(EMUFILE *is);
	bool skipLoad(EMUFILE *is);

	void compressData();
	bool isAlreadyCompressed();

	int findFirstChange(INPUTLOG& theirLog, int start = 0, int end = -1);
	int findFirstChange(MovieData& md, int start = 0, int end = -1);

	int getJoystickData(int frame, int joy);
	int getCommandsData(int frame);

	void insertFrames(int at, int frames);
	void eraseFrame(int frame);

	void initHotChanges();

	void copyHotChanges(INPUTLOG* sourceOfHotChanges, int limiterFrameOfSource = -1);
	void inheritHotChanges(INPUTLOG* sourceOfHotChanges);
	void inheritHotChanges_DeleteSelection(INPUTLOG* sourceOfHotChanges, RowsSelection* frameset);
	void inheritHotChanges_InsertSelection(INPUTLOG* sourceOfHotChanges, RowsSelection* frameset);
	void inheritHotChanges_DeleteNum(INPUTLOG* sourceOfHotChanges, int start, int frames, bool fadeOld);
	void inheritHotChanges_InsertNum(INPUTLOG* sourceOfHotChanges, int start, int frames, bool fadeOld);
	void inheritHotChanges_PasteInsert(INPUTLOG* sourceOfHotChanges, RowsSelection* insertedSet);
	void fillHotChanges(INPUTLOG& theirLog, int start = 0, int end = -1);

	void setMaxHotChangeBits(int frame, int joypad, uint8 joyBits);
	void setMaxHotChanges(int frame, int absoluteButtonNumber);

	void fadeHotChanges(int startByte = 0, int endByte = -1);

	int getHotChangesInfo(int frame, int absoluteButtonNumber);

	// saved data
	int size;						// in frames
	int inputType;						// theoretically TAS Editor can support any other Input types
	bool hasHotChanges;

private:
	
	// also saved data
	std::vector<uint8> compressedJoysticks;
	std::vector<uint8> compressedCommands;
	std::vector<uint8> compressedHotChanges;

	// not saved data
	std::vector<uint8> hotChanges;		// Format: buttons01joy0-for-frame0, buttons23joy0-for-frame0, buttons45joy0-for-frame0, buttons67joy0-for-frame0, buttons01joy1-for-frame0, ...
	std::vector<uint8> joysticks;		// Format: joy0-for-frame0, joy1-for-frame0, joy2-for-frame0, joy3-for-frame0, joy0-for-frame1, joy1-for-frame1, ...
	std::vector<uint8> commands;		// Format: commands-for-frame0, commands-for-frame1, ...
	bool alreadyCompressed;			// to compress only once
};

