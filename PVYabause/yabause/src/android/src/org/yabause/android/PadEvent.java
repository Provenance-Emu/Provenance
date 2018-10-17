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

class PadEvent {
    final static int BUTTON_UP = 0;
    final static int BUTTON_RIGHT = 1;
    final static int BUTTON_DOWN = 2;
    final static int BUTTON_LEFT = 3;
    final static int BUTTON_RIGHT_TRIGGER = 4;
    final static int BUTTON_LEFT_TRIGGER = 5;
    final static int BUTTON_START = 6;
    final static int BUTTON_A = 7;
    final static int BUTTON_B = 8;
    final static int BUTTON_C = 9;
    final static int BUTTON_X = 10;
    final static int BUTTON_Y = 11;
    final static int BUTTON_Z = 12;
    final static int BUTTON_LAST = 13;

    private int action;
    private int key;

    PadEvent(int action, int key) {
        this.action = action;
        this.key = key;
    }

    public int getAction() {
        return this.action;
    }

    public int getKey() {
        return this.key;
    }
}
