package org.yabause.android;

import android.view.KeyEvent;

import org.yabause.android.PadEvent;
import org.yabause.android.PadManager;

class PadManagerV8 extends PadManager {

    public boolean hasPad() {
        return false;
    }

    public PadEvent onKeyDown(int keyCode, KeyEvent event) {
        return null;
    }

    public PadEvent onKeyUp(int keyCode, KeyEvent event) {
        return null;
    }
}
