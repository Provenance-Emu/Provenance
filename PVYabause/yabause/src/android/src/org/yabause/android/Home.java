/*  Copyright 2015 Guillaume Duhamel

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
import android.content.Intent;
import android.view.View;
import android.os.Bundle;

import org.yabause.android.GameList;

public class Home extends Activity
{
    private static final String TAG = "Yabause";

    @Override
    public void onCreate(Bundle savedInstanceState)
    {
        super.onCreate(savedInstanceState);

        setContentView(R.layout.home);
    }

    public void onLoadGame(View view)
    {
        Intent intent = new Intent(this, GameList.class);
        startActivity(intent);
    }

    public void onSettings(View view)
    {
        Intent intent = new Intent(this, YabauseSettings.class);
        startActivity(intent);
    }

    static {
        System.loadLibrary("yabause");
    }
}
