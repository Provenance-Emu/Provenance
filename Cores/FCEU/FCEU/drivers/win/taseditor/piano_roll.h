// Specification file for PIANO_ROLL class

#define PIANO_ROLL_ID_LEN 11

#define CDDS_SUBITEMPREPAINT       (CDDS_SUBITEM | CDDS_ITEMPREPAINT)
#define CDDS_SUBITEMPOSTPAINT      (CDDS_SUBITEM | CDDS_ITEMPOSTPAINT)
#define CDDS_SUBITEMPREERASE       (CDDS_SUBITEM | CDDS_ITEMPREERASE)
#define CDDS_SUBITEMPOSTERASE      (CDDS_SUBITEM | CDDS_ITEMPOSTERASE)

#define MAX_NUM_JOYPADS 4			// = max(joysticks_per_frame[])
#define NUM_JOYPAD_BUTTONS 8

#define HEADER_LIGHT_MAX 10
#define HEADER_LIGHT_HOLD 5
#define HEADER_LIGHT_MOUSEOVER_SEL 3
#define HEADER_LIGHT_MOUSEOVER 0
#define HEADER_LIGHT_UPDATE_TICK 40	// 25FPS
#define HEADER_DX_FIX 4

#define PIANO_ROLL_SCROLLING_BOOST 2
#define PLAYBACK_WHEEL_BOOST 2

#define MARKER_DRAG_BOX_ALPHA 180
#define MARKER_DRAG_COUNTDOWN_MAX 14
#define MARKER_DRAG_ALPHA_PER_TICK 13
#define MARKER_DRAG_MAX_SPEED 72
#define MARKER_DRAG_GRAVITY 2

#define DRAG_SCROLLING_BORDER_SIZE 10		// in pixels

#define DOUBLETAP_COUNT 3			// 3 actions: 1 = quick press, 2 = quick release, 3 = quick press

enum PIANO_ROLL_COLUMNS
{
	COLUMN_ICONS,
	COLUMN_FRAMENUM,
	COLUMN_JOYPAD1_A,
	COLUMN_JOYPAD1_B,
	COLUMN_JOYPAD1_S,
	COLUMN_JOYPAD1_T,
	COLUMN_JOYPAD1_U,
	COLUMN_JOYPAD1_D,
	COLUMN_JOYPAD1_L,
	COLUMN_JOYPAD1_R,
	COLUMN_JOYPAD2_A,
	COLUMN_JOYPAD2_B,
	COLUMN_JOYPAD2_S,
	COLUMN_JOYPAD2_T,
	COLUMN_JOYPAD2_U,
	COLUMN_JOYPAD2_D,
	COLUMN_JOYPAD2_L,
	COLUMN_JOYPAD2_R,
	COLUMN_JOYPAD3_A,
	COLUMN_JOYPAD3_B,
	COLUMN_JOYPAD3_S,
	COLUMN_JOYPAD3_T,
	COLUMN_JOYPAD3_U,
	COLUMN_JOYPAD3_D,
	COLUMN_JOYPAD3_L,
	COLUMN_JOYPAD3_R,
	COLUMN_JOYPAD4_A,
	COLUMN_JOYPAD4_B,
	COLUMN_JOYPAD4_S,
	COLUMN_JOYPAD4_T,
	COLUMN_JOYPAD4_U,
	COLUMN_JOYPAD4_D,
	COLUMN_JOYPAD4_L,
	COLUMN_JOYPAD4_R,
	COLUMN_FRAMENUM2,

	TOTAL_COLUMNS
};

enum DRAG_MODES
{
	DRAG_MODE_NONE,
	DRAG_MODE_OBSERVE,
	DRAG_MODE_PLAYBACK,
	DRAG_MODE_MARKER,
	DRAG_MODE_SET,
	DRAG_MODE_UNSET,
	DRAG_MODE_SELECTION,
	DRAG_MODE_DESELECTION,
};

// when there's too many button columns, there's need for 2nd Frame# column at the end
#define NUM_COLUMNS_NEED_2ND_FRAMENUM COLUMN_JOYPAD4_R

#define DIGITS_IN_FRAMENUM 7			// should be enough for any TAS movie
#define BOOKMARKS_WITH_BLUE_ARROW 20
#define BOOKMARKS_WITH_GREEN_ARROW 40
#define BLUE_ARROW_IMAGE_ID 60
#define GREEN_ARROW_IMAGE_ID 61
#define GREEN_BLUE_ARROW_IMAGE_ID 62

#define COLUMN_ICONS_WIDTH 17
#define COLUMN_FRAMENUM_WIDTH 75
#define COLUMN_BUTTON_WIDTH 21

// listview colors
#define NORMAL_TEXT_COLOR 0x0
#define NORMAL_BACKGROUND_COLOR 0xFFFFFF

#define NORMAL_FRAMENUM_COLOR 0xFFFFFF
#define NORMAL_INPUT_COLOR1 0xEDEDED
#define NORMAL_INPUT_COLOR2 0xE2E2E2

#define GREENZONE_FRAMENUM_COLOR 0xDDFFDD
#define GREENZONE_INPUT_COLOR1 0xC8F7C4
#define GREENZONE_INPUT_COLOR2 0xADE7AD

#define PALE_GREENZONE_FRAMENUM_COLOR 0xE4FFE4
#define PALE_GREENZONE_INPUT_COLOR1 0xD3F9D2
#define PALE_GREENZONE_INPUT_COLOR2 0xBAEBBA

#define VERY_PALE_GREENZONE_FRAMENUM_COLOR 0xF9FFF9
#define VERY_PALE_GREENZONE_INPUT_COLOR1 0xE0FBE0
#define VERY_PALE_GREENZONE_INPUT_COLOR2 0xD2F2D2

#define LAG_FRAMENUM_COLOR 0xDDDCFF
#define LAG_INPUT_COLOR1 0xD2D0F0
#define LAG_INPUT_COLOR2 0xC9C6E8

#define PALE_LAG_FRAMENUM_COLOR 0xE3E3FF
#define PALE_LAG_INPUT_COLOR1 0xDADAF4
#define PALE_LAG_INPUT_COLOR2 0xCFCEEA

#define VERY_PALE_LAG_FRAMENUM_COLOR 0xE9E9FF 
#define VERY_PALE_LAG_INPUT_COLOR1 0xE5E5F7
#define VERY_PALE_LAG_INPUT_COLOR2 0xE0E0F1

#define CUR_FRAMENUM_COLOR 0xFCEDCF
#define CUR_INPUT_COLOR1 0xF7E7B5
#define CUR_INPUT_COLOR2 0xE5DBA5

#define UNDOHINT_FRAMENUM_COLOR 0xF9DDE6
#define UNDOHINT_INPUT_COLOR1 0xF7D2E1
#define UNDOHINT_INPUT_COLOR2 0xE9BED1

#define MARKED_FRAMENUM_COLOR 0xAEF0FF
#define CUR_MARKED_FRAMENUM_COLOR 0xCAEDEA
#define MARKED_UNDOHINT_FRAMENUM_COLOR 0xDDE5E9

#define BINDMARKED_FRAMENUM_COLOR 0xC9FFF7
#define CUR_BINDMARKED_FRAMENUM_COLOR 0xD5F2EC
#define BINDMARKED_UNDOHINT_FRAMENUM_COLOR 0xE1EBED

#define PLAYBACK_MARKER_COLOR 0xC9AF00

class PIANO_ROLL
{
public:
	PIANO_ROLL();
	void init();
	void free();
	void reset();
	void update();
	void redraw();

	void save(EMUFILE *os, bool really_save = true);
	bool load(EMUFILE *is, unsigned int offset);

	void redrawRow(int index);
	void redrawHeader();

	void updateLinesCount();
	bool isLineVisible(int frame);

	void recalculatePlaybackCursorOffset();

	void followPlaybackCursor();
	void followPlaybackCursorIfNeeded(bool followPauseframe = true);
	void updatePlaybackCursorPositionInPianoRoll();
	void followPauseframe();
	void followUndoHint();
	void followSelection();
	void followMarker(int markerID);
	void ensureTheLineIsVisible(int rowIndex);

	void handleColumnSet(int column, bool altPressed);

	void setLightInHeaderColumn(int column, int level);

	void startDraggingPlaybackCursor();
	void startDraggingMarker(int mouseX, int mouseY, int rowIndex, int columnIndex);
	void startSelectingDrag(int startFrame);
	void startDeselectingDrag(int startFrame);

	void getDispInfo(NMLVDISPINFO* nmlvDispInfo);
	LONG handleCustomDraw(NMLVCUSTOMDRAW* msg);
	LONG handleHeaderCustomDraw(NMLVCUSTOMDRAW* msg);

	void handleRightClick(LVHITTESTINFO& info);

	bool checkIfTheresAnIconAtFrame(int frame);
	void crossGaps(int zDelta);

	int headerItemUnderMouse;
	HWND hwndList, hwndHeader;
	TRACKMOUSEEVENT tme;

	int listTopMargin, listRowHeight, listHeaderHeight;

	bool mustCheckItemUnderMouse;

	int rowUnderMouse, realRowUnderMouse, columnUnderMouse;
	unsigned int dragMode;
	bool rightButtonDragMode;
	int markerDragBoxDX, markerDragBoxDY;
	int markerDragBoxX, markerDragBoxY;
	int markerDragCountdown;
	int markerDragFrameNumber;
	int drawingLastX, drawingLastY;
	int drawingStartTimestamp;
	int dragSelectionStartingFrame;
	int dragSelectionEndingFrame;

	bool shiftHeld, ctrlHeld, altHeld;
	int shiftTimer, ctrlTimer;
	int shiftActions—ount, ctrlActions—ount;

	HWND hwndMarkerDragBox, hwndMarkerDragBoxText;
	// GDI stuff
	HFONT hMainListFont, hMainListSelectFont, hMarkersFont, hMarkersEditFont, hTaseditorAboutFont;
	HBRUSH bgBrush, markerDragBoxBrushNormal, markerDragBoxBrushBind;

private:
	void centerListAroundLine(int rowIndex);
	void setListTopRow(int rowIndex);

	void handlePlaybackCursorDragging();
	void finishDrag();

	std::vector<uint8> headerColors;
	int numColumns;
	int nextHeaderUpdateTime;

	bool mustRedrawList;
	int playbackCursorOffset;

	HMENU hrMenu;

	// GDI stuff
	HIMAGELIST hImgList;

	WNDCLASSEX winCl;
	BLENDFUNCTION blend;

};
