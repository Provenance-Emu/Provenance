// Specification file for LagLog class

enum LAG_FLAG_VALUES
{
	LAGGED_NO = 0,
	LAGGED_YES = 1,
	LAGGED_UNKNOWN = 2
};

class LAGLOG
{
public:
	LAGLOG();
	void reset();

	void compressData();
	bool isAlreadyCompressed();
	void resetCompressedStatus();

	void save(EMUFILE *os);
	bool load(EMUFILE *is);
	bool skipLoad(EMUFILE *is);

	void invalidateFromFrame(int frame);

	void setLagInfo(int frame, bool lagFlag);
	void eraseFrame(int frame, int numFrames = 1);
	void insertFrame(int frame, bool lagFlag, int numFrames = 1);

	int getSize();
	int getLagInfoAtFrame(int frame);

	int findFirstChange(LAGLOG& theirLog);

private:
	// saved data
	std::vector<uint8> compressedLagLog;

	// not saved data
	std::vector<uint8> lagLog;
	bool alreadyCompressed;			// to compress only once
};
