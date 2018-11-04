package org.yabause.android;

import android.util.Log;
import android.view.InputDevice;
import android.view.KeyEvent;
import java.util.ArrayList;

import org.yabause.android.PadEvent;
import org.yabause.android.PadManager;

class PadManagerV16 extends PadManager {
    private ArrayList deviceIds;

    PadManagerV16() {
        deviceIds = new ArrayList();

        int[] ids = InputDevice.getDeviceIds();
        for (int deviceId : ids) {
            InputDevice dev = InputDevice.getDevice(deviceId);
            int sources = dev.getSources();

            if (((sources & InputDevice.SOURCE_GAMEPAD) == InputDevice.SOURCE_GAMEPAD)
                    || ((sources & InputDevice.SOURCE_JOYSTICK)
                    == InputDevice.SOURCE_JOYSTICK)) {
                if (!deviceIds.contains(deviceId)) {
                    deviceIds.add(deviceId);
                }
            }
        }
    }

    public boolean hasPad() {
        return deviceIds.size() > 0;
    }

    public PadEvent onKeyDown(int keyCode, KeyEvent event) {
        PadEvent pe = null;

        if (((event.getSource() & InputDevice.SOURCE_GAMEPAD) == InputDevice.SOURCE_GAMEPAD) ||
            ((event.getSource() & InputDevice.SOURCE_JOYSTICK) == InputDevice.SOURCE_JOYSTICK)) {
            if (event.getRepeatCount() == 0) {
                switch(keyCode) {
                    case KeyEvent.KEYCODE_DPAD_UP:
                        pe = new PadEvent(0, pe.BUTTON_UP);
                        break;
                    case KeyEvent.KEYCODE_DPAD_RIGHT:
                        pe = new PadEvent(0, pe.BUTTON_RIGHT);
                        break;
                    case KeyEvent.KEYCODE_DPAD_DOWN:
                        pe = new PadEvent(0, pe.BUTTON_DOWN);
                        break;
                    case KeyEvent.KEYCODE_DPAD_LEFT:
                        pe = new PadEvent(0, pe.BUTTON_LEFT);
                        break;
                    case KeyEvent.KEYCODE_BUTTON_L1:
                        pe = new PadEvent(0, pe.BUTTON_START);
                        break;
                    case KeyEvent.KEYCODE_BUTTON_A:
                        pe = new PadEvent(0, pe.BUTTON_A);
                        break;
                    case KeyEvent.KEYCODE_BUTTON_B:
                        pe = new PadEvent(0, pe.BUTTON_B);
                        break;
                }
            }
        }

        return pe;
    }

    public PadEvent onKeyUp(int keyCode, KeyEvent event) {
        PadEvent pe = null;

        if (((event.getSource() & InputDevice.SOURCE_GAMEPAD) == InputDevice.SOURCE_GAMEPAD) ||
            ((event.getSource() & InputDevice.SOURCE_JOYSTICK) == InputDevice.SOURCE_JOYSTICK)) {
            if (event.getRepeatCount() == 0) {
                switch(keyCode) {
                    case KeyEvent.KEYCODE_DPAD_UP:
                        pe = new PadEvent(1, pe.BUTTON_UP);
                        break;
                    case KeyEvent.KEYCODE_DPAD_RIGHT:
                        pe = new PadEvent(1, pe.BUTTON_RIGHT);
                        break;
                    case KeyEvent.KEYCODE_DPAD_DOWN:
                        pe = new PadEvent(1, pe.BUTTON_DOWN);
                        break;
                    case KeyEvent.KEYCODE_DPAD_LEFT:
                        pe = new PadEvent(1, pe.BUTTON_LEFT);
                        break;
                    case KeyEvent.KEYCODE_BUTTON_L1:
                        pe = new PadEvent(1, pe.BUTTON_START);
                        break;
                    case KeyEvent.KEYCODE_BUTTON_A:
                        pe = new PadEvent(1, pe.BUTTON_A);
                        break;
                    case KeyEvent.KEYCODE_BUTTON_B:
                        pe = new PadEvent(1, pe.BUTTON_B);
                        break;
                }
            }
        }

        return pe;
    }
}
