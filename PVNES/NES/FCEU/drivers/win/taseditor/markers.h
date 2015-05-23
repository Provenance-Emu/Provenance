// Specification file for Markers class

#define MAX_NOTE_LEN 100

class MARKERS
{
public:
	MARKERS();

	void save(EMUFILE *os);
	bool load(EMUFILE *is);
	bool skipLoad(EMUFILE *is);

	void compressData();
	bool isAalreadyCompressed();
	void resetCompressedStatus();

	// saved data
	std::vector<std::string> notes;		// Format: 0th - note for intro (Marker 0), 1st - note for Marker1, 2nd - note for Marker2, ...
	// not saved data
	std::vector<int> markersArray;		// Format: 0th = Marker number (id) for frame 0, 1st = Marker number for frame 1, ...

private:
	// also saved data
	std::vector<uint8> compressedMarkersArray;

	bool alreadyCompressed;			// to compress only once
};
