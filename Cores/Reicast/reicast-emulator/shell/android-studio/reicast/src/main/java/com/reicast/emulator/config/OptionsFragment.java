package com.reicast.emulator.config;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Context;
import android.content.DialogInterface;
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
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.inputmethod.EditorInfo;
import android.view.inputmethod.InputMethodManager;
import android.widget.AdapterView;
import android.widget.AdapterView.OnItemSelectedListener;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.CompoundButton;
import android.widget.CompoundButton.OnCheckedChangeListener;
import android.widget.EditText;
import android.widget.SeekBar;
import android.widget.SeekBar.OnSeekBarChangeListener;
import android.widget.Spinner;
import android.widget.TextView;

import com.android.util.FileUtils;
import com.reicast.emulator.Emulator;
import com.reicast.emulator.FileBrowser;
import com.reicast.emulator.R;
import com.reicast.emulator.emu.GL2JNIView;
import com.reicast.emulator.emu.JNIdc;

import org.apache.commons.lang3.StringUtils;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.FilenameFilter;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.lang.ref.WeakReference;
import java.util.Collection;
import java.util.HashSet;
import java.util.List;

public class OptionsFragment extends Fragment {

	private Spinner mSpnrThemes;
	private OnClickListener mCallback;

	private SharedPreferences mPrefs;
	private File sdcard = Environment.getExternalStorageDirectory();
	private String home_directory = sdcard.getAbsolutePath();
	private String game_directory = sdcard.getAbsolutePath();

	private String[] codes;

	// Container Activity must implement this interface
	public interface OnClickListener {
		void recreateActivity();
		void onMainBrowseSelected(String path_entry, boolean games, String query);
		void launchBIOSdetection();
	}

	@Override  @SuppressWarnings("deprecation")
	public void onAttach(Activity activity) {
		super.onAttach(activity);

		// This makes sure that the container activity has implemented
		// the callback interface. If not, it throws an exception
		try {
			mCallback = (OnClickListener) activity;
		} catch (ClassCastException e) {
			throw new ClassCastException(activity.toString()
					+ " must implement OnClickListener");
		}
	}

	@Override
	public void onAttach(Context context) {
		super.onAttach(context);

		// This makes sure that the container activity has implemented
		// the callback interface. If not, it throws an exception
		try {
			mCallback = (OnClickListener) context;
		} catch (ClassCastException e) {
			throw new ClassCastException(context.getClass().toString()
					+ " must implement OnClickListener");
		}
	}

	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container,
							 Bundle savedInstanceState) {
		// Inflate the layout for this fragment
		return inflater.inflate(R.layout.configure_fragment, container, false);
	}

	@Override
	public void onViewCreated(View view, Bundle savedInstanceState) {

		mPrefs = PreferenceManager.getDefaultSharedPreferences(getActivity());

		// Specialized handler for devices with an extSdCard mount for external
		HashSet<String> extStorage = FileBrowser.getExternalMounts();
		if (extStorage != null && !extStorage.isEmpty()) {
			for (String sd : extStorage) {
				String sdCardPath = sd.replace("mnt/media_rw", "storage");
				if (!sdCardPath.equals(sdcard.getAbsolutePath())) {
					game_directory = sdCardPath;
				}
			}
		}

		home_directory = mPrefs.getString(Config.pref_home, home_directory);
		Emulator app = (Emulator) getActivity().getApplicationContext();
		app.getConfigurationPrefs(mPrefs);

		// Generate the menu options and fill in existing settings
		Button mainBrowse = (Button) getView().findViewById(R.id.browse_main_path);
		mSpnrThemes = (Spinner) getView().findViewById(R.id.pick_button_theme);
		new LocateThemes(this).execute(home_directory + "/themes");

		final EditText editBrowse = (EditText) getView().findViewById(R.id.main_path);
		editBrowse.setText(home_directory);

		mainBrowse.setOnClickListener(new View.OnClickListener() {
			public void onClick(View view) {
				mPrefs.edit().remove(Config.pref_home).apply();
				hideSoftKeyBoard();
				mCallback.launchBIOSdetection();
			}
		});
		editBrowse.setOnEditorActionListener(new EditText.OnEditorActionListener() {
			@Override
			public boolean onEditorAction(TextView v, int actionId, KeyEvent event) {
				if (actionId == EditorInfo.IME_ACTION_DONE
						|| (event.getKeyCode() == KeyEvent.KEYCODE_ENTER
						&& event.getAction() == KeyEvent.ACTION_DOWN)) {
					if (event == null || !event.isShiftPressed()) {
						if (v.getText() != null) {
							home_directory = v.getText().toString();
							if (home_directory.endsWith("/data")) {
								home_directory.replace("/data", "");
								showToastMessage(getActivity().getString(R.string.data_folder),
										Snackbar.LENGTH_SHORT);
							}
							mPrefs.edit().putString(Config.pref_home, home_directory).apply();
							JNIdc.config(home_directory);
							new LocateThemes(OptionsFragment.this).execute(home_directory + "/themes");
						}
						hideSoftKeyBoard();
						return true;
					}
				}
				return false;
			}
		});

		OnCheckedChangeListener reios_options = new OnCheckedChangeListener() {

			public void onCheckedChanged(CompoundButton buttonView,
										 boolean isChecked) {
				mPrefs.edit().putBoolean(Emulator.pref_usereios, isChecked).apply();
			}
		};
		CompoundButton reios_opt = (CompoundButton) getView().findViewById(R.id.reios_option);
		reios_opt.setChecked(mPrefs.getBoolean(Emulator.pref_usereios, false));
		reios_opt.setOnCheckedChangeListener(reios_options);

		String[] app_themes = getResources().getStringArray(R.array.themes_app);
		Spinner aSpnrThemes = (Spinner) getView().findViewById(R.id.pick_app_theme);
		ArrayAdapter<String> themeAdapter = new ArrayAdapter<>(getActivity(),
				android.R.layout.simple_spinner_item, app_themes);
		themeAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
		aSpnrThemes.setAdapter(themeAdapter);
		int app_theme = mPrefs.getInt(Config.pref_app_theme, 0);
		if (app_theme == 7) {
			aSpnrThemes.setSelection(themeAdapter.getPosition("Dream"), true);
		} else {
			aSpnrThemes.setSelection(app_theme, true);
		}
		aSpnrThemes.setOnItemSelectedListener(new OnItemSelectedListener() {
			@Override
			public void onItemSelected(AdapterView<?> parentView, View selectedItemView, int position, long id) {
				String theme = String.valueOf(parentView.getItemAtPosition(position));
				int current = mPrefs.getInt(Config.pref_app_theme, 0);
				if (theme.equals("Dream")) {
					mPrefs.edit().putInt(Config.pref_app_theme, 7).apply();
					if (current != 7)
						mCallback.recreateActivity();
				} else {
					mPrefs.edit().putInt(Config.pref_app_theme, position).apply();
					if (current != position)
						mCallback.recreateActivity();
				}
			}
			@Override
			public void onNothingSelected(AdapterView<?> parentView) {

			}
		});

		OnCheckedChangeListener details_options = new OnCheckedChangeListener() {

			public void onCheckedChanged(CompoundButton buttonView,
										 boolean isChecked) {
				mPrefs.edit().putBoolean(Config.pref_gamedetails, isChecked).apply();
				if (!isChecked) {
					File dir = new File(getActivity().getExternalFilesDir(null), "images");
					for (File file : dir.listFiles()) {
						if (!file.isDirectory()) {
							file.delete();
						}
					}
				}
			}
		};
		CompoundButton details_opt = (CompoundButton) getView().findViewById(R.id.details_option);
		details_opt.setChecked(mPrefs.getBoolean(Config.pref_gamedetails, false));
		details_opt.setOnCheckedChangeListener(details_options);

		Button gameBrowse = (Button) getView().findViewById(R.id.browse_game_path);

		final EditText editGames = (EditText) getView().findViewById(R.id.game_path);
		game_directory = mPrefs.getString(Config.pref_games, game_directory);
		editGames.setText(game_directory);

		gameBrowse.setOnClickListener(new View.OnClickListener() {
			public void onClick(View view) {
				mPrefs.edit().remove(Config.pref_games).apply();
				if (editBrowse.getText() != null) {
					game_directory = editGames.getText().toString();
				}
				hideSoftKeyBoard();
				mCallback.onMainBrowseSelected(game_directory, true, null);
			}
		});
		editGames.setOnEditorActionListener(new EditText.OnEditorActionListener() {
			@Override
			public boolean onEditorAction(TextView v, int actionId, KeyEvent event) {
				if (actionId == EditorInfo.IME_ACTION_DONE
						|| (event.getKeyCode() == KeyEvent.KEYCODE_ENTER
						&& event.getAction() == KeyEvent.ACTION_DOWN)) {
					if (event == null || !event.isShiftPressed()) {
						if (v.getText() != null) {
							game_directory = v.getText().toString();
							mPrefs.edit().putString(Config.pref_games, game_directory).apply();
						}
						hideSoftKeyBoard();
						return true;
					}
				}
				return false;
			}
		});

		String[] bios = getResources().getStringArray(R.array.bios);
		codes = getResources().getStringArray(R.array.bioscode);
		Spinner bios_spnr = (Spinner) getView().findViewById(R.id.bios_spinner);
		ArrayAdapter<String> biosAdapter = new ArrayAdapter<>(
				getActivity(), android.R.layout.simple_spinner_item, bios);
		biosAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
		bios_spnr.setAdapter(biosAdapter);
		String region = mPrefs.getString(Config.bios_code, codes[4]);
		bios_spnr.setSelection(biosAdapter.getPosition(region), true);
		bios_spnr.setOnItemSelectedListener(new OnItemSelectedListener() {

			public void onItemSelected(AdapterView<?> parent, View view, int pos, long id) {
				flashBios(codes[pos]);
			}

			public void onNothingSelected(AdapterView<?> arg0) {

			}

		});

		OnCheckedChangeListener dynarec_options = new OnCheckedChangeListener() {

			public void onCheckedChanged(CompoundButton buttonView,
										 boolean isChecked) {
				mPrefs.edit().putBoolean(Emulator.pref_dynarecopt, isChecked).apply();
			}
		};
		CompoundButton dynarec_opt = (CompoundButton) getView().findViewById(R.id.dynarec_option);
		dynarec_opt.setChecked(Emulator.dynarecopt);
		dynarec_opt.setOnCheckedChangeListener(dynarec_options);

		OnCheckedChangeListener unstable_option = new OnCheckedChangeListener() {

			public void onCheckedChanged(CompoundButton buttonView,
										 boolean isChecked) {
				mPrefs.edit().putBoolean(Emulator.pref_unstable, isChecked).apply();
			}
		};
		CompoundButton unstable_opt = (CompoundButton) getView().findViewById(R.id.unstable_option);
		unstable_opt.setChecked(mPrefs.getBoolean(Emulator.pref_unstable, Emulator.unstableopt));
		unstable_opt.setOnCheckedChangeListener(unstable_option);

		setSpinner(R.array.cable, R.id.cable_spinner,
				Emulator.pref_cable, Emulator.cable, false);

		setSpinner(R.array.region, R.id.region_spinner,
				Emulator.pref_dcregion, Emulator.dcregion, false);

		String[] broadcasts = getResources().getStringArray(R.array.broadcast);
		Spinner broadcast_spnr = (Spinner) getView().findViewById(R.id.broadcast_spinner);
		ArrayAdapter<String> broadcastAdapter = new ArrayAdapter<>(
				getActivity(), R.layout.spinner_selected, broadcasts);
		broadcastAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
		broadcast_spnr.setAdapter(broadcastAdapter);

		String cast = getBroadcastName(mPrefs.getInt(Emulator.pref_broadcast, Emulator.broadcast));
		for (int i = 0; i < broadcasts.length; i++) {
			if (broadcasts[i].equals(cast)) {
				broadcast_spnr.setSelection(i, true);
				break;
			}
		}
		broadcast_spnr.setOnItemSelectedListener(new OnItemSelectedListener() {

			public void onItemSelected(AdapterView<?> parent, View view, int pos, long id) {
				String item = parent.getItemAtPosition(pos).toString();
				int broadcastValue = getBroadcastValue(item);
				mPrefs.edit().putInt(Emulator.pref_broadcast, broadcastValue).apply();

			}

			public void onNothingSelected(AdapterView<?> arg0) {

			}
		});

		OnCheckedChangeListener limitfps_option = new OnCheckedChangeListener() {

			public void onCheckedChanged(CompoundButton buttonView, boolean isChecked) {
				mPrefs.edit().putBoolean(Emulator.pref_limitfps, isChecked).apply();
			}
		};
		CompoundButton limit_fps = (CompoundButton) getView().findViewById(R.id.limitfps_option);
		limit_fps.setChecked(mPrefs.getBoolean(Emulator.pref_limitfps, Emulator.limitfps));
		limit_fps.setOnCheckedChangeListener(limitfps_option);

		OnCheckedChangeListener mipmaps_option = new OnCheckedChangeListener() {

			public void onCheckedChanged(CompoundButton buttonView, boolean isChecked) {
				mPrefs.edit().putBoolean(Emulator.pref_mipmaps, isChecked).apply();
			}
		};
		CompoundButton mipmap_opt = (CompoundButton) getView().findViewById(R.id.mipmaps_option);
		mipmap_opt.setChecked(mPrefs.getBoolean(Emulator.pref_mipmaps, Emulator.mipmaps));
		mipmap_opt.setOnCheckedChangeListener(mipmaps_option);

		setSpinner(R.array.resolution, R.id.resolution_spinner,
				Emulator.pref_resolution, 0, false);

		int frameskip = mPrefs.getInt(Emulator.pref_frameskip, Emulator.frameskip);

		final EditText mainFrames = (EditText) getView().findViewById(R.id.current_frames);
		mainFrames.setText(String.valueOf(frameskip));

		final SeekBar frameSeek = (SeekBar) getView().findViewById(R.id.frame_seekbar);
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
				int progress = seekBar.getProgress();
				mPrefs.edit().putInt(Emulator.pref_frameskip, progress).apply();
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
							mPrefs.edit().putInt(Emulator.pref_frameskip, frames).apply();
						}
						hideSoftKeyBoard();
						return true;
					}
				}
				return false;
			}
		});

		OnCheckedChangeListener pvr_rendering = new OnCheckedChangeListener() {

			public void onCheckedChanged(CompoundButton buttonView, boolean isChecked) {
				mPrefs.edit().putBoolean(Emulator.pref_pvrrender, isChecked).apply();
			}
		};
		CompoundButton pvr_render = (CompoundButton) getView().findViewById(R.id.render_option);
		pvr_render.setChecked(mPrefs.getBoolean(Emulator.pref_pvrrender, Emulator.pvrrender));
		pvr_render.setOnCheckedChangeListener(pvr_rendering);

		OnCheckedChangeListener synchronous = new OnCheckedChangeListener() {
			public void onCheckedChanged(CompoundButton buttonView, boolean isChecked) {
				mPrefs.edit().putBoolean(Emulator.pref_syncedrender, isChecked).apply();
			}
		};
		CompoundButton synced_render = (CompoundButton) getView().findViewById(R.id.syncrender_option);
		synced_render.setChecked(mPrefs.getBoolean(Emulator.pref_syncedrender, Emulator.syncedrender));
		synced_render.setOnCheckedChangeListener(synchronous);

		final EditText bootdiskEdit = (EditText) getView().findViewById(R.id.boot_disk);
		bootdiskEdit.setText(mPrefs.getString(Emulator.pref_bootdisk, Emulator.bootdisk));

		bootdiskEdit.setOnEditorActionListener(new EditText.OnEditorActionListener() {
					@Override
					public boolean onEditorAction(TextView v, int actionId, KeyEvent event) {
						if (actionId == EditorInfo.IME_ACTION_DONE
								|| (event.getKeyCode() == KeyEvent.KEYCODE_ENTER
								&& event.getAction() == KeyEvent.ACTION_DOWN)) {
							if (event == null || !event.isShiftPressed()) {
								String disk = null;
								if (v.getText() != null) {
									disk = v.getText().toString();
									if (disk.equals("") || disk.substring(
											disk.lastIndexOf("/") + 1).length() == 0) {
										disk = null;
									} else {
										if (!disk.contains("/"))
											disk = game_directory + "/" + disk;
										if (!new File(disk).exists())
											disk = null;
									}
									v.setText(disk);
								}
								if (disk == null)
									mPrefs.edit().remove(Emulator.pref_bootdisk).apply();
								else
									mPrefs.edit().putString(Emulator.pref_bootdisk, disk).apply();
								hideSoftKeyBoard();
								return true;
							}
						}
						return false;
					}
				});

		final CompoundButton fps_opt = (CompoundButton) getView().findViewById(R.id.fps_option);
		OnCheckedChangeListener fps_options = new OnCheckedChangeListener() {

			public void onCheckedChanged(CompoundButton buttonView,
										 boolean isChecked) {
				mPrefs.edit().putBoolean(Config.pref_showfps, isChecked).apply();
			}
		};
		boolean counter = mPrefs.getBoolean(Config.pref_showfps, false);
		fps_opt.setChecked(counter);
		fps_opt.setOnCheckedChangeListener(fps_options);

		CompoundButton force_software_opt = (CompoundButton) getView().findViewById(
				R.id.software_option);
		OnCheckedChangeListener force_software = new OnCheckedChangeListener() {

			public void onCheckedChanged(CompoundButton buttonView, boolean isChecked) {
				mPrefs.edit().putInt(Config.pref_rendertype, isChecked ?
						GL2JNIView.LAYER_TYPE_SOFTWARE : GL2JNIView.LAYER_TYPE_HARDWARE).apply();
			}
		};
		int software = mPrefs.getInt(Config.pref_rendertype, GL2JNIView.LAYER_TYPE_HARDWARE);
		force_software_opt.setChecked(software == GL2JNIView.LAYER_TYPE_SOFTWARE);
		force_software_opt.setOnCheckedChangeListener(force_software);

		CompoundButton sound_opt = (CompoundButton) getView().findViewById(R.id.sound_option);
		OnCheckedChangeListener emu_sound = new OnCheckedChangeListener() {

			public void onCheckedChanged(CompoundButton buttonView, boolean isChecked) {
				mPrefs.edit().putBoolean(Emulator.pref_nosound, isChecked).apply();
			}
		};
		boolean sound = mPrefs.getBoolean(Emulator.pref_nosound, false);
		sound_opt.setChecked(sound);
		sound_opt.setOnCheckedChangeListener(emu_sound);


		setSpinner(R.array.depth, R.id.depth_spinner,
				Config.pref_renderdepth, 24, true);

		Button resetEmu = (Button) getView().findViewById(R.id.reset_emu_btn);
		resetEmu.setOnClickListener(new View.OnClickListener() {
			public void onClick(View view) {
				AlertDialog.Builder b = new AlertDialog.Builder(getActivity());
				b.setIcon(android.R.drawable.ic_dialog_alert);
				b.setTitle(getActivity().getString(R.string.reset_emu_title) + "?");
				b.setMessage(getActivity().getString(R.string.reset_emu_details));
				b.setPositiveButton(android.R.string.yes, new DialogInterface.OnClickListener() {
					public void onClick(DialogInterface dialog, int id) {
						resetEmuSettings();
					}
				});
				b.setNegativeButton(android.R.string.no, null);
				b.show();
			}
		});
	}

	private void setSpinner(int array, int view, final String pref, int def, final boolean parse) {
		String[] stringArray = getResources().getStringArray(array);
		Spinner spinner = (Spinner) getView().findViewById(view);
		ArrayAdapter<String> adapter = new ArrayAdapter<>(
				getActivity(), R.layout.spinner_selected, stringArray);
		adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
		spinner.setAdapter(adapter);

		if (parse) {
			String value = String.valueOf(mPrefs.getInt(pref, def));
			spinner.setSelection(adapter.getPosition(value), true);
		} else {
			spinner.setSelection(mPrefs.getInt(pref, def), true);
		}

		spinner.setOnItemSelectedListener(new OnItemSelectedListener() {

			public void onItemSelected(AdapterView<?> parent, View view, int pos, long id) {
				if (parse) {
					int value = Integer.parseInt(parent.getItemAtPosition(pos).toString());
					mPrefs.edit().putInt(pref, value).apply();
				} else {
					mPrefs.edit().putInt(pref, pos).apply();
				}

			}

			public void onNothingSelected(AdapterView<?> arg0) {

			}

		});
	}

	private static class LocateThemes extends AsyncTask<String, Integer, List<File>> {
		private WeakReference<OptionsFragment> options;

		LocateThemes(OptionsFragment context) {
			options = new WeakReference<>(context);
		}

		@Override
		protected List<File> doInBackground(String... paths) {
			File storage = new File(paths[0]);
			String[] mediaTypes = options.get().getResources().getStringArray(R.array.themes_ext);
			FilenameFilter[] filter = new FilenameFilter[mediaTypes.length];
			int i = 0;
			for (final String type : mediaTypes) {
				filter[i] = new FilenameFilter() {
					public boolean accept(File dir, String name) {
						return !dir.getName().startsWith(".") && !name.startsWith(".")
								&& StringUtils.endsWithIgnoreCase(name, "." + type);
					}
				};
				i++;
			}
			FileUtils fileUtils = new FileUtils();
			Collection<File> files = fileUtils.listFiles(storage, filter, 0);
			return (List<File>) files;
		}

		@Override
		protected void onPostExecute(List<File> items) {
			if (items != null && !items.isEmpty()) {
				String[] themes = new String[items.size() + 1];
				for (int i = 0; i < items.size(); i ++) {
					themes[i] = items.get(i).getName();
				}
				themes[items.size()] = "None";
				ArrayAdapter<String> themeAdapter = new ArrayAdapter<>(
						options.get().getActivity(), android.R.layout.simple_spinner_item, themes);
				themeAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
				options.get().mSpnrThemes.setAdapter(themeAdapter);
				options.get().mSpnrThemes.setOnItemSelectedListener(new OnItemSelectedListener() {
					@Override
					public void onItemSelected(AdapterView<?> parentView, View selectedItemView, int position, long id) {
						String theme = String.valueOf(parentView.getItemAtPosition(position));
						if (theme.equals("None")) {
							options.get().mPrefs.edit().remove(Config.pref_button_theme).apply();
						} else {
							String theme_path = options.get().home_directory + "/themes/" + theme;
							options.get().mPrefs.edit().putString(Config.pref_button_theme, theme_path).apply();
						}
					}
					@Override
					public void onNothingSelected(AdapterView<?> parentView) {

					}
				});
			} else {
				options.get().mSpnrThemes.setEnabled(false);
			}
		}
	}

	private void hideSoftKeyBoard() {
		try {
			InputMethodManager iMm = (InputMethodManager) getActivity()
					.getSystemService(Context.INPUT_METHOD_SERVICE);
			if (iMm != null && iMm.isAcceptingText()) {
				iMm.hideSoftInputFromWindow(getActivity().getCurrentFocus().getWindowToken(), 0);
			}
		} catch (NullPointerException e) {
			// Keyboard may still be visible
		}
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

	private void flashBios(String localized) {
		File local = new File(home_directory, "data/dc_flash[" + localized
				+ "].bin");
		File flash = new File(home_directory, "data/dc_flash.bin");

		if (local.exists()) {
			if (flash.exists()) {
				flash.delete();
			}
			try {
				copy(local, flash);
			} catch (IOException ex) {
				ex.printStackTrace();
				local.renameTo(flash);
			}
			mPrefs.edit().putString(Config.bios_code, localized).apply();
		}
	}

	private void resetEmuSettings() {
		mPrefs.edit().remove(Emulator.pref_usereios).apply();
		mPrefs.edit().remove(Config.pref_gamedetails).apply();
		mPrefs.edit().remove(Emulator.pref_dynarecopt).apply();
		mPrefs.edit().remove(Emulator.pref_unstable).apply();
		mPrefs.edit().remove(Emulator.pref_cable).apply();
		mPrefs.edit().remove(Emulator.pref_dcregion).apply();
		mPrefs.edit().remove(Emulator.pref_broadcast).apply();
		mPrefs.edit().remove(Emulator.pref_limitfps).apply();
		mPrefs.edit().remove(Emulator.pref_mipmaps).apply();
		mPrefs.edit().remove(Emulator.pref_resolution).apply();
		mPrefs.edit().remove(Emulator.pref_frameskip).apply();
		mPrefs.edit().remove(Emulator.pref_pvrrender).apply();
		mPrefs.edit().remove(Emulator.pref_syncedrender).apply();
		mPrefs.edit().remove(Emulator.pref_bootdisk).apply();
		mPrefs.edit().remove(Config.pref_showfps).apply();
		mPrefs.edit().remove(Config.pref_rendertype).apply();
		mPrefs.edit().remove(Emulator.pref_nosound).apply();
		mPrefs.edit().remove(Config.pref_renderdepth).apply();
		mPrefs.edit().remove(Config.pref_button_theme).apply();

		Emulator.usereios = false;
		Emulator.dynarecopt = true;
		Emulator.unstableopt = false;
		Emulator.cable = 3;
		Emulator.dcregion = 3;
		Emulator.broadcast = 4;
		Emulator.limitfps = true;
		Emulator.mipmaps = true;
		Emulator.widescreen = false;
		Emulator.crtview = false;
		Emulator.frameskip = 0;
		Emulator.pvrrender = false;
		Emulator.syncedrender = false;
		Emulator.bootdisk = null;
		Emulator.nosound = false;

		mCallback.recreateActivity();
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
