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

import android.content.Context;
import android.database.DataSetObserver;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ListAdapter;
import android.widget.TextView;
import org.yabause.android.YabauseStorage;
import org.yabause.android.GameInfoManager;

class GameListAdapter implements ListAdapter {
    private YabauseStorage storage;
    private String[] gamefiles;
    private Context context;
    private GameInfoManager gim;

    GameListAdapter(Context ctx) {
        storage = YabauseStorage.getStorage();
        gamefiles = storage.getGameFiles();
        context = ctx;
        gim = new GameInfoManager(ctx);
    }

    public int getCount() {
        return gamefiles.length;
    }

    public Object getItem(int position) {
        return gamefiles[position];
    }

    public long getItemId(int position) {
        return position;
    }

    public int getItemViewType(int position) {
        return 0;
    }

    public View getView(int position, View convertView, ViewGroup parent) {
        View layout;
        TextView name;

        if (convertView != null) {
            layout = convertView;
        } else {
            LayoutInflater inflater = (LayoutInflater) context.getSystemService( Context.LAYOUT_INFLATER_SERVICE );
            layout = inflater.inflate(R.layout.game_item, parent, false);
        }

        name = (TextView) layout.findViewById(R.id.game_name);

        GameInfo gi = gim.gameInfo(gamefiles[position]);
        if (gi == null) {
            name.setText(gamefiles[position]);
        } else {
            name.setText(gi.getName());
        }

        return layout;
    }

    public int getViewTypeCount() {
        return 1;
    }

    public boolean hasStableIds() {
        return false;
    }

    public boolean isEmpty() {
        return getCount() == 0;
    }

    public void registerDataSetObserver(DataSetObserver observer) {
    }

    public void unregisterDataSetObserver(DataSetObserver observer) {
    }

    public boolean areAllItemsEnabled() {
        return true;
    }

    public boolean isEnabled(int position) {
        return true;
    }
}
