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
import android.view.KeyEvent;
import android.view.View.OnTouchListener;
import android.view.View;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.Rect;
import android.graphics.RectF;
import android.content.Context;
import android.util.AttributeSet;
import android.util.Log;
import java.util.HashMap;

import org.yabause.android.PadEvent;

class PadButton {
    protected Rect rect;

    PadButton() {
        rect = new Rect();
    }

    public void updateRect(int x1, int y1, int x2, int y2) {
        rect.set(x1, y1, x2, y2);
    }

    public boolean contains(int x, int y) {
        return rect.contains(x, y);
    }

    public void draw(Canvas canvas, Paint back, Paint front) {
    }
}

class DPadButton extends PadButton {
    public void draw(Canvas canvas, Paint back, Paint front) {
        canvas.drawRect(rect, back);
    }
}

class StartButton extends PadButton {
    public void draw(Canvas canvas, Paint back, Paint front) {
        canvas.drawOval(new RectF(rect), back);
    }
}

class ActionButton extends PadButton {
    private int width;
    private String text;
    private int textsize;

    ActionButton(String t) {
        super();
        text = t;
    }

    public void draw(Canvas canvas, Paint back, Paint front) {
        int textsize = (int) (((float) rect.width() / 3) * 4);

        canvas.drawCircle(rect.centerX(), rect.centerY(), rect.width(), back);
        front.setTextSize(textsize);
        front.setTextAlign(Paint.Align.CENTER);
        canvas.drawText(text, rect.centerX(), rect.centerY() + (rect.width() / 2), front);
    }
}

interface OnPadListener {
    public abstract boolean onPad(PadEvent event);
}

class YabausePad extends View implements OnTouchListener {
    private PadButton buttons[];
    private OnPadListener listener = null;
    private HashMap<Integer, Integer> active;

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

        buttons = new PadButton[PadEvent.BUTTON_LAST];

        buttons[PadEvent.BUTTON_UP]    = new DPadButton();
        buttons[PadEvent.BUTTON_RIGHT] = new DPadButton();
        buttons[PadEvent.BUTTON_DOWN]  = new DPadButton();
        buttons[PadEvent.BUTTON_LEFT]  = new DPadButton();

        buttons[PadEvent.BUTTON_RIGHT_TRIGGER] = new PadButton();
        buttons[PadEvent.BUTTON_LEFT_TRIGGER]  = new PadButton();

        buttons[PadEvent.BUTTON_START] = new StartButton();

        buttons[PadEvent.BUTTON_A] = new ActionButton("A");
        buttons[PadEvent.BUTTON_B] = new ActionButton("B");
        buttons[PadEvent.BUTTON_C] = new ActionButton("C");

        buttons[PadEvent.BUTTON_X] = new ActionButton("X");
        buttons[PadEvent.BUTTON_Y] = new ActionButton("Y");
        buttons[PadEvent.BUTTON_Z] = new ActionButton("Z");

        active = new HashMap<Integer, Integer>();
    }

    @Override public void onDraw(Canvas canvas) {
        Paint paint = new Paint();
        paint.setARGB(0x80, 0x80, 0x80, 0x80);
        Paint apaint = new Paint();
        apaint.setARGB(0x80, 0xFF, 0x00, 0x00);
        Paint tpaint = new Paint();
        tpaint.setARGB(0x80, 0xFF, 0xFF, 0xFF);

        for(int i = 0;i < PadEvent.BUTTON_LAST;i++) {
            Paint p = active.containsValue(i) ? apaint : paint;
            buttons[i].draw(canvas, p, tpaint);
        }
    }

    public void setOnPadListener(OnPadListener listener) {
        this.listener = listener;
    }

    public boolean onTouch(View v, MotionEvent event) {
        int action = event.getActionMasked();
        int index = event.getActionIndex();
        int posx = (int) event.getX(index);
        int posy = (int) event.getY(index);
        PadEvent pe = null;

        if ((action == event.ACTION_DOWN) || (action == event.ACTION_POINTER_DOWN)) {
            for(int i = 0;i < PadEvent.BUTTON_LAST;i++) {
                if (buttons[i].contains(posx, posy)) {
                    active.put(index, i);
                    pe = new PadEvent(0, i);
                }
            }
        }

        if (((action == event.ACTION_UP) || (action == event.ACTION_POINTER_UP)) && active.containsKey(index)) {
            int i = active.remove(index);
            pe = new PadEvent(1, i);
        }

        if ((listener != null) && (pe != null)) {
            invalidate();
            listener.onPad(pe);
            return true;
        }

        return false;
    }

    @Override protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
        int width = MeasureSpec.getSize(widthMeasureSpec);
        int height = MeasureSpec.getSize(heightMeasureSpec);

        float xu = (float) getWidth() / 160;
        float yu = (float) getHeight() / 160;

        buttons[PadEvent.BUTTON_UP].updateRect((int) (20 * xu), (int) (getHeight() - 70 * yu), (int) (28 * xu), (int) (getHeight() - 50 * yu));
        buttons[PadEvent.BUTTON_RIGHT].updateRect((int) (30 * xu), (int) (getHeight() - 47 * yu), (int) (42 * xu), (int) (getHeight() - 33 * yu));
        buttons[PadEvent.BUTTON_DOWN].updateRect((int) (20 * xu), (int) (getHeight() - 30 * yu), (int) (28 * xu), (int) (getHeight() - 10 * yu));
        buttons[PadEvent.BUTTON_LEFT].updateRect((int) (6 * xu), (int) (getHeight() - 47 * yu), (int) (18 * xu), (int) (getHeight() - 33 * yu));

        buttons[PadEvent.BUTTON_START].updateRect((int) (getWidth() / 2 - (8 * xu)), (int) (getHeight() - 20 * yu), (int) (getWidth() / 2 + 8 * xu), (int) (getHeight() - 5 * yu));

        buttons[PadEvent.BUTTON_A].updateRect((int) (getWidth() - 46 * xu), (int) (getHeight() - 24 * yu), (int) (getWidth() - 38 * xu), (int) (getHeight() - 9 * yu));
        buttons[PadEvent.BUTTON_B].updateRect((int) (getWidth() - 31 * xu), (int) (getHeight() - 41 * yu), (int) (getWidth() - 23 * xu), (int) (getHeight() - 26 * yu));
        buttons[PadEvent.BUTTON_C].updateRect((int) (getWidth() - 14 * xu), (int) (getHeight() - 51 * yu), (int) (getWidth() - 6 * xu), (int) (getHeight() - 36 * yu));

        buttons[PadEvent.BUTTON_X].updateRect((int) (getWidth() - 55 * xu), (int) (getHeight() - 46 * yu), (int) (getWidth() - 49 * xu), (int) (getHeight() - 34 * yu));
        buttons[PadEvent.BUTTON_Y].updateRect((int) (getWidth() - 40 * xu), (int) (getHeight() - 63 * yu), (int) (getWidth() - 34 * xu), (int) (getHeight() - 51 * yu));
        buttons[PadEvent.BUTTON_Z].updateRect((int) (getWidth() - 23 * xu), (int) (getHeight() - 73 * yu), (int) (getWidth() - 17 * xu), (int) (getHeight() - 61 * yu));

        setMeasuredDimension(width, height);
    }
}
