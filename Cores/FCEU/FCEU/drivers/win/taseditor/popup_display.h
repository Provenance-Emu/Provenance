// Specification file for POPUP_DISPLAY class

#define SCREENSHOT_BITMAP_PHASE_MAX 10
#define SCREENSHOT_BITMAP_PHASE_ALPHA_MAX 8
#define SCREENSHOT_BITMAP_DX 7
#define SCREENSHOT_BITMAP_DESCRIPTION_GAP 2
#define DISPLAY_UPDATE_TICK 40		// update at 25FPS

class POPUP_DISPLAY
{
public:
	POPUP_DISPLAY();
	void init();
	void free();
	void reset();
	void update();

	void changeScreenshotBitmap();
	void redrawScreenshotBitmap();
	void changeDescriptionText();

	void updateBecauseParentWindowMoved();

	int currentlyDisplayedBookmark;
	HWND hwndScreenshotBitmap, hwndScreenshotPicture, hwndNoteDescription, hwndNoteText;
	
private:
	int screenshotBitmapX;
	int screenshotBitmapY;
	int screenshotBitmapPhase;
	int nextUpdateTime;

	int descriptionX;
	int descriptionY;
	
	WNDCLASSEX winCl1, winCl2;
	BLENDFUNCTION blend;
	LPBITMAPINFO screenshotBmi;
	HBITMAP screenshotHBitmap;
	uint8* screenshotRasterPointer;

};
