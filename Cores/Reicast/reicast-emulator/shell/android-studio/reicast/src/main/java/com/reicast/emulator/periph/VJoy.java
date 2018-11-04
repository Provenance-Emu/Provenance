package com.reicast.emulator.periph;

import android.content.Context;
import android.content.SharedPreferences;
import android.preference.PreferenceManager;

public class VJoy {

	public static final int key_CONT_B          = 0x0002;
	public static final int key_CONT_A          = 0x0004;
	public static final int key_CONT_START      = 0x0008;
	public static final int key_CONT_DPAD_UP    = 0x0010;
	public static final int key_CONT_DPAD_DOWN  = 0x0020;
	public static final int key_CONT_DPAD_LEFT  = 0x0040;
	public static final int key_CONT_DPAD_RIGHT = 0x0080;
	public static final int key_CONT_Y          = 0x0200;
	public static final int key_CONT_X          = 0x0400;

	public static int VJoyCount = 13;

	public static float[][] baseVJoy() {
		return new float[][] {
				new float[] { 24,		24+64,	64,64,	VJoy.key_CONT_DPAD_LEFT,				0},
				new float[] { 24+64,	24,		64,64,	VJoy.key_CONT_DPAD_UP,					0},
				new float[] { 24+128,	24+64,	64,64,	VJoy.key_CONT_DPAD_RIGHT,				0},
				new float[] { 24+64,    24+128,	64,64,	VJoy.key_CONT_DPAD_DOWN,				0},

				new float[] { 440,		280+64,	64,64,	VJoy.key_CONT_X,						0},
				new float[] { 440+64,   280,	64,64,	VJoy.key_CONT_Y,						0},
				new float[] { 440+128,  280+64,	64,64,	VJoy.key_CONT_B,						0},
				new float[] { 440+64,   280+128,64,64,	VJoy.key_CONT_A,						0},

				new float[] { 320-32,   360+32,	64,64,	VJoy.key_CONT_START,					0},

				new float[] { 440,		200,	90,64,	-1,										0},
				new float[] { 542,		200,	90,64,	-2,										0},

				new float[] { 0,		128+224,128,128,-3,										0},
				new float[] { 96,		320,	32,32,	-4,										0},

				new float[] { 20,		288,	64,64,	key_CONT_DPAD_LEFT|key_CONT_DPAD_UP,	0},
				new float[] { 20+128,	288,	64,64,	key_CONT_DPAD_RIGHT|key_CONT_DPAD_UP,	0},
				new float[] { 20,		288+128,64,64,	key_CONT_DPAD_LEFT|key_CONT_DPAD_DOWN,	0},
				new float[] { 20+128,	288+128,64,64,	key_CONT_DPAD_RIGHT|key_CONT_DPAD_DOWN,	0},
		};
	}

	public static float[][] readCustomVjoyValues(Context context) {
		SharedPreferences prefs = PreferenceManager.getDefaultSharedPreferences(context);
		return new float[][] {
				// x-shift, y-shift, sizing-factor
				new float[] { prefs.getFloat("touch_x_shift_dpad", 0),
						prefs.getFloat("touch_y_shift_dpad", 0),
						prefs.getFloat("touch_scale_dpad", 1)
				}, // DPAD
				new float[] { prefs.getFloat("touch_x_shift_buttons", 0),
						prefs.getFloat("touch_y_shift_buttons", 0),
						prefs.getFloat("touch_scale_buttons", 1)
				}, // X, Y, B, A Buttons
				new float[] { prefs.getFloat("touch_x_shift_start", 0),
						prefs.getFloat("touch_y_shift_start", 0),
						prefs.getFloat("touch_scale_start", 1)
				}, // Start
				new float[] { prefs.getFloat("touch_x_shift_left_trigger", 0),
						prefs.getFloat("touch_y_shift_left_trigger", 0),
						prefs.getFloat("touch_scale_left_trigger", 1)
				}, // Left Trigger
				new float[] { prefs.getFloat("touch_x_shift_right_trigger", 0),
						prefs.getFloat("touch_y_shift_right_trigger", 0),
						prefs.getFloat("touch_scale_right_trigger", 1)
				}, // Right Trigger
				new float[] { prefs.getFloat("touch_x_shift_analog", 0),
						prefs.getFloat("touch_y_shift_analog", 0),
						prefs.getFloat("touch_scale_analog", 1)
				} // Analog Stick
		};
	}

	public static float[][] getVjoy_d(float[][] vjoy_d_custom) {
		return new float[][] {
				new float[] { 20+0*vjoy_d_custom[0][2]+vjoy_d_custom[0][0],		288+64*vjoy_d_custom[0][2]+vjoy_d_custom[0][1],
						64*vjoy_d_custom[0][2],64*vjoy_d_custom[0][2],	key_CONT_DPAD_LEFT},
				new float[] { 20+64*vjoy_d_custom[0][2]+vjoy_d_custom[0][0],	288+0*vjoy_d_custom[0][2]+vjoy_d_custom[0][1],
						64*vjoy_d_custom[0][2],64*vjoy_d_custom[0][2],	key_CONT_DPAD_UP},
				new float[] { 20+128*vjoy_d_custom[0][2]+vjoy_d_custom[0][0],	288+64*vjoy_d_custom[0][2]+vjoy_d_custom[0][1],
						64*vjoy_d_custom[0][2],64*vjoy_d_custom[0][2],	key_CONT_DPAD_RIGHT},
				new float[] { 20+64*vjoy_d_custom[0][2]+vjoy_d_custom[0][0],	288+128*vjoy_d_custom[0][2]+vjoy_d_custom[0][1],
						64*vjoy_d_custom[0][2],64*vjoy_d_custom[0][2],	key_CONT_DPAD_DOWN},

				new float[] { 448+0*vjoy_d_custom[1][2]+vjoy_d_custom[1][0],	288+64*vjoy_d_custom[1][2]+vjoy_d_custom[1][1],
						64*vjoy_d_custom[1][2],64*vjoy_d_custom[1][2],	key_CONT_X},
				new float[] { 448+64*vjoy_d_custom[1][2]+vjoy_d_custom[1][0],	288+0*vjoy_d_custom[1][2]+vjoy_d_custom[1][1],
						64*vjoy_d_custom[1][2],64*vjoy_d_custom[1][2],	key_CONT_Y},
				new float[] { 448+128*vjoy_d_custom[1][2]+vjoy_d_custom[1][0],	288+64*vjoy_d_custom[1][2]+vjoy_d_custom[1][1],
						64*vjoy_d_custom[1][2],64*vjoy_d_custom[1][2],	key_CONT_B},
				new float[] { 448+64*vjoy_d_custom[1][2]+vjoy_d_custom[1][0],	288+128*vjoy_d_custom[1][2]+vjoy_d_custom[1][1],
						64*vjoy_d_custom[1][2],64*vjoy_d_custom[1][2],	key_CONT_A},

				new float[] { 320-32+vjoy_d_custom[2][0],						288+128+vjoy_d_custom[2][1],
						64*vjoy_d_custom[2][2],64*vjoy_d_custom[2][2],	key_CONT_START},

				new float[] { 440+vjoy_d_custom[3][0],							200+vjoy_d_custom[3][1],
						90*vjoy_d_custom[3][2],64*vjoy_d_custom[3][2],	-1},
				new float[] { 542+vjoy_d_custom[4][0],							200+vjoy_d_custom[4][1],
						90*vjoy_d_custom[4][2],64*vjoy_d_custom[4][2],	-2},

				new float[] { 16+vjoy_d_custom[5][0],							24+32+vjoy_d_custom[5][1],
						128*vjoy_d_custom[5][2],128*vjoy_d_custom[5][2],-3},
				new float[] { 96+vjoy_d_custom[5][0],							320+vjoy_d_custom[5][1],
						32*vjoy_d_custom[5][2],32*vjoy_d_custom[5][2],	-4},

				new float[] { 20+0*vjoy_d_custom[0][2]+vjoy_d_custom[0][0],		288+0*vjoy_d_custom[0][2]+vjoy_d_custom[0][1],
						64*vjoy_d_custom[0][2],64*vjoy_d_custom[0][2],	key_CONT_DPAD_LEFT|key_CONT_DPAD_UP},
				new float[] { 20+128*vjoy_d_custom[0][2]+vjoy_d_custom[0][0],	288+0*vjoy_d_custom[0][2]+vjoy_d_custom[0][1],
						64*vjoy_d_custom[0][2],64*vjoy_d_custom[0][2],	key_CONT_DPAD_RIGHT|key_CONT_DPAD_UP},
				new float[] { 20+0*vjoy_d_custom[0][2]+vjoy_d_custom[0][0],		288+128*vjoy_d_custom[0][2]+vjoy_d_custom[0][1],
						64*vjoy_d_custom[0][2],64*vjoy_d_custom[0][2],	key_CONT_DPAD_LEFT|key_CONT_DPAD_DOWN},
				new float[] { 20+128*vjoy_d_custom[0][2]+vjoy_d_custom[0][0],	288+128*vjoy_d_custom[0][2]+vjoy_d_custom[0][1],
						64*vjoy_d_custom[0][2],64*vjoy_d_custom[0][2],	key_CONT_DPAD_RIGHT|key_CONT_DPAD_DOWN},
		};
	}

	public static void writeCustomVjoyValues(float[][] vjoy_d_custom, Context context) {
		SharedPreferences prefs = PreferenceManager.getDefaultSharedPreferences(context);

		prefs.edit().putFloat("touch_x_shift_dpad", vjoy_d_custom[0][0]).apply();
		prefs.edit().putFloat("touch_y_shift_dpad", vjoy_d_custom[0][1]).apply();
		prefs.edit().putFloat("touch_scale_dpad", vjoy_d_custom[0][2]).apply();

		prefs.edit().putFloat("touch_x_shift_buttons", vjoy_d_custom[1][0]).apply();
		prefs.edit().putFloat("touch_y_shift_buttons", vjoy_d_custom[1][1]).apply();
		prefs.edit().putFloat("touch_scale_buttons", vjoy_d_custom[1][2]).apply();

		prefs.edit().putFloat("touch_x_shift_start", vjoy_d_custom[2][0]).apply();
		prefs.edit().putFloat("touch_y_shift_start", vjoy_d_custom[2][1]).apply();
		prefs.edit().putFloat("touch_scale_start", vjoy_d_custom[2][2]).apply();

		prefs.edit().putFloat("touch_x_shift_left_trigger", vjoy_d_custom[3][0]).apply();
		prefs.edit().putFloat("touch_y_shift_left_trigger", vjoy_d_custom[3][1]).apply();
		prefs.edit().putFloat("touch_scale_left_trigger", vjoy_d_custom[3][2]).apply();

		prefs.edit().putFloat("touch_x_shift_right_trigger", vjoy_d_custom[4][0]).apply();
		prefs.edit().putFloat("touch_y_shift_right_trigger", vjoy_d_custom[4][1]).apply();
		prefs.edit().putFloat("touch_scale_right_trigger", vjoy_d_custom[4][2]).apply();

		prefs.edit().putFloat("touch_x_shift_analog", vjoy_d_custom[5][0]).apply();
		prefs.edit().putFloat("touch_y_shift_analog", vjoy_d_custom[5][1]).apply();
		prefs.edit().putFloat("touch_scale_analog", vjoy_d_custom[5][2]).apply();
	}

	public static void resetCustomVjoyValues(Context context) {
		SharedPreferences prefs = PreferenceManager.getDefaultSharedPreferences(context);

		prefs.edit().remove("touch_x_shift_dpad").apply();
		prefs.edit().remove("touch_y_shift_dpad").apply();
		prefs.edit().remove("touch_scale_dpad").apply();

		prefs.edit().remove("touch_x_shift_buttons").apply();
		prefs.edit().remove("touch_y_shift_buttons").apply();
		prefs.edit().remove("touch_scale_buttons").apply();

		prefs.edit().remove("touch_x_shift_start").apply();
		prefs.edit().remove("touch_y_shift_start").apply();
		prefs.edit().remove("touch_scale_start").apply();

		prefs.edit().remove("touch_x_shift_left_trigger").apply();
		prefs.edit().remove("touch_y_shift_left_trigger").apply();
		prefs.edit().remove("touch_scale_left_trigger").apply();

		prefs.edit().remove("touch_x_shift_right_trigger").apply();
		prefs.edit().remove("touch_y_shift_right_trigger").apply();
		prefs.edit().remove("touch_scale_right_trigger").apply();

		prefs.edit().remove("touch_x_shift_analog").apply();
		prefs.edit().remove("touch_y_shift_analog").apply();
		prefs.edit().remove("touch_scale_analog").apply();
	}
}
