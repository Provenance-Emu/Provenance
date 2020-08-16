// Specification file for RECORDER class

enum MULTITRACK_RECORDING_MODES
{
	MULTITRACK_RECORDING_ALL = 0,
	MULTITRACK_RECORDING_1P = 1,
	MULTITRACK_RECORDING_2P = 2,
	MULTITRACK_RECORDING_3P = 3,
	MULTITRACK_RECORDING_4P = 4,
};

enum SUPERIMPOSE_OPTIONS
{
	SUPERIMPOSE_UNCHECKED = 0,
	SUPERIMPOSE_CHECKED = 1,
	SUPERIMPOSE_INDETERMINATE = 2,
};

class RECORDER
{
public:
	RECORDER();
	void init();
	void reset();
	void update();

	void uncheckRecordingRadioButtons();
	void recheckRecordingRadioButtons();

	void recordInput();

	const char* getRecordingMode();
	const char* getRecordingCaption();
	
	int multitrackRecordingJoypadNumber;
	int patternOffset;
	std::vector<uint8> currentJoypadData;
	bool stateWasLoadedInReadWriteMode;

private:
	int oldMultitrackRecordingJoypadNumber;
	int oldCurrentPattern, oldPatternOffset;
	bool oldStateOfMovieReadonly;
	bool mustIncreasePatternOffset;

	HWND hwndRecordingCheckbox, hwndRadioButtonRecordAll, hwndRadioButtonRecord1P, hwndRadioButtonRecord2P, hwndRadioButtonRecord3P, hwndRadioButtonRecord4P;

	// temps
	std::vector<uint8> oldJoyData;
	std::vector<uint8> newJoyData;
};
