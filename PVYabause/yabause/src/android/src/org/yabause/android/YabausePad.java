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

import android.view.MotionEvent;
import android.view.View.OnTouchListener;
import android.view.View;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.Rect;
import android.graphics.RectF;
import android.content.Context;
import android.util.AttributeSet;
import android.util.Log;

class PadEvent {
    final static int BUTTON_UP = 0;
    final static int BUTTON_RIGHT = 1;
    final static int BUTTON_DOWN = 2;
    final static int BUTTON_LEFT = 3;
    final static int BUTTON_START = 6;
    final static int BUTTON_A = 7;
    final static int BUTTON_B = 8;
    final static int BUTTON_C = 9;
    final static int BUTTON_X = 10;
    final static int BUTTON_Y = 11;
    final static int BUTTON_Z = 12;

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

interface OnPadListener {
    public abstract boolean onPad(View v, PadEvent event);
}

class YabausePad extends View implements OnTouchListener {
    private Rect up;
    private Rect right;
    private Rect down;
    private Rect left;
    private Rect start;
    private Rect a;
    private Rect b;
    private Rect c;
    private Rect x;
    private Rect y;
    private Rect z;
    private OnPadListener listener = null;

    public YabausePad(Context context) {
        super(context);
        init();
    }

    public YabausePad(Context context, AttributeSet attrs) {
        super(context, attrs);
        init();
    }

    public YabausePad(Context context, AttributeSet attrs, int defStyle) {
        super(context, attrs, defStyle);
        init();
    }

    private void init() {
        setOnTouchListener(this);
    }

    @Override public void onDraw(Canvas canvas) {
        Paint paint = new Paint();
        paint.setARGB(0x80, 0x80, 0x80, 0x80);

        canvas.drawRect(up, paint);
        canvas.drawRect(right, paint);
        canvas.drawRect(down, paint);
        canvas.drawRect(left, paint);

        canvas.drawOval(new RectF(start), paint);

        canvas.drawCircle(a.centerX(), a.centerY(), 30, paint);
        canvas.drawCircle(b.centerX(), b.centerY(), 30, paint);
        canvas.drawCircle(c.centerX(), c.centerY(), 30, paint);

        canvas.drawCircle(x.centerX(), x.centerY(), 20, paint);
        canvas.drawCircle(y.centerX(), y.centerY(), 20, paint);
        canvas.drawCircle(z.centerX(), z.centerY(), 20, paint);

        paint.setARGB(0x80, 0xFF, 0xFF, 0xFF);
        paint.setTextAlign(Paint.Align.CENTER);

        paint.setTextSize(40);
        canvas.drawText("A", a.centerX(), a.centerY() + 15, paint);
        canvas.drawText("B", b.centerX(), b.centerY() + 15, paint);
        canvas.drawText("C", c.centerX(), c.centerY() + 15, paint);

        paint.setTextSize(25);
        canvas.drawText("X", x.centerX(), x.centerY() + 10, paint);
        canvas.drawText("Y", y.centerX(), y.centerY() + 10, paint);
        canvas.drawText("Z", z.centerX(), z.centerY() + 10, paint);
    }

    public void setOnPadListener(OnPadListener listener) {
        this.listener = listener;
    }

    public boolean onTouch(View v, MotionEvent event) {
        int action = event.getActionMasked();
        int posx = (int) event.getX();
        int posy = (int) event.getY();
        PadEvent pe = null;

        if ((action != event.ACTION_DOWN) && (action != event.ACTION_UP)) return false;

        if (up.contains(posx, posy)) pe = new PadEvent(action, pe.BUTTON_UP);
        if (right.contains(posx, posy)) pe = new PadEvent(action, pe.BUTTON_RIGHT);
        if (down.contains(posx, posy)) pe = new PadEvent(action, pe.BUTTON_DOWN);
        if (left.contains(posx, posy)) pe = new PadEvent(action, pe.BUTTON_LEFT);

        if (start.contains(posx, posy)) pe = new PadEvent(action, pe.BUTTON_START);

        if (a.contains(posx, posy)) pe = new PadEvent(action, pe.BUTTON_A);
        if (b.contains(posx, posy)) pe = new PadEvent(action, pe.BUTTON_B);
        if (c.contains(posx, posy)) pe = new PadEvent(action, pe.BUTTON_C);

        if (x.contains(posx, posy)) pe = new PadEvent(action, pe.BUTTON_X);
        if (y.contains(posx, posy)) pe = new PadEvent(action, pe.BUTTON_Y);
        if (z.contains(posx, posy)) pe = new PadEvent(action, pe.BUTTON_Z);

        if ((listener != null) && (pe != null)) listener.onPad(v, pe);

        return true;
    }

    @Override protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
        int width = MeasureSpec.getSize(widthMeasureSpec);
        int height = MeasureSpec.getSize(heightMeasureSpec);

        up =    new Rect(100, getHeight() - 210, 140, getHeight() - 150);
        right = new Rect(150, getHeight() - 140, 210, getHeight() - 100);
        down =  new Rect(100, getHeight() - 90,  140, getHeight() - 30);
        left =  new Rect(30,  getHeight() - 140, 90,  getHeight() - 100);

        start = new Rect(getWidth() / 2 - 40, getHeight() - 60, getWidth() / 2 + 40, getHeight() - 15);

        a = new Rect(getWidth() - 235, getHeight() - 75, getWidth() - 185, getHeight() - 25);
        b = new Rect(getWidth() - 165, getHeight() - 125, getWidth() - 115, getHeight() - 75);
        c = new Rect(getWidth() - 75, getHeight() - 155, getWidth() - 25, getHeight() - 105);

        x = new Rect(getWidth() - 280, getHeight() - 140, getWidth() - 240, getHeight() - 100);
        y = new Rect(getWidth() - 210, getHeight() - 190, getWidth() - 170, getHeight() - 150);
        z = new Rect(getWidth() - 120, getHeight() - 220, getWidth() - 80, getHeight() - 180);

        setMeasuredDimension(width, height);
    }
}
