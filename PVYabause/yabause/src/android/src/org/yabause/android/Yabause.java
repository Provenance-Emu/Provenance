/*  Copyright 2011-2013 Guillaume Duhamel

    This file is part of Yabause.

    Yabause is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    Yabause is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Yabause; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
*/

package org.yabause.android;

import java.lang.Runnable;
import java.io.File;
import java.io.FileOutputStream;

import android.app.Activity;
import android.os.Bundle;
import android.os.Handler;
import android.os.Message;
import android.util.Log;
import android.view.Menu;
import android.view.MenuItem;
import android.view.MenuInflater;
import android.app.Dialog;
import android.app.AlertDialog;
import android.app.AlertDialog.Builder;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.ContentValues;
import android.content.SharedPreferences;
import android.preference.PreferenceManager;
import android.view.View;
import android.graphics.Bitmap;
import android.os.Environment;
import android.provider.MediaStore;
import android.net.Uri;

class InputHandler extends Handler {
    private YabauseRunnable yr;

    public InputHandler(YabauseRunnable yr) {
        this.yr = yr;
    }

    public void handleMessage(Message msg) {
        Log.v("Yabause", "received message: " + msg.arg1 + " " + msg.arg2);
        if (msg.arg1 == 0) {
            yr.press(msg.arg2);
        } else if (msg.arg1 == 1) {
            yr.release(msg.arg2);
        }
    }
}

class YabauseRunnable implements Runnable
{
    public static native int init(Yabause yabause);
    public static native void deinit();
    public static native void exec();
    public static native void press(int key);
    public static native void release(int key);
    public static native int initViewport( int width, int hieght);
    public static native int drawScreen();
    public static native int lockGL();
    public static native int unlockGL();
    public static native void enableFPS(int enable);
    public static native void enableFrameskip(int enable);
    public static native void setVolume(int volume);
    public static native void screenshot(Bitmap bitmap);
    
    private boolean inited;
    private boolean paused;
    public InputHandler handler;

    public YabauseRunnable(Yabause yabause)
    {
        handler = new InputHandler(this);
        int ok = init(yabause);
        inited = (ok == 0);
    }

    public void pause()
    {
        Log.v("Yabause", "pause... should really pause emulation now...");
        paused = true;
    }

    public void resume()
    {
        Log.v("Yabause", "resuming emulation...");
        paused = false;
        handler.post(this);
    }

    public void destroy()
    {
        Log.v("Yabause", "destroying yabause...");
        inited = false;
        deinit();
    }

    public void run()
    {
        if (inited && (! paused))
        {
            exec();
            
            handler.post(this);
        }
    }

    public boolean paused()
    {
        return paused;
    }
}

class YabauseHandler extends Handler {
    private Yabause yabause;

    public YabauseHandler(Yabause yabause) {
        this.yabause = yabause;
    }

    public void handleMessage(Message msg) {
        yabause.showDialog(msg.what, msg.getData());
    }
}

public class Yabause extends Activity implements OnPadListener
{
    private static final String TAG = "Yabause";
    private YabauseRunnable yabauseThread;
    private YabauseHandler handler;
    private YabauseAudio audio;
    private String biospath;
    private String gamepath;
    private int carttype;

    /** Called when the activity is first created. */
    @Override
    public void onCreate(Bundle savedInstanceState)
    {
        super.onCreate(savedInstanceState);

        setContentView(R.layout.main);

        audio = new YabauseAudio(this);

        PreferenceManager.setDefaultValues(this, R.xml.preferences, false);
        readPreferences();

        handler = new YabauseHandler(this);
        yabauseThread = new YabauseRunnable(this);

        YabausePad pad = (YabausePad) findViewById(R.id.yabause_pad);
        pad.setOnPadListener(this);
    }

    @Override
    public void onPause()
    {
        super.onPause();
        Log.v(TAG, "pause... should pause emulation...");
        yabauseThread.pause();
        audio.mute(audio.SYSTEM);
    }

    @Override
    public void onResume()
    {
        super.onResume();
        Log.v(TAG, "resume... should resume emulation...");

        readPreferences();
        audio.unmute(audio.SYSTEM);

        yabauseThread.resume();
    }

    @Override
    public void onDestroy()
    {
        super.onDestroy();
        Log.v(TAG, "this is the end...");
        yabauseThread.destroy();
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        MenuInflater inflater = getMenuInflater();
        inflater.inflate(R.menu.emulation, menu);
        return true;
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        switch (item.getItemId()) {
        case R.id.pause:
            yabauseThread.pause();
            return true;
        case R.id.quit:
            this.finish();
            return true;
        case R.id.resume:
            yabauseThread.resume();
            return true;
        case R.id.settings:
            Intent intent = new Intent(this, YabauseSettings.class);
            startActivity(intent);
            return true;
        case R.id.screenshot:
            Bitmap bitmap = Bitmap.createBitmap(320, 224, Bitmap.Config.ARGB_8888);
            yabauseThread.screenshot(bitmap);
            File path = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES);
            if (! path.isDirectory()) path.mkdir();
            File file = new File(path, "screenshot.png");
            try {
                file.createNewFile();
                FileOutputStream ostream = new FileOutputStream(file);
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, ostream);
                ostream.close();

                Intent mediaScanIntent = new Intent(Intent.ACTION_MEDIA_SCANNER_SCAN_FILE);
                Uri contentUri = Uri.fromFile(file);
                mediaScanIntent.setData(contentUri);
                this.sendBroadcast(mediaScanIntent);
            } catch(Exception e) {
                e.printStackTrace();
            }
            return true;
        default:
            return super.onOptionsItemSelected(item);
        }
    }

    @Override
    public boolean onPrepareOptionsMenu(Menu menu) {
        if (yabauseThread.paused()) {
            menu.setGroupVisible(R.id.paused, true);
            menu.setGroupVisible(R.id.running, false);
        } else {
            menu.setGroupVisible(R.id.paused, false);
            menu.setGroupVisible(R.id.running, true);
        }
        return true;
    }

    @Override
    public Dialog onCreateDialog(int id, Bundle args) {
        AlertDialog.Builder builder = new AlertDialog.Builder(this);
        builder.setMessage(args.getString("message"))
            .setCancelable(false)
            .setNegativeButton("Exit", new DialogInterface.OnClickListener() {
                public void onClick(DialogInterface dialog, int id) {
                    Yabause.this.finish();
                }
            })
            .setPositiveButton("Ignore", new DialogInterface.OnClickListener() {
                public void onClick(DialogInterface dialog, int id) {
                    dialog.cancel();
                }
            });
        AlertDialog alert = builder.create();
        return alert;
    }

    @Override
    public boolean onPad(View v, PadEvent event) {
        Message message = handler.obtainMessage();
        message.arg1 = event.getAction();
        message.arg2 = event.getKey();
        yabauseThread.handler.sendMessage(message);

        return true;
    }

    private void errorMsg(String msg) {
        Message message = handler.obtainMessage();
        Bundle bundle = new Bundle();
        bundle.putString("message", msg);
        message.setData(bundle);
        handler.sendMessage(message);
    }

    private void readPreferences() {
        SharedPreferences sharedPref = PreferenceManager.getDefaultSharedPreferences(this);
        boolean fps = sharedPref.getBoolean("pref_fps", false);
        yabauseThread.enableFPS(fps ? 1 : 0);

        boolean frameskip = sharedPref.getBoolean("pref_frameskip", false);
        yabauseThread.enableFrameskip(frameskip ? 1 : 0);

        boolean audioout = sharedPref.getBoolean("pref_audio", true);
        if (audioout) {
            audio.unmute(audio.USER);
        } else {
            audio.mute(audio.USER);
        }

        String bios = sharedPref.getString("pref_bios", "");
        if (bios.length() > 0) {
            YabauseStorage storage = YabauseStorage.getStorage();
            biospath = storage.getBiosPath(bios);
        } else
            biospath = "";

        String game = sharedPref.getString("pref_game", "");
        if (game.length() > 0) {
            YabauseStorage storage = YabauseStorage.getStorage();
            gamepath = storage.getGamePath(game);
        } else
            gamepath = "";

        String cart = sharedPref.getString("pref_cart", "");
        if (cart.length() > 0) {
            Integer i = new Integer(cart);
            carttype = i.intValue();
        } else
            carttype = -1;
    }

    public String getBiosPath() {
        return biospath;
    }

    public String getGamePath() {
        return gamepath;
    }

    public String getMemoryPath() {
        return YabauseStorage.getStorage().getMemoryPath("memory.ram");
    }

    public int getCartridgeType() {
        return carttype;
    }

    public String getCartridgePath() {
        return YabauseStorage.getStorage().getCartridgePath(Cartridge.getDefaultFilename(carttype));
    }

    static {
        System.loadLibrary("yabause");
    }
}
