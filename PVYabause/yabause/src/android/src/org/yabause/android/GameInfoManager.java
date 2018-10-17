/*  Copyright 2016 Guillaume Duhamel

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

import org.yabause.android.GameInfo;
import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteOpenHelper;
import java.util.HashMap;

class GameInfoOpenHelper extends SQLiteOpenHelper {
    private static final int DATABASE_VERSION = 1;
    private static final String GAMEINFO_TABLE_NAME = "gameinfo";
    private static final String GAMEINFO_TABLE_CREATE =
                "CREATE TABLE " + GAMEINFO_TABLE_NAME + " (" +
                 "path TEXT PRIMARY KEY, " +
                 "system TEXT, " +
                 "company TEXT, " +
                 "itemnum TEXT, " +
                 "version TEXT, " +
                 "date TEXT, " +
                 "cdinfo TEXT, " +
                 "region TEXT, " +
                 "peripheral TEXT, " +
                 "gamename TEXT);";

    GameInfoOpenHelper(Context context) {
        super(context, "gameinfo", null, DATABASE_VERSION);
    }

    @Override
    public void onCreate(SQLiteDatabase db) {
        db.execSQL(GAMEINFO_TABLE_CREATE);
    }

    @Override
    public void onUpgrade(SQLiteDatabase db, int oldVersion, int newVersion) {
    }
}

class GameInfoManager
{
    private GameInfoOpenHelper opener;
    private HashMap<String, GameInfo> games;

    public GameInfoManager(Context ctx)
    {
        this.opener = new GameInfoOpenHelper(ctx);
        this.games = new HashMap<String, GameInfo>();

        SQLiteDatabase db = this.opener.getReadableDatabase();
        Cursor cur = db.rawQuery("SELECT path, system, company, itemnum, version, date, cdinfo, region, peripheral, gamename FROM gameinfo", null);
        while(cur.moveToNext())
        {
            String path = cur.getString(0);
            GameInfo gi = new GameInfo(cur.getString(1), cur.getString(2), cur.getString(3),
                cur.getString(4), cur.getString(5), cur.getString(6),
                cur.getString(7), cur.getString(8), cur.getString(9));
            games.put(path, gi);
        }
        cur.close();
    }

    public GameInfo gameInfo(String name) {
        String path = YabauseStorage.getStorage().getGamePath(name);

        GameInfo gi = games.get(path);

        if (gi == null) {
            gi = YabauseRunnable.gameInfo(path);
            if (gi != null) {
                SQLiteDatabase db = this.opener.getWritableDatabase();
                ContentValues cv = new ContentValues();
                cv.put("path", path);
                cv.put("system", gi.getSystem());
                cv.put("company", gi.getCompany());
                cv.put("itemnum", gi.getItemnum());
                cv.put("version", gi.getVersion());
                cv.put("date", gi.getDate());
                cv.put("cdinfo", gi.getCdinfo());
                cv.put("region", gi.getRegion());
                cv.put("peripheral", gi.getPeripheral());
                cv.put("gamename", gi.getGamename());
                db.insert("gameinfo", null, cv);

                games.put(path, gi);
            }
        }

        return gi;
    }
}
