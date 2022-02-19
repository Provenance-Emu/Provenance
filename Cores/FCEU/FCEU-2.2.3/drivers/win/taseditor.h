// Header file for Main TAS Editor file

struct NewProjectParameters
{
	int inputType;
	bool copyCurrentInput;
	bool copyCurrentMarkers;
	std::wstring authorName;
};

bool enterTASEditor();
bool exitTASEditor();
void updateTASEditor();

void createNewProject();
void openProject();
bool loadProject(const char* fullname);
bool saveProject(bool save_compact = false);
bool saveProjectAs(bool save_compact = false);
void saveCompact();
bool askToSaveProject();

void importInputData();
void exportToFM2();

int getInputType(MovieData& md);
void setInputType(MovieData& md, int newInputType);

void applyMovieInputConfig();

bool isTaseditorRecording();
void recordInputByTaseditor();

void handleEmuCmdByTaseditor(int command);

void enableGeneralKeyboardInput();
void disableGeneralKeyboardInput();

