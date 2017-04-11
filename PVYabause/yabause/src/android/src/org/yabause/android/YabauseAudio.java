/*  Copyright 2013 Guillaume Duhamel

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

import android.app.Activity;
import android.media.AudioManager;

public class YabauseAudio implements AudioManager.OnAudioFocusChangeListener {
    public final int SYSTEM = 1;
    public final int USER = 2;

    private Activity activity;
    private int muteFlags;
    private boolean muted;

    YabauseAudio(Activity activity) {
        this.activity = activity;

        activity.setVolumeControlStream(AudioManager.STREAM_MUSIC);
        this.muteFlags = 0;
        this.muted = false;
    }

    public void mute(int flags) {
        muted = true;
        muteFlags |= flags;
        AudioManager am = (AudioManager) activity.getSystemService(Activity.AUDIO_SERVICE);
        am.abandonAudioFocus(this);
        YabauseRunnable.setVolume(0);
    }

    public void unmute(int flags) {
        muteFlags &= ~flags;
        if (0 == muteFlags) {
            muted = false;
            AudioManager am = (AudioManager) activity.getSystemService(Activity.AUDIO_SERVICE);

            int result = am.requestAudioFocus(this, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN);
            if (result != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
                YabauseRunnable.setVolume(0);
            } else {
                YabauseRunnable.setVolume(100);
            }
        }
    }

    @Override
    public void onAudioFocusChange(int focusChange) {
        if (focusChange == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT) {
            mute(SYSTEM);
        } else if (focusChange == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK) {
            YabauseRunnable.setVolume(50);
        } else if (focusChange == AudioManager.AUDIOFOCUS_GAIN) {
            if (muted) unmute(SYSTEM);
            else YabauseRunnable.setVolume(100);
        } else if (focusChange == AudioManager.AUDIOFOCUS_LOSS) {
            mute(SYSTEM);
        }
    }
}
