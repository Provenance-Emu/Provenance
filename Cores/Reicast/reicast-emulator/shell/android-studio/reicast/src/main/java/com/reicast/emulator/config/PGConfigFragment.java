package com.reicast.emulator.config;

import android.app.Activity;
import android.content.Context;
import android.content.SharedPreferences;
import android.graphics.drawable.Drawable;
import android.os.AsyncTask;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.preference.PreferenceManager;
import android.support.constraint.ConstraintLayout;
import android.support.design.widget.Snackbar;
import android.support.graphics.drawable.VectorDrawableCompat;
import android.support.v4.app.Fragment;
import android.util.Log;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.inputmethod.EditorInfo;
import android.view.inputmethod.InputMethodManager;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.CompoundButton;
import android.widget.EditText;
import android.widget.SeekBar;
import android.widget.SeekBar.OnSeekBarChangeListener;
import android.widget.Spinner;
import android.widget.TextView;

import com.android.util.FileUtils;
import com.reicast.emulator.Emulator;
import com.reicast.emulator.R;
import com.reicast.emulator.periph.Gamepad;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.FilenameFilter;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.lang.ref.WeakReference;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class PGConfigFragment extends Fragment {

	private Spinner mSpnrConfigs;

	private CompoundButton switchJoystickDpadEnabled;
	private CompoundButton dynarec_opt;
	private CompoundButton unstable_opt;
	private CompoundButton safemode_opt;
	private EditText mainFrames;
	private SeekBar frameSeek;
	private CompoundButton pvr_render;
	private CompoundButton synced_render;
	private CompoundButton modifier_volumes;
	private Spinner cable_spnr;
	private Spinner region_spnr;
	private Spinner broadcast_spnr;
	private ArrayAdapter<String> broadcastAdapter;
	private EditText bootdiskEdit;

	@Override
	public void onAttach(Activity activity) {
		super.onAttach(activity);
	}

	@Override
	public void onAttach(Context context) {
		super.onAttach(context);
	}

	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container,
							 Bundle savedInstanceState) {
		// Inflate the layout for this fragment
		return inflater.inflate(R.layout.pgconfig_fragment, container, false);
	}

	@Override
	public void onViewCreated(View view, Bundle savedInstanceState) {

		Emulator app = (Emulator) getActivity().getApplicationContext();
		app.getConfigurationPrefs(PreferenceManager.getDefaultSharedPreferences(getActivity()));

		mSpnrConfigs = (Spinner) getView().findViewById(R.id.config_spinner);
		new LocateConfigs(PGConfigFragment.this).execute("/data/data/"
				+ getActivity().getPackageName() + "/shared_prefs/");

		switchJoystickDpadEnabled = (CompoundButton) getView().findViewById(
				R.id.switchJoystickDpadEnabled);
		dynarec_opt = (CompoundButton) getView().findViewById(R.id.dynarec_option);
		unstable_opt = (CompoundButton) getView().findViewById(R.id.unstable_option);
		safemode_opt = (CompoundButton) getView().findViewById(R.id.dynarec_safemode);
		mainFrames = (EditText) getView().findViewById(R.id.current_frames);
		frameSeek = (SeekBar) getView().findViewById(R.id.frame_seekbar);
		pvr_render = (CompoundButton) getView().findViewById(R.id.render_option);
		synced_render = (CompoundButton) getView().findViewById(R.id.syncrender_option);
		modifier_volumes = (CompoundButton) getView().findViewById(R.id.modvols_option);
		cable_spnr = (Spinner) getView().findViewById(R.id.cable_spinner);
		region_spnr = (Spinner) getView().findViewById(R.id.region_spinner);
		broadcast_spnr = (Spinner) getView().findViewById(R.id.broadcast_spinner);
		bootdiskEdit = (EditText) getView().findViewById(R.id.boot_disk);
	}

	private void saveSettings(SharedPreferences mPrefs) {
		mPrefs.edit()
				.putBoolean(Gamepad.pref_js_merged + "_A", switchJoystickDpadEnabled.isChecked())
				.putBoolean(Emulator.pref_dynarecopt, dynarec_opt.isChecked())
				.putBoolean(Emulator.pref_unstable, unstable_opt.isChecked())
				.putBoolean(Emulator.pref_dynsafemode, safemode_opt.isChecked())
				.putInt(Emulator.pref_frameskip, frameSeek.getProgress())
				.putBoolean(Emulator.pref_pvrrender, pvr_render.isChecked())
				.putBoolean(Emulator.pref_syncedrender, synced_render.isChecked())
				.putBoolean(Emulator.pref_modvols, modifier_volumes.isChecked()).apply();

		mPrefs.edit().putInt(Emulator.pref_cable, cable_spnr.getSelectedItemPosition()).apply();
		mPrefs.edit().putInt(Emulator.pref_dcregion, region_spnr.getSelectedItemPosition()).apply();
		String item = broadcastAdapter.getItem(broadcast_spnr.getSelectedItemPosition());
		int broadcastValue = getBroadcastValue(item);
		mPrefs.edit().putInt(Emulator.pref_broadcast, broadcastValue).apply();

		if (bootdiskEdit.getText() != null)
			mPrefs.edit().putString(Emulator.pref_bootdisk,
					bootdiskEdit.getText().toString()).apply();
		else
			mPrefs.edit().remove(Emulator.pref_bootdisk).apply();
		showToastMessage(getActivity().getString(R.string.pgconfig_saved), Snackbar.LENGTH_SHORT);
	}

	private void clearSettings(SharedPreferences mPrefs, String gameId) {
		mPrefs.edit() // Prevent clear() removing title
				.remove(Gamepad.pref_js_merged + "_A")
				.remove(Emulator.pref_dynarecopt)
				.remove(Emulator.pref_unstable)
				.remove(Emulator.pref_dynsafemode)
				.remove(Emulator.pref_frameskip)
				.remove(Emulator.pref_pvrrender)
				.remove(Emulator.pref_syncedrender)
				.remove(Emulator.pref_modvols)
				.remove(Emulator.pref_cable)
				.remove(Emulator.pref_dcregion)
				.remove(Emulator.pref_broadcast)
				.remove(Emulator.pref_bootdisk).apply();
		showToastMessage(getActivity().getString(R.string.pgconfig_cleared), Snackbar.LENGTH_SHORT);
		configureViewByGame(gameId);
	}

	private void configureViewByGame(final String gameId) {
		final SharedPreferences mPrefs = getActivity()
				.getSharedPreferences(gameId, Activity.MODE_PRIVATE);
		Compat compat = new Compat();
		switchJoystickDpadEnabled.setChecked(mPrefs.getBoolean(
				Gamepad.pref_js_merged + "_A", false));
		dynarec_opt.setChecked(mPrefs.getBoolean(Emulator.pref_dynarecopt, Emulator.dynarecopt));
		unstable_opt.setChecked(mPrefs.getBoolean(Emulator.pref_unstable, Emulator.unstableopt));
		safemode_opt.setChecked(mPrefs.getBoolean(
				Emulator.pref_dynsafemode, compat.useSafeMode(gameId)));

		int frameskip = mPrefs.getInt(Emulator.pref_frameskip, Emulator.frameskip);
		mainFrames.setText(String.valueOf(frameskip));

		frameSeek.setProgress(frameskip);
		frameSeek.setIndeterminate(false);
		frameSeek.setOnSeekBarChangeListener(new OnSeekBarChangeListener() {
			public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
				mainFrames.setText(String.valueOf(progress));
			}

			public void onStartTrackingTouch(SeekBar seekBar) {
				// TODO Auto-generated method stub
			}

			public void onStopTrackingTouch(SeekBar seekBar) {

			}
		});

		mainFrames.setOnEditorActionListener(new EditText.OnEditorActionListener() {
			@Override
			public boolean onEditorAction(TextView v, int actionId, KeyEvent event) {
				if (actionId == EditorInfo.IME_ACTION_DONE
						|| (event.getKeyCode() == KeyEvent.KEYCODE_ENTER
						&& event.getAction() == KeyEvent.ACTION_DOWN)) {
					if (event == null || !event.isShiftPressed()) {
						if (v.getText() != null) {
							int frames = Integer.parseInt(v.getText().toString());
							frameSeek.setProgress(frames);
						}
						hideSoftKeyBoard();
						return true;
					}
				}
				return false;
			}
		});

		pvr_render.setChecked(mPrefs.getBoolean(Emulator.pref_pvrrender, Emulator.pvrrender));
		synced_render.setChecked(mPrefs.getBoolean(Emulator.pref_syncedrender, Emulator.syncedrender));
		modifier_volumes.setChecked(mPrefs.getBoolean(Emulator.pref_modvols, Emulator.modvols));

		String[] cables = getResources().getStringArray(R.array.cable);
		ArrayAdapter<String> cableAdapter = new ArrayAdapter<>(getActivity(), R.layout.spinner_selected, cables);
		cableAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
		cable_spnr.setAdapter(cableAdapter);
		cable_spnr.setSelection(mPrefs.getInt(Emulator.pref_cable,
				compat.isVGACompatible(gameId)), true);

		String[] regions = getResources().getStringArray(R.array.region);
		ArrayAdapter<String> regionAdapter = new ArrayAdapter<>(getActivity(), R.layout.spinner_selected, regions);
		regionAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
		region_spnr.setAdapter(regionAdapter);
		region_spnr.setSelection(mPrefs.getInt(Emulator.pref_dcregion, Emulator.dcregion), true);

		String[] broadcasts = getResources().getStringArray(R.array.broadcast);
		Spinner broadcast_spnr = (Spinner) getView().findViewById(R.id.broadcast_spinner);
		broadcastAdapter = new ArrayAdapter<>(getActivity(), R.layout.spinner_selected, broadcasts);
		broadcastAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
		broadcast_spnr.setAdapter(broadcastAdapter);

		String cast = getBroadcastName(mPrefs.getInt(Emulator.pref_broadcast, Emulator.broadcast));
		for (int i = 0; i < broadcasts.length; i++) {
			if (broadcasts[i].equals(cast)) {
				broadcast_spnr.setSelection(i, true);
				break;
			}
		}
		
		bootdiskEdit.setText(mPrefs.getString(Emulator.pref_bootdisk, Emulator.bootdisk));

		bootdiskEdit.setOnEditorActionListener(new EditText.OnEditorActionListener() {
			@Override
			public boolean onEditorAction(TextView v, int actionId, KeyEvent event) {
				if (actionId == EditorInfo.IME_ACTION_DONE
						|| (event.getKeyCode() == KeyEvent.KEYCODE_ENTER
						&& event.getAction() == KeyEvent.ACTION_DOWN)) {
					if (event == null || !event.isShiftPressed()) {
						String disk;
						if (v.getText() != null) {
							disk = v.getText().toString();
							if (disk.equals("") || disk.substring(
									disk.lastIndexOf("/") + 1).length() == 0) {
								disk = null;
							} else {
								if (!disk.contains("/"))
									disk = mPrefs.getString(Config.pref_games,
											Environment.getExternalStorageDirectory()
													.getAbsolutePath()) + "/" + disk;
								if (!new File(disk).exists())
									disk = null;
							}
							v.setText(disk);
						}
						hideSoftKeyBoard();
						return true;
					}
				}
				return false;
			}
		});

		Button savePGC = (Button) getView().findViewById(R.id.save_pg_btn);
		savePGC.setOnClickListener(new View.OnClickListener() {
			public void onClick(View view) {
				saveSettings(mPrefs);
			}
		});

		Button importPGC = (Button) getView().findViewById(R.id.import_pg_btn);
		importPGC.setOnClickListener(new View.OnClickListener() {
			public void onClick(View view) {
				try {
					File xml = new File("/data/data/"
							+ getActivity().getPackageName(),"/shared_prefs/");
					if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
						xml = new File(getActivity().getDataDir(),
								"/shared_prefs/" + gameId + ".xml");
					}
					copy(new File(getActivity().getExternalFilesDir(null),
							gameId + ".xml"), xml);
					showToastMessage(getActivity().getString(
							R.string.pgconfig_imported), Snackbar.LENGTH_SHORT);
					configureViewByGame(gameId);
				} catch (Exception e) {
					e.printStackTrace();
				}
			}
		});

		Button exportPGC = (Button) getView().findViewById(R.id.export_pg_btn);
		exportPGC.setOnClickListener(new View.OnClickListener() {
			public void onClick(View view) {
				try {
					File xml = new File("/data/data/"
							+ getActivity().getPackageName(),"/shared_prefs/");
					if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
						xml = new File(getActivity().getDataDir(),
								"/shared_prefs/" + gameId + ".xml");
					}
						copy(xml, new File(getActivity().getExternalFilesDir(null),
								gameId + ".xml"));
					showToastMessage(getActivity().getString(
							R.string.pgconfig_exported), Snackbar.LENGTH_SHORT);
				} catch (Exception e) {
					e.printStackTrace();
				}
			}
		});

		Button clearPGC = (Button) getView().findViewById(R.id.clear_pg_btn);
		clearPGC.setOnClickListener(new View.OnClickListener() {
			public void onClick(View view) {
				clearSettings(mPrefs, gameId);
			}
		});
	}

	private void copy(File src, File dst) throws IOException {
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
			try (InputStream in = new FileInputStream(src)) {
				try (OutputStream out = new FileOutputStream(dst)) {
					// Transfer bytes from in to out
					byte[] buf = new byte[1024];
					int len;
					while ((len = in.read(buf)) > 0) {
						out.write(buf, 0, len);
					}
				}
			}
		} else {
			InputStream in = new FileInputStream(src);
			OutputStream out = new FileOutputStream(dst);
			try {
				// Transfer bytes from in to out
				byte[] buf = new byte[1024];
				int len;
				while ((len = in.read(buf)) > 0) {
					out.write(buf, 0, len);
				}
			} finally {
				in.close();
				out.close();
			}
		}
	}

	private static class LocateConfigs extends AsyncTask<String, Integer, List<File>> {
		private WeakReference<PGConfigFragment> options;

		LocateConfigs(PGConfigFragment context) {
			options = new WeakReference<>(context);
		}

		@Override
		protected List<File> doInBackground(String... paths) {
			File storage = new File(paths[0]);
			Log.d("Files", storage.getAbsolutePath());
			FilenameFilter[] filter = new FilenameFilter[1];
			filter[0] = new FilenameFilter() {
				public boolean accept(File dir, String name) {
					return !name.endsWith("_preferences.xml");
				}
			};
			FileUtils fileUtils = new FileUtils();
			Collection<File> files = fileUtils.listFiles(storage, filter, 0);
			return (List<File>) files;
		}

		@Override
		protected void onPostExecute(List<File> items) {
			if (items != null && !items.isEmpty()) {
				final Map<String, String> gameMap = new HashMap<>();
				String[] titles = new String[items.size()];
				for (int i = 0; i < items.size(); i ++) {
					String filename = items.get(i).getName();
					String gameFile = filename.substring(0, filename.length() - 4);
					SharedPreferences mPrefs = options.get().getActivity()
							.getSharedPreferences(gameFile, Activity.MODE_PRIVATE);
					titles[i] = mPrefs.getString(Config.game_title, "Title Unavailable");
					gameMap.put(titles[i], gameFile);
				}
				ArrayAdapter<String> configAdapter = new ArrayAdapter<String>(
						options.get().getActivity(), android.R.layout.simple_spinner_item, titles);
				configAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
				options.get().mSpnrConfigs.setAdapter(configAdapter);
				options.get().mSpnrConfigs.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {
					@Override
					public void onItemSelected(AdapterView<?> parent, View select, int pos, long id) {
						options.get().configureViewByGame(gameMap.get(
								String.valueOf(parent.getItemAtPosition(pos))
						));
					}
					@Override
					public void onNothingSelected(AdapterView<?> parentView) {

					}
				});
			} else {
				options.get().mSpnrConfigs.setEnabled(false);
			}
		}
	}

	private void hideSoftKeyBoard() {
		InputMethodManager iMm = (InputMethodManager) getActivity()
				.getSystemService(Context.INPUT_METHOD_SERVICE);
		if (iMm != null && iMm.isAcceptingText()) {
			iMm.hideSoftInputFromWindow(getActivity().getCurrentFocus().getWindowToken(), 0);
		}
	}

	private void showToastMessage(String message, int duration) {
		ConstraintLayout layout = (ConstraintLayout) getActivity().findViewById(R.id.mainui_layout);
		Snackbar snackbar = Snackbar.make(layout, message, duration);
		View snackbarLayout = snackbar.getView();
		TextView textView = (TextView) snackbarLayout.findViewById(
				android.support.design.R.id.snackbar_text);
		textView.setGravity(Gravity.CENTER_VERTICAL);
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR1)
			textView.setTextAlignment(View.TEXT_ALIGNMENT_GRAVITY);
		Drawable drawable;
		if (android.os.Build.VERSION.SDK_INT > Build.VERSION_CODES.M) {
			drawable = getResources().getDrawable(
					R.drawable.ic_settings, getActivity().getTheme());
		} else {
			drawable = VectorDrawableCompat.create(getResources(),
					R.drawable.ic_settings, getActivity().getTheme());
		}
		textView.setCompoundDrawablesWithIntrinsicBounds(drawable, null, null, null);
		textView.setCompoundDrawablePadding(getResources()
				.getDimensionPixelOffset(R.dimen.snackbar_icon_padding));
		snackbar.show();
	}

	private int getBroadcastValue(String broadcastName) {
		if (broadcastName.equals("NTSC-J"))
			return 0;
		else if (broadcastName.equals("NTSC-U"))
			return 4;
		else if (broadcastName.equals("PAL-M"))
			return 6;
		else if (broadcastName.equals("PAL-N"))
			return 7;
		else if (broadcastName.equals("PAL-E"))
			return 9;
		else
			return -1;
	}

	private String getBroadcastName(int broadcastValue) {
		if (broadcastValue == 0)
			return "NTSC-J";
		else if (broadcastValue == 4)
			return "NTSC-U";
		else if (broadcastValue == 6)
			return "PAL-M";
		else if (broadcastValue == 7)
			return "PAL-N";
		else if (broadcastValue == 9)
			return "PAL-E";
		else
			return null;
	}
}
