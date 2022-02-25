// Specification file for EDITOR class

class EDITOR
{
public:
	EDITOR();
	void init();
	void free();
	void reset();
	void update();

	void toggleInput(int start, int end, int joy, int button, int consecutivenessTag = 0);
	void setInputUsingPattern(int start, int end, int joy, int button, int consecutivenessTag = 0);

	bool handleColumnSet();
	bool handleColumnSetUsingPattern();
	bool handleInputColumnSet(int joy, int button);
	bool handleInputColumnSetUsingPattern(int joy, int button);
	void setMarkers();
	void removeMarkers();

	std::vector<std::string> patternsNames;
	std::vector<std::vector<uint8>> patterns;

private:
	bool readStringFromPatternsFile(EMUFILE *is, std::string& dest);

};
