// Specification file for SELECTION class

#include <set>
typedef std::set<int> RowsSelection;

#define SELECTION_ID_LEN 10

class SELECTION
{
public:
	SELECTION();
	void init();
	void free();
	void reset();
	void reset_vars();
	void update();

	void updateSelectionSize();

	void updateHistoryLogSize();

	void redrawMarkerData();

	void save(EMUFILE *os, bool really_save = true);
	bool load(EMUFILE *is, unsigned int offset);
	void saveSelection(RowsSelection& selection, EMUFILE *os);
	bool loadSelection(RowsSelection& selection, EMUFILE *is);
	bool skipLoadSelection(EMUFILE *is);

	void noteThatItemRangeChanged(NMLVODSTATECHANGE* info);
	void noteThatItemChanged(NMLISTVIEW* info);

	void addNewSelectionToHistory();
	void addCurrentSelectionToHistory();

	void undo();
	void redo();

	bool isRowSelected(int index);

	void clearAllRowsSelection();
	void clearSingleRowSelection(int index);
	void clearRegionOfRowsSelection(int start, int end);

	void selectAllRows();
	void setRowSelection(int index);
	void setRegionOfRowsSelection(int start, int end);

	void setRegionOfRowsSelectionUsingPattern(int start, int end);
	void selectAllRowsBetweenMarkers();

	void reselectClipboard();

	void transposeVertically(int shift);

	void jumpToPreviousMarker(int speed = 1);
	void jumpToNextMarker(int speed = 1);

	void jumpToFrame(int frame);

	// getters
	int getCurrentRowsSelectionSize();
	int getCurrentRowsSelectionBeginning();
	int getCurrentRowsSelectionEnd();
	RowsSelection* getCopyOfCurrentRowsSelection();

	bool mustFindCurrentMarker;
	int displayedMarkerNumber;

	HWND hwndPreviousMarkerButton, hwndNextMarkerButton;
	HWND hwndSelectionMarkerNumber, hwndSelectionMarkerEditField;

private:

	void jumpInTime(int new_pos);
	void enforceRowsSelectionToList();

	RowsSelection& getCurrentRowsSelection();

	bool trackSelectionChanges;
	int lastSelectionBeginning;

	bool previousMarkerButtonState, previousMarkerButtonOldState;
	bool nextMarkerButtonState, nextMarkerButtonOldState;
	int buttonHoldTimer;

	std::vector<RowsSelection> rowsSelectionHistory;

	int historyCursorPos;
	int historyStartPos;
	int historySize;
	int historyTotalItems;

	RowsSelection tempRowsSelection;

};
