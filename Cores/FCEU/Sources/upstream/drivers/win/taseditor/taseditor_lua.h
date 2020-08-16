// Specification file for TASEDITOR_LUA class

#define LUACHANGES_NAME_MAX_LEN 70			// custom name of operation should not be longer than 70 letters

struct PENDING_CHANGES
{
	uint8 type;
	int frame;
	uint8 joypad;
	int data;
};

enum LUA_CHANGE_TYPES
{
	LUA_CHANGE_TYPE_INPUTCHANGE,
	LUA_CHANGE_TYPE_INSERTFRAMES,
	LUA_CHANGE_TYPE_DELETEFRAMES,
};

enum
{
	LUA_JOYPAD_COMMANDS = 0,
	LUA_JOYPAD_1P = 1,
	LUA_JOYPAD_2P = 2,
	LUA_JOYPAD_3P = 3,
	LUA_JOYPAD_4P = 4,
};

class TASEDITOR_LUA
{
public:
	TASEDITOR_LUA();
	void init();
	void reset();
	void update();

	void enableRunFunction(const char* caption = NULL);
	void disableRunFunction();

	void insertAndDeleteRowsInSnaphot(SNAPSHOT& snapshot);

	// Taseditor Lua library
	bool engaged();
	bool markedframe(int frame);
	int getmarker(int frame);
	int setmarker(int frame);
	void removemarker(int frame);
	const char* getnote(int index);
	void setnote(int index, const char* newtext);
	int getcurrentbranch();
	const char* getrecordermode();
	int getsuperimpose();
	int getlostplayback();
	int getplaybacktarget();
	void setplayback(int frame);
	void stopseeking();
	void getselection(std::vector<int>& placeholder);
	void setselection(std::vector<int>& new_set);
	int getinput(int frame, int joypad);
	void submitinputchange(int frame, int joypad, int input);
	void submitinsertframes(int frame, int number);
	void submitdeleteframes(int frame, int number);
	int applyinputchanges(const char* name);
	void clearinputchanges();

private:
	std::vector<PENDING_CHANGES> pending_changes;

	HWND hwndRunFunctionButton;

};
