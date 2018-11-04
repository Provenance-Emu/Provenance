package com.reicast.emulator.config;

import android.app.Activity;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.res.Configuration;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.preference.PreferenceManager;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.ViewGroup.LayoutParams;
import android.view.Window;
import android.widget.ImageButton;
import android.widget.ImageView.ScaleType;
import android.widget.LinearLayout;
import android.widget.PopupWindow;

import com.reicast.emulator.MainActivity;
import com.reicast.emulator.R;
import com.reicast.emulator.emu.GL2JNIView;
import com.reicast.emulator.emu.JNIdc;
import com.reicast.emulator.emu.OnScreenMenu;
import com.reicast.emulator.periph.VJoy;

public class EditVJoyActivity extends Activity {
	GL2JNIView mView;
	PopupWindow popUp;
	LayoutParams params;

	private float[][] vjoy_d_cached;

	View addbut(int x, OnClickListener ocl) {
		ImageButton but = new ImageButton(this);

		but.setImageResource(x);
		but.setScaleType(ScaleType.FIT_CENTER);
		but.setOnClickListener(ocl);

		return but;
	}

	@Override
	protected void onCreate(Bundle icicle) {
		requestWindowFeature(Window.FEATURE_NO_TITLE);

		popUp = createVJoyPopup();

		String fileName = null;

		// Call parent onCreate()
		super.onCreate(icicle);

		SharedPreferences prefs = PreferenceManager.getDefaultSharedPreferences(this);

		JNIdc.initControllers(new boolean[] { false, false, false },
				new int[][] { {1, 1}, {0, 0}, {0, 0}, {0, 0} });

		if (getIntent().getAction().equals("com.reicast.EMULATOR"))
			fileName = Uri.decode(getIntent().getData().toString());

		// Create the actual GLES view
		mView = new GL2JNIView(EditVJoyActivity.this, fileName, false,
				prefs.getInt(Config.pref_renderdepth, 24), 0, true);
		mView.setFpsDisplay(null);
		setContentView(mView);

		vjoy_d_cached = VJoy.readCustomVjoyValues(getApplicationContext());

		JNIdc.show_osd();
	}

	@Override
	protected void onPause() {
		super.onPause();
		mView.onPause();
	}

	@Override
	protected void onStop() {
		super.onStop();
//		mView.onStop();
	}

	@Override
	protected void onResume() {
		super.onResume();
		mView.onResume();
	}

	@Override
	protected void onDestroy() {
		super.onDestroy();
		mView.onDestroy();
	}

	PopupWindow createVJoyPopup() {
		final PopupWindow popUp = new PopupWindow(this);
		int p = OnScreenMenu.getPixelsFromDp(60, this);
		params = new LayoutParams(p, p);

		LinearLayout hlay = new LinearLayout(this);

		hlay.setOrientation(LinearLayout.HORIZONTAL);

		hlay.addView(addbut(R.drawable.apply, new OnClickListener() {
			public void onClick(View v) {
				Intent inte = new Intent(EditVJoyActivity.this, MainActivity.class);
				startActivity(inte);
				finish();
			}
		}), params);

		hlay.addView(addbut(R.drawable.reset, new OnClickListener() {
			public void onClick(View v) {
				// Reset VJoy positions and scale
				VJoy.resetCustomVjoyValues(getApplicationContext());
				mView.vjoy_d_custom = VJoy
						.readCustomVjoyValues(getApplicationContext());
				mView.resetEditMode();
				mView.requestLayout();
				popUp.dismiss();
			}
		}), params);

		hlay.addView(addbut(R.drawable.close, new OnClickListener() {
			public void onClick(View v) {
				mView.restoreCustomVjoyValues(vjoy_d_cached);
				popUp.dismiss();
			}
		}), params);

		popUp.setContentView(hlay);
		return popUp;
	}

	public boolean onKeyDown(int keyCode, KeyEvent event) {
		if (keyCode == KeyEvent.KEYCODE_MENU
				|| keyCode == KeyEvent.KEYCODE_BACK) {
			if (!popUp.isShowing()) {
				if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
					popUp.showAtLocation(mView, Gravity.BOTTOM, 0, 60);
				} else {
					popUp.showAtLocation(mView, Gravity.BOTTOM, 0, 0);
				}
				popUp.update(LayoutParams.WRAP_CONTENT,
						LayoutParams.WRAP_CONTENT);
			} else {
				popUp.dismiss();
			}

			return true;
		} else
			return super.onKeyDown(keyCode, event);
	}

	@Override
	public void onConfigurationChanged(Configuration newConfig) {
		super.onConfigurationChanged(newConfig);
	}
}
