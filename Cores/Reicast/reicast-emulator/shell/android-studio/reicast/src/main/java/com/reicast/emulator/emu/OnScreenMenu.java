package com.reicast.emulator.emu;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;
import android.view.Gravity;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.ViewGroup.LayoutParams;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.PopupWindow;
import android.widget.ScrollView;
import android.widget.TextView;

import com.reicast.emulator.Emulator;
import com.reicast.emulator.GL2JNIActivity;
import com.reicast.emulator.MainActivity;
import com.reicast.emulator.R;
import com.reicast.emulator.config.Config;
import com.reicast.emulator.periph.VmuLcd;

import java.util.Vector;

public class OnScreenMenu {

	private Activity mContext;

	private VmuLcd vmuLcd;

	private Vector<PopupWindow> popups;

	private int frames = Emulator.frameskip;
	private boolean screen = Emulator.widescreen;
	private boolean limit = Emulator.limitfps;
	private boolean audio;
	private boolean masteraudio;
	private boolean boosted = false;
	private boolean syncedrender;

	public OnScreenMenu(Activity context, SharedPreferences prefs) {
		if (context instanceof GL2JNIActivity) {
			this.mContext = context;
		}
		popups = new Vector<>();
		if (prefs != null) {
			masteraudio = !Emulator.nosound;
			audio = masteraudio;
			syncedrender = Emulator.syncedrender;
		}
		vmuLcd = new VmuLcd(mContext);
		vmuLcd.setOnClickListener(new OnClickListener() {
			public void onClick(View v) {
				if (mContext instanceof GL2JNIActivity) {
					((GL2JNIActivity) OnScreenMenu.this.mContext).toggleVmu();
				}
			}
		});
	}

	private void displayDebugPopup() {
		if (mContext instanceof GL2JNIActivity) {
			((GL2JNIActivity) mContext).displayDebug(new DebugPopup(mContext));
		}

	}

	public class FpsPopup extends PopupWindow {

		private TextView fpsText;

		public FpsPopup(Context c) {
			super(c);
			setBackgroundDrawable(null);
			fpsText = new TextView(mContext);
			fpsText.setTextAppearance(mContext, R.style.fpsOverlayText);
			fpsText.setGravity(Gravity.CENTER);
			fpsText.setText("XX");
			setContentView(fpsText);
			setFocusable(false);
		}

		public void setText(int frames) {
			fpsText.setText(String.valueOf(frames));
			fpsText.invalidate();
		}
	}

	private void removePopUp(PopupWindow window) {
		window.dismiss();
		popups.remove(window);
		if (mContext instanceof GL2JNIActivity) {
			((GL2JNIActivity) mContext)
					.displayPopUp(((GL2JNIActivity) OnScreenMenu.this.mContext).popUp);
		}
	}

	public class DebugPopup extends PopupWindow {

	    DebugPopup(Context c) {
			super(c);
            //noinspection deprecation
			setBackgroundDrawable(new BitmapDrawable());

			View shell = mContext.getLayoutInflater().inflate(R.layout.menu_popup_debug, null);
			ScrollView hlay = (ScrollView) shell.findViewById(R.id.menuDebug);

			OnClickListener clickBack = new OnClickListener() {
				public void onClick(View v) {
					removePopUp(DebugPopup.this);
				}
			};
			Button buttonBack = (Button) hlay.findViewById(R.id.buttonBack);
			addimg(buttonBack, R.drawable.up, clickBack);

			OnClickListener clickClearCache = new OnClickListener() {
				public void onClick(View v) {
					JNIdc.send(0, 0); // Killing texture cache
					dismiss();
				}
			};
			Button buttonCache = (Button) hlay.findViewById(R.id.buttonClearCache);
			addimg(buttonCache, R.drawable.clear_cache, clickClearCache);

			OnClickListener clickProfilerOne = new OnClickListener() {
				public void onClick(View v) {
					JNIdc.send(1, 3000); // sample_Start(param);
					dismiss();
				}
			};
			Button buttonProfilerOne = (Button) hlay.findViewById(R.id.buttonProfilerOne);
			addimg(buttonProfilerOne, R.drawable.profiler, clickProfilerOne);

			OnClickListener clickProfilerTwo = new OnClickListener() {
				public void onClick(View v) {
					JNIdc.send(1, 0); // sample_Start(param);
					dismiss();
				}
			};
			Button buttonProfilerTwo = (Button) hlay.findViewById(R.id.buttonProfilerTwo);
			addimg(buttonProfilerTwo, R.drawable.profiler, clickProfilerTwo);

			OnClickListener clickPrintStats = new OnClickListener() {
				public void onClick(View v) {
					JNIdc.send(0, 2);
					dismiss(); // print_stats=true;
				}
			};
			Button buttonPrintStats = (Button) hlay.findViewById(R.id.buttonPrintStats);
			addimg(buttonPrintStats, R.drawable.print_stats, clickPrintStats);

			setContentView(shell);
			setFocusable(true);
			popups.add(this);
		}
	}

	private void displayConfigPopup() {
		if (mContext instanceof GL2JNIActivity) {
			((GL2JNIActivity) mContext)
					.displayConfig(new ConfigPopup(mContext));
		}
	}

	public class ConfigPopup extends PopupWindow {

		private Button framelimit;
		private Button audiosetting;
		private Button fastforward;
		private Button fdown;
		private Button fup;

		ConfigPopup(Context c) {
			super(c);
            //noinspection deprecation
			setBackgroundDrawable(new BitmapDrawable());

			View shell = mContext.getLayoutInflater().inflate(R.layout.menu_popup_config, null);
			final ScrollView hlay = (ScrollView) shell.findViewById(R.id.menuConfig);

			OnClickListener clickBack = new OnClickListener() {
				public void onClick(View v) {
					removePopUp(ConfigPopup.this);
				}
			};
			Button buttonBack = (Button) hlay.findViewById(R.id.buttonBack);
			addimg(buttonBack, R.drawable.up, clickBack);

			final Button buttonScreen = (Button) hlay.findViewById(R.id.buttonWidescreen);
			OnClickListener clickScreen = new OnClickListener() {
				public void onClick(View v) {
					if (screen) {
						JNIdc.widescreen(0);
						screen = false;
						addimg(buttonScreen, R.drawable.widescreen, this);
					} else {
						JNIdc.widescreen(1);
						screen = true;
						addimg(buttonScreen, R.drawable.normal_view, this);
					}
				}
			};
			if (screen) {
				addimg(buttonScreen, R.drawable.normal_view, clickScreen);
			} else {
				addimg(buttonScreen, R.drawable.widescreen, clickScreen);
			}

			fdown = (Button) hlay.findViewById(R.id.buttonFramesDown);
			OnClickListener clickFdown = new OnClickListener() {
				public void onClick(View v) {
					if (frames > 0) {
						frames--;
					}
					JNIdc.frameskip(frames);
					enableState(fdown, fup);
				}
			};
			addimg(fdown, R.drawable.frames_down, clickFdown);

			fup = (Button) hlay.findViewById(R.id.buttonFramesUp);
			OnClickListener clickFup = new OnClickListener() {
				public void onClick(View v) {
					if (frames < 5) {
						frames++;
					}
					JNIdc.frameskip(frames);
					enableState(fdown, fup);
				}
			};
			addimg(fup, R.drawable.frames_up, clickFup);
			enableState(fdown, fup);

			framelimit = (Button) hlay.findViewById(R.id.buttonFrameLimit);
			OnClickListener clickFrameLimit = new OnClickListener() {
				public void onClick(View v) {
					if (limit) {
						JNIdc.limitfps(0);
						limit = false;
						addimg(framelimit, R.drawable.frames_limit_on, this);
					} else {
						JNIdc.limitfps(1);
						limit = true;
						addimg(framelimit, R.drawable.frames_limit_off, this);
					}
				}
			};
			if (limit) {
				addimg(framelimit, R.drawable.frames_limit_off, clickFrameLimit);
			} else {
				addimg(framelimit, R.drawable.frames_limit_on, clickFrameLimit);
			}

			audiosetting = (Button) hlay.findViewById(R.id.buttonAudio);
			OnClickListener clickAudio = new OnClickListener() {
				public void onClick(View v) {
					if (audio) {
						if (mContext instanceof GL2JNIActivity) {
							((GL2JNIActivity) mContext).mView
									.audioDisable(true);
						}
						audio = false;
						addimg(audiosetting, R.drawable.enable_sound, this);
					} else {
						if (mContext instanceof GL2JNIActivity) {
							((GL2JNIActivity) mContext).mView
									.audioDisable(false);
						}
						audio = true;
						addimg(audiosetting, R.drawable.mute_sound, this);
					}
				}
			};
			if (audio) {
				addimg(audiosetting, R.drawable.mute_sound, clickAudio);
			} else {
				addimg(audiosetting, R.drawable.enable_sound, clickAudio);
			}
			if (!masteraudio) {
				audiosetting.setEnabled(false);
			}

			fastforward = (Button) hlay.findViewById(R.id.buttonTurbo);
			OnClickListener clickTurbo = new OnClickListener() {
				public void onClick(View v) {
					if (boosted) {
						if (mContext instanceof GL2JNIActivity) {
							((GL2JNIActivity) mContext).mView
									.audioDisable(!audio);
						}
						JNIdc.nosound(!audio ? 1 : 0);
						audiosetting.setEnabled(true);
						JNIdc.limitfps(limit ? 1 : 0);
						framelimit.setEnabled(true);
						JNIdc.frameskip(frames);
						enableState(fdown, fup);
						if (mContext instanceof GL2JNIActivity) {
							((GL2JNIActivity) mContext).mView
									.fastForward(false);
						}
						boosted = false;
						addimg(fastforward, R.drawable.star, this);
					} else {
						if (mContext instanceof GL2JNIActivity) {
							((GL2JNIActivity) mContext).mView
									.audioDisable(true);
						}
						JNIdc.nosound(1);
						audiosetting.setEnabled(false);
						JNIdc.limitfps(0);
						framelimit.setEnabled(false);
						JNIdc.frameskip(5);
						fdown.setEnabled(false);
						fup.setEnabled(false);
						if (mContext instanceof GL2JNIActivity) {
							((GL2JNIActivity) mContext).mView.fastForward(true);
						}
						boosted = true;
						addimg(fastforward, R.drawable.reset, this);
					}
				}
			};
			fastforward.setOnClickListener(clickTurbo);
			if (boosted) {
				addimg(fastforward, R.drawable.reset, clickTurbo);
			} else {
				addimg(fastforward, R.drawable.star, clickTurbo);
			}
			if (syncedrender) {
				fastforward.setEnabled(false);
			}

			setContentView(shell);
			setFocusable(true);
			popups.add(this);
		}
	}

	/**
	 * Toggle the frameskip button visibility by current value
	 *
	 * @param fdown
	 *            The frameskip reduction button view
	 * @param fup
	 *            The frameskip increase button view
	 */
	private void enableState(Button fdown, Button fup) {
		if (frames == 0) {
			fdown.setEnabled(false);
		} else {
			fdown.setEnabled(true);
		}
		if (frames == 5) {
			fup.setEnabled(false);
		} else {
			fup.setEnabled(true);
		}
	}

	public boolean dismissPopUps() {
		for (PopupWindow popup : popups) {
			if (popup.isShowing()) {
				popup.dismiss();
				popups.remove(popup);
				return true;
			}
		}
		return false;
	}

	public static int getPixelsFromDp(float dps, Context context) {
		return (int) (dps * context.getResources().getDisplayMetrics().density + 0.5f);
	}

	public VmuLcd getVmu() {
		return vmuLcd;
	}

	View addbut(int x, String l, OnClickListener ocl) {
		Button but = new Button(mContext);
		Drawable image = mContext.getResources().getDrawable(x);
		image.setBounds(0, 0, 72, 72);
		but.setCompoundDrawables(image, null, null, null);
		but.setOnClickListener(ocl);
		return but;
	}

	Button addimg(Button but, int x, OnClickListener ocl) {
		Drawable image = mContext.getResources().getDrawable(x);
		image.setBounds(0, 0, 72, 72);
		but.setCompoundDrawables(image, null, null, null);
		but.setOnClickListener(ocl);
		return but;
	}

	void modbut (View button, int x) {
		Button but = (Button) button;
		Drawable image = mContext.getResources().getDrawable(x);
		image.setBounds(0, 0, 72, 72);
		but.setCompoundDrawables(image, null, null, null);
	}

	public class VmuPopup extends PopupWindow {
		LayoutParams vparams;
		LinearLayout vlay;

		public VmuPopup(Context c) {
			super(c);
			setBackgroundDrawable(null);
			int pX = OnScreenMenu.getPixelsFromDp(96, mContext);
			int pY = OnScreenMenu.getPixelsFromDp(68, mContext);
			vparams = new LayoutParams(pX, pY);
			vlay = new LinearLayout(mContext);
			vlay.setOrientation(LinearLayout.HORIZONTAL);
			setContentView(vlay);
			setFocusable(false);
		}

		public void showVmu() {
			vmuLcd.configureScale(96);
			vlay.addView(vmuLcd, vparams);
		}

		public void hideVmu() {
			vlay.removeView(vmuLcd);
		}

	}

	public class MainPopup extends PopupWindow {

		private LinearLayout vmuIcon;
		LinearLayout.LayoutParams params;

		@SuppressLint("RtlHardcoded")
        private LinearLayout.LayoutParams setVmuParams() {
			int vpX = getPixelsFromDp(72, mContext);
			int vpY = getPixelsFromDp(52, mContext);
			LinearLayout.LayoutParams vmuParams = new LinearLayout.LayoutParams(
					vpX, vpY);
			vmuParams.weight = 1.0f;
			vmuParams.gravity = Gravity.LEFT | Gravity.CENTER_VERTICAL;
			vmuParams.leftMargin = 6;
			return vmuParams;
		}

		public MainPopup(Context c) {
			super(c);
			//noinspection deprecation
			setBackgroundDrawable(new BitmapDrawable());

			View shell = mContext.getLayoutInflater().inflate(R.layout.menu_popup_main, null);
			ScrollView hlay = (ScrollView) shell.findViewById(R.id.menuMain);

			vmuIcon = (LinearLayout) hlay.findViewById(R.id.vmuIcon);
			vmuLcd.configureScale(72);
			params = setVmuParams();
			vmuIcon.addView(vmuLcd, params);

			OnClickListener clickDisk = new OnClickListener() {
				public void onClick(View v) {
					if (Emulator.bootdisk != null)
						JNIdc.diskSwap(null);
					dismiss();
				}
			};
			Button buttonDisk = (Button) hlay.findViewById(R.id.buttonDisk);
			addimg(buttonDisk, R.drawable.disk_swap, clickDisk);

			OnClickListener clickVmuSwap = new OnClickListener() {
				public void onClick(View v) {
					JNIdc.vmuSwap();
					dismiss();
				}
			};
			Button buttonVmuSwap = (Button) hlay.findViewById(R.id.buttonVmuSwap);
			addimg(buttonVmuSwap, R.drawable.vmu_swap, clickVmuSwap);

			OnClickListener clickOptions = new OnClickListener() {
				public void onClick(View v) {
					displayConfigPopup();
					popups.remove(MainPopup.this);
					dismiss();
				}
			};
			Button buttonOptions = (Button) hlay.findViewById(R.id.buttonOptions);
			addimg(buttonOptions, R.drawable.config, clickOptions);

			OnClickListener clickDebugging = new OnClickListener() {
				public void onClick(View v) {
					displayDebugPopup();
					popups.remove(MainPopup.this);
					dismiss();
				}
			};
			Button buttonDebugging = (Button) hlay.findViewById(R.id.buttonDebugging);
			addimg(buttonDebugging, R.drawable.disk_unknown, clickDebugging);

			OnClickListener clickScreenshot = new OnClickListener() {
				public void onClick(View v) {
					// screenshot
					if (mContext instanceof GL2JNIActivity) {
						((GL2JNIActivity) OnScreenMenu.this.mContext)
								.screenGrab();
					}
				}
			};
			Button buttonScreenshot = (Button) hlay.findViewById(R.id.buttonScreenshot);
			addimg(buttonScreenshot, R.drawable.print_stats, clickScreenshot);

			OnClickListener clickExit = new OnClickListener() {
				public void onClick(View v) {
					if (Config.externalIntent) {
						mContext.finish();
					} else {
						Intent inte = new Intent(mContext, MainActivity.class);
						mContext.startActivity(inte);
						mContext.finish();
					}
				}
			};
			Button buttonExit = (Button) hlay.findViewById(R.id.buttonExit);
			addimg(buttonExit, R.drawable.close, clickExit);

			setContentView(shell);
			setFocusable(true);
		}

		public void hideVmu() {
			vmuIcon.removeView(vmuLcd);
		}

		public void showVmu() {
			vmuLcd.configureScale(72);
			params = setVmuParams();
			vmuIcon.addView(vmuLcd, params);
		}
	}
}
