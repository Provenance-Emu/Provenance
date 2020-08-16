// Specification file for SPLICER class

class SPLICER
{
public:
	SPLICER();
	void init();
	void reset();
	void update();

	void cloneSelectedFrames();
	void insertSelectedFrames();
	void insertNumberOfFrames();
	void deleteSelectedFrames();
	void clearSelectedFrames(RowsSelection* currentSelectionOverride = 0);
	void truncateMovie();
	bool copySelectedInputToClipboard(RowsSelection* currentSelectionOverride = 0);
	void cutSelectedInputToClipboard();
	bool pasteInputFromClipboard();
	bool pasteInsertInputFromClipboard();

	void redrawInfoAboutClipboard();

	RowsSelection& getClipboardSelection();

	bool mustRedrawInfoAboutSelection;

private:
	void checkClipboardContents();

	RowsSelection clipboardSelection;
	HWND hwndSelectionInfo, hwndClipboardInfo;

};
