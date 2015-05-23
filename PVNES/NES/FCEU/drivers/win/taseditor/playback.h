// Specification file for Playback class

#define PROGRESSBAR_WIDTH 200

#define PAUSEFRAME_BLINKING_PERIOD_WHEN_SEEKING 100
#define PAUSEFRAME_BLINKING_PERIOD_WHEN_PAUSED 250

#define BUTTON_HOLD_REPEAT_DELAY 250			// in milliseconds


class PLAYBACK
{
public:
	PLAYBACK();
	void init();
	void reset();
	void update();

	void ensurePlaybackIsInsideGreenzone(bool executeLua = true);
	void jump(int frame, bool forceStateReload = false, bool executeLua = true, bool followPauseframe = true);

	void updateProgressbar();

	void startSeekingToFrame(int frame);
	void stopSeeking();
	void cancelSeeking();

	void toggleEmulationPause();
	void pauseEmulation();
	void unpauseEmulation();

	void restoreLastPosition();
	void handleMiddleButtonClick();

	void handleRewindFrame();
	void handleForwardFrame();
	void handleRewindFull(int speed = 1);
	void handleForwardFull(int speed = 1);

	void redrawMarkerData();

	void restartPlaybackFromZeroGround();

	int getLastPosition();		// actually returns lost_position_frame-1
	void setLastPosition(int frame);

	int getPauseFrame();
	int getFlashingPauseFrame();

	void setProgressbar(int a, int b);

	bool mustFindCurrentMarker;
	int displayedMarkerNumber;

	HWND hwndProgressbar, hwndRewind, hwndForward, hwndRewindFull, hwndForwardFull;
	HWND hwndPlaybackMarkerNumber, hwndPlaybackMarkerEditField;

private:
	bool setPlaybackAboveOrToFrame(int frame, bool forceStateReload = false);

	int pauseFrame;
	int lastPositionFrame;
	bool lastPositionIsStable;	// for when Greenzone invalidates several times, but the end of current segment must remain the same

	bool mustAutopauseAtTheEnd;
	bool emuPausedState, emuPausedOldState;
	int oldPauseFrame;
	bool showPauseFrame, oldStateOfShowPauseFrame;
	int lastCursorPos;		// but for currentCursor we use external variable currFrameCounter

	bool rewindButtonState, rewindButtonOldState;
	bool forwardButtonState, forwardButtonOldState;
	bool rewindFullButtonState, rewindFullButtonOldState;
	bool forwardFullButtonState, forwardFullButtonOldState;
	int buttonHoldTimer;
	int seekingBeginningFrame;

};
