package com.reicast.emulator;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.SharedPreferences;
import android.content.res.Configuration;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.preference.PreferenceManager;
import android.util.Log;
import android.view.Gravity;
import android.view.InputDevice;
import android.view.KeyEvent;
import android.view.MotionEvent;
import android.view.ViewConfiguration;
import android.view.ViewGroup.LayoutParams;
import android.view.Window;
import android.view.WindowManager;
import android.widget.PopupWindow;

import com.reicast.emulator.config.Config;
import com.reicast.emulator.emu.GL2JNIView;
import com.reicast.emulator.emu.JNIdc;
import com.reicast.emulator.emu.OnScreenMenu;
import com.reicast.emulator.emu.OnScreenMenu.FpsPopup;
import com.reicast.emulator.emu.OnScreenMenu.MainPopup;
import com.reicast.emulator.emu.OnScreenMenu.VmuPopup;
import com.reicast.emulator.periph.Gamepad;
import com.reicast.emulator.periph.SipEmulator;

import java.util.Arrays;
import java.util.HashMap;

import tv.ouya.console.api.OuyaController;

public class GL2JNIActivity extends Activity {
    public GL2JNIView mView;
    OnScreenMenu menu;
    public MainPopup popUp;
    VmuPopup vmuPop;
    FpsPopup fpsPop;
    private SharedPreferences prefs;

    private Gamepad pad = new Gamepad();

    public static byte[] syms;

    @Override
    protected void onCreate(Bundle icicle) {
        requestWindowFeature(Window.FEATURE_NO_TITLE);
        prefs = PreferenceManager.getDefaultSharedPreferences(this);
        if (prefs.getInt(Config.pref_rendertype, 2) == 2) {
            getWindow().setFlags(
                    WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
                    WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED);
        }

        Emulator app = (Emulator)getApplicationContext();
        app.getConfigurationPrefs(prefs);
        menu = new OnScreenMenu(GL2JNIActivity.this, prefs);

        pad.isOuyaOrTV = pad.IsOuyaOrTV(GL2JNIActivity.this, false);
//		pad.isNvidiaShield = pad.IsNvidiaShield();

        /*
         * try { //int rID =
         * getResources().getIdentifier("fortyonepost.com.lfas:raw/syms.map",
         * null, null); //get the file as a stream InputStream is =
         * getResources().openRawResource(R.raw.syms);
         *
         * syms = new byte[(int) is.available()]; is.read(syms); is.close(); }
         * catch (IOException e) { e.getMessage(); e.printStackTrace(); }
         */

        String fileName = null;

        // Call parent onCreate()
        super.onCreate(icicle);
        OuyaController.init(this);

        // Populate device descriptor-to-player-map from preferences
        pad.deviceDescriptor_PlayerNum.put(
                prefs.getString(Gamepad.pref_player1, null), 0);
        pad.deviceDescriptor_PlayerNum.put(
                prefs.getString(Gamepad.pref_player2, null), 1);
        pad.deviceDescriptor_PlayerNum.put(
                prefs.getString(Gamepad.pref_player3, null), 2);
        pad.deviceDescriptor_PlayerNum.put(
                prefs.getString(Gamepad.pref_player4, null), 3);
        pad.deviceDescriptor_PlayerNum.remove(null);

        boolean player2connected = false;
        boolean player3connected = false;
        boolean player4connected = false;
        int p1periphs[] = {
                1, // Hardcoded VMU
                prefs.getBoolean(Gamepad.pref_mic, false) ? 2 : 1
        };
        int p2periphs[] = {
                prefs.getInt(Gamepad.p2_peripheral + 1, 0),
                prefs.getInt(Gamepad.p2_peripheral + 2, 0)
        };
        int p3periphs[] = {
                prefs.getInt(Gamepad.p3_peripheral + 1, 0),
                prefs.getInt(Gamepad.p3_peripheral + 2, 0)
        };
        int p4periphs[] = {
                prefs.getInt(Gamepad.p4_peripheral + 1, 0),
                prefs.getInt(Gamepad.p4_peripheral + 2, 0)
        };

        for (HashMap.Entry<String, Integer> e : pad.deviceDescriptor_PlayerNum.entrySet()) {
            String descriptor = e.getKey();
            Integer playerNum = e.getValue();

            switch (playerNum) {
                case 1:
                    if (descriptor != null)
                        player2connected = true;
                    break;
                case 2:
                    if (descriptor != null)
                        player3connected = true;
                    break;
                case 3:
                    if (descriptor != null)
                        player4connected = true;
                    break;
            }
        }

        JNIdc.initControllers(
                new boolean[] { player2connected, player3connected, player4connected },
                new int[][] { p1periphs, p2periphs, p3periphs, p4periphs });
        int joys[] = InputDevice.getDeviceIds();
        for (int joy: joys) {
            String descriptor;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN) {
                descriptor = InputDevice.getDevice(joy).getDescriptor();
            } else {
                descriptor = InputDevice.getDevice(joy).getName();
            }
            Log.d("reicast", "InputDevice ID: " + joy);
            Log.d("reicast",
                    "InputDevice Name: "
                            + InputDevice.getDevice(joy).getName());
            Log.d("reicast", "InputDevice Descriptor: " + descriptor);
            pad.deviceId_deviceDescriptor.put(joy, descriptor);
        }

        boolean detected = false;
        for (int joy : joys) {
            Integer playerNum = pad.deviceDescriptor_PlayerNum
                    .get(pad.deviceId_deviceDescriptor.get(joy));

            if (playerNum != null) {
                detected = true;
                String id = pad.portId[playerNum];
                pad.custom[playerNum] = prefs.getBoolean(Gamepad.pref_js_modified + id, false);
                pad.compat[playerNum] = prefs.getBoolean(Gamepad.pref_js_compat + id, false);
                pad.joystick[playerNum] = prefs.getBoolean(Gamepad.pref_js_merged + id, false);
                if (InputDevice.getDevice(joy).getName()
                        .contains(Gamepad.controllers_gamekey)) {
                    if (pad.custom[playerNum]) {
                        pad.setCustomMapping(id, playerNum, prefs);
                    } else {
                        pad.map[playerNum] = pad.getConsoleController();
                    }
                } else if (!pad.compat[playerNum]) {
                    if (pad.custom[playerNum]) {
                        pad.setCustomMapping(id, playerNum, prefs);
                    } else if (InputDevice.getDevice(joy).getName()
                            .equals(Gamepad.controllers_sony)) {
                        pad.map[playerNum] = pad.getConsoleController();
                    } else if (InputDevice.getDevice(joy).getName()
                            .equals(Gamepad.controllers_xbox)) {
                        pad.map[playerNum] = pad.getConsoleController();
                    } else if (InputDevice.getDevice(joy).getName()
                            .contains(Gamepad.controllers_shield)) {
                        pad.map[playerNum] = pad.getConsoleController();
                    } else if (InputDevice.getDevice(joy).getName()
                            .startsWith(Gamepad.controllers_moga)) {
                        pad.map[playerNum] = pad.getMogaController();
                    } else { // Ouya controller
                        pad.map[playerNum] = pad.getOUYAController();
                    }
                } else {
                    pad.getCompatibilityMap(playerNum, id, prefs);
                }
                pad.initJoyStickLayout(playerNum);
            }
        }
        if (joys.length == 0 || !detected) {
            pad.fullCompatibilityMode(prefs);
        }

        app.loadConfigurationPrefs();

        // When viewing a resource, pass its URI to the native code for opening
        if (getIntent().getAction().equals("com.reicast.EMULATOR"))
            fileName = Uri.decode(getIntent().getData().toString());

        // Create the actual GLES view
        mView = new GL2JNIView(GL2JNIActivity.this, fileName, false,
                prefs.getInt(Config.pref_renderdepth, 24), 0, false);
        setContentView(mView);

        //setup mic
        boolean micPluggedIn = prefs.getBoolean(Gamepad.pref_mic, false);
        if (micPluggedIn) {
            SipEmulator sip = new SipEmulator();
            sip.startRecording();
            JNIdc.setupMic(sip);
        }

        popUp = menu.new MainPopup(this);
        vmuPop = menu.new VmuPopup(this);
        if(prefs.getBoolean(Config.pref_vmu, false)){
            //kind of a hack - if the user last had the vmu on screen
            //inverse it and then "toggle"
            prefs.edit().putBoolean(Config.pref_vmu, false).apply();
            //can only display a popup after onCreate
            mView.post(new Runnable() {
                public void run() {
                    toggleVmu();
                }
            });
        }
        JNIdc.setupVmu(menu.getVmu());
        if (prefs.getBoolean(Config.pref_showfps, false)) {
            fpsPop = menu.new FpsPopup(this);
            mView.setFpsDisplay(fpsPop);
            mView.post(new Runnable() {
                public void run() {
                    displayFPS();
                }
            });
        }
    }

    public Gamepad getPad() {
        return pad;
    }

    public void displayFPS() {
        fpsPop.showAtLocation(mView, Gravity.TOP | Gravity.LEFT, 20, 20);
        fpsPop.update(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT);
    }

    @SuppressLint("RtlHardcoded")
    public void toggleVmu() {
        boolean showFloating = !prefs.getBoolean(Config.pref_vmu, false);
        if (showFloating) {
            if (popUp.isShowing()) {
                popUp.dismiss();
            }
            //remove from popup menu
            popUp.hideVmu();
            //add to floating window
            vmuPop.showVmu();
            vmuPop.showAtLocation(mView, Gravity.TOP | Gravity.RIGHT, 4, 4);
            vmuPop.update(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT);
        } else {
            vmuPop.dismiss();
            //remove from floating window
            vmuPop.hideVmu();
            //add back to popup menu
            popUp.showVmu();
        }
        prefs.edit().putBoolean(Config.pref_vmu, showFloating).apply();
    }

    public void screenGrab() {
        mView.screenGrab();
    }

    public void displayPopUp(PopupWindow popUp) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            popUp.showAtLocation(mView, Gravity.BOTTOM, 0, 60);
        } else {
            popUp.showAtLocation(mView, Gravity.BOTTOM, 0, 0);
        }
        popUp.update(LayoutParams.WRAP_CONTENT,
                LayoutParams.WRAP_CONTENT);
    }

    public void displayConfig(PopupWindow popUpConfig) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            popUpConfig.showAtLocation(mView, Gravity.BOTTOM, 0, 60);
        } else {
            popUpConfig.showAtLocation(mView, Gravity.BOTTOM, 0, 0);
        }
        popUpConfig.update(LayoutParams.WRAP_CONTENT,
                LayoutParams.WRAP_CONTENT);
    }

    public void displayDebug(PopupWindow popUpDebug) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            popUpDebug.showAtLocation(mView, Gravity.BOTTOM, 0, 60);
        } else {
            popUpDebug.showAtLocation(mView, Gravity.BOTTOM, 0, 0);
        }
        popUpDebug.update(LayoutParams.WRAP_CONTENT,
                LayoutParams.WRAP_CONTENT);
    }

    private boolean showMenu() {
        if (popUp != null) {
            if (menu.dismissPopUps()) {
                popUp.dismiss();
            } else {
                if (!popUp.isShowing()) {
                    displayPopUp(popUp);
                } else {
                    popUp.dismiss();
                }
            }
        }
        return true;
    }

    float getAxisValues(MotionEvent event, int axis, int historyPos) {
        return historyPos < 0 ? event.getAxisValue(axis) :
                event.getHistoricalAxisValue(axis, historyPos);
    }

    private void processJoystickInput(MotionEvent event, Integer playerNum, int historyPos) {
        float LS_X = getAxisValues(event, prefs.getInt(
                Gamepad.pref_axis_x, MotionEvent.AXIS_X), historyPos);
        float LS_Y = getAxisValues(event, prefs.getInt(
                Gamepad.pref_axis_y, MotionEvent.AXIS_Y), historyPos);
        float RS_X = getAxisValues(event, MotionEvent.AXIS_RX, historyPos);
        float RS_Y = getAxisValues(event, MotionEvent.AXIS_RY, historyPos);
        float L2 = getAxisValues(event, MotionEvent.AXIS_LTRIGGER, historyPos);
        float R2 = getAxisValues(event, MotionEvent.AXIS_RTRIGGER, historyPos);

        if (pad.IsOuyaOrTV(GL2JNIActivity.this, true)) {
            LS_X = getAxisValues(event, prefs.getInt(Gamepad.pref_axis_x,
                    OuyaController.AXIS_LS_X), historyPos);
            LS_Y = getAxisValues(event, prefs.getInt(Gamepad.pref_axis_y,
                    OuyaController.AXIS_LS_Y), historyPos);
            RS_X = getAxisValues(event, OuyaController.AXIS_RS_X, historyPos);
            RS_Y = getAxisValues(event, OuyaController.AXIS_RS_Y, historyPos);
            L2 = getAxisValues(event, OuyaController.AXIS_L2, historyPos);
            R2 = getAxisValues(event, OuyaController.AXIS_R2, historyPos);
        }

        if (!pad.joystick[playerNum]) {
            pad.previousLS_X[playerNum] = pad.globalLS_X[playerNum];
            pad.previousLS_Y[playerNum] = pad.globalLS_Y[playerNum];
            pad.globalLS_X[playerNum] = LS_X;
            pad.globalLS_Y[playerNum] = LS_Y;
        }

        GL2JNIView.jx[playerNum] = (int) (LS_X * 126);
        GL2JNIView.jy[playerNum] = (int) (LS_Y * 126);

        if (prefs.getInt(Gamepad.pref_js_rstick + pad.portId[playerNum], 0) == 1) {
            float R2Sum = RS_Y > 0.25 ? RS_Y : R2;
            GL2JNIView.rt[playerNum] = (int) (R2Sum * 255);
            float L2Sum = RS_Y < -0.25 ? -(RS_Y) : L2;
            GL2JNIView.lt[playerNum] = (int) (L2Sum * 255);
        } else {
            GL2JNIView.lt[playerNum] = (int) (L2 * 255);
            GL2JNIView.rt[playerNum] = (int) (R2 * 255);
        }
        if (prefs.getInt(Gamepad.pref_js_rstick + pad.portId[playerNum], 0) == 2) {
            if (RS_Y > 0.25) {
                handle_key(playerNum, pad.map[playerNum][0]/* A */, true);
                pad.wasKeyStick[playerNum] = true;
            } else if (RS_Y < 0.25) {
                handle_key(playerNum, pad.map[playerNum][1]/* B */, true);
                pad.wasKeyStick[playerNum] = true;
            } else if (pad.wasKeyStick[playerNum]) {
                handle_key(playerNum, pad.map[playerNum][0], false);
                handle_key(playerNum, pad.map[playerNum][1], false);
                pad.wasKeyStick[playerNum] = false;
            }
        }

        mView.pushInput();
    }

    @Override
    public boolean onGenericMotionEvent(MotionEvent event) {

        Integer playerNum = Arrays.asList(pad.name).indexOf(event.getDeviceId());
        if (playerNum == -1) {
            playerNum = pad.deviceDescriptor_PlayerNum
                    .get(pad.deviceId_deviceDescriptor.get(event.getDeviceId()));
        } else {
            playerNum = -1;
        }

        if (playerNum == null || playerNum == -1)
            return false;

        if (!pad.compat[playerNum]) {
            if ((event.getSource() & InputDevice.SOURCE_JOYSTICK) ==
                    InputDevice.SOURCE_JOYSTICK &&
                    event.getAction() == MotionEvent.ACTION_MOVE) {
                final int historySize = event.getHistorySize();
                for (int i = 0; i < historySize; i++) {
                    processJoystickInput(event, playerNum, i);
                }
                processJoystickInput(event, playerNum, -1);
            }
        }
        // Only handle Left Stick on an Xbox 360 controller if there was actual
        // motion on the stick, otherwise event can be handled as a DPAD event
        return (pad.joystick[playerNum] || (pad.globalLS_X[playerNum] != pad.previousLS_X[playerNum]
                || pad.globalLS_Y[playerNum] != pad.previousLS_Y[playerNum]))
                && (pad.previousLS_X[playerNum] != 0.0f || pad.previousLS_Y[playerNum] != 0.0f);
    }

    public boolean simulatedLTouchEvent(int playerNum, float L2) {
        GL2JNIView.lt[playerNum] = (int) (L2 * 255);
        mView.pushInput();
        return true;
    }

    public boolean simulatedRTouchEvent(int playerNum, float R2) {
        GL2JNIView.rt[playerNum] = (int) (R2 * 255);
        mView.pushInput();
        return true;
    }

    public boolean handle_key(Integer playerNum, int kc, boolean down) {
        if (playerNum == null || playerNum == -1)
            return false;
        if (kc == pad.getSelectButtonCode()) {
            return false;
        }

        boolean rav = false;
        for (int i = 0; i < pad.map[playerNum].length; i += 2) {
            if (pad.map[playerNum][i] == kc) {
                if (down)
                    GL2JNIView.kcode_raw[playerNum] &= ~pad.map[playerNum][i + 1];
                else
                    GL2JNIView.kcode_raw[playerNum] |= pad.map[playerNum][i + 1];
                rav = true;
                break;
            }
        }
        mView.pushInput();
        return rav;
    }

    public boolean onKeyUp(int keyCode, KeyEvent event) {
        Integer playerNum = Arrays.asList(pad.name).indexOf(event.getDeviceId());
        if (playerNum == -1) {
            playerNum = pad.deviceDescriptor_PlayerNum
                    .get(pad.deviceId_deviceDescriptor.get(event.getDeviceId()));
        } else {
            playerNum = -1;
        }

        if (playerNum != null && playerNum != -1) {
            if (pad.compat[playerNum] || pad.custom[playerNum]) {
                String id = pad.portId[playerNum];
                if (keyCode == prefs.getInt(Gamepad.pref_button_l + id, KeyEvent.KEYCODE_BUTTON_L1))
                    return simulatedLTouchEvent(playerNum, 0.0f);
                if (keyCode == prefs.getInt(Gamepad.pref_button_r + id, KeyEvent.KEYCODE_BUTTON_R1))
                    return simulatedRTouchEvent(playerNum, 0.0f);
            }
        }

        return handle_key(playerNum, keyCode, false) || super.onKeyUp(keyCode, event);
    }

    public boolean onKeyDown(int keyCode, KeyEvent event) {
        Integer playerNum = Arrays.asList(pad.name).indexOf(event.getDeviceId());
        if (playerNum == -1) {
            playerNum = pad.deviceDescriptor_PlayerNum
                    .get(pad.deviceId_deviceDescriptor.get(event.getDeviceId()));
        } else {
            playerNum = -1;
        }

        if (playerNum != null && playerNum != -1) {
            if (pad.compat[playerNum] || pad.custom[playerNum]) {
                String id = pad.portId[playerNum];
                if (keyCode == prefs.getInt(Gamepad.pref_button_l + id, KeyEvent.KEYCODE_BUTTON_L1)) {
                    return simulatedLTouchEvent(playerNum, 1.0f);
                }
                if (keyCode == prefs.getInt(Gamepad.pref_button_r + id, KeyEvent.KEYCODE_BUTTON_R1)) {
                    return simulatedRTouchEvent(playerNum, 1.0f);
                }
            }
        }

        if (handle_key(playerNum, keyCode, true)) {
            if (playerNum == 0)
                JNIdc.hide_osd();
            return true;
        }

        if (keyCode == pad.getSelectButtonCode()) {
            return showMenu();
        }
        if (ViewConfiguration.get(this).hasPermanentMenuKey()) {
            if (keyCode == KeyEvent.KEYCODE_MENU) {
                return showMenu();
            }
        }
        if (keyCode == KeyEvent.KEYCODE_BACK) {
            return showMenu();
        }
        return super.onKeyDown(keyCode, event);
    }

    @Override
    protected void onPause() {
        super.onPause();
        mView.onPause();
        JNIdc.pause();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        mView.onDestroy();
        JNIdc.destroy();
    }

    @Override
    public void onConfigurationChanged(Configuration newConfig) {
        super.onConfigurationChanged(newConfig);
    }

    @Override
    protected void onResume() {
        super.onResume();
        mView.onResume();
    }
}
