package com.reicast.emulator;

import android.app.Activity;
import android.content.Context;
import android.content.SharedPreferences;
import android.content.res.ColorStateList;
import android.graphics.Typeface;
import android.graphics.drawable.Drawable;
import android.net.Uri;
import android.os.AsyncTask;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.os.Vibrator;
import android.preference.PreferenceManager;
import android.support.constraint.ConstraintLayout;
import android.support.design.widget.Snackbar;
import android.support.graphics.drawable.VectorDrawableCompat;
import android.support.v4.app.Fragment;
import android.support.v4.content.ContextCompat;
import android.support.v4.content.FileProvider;
import android.support.v4.widget.ImageViewCompat;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import com.android.util.FileUtils;
import com.reicast.emulator.config.Config;
import com.reicast.emulator.emu.JNIdc;

import org.apache.commons.lang3.StringUtils;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.FilenameFilter;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.lang.ref.WeakReference;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collection;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;

public class FileBrowser extends Fragment {

	private Vibrator vib;
	private boolean games;
	private String searchQuery = null;
	private OnItemSelectedListener mCallback;

	private SharedPreferences mPrefs;
	private File sdcard = Environment.getExternalStorageDirectory();
	private String home_directory = sdcard.getAbsolutePath();
	private String game_directory = sdcard.getAbsolutePath();

	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);

		mPrefs = PreferenceManager.getDefaultSharedPreferences(getActivity());
		home_directory = mPrefs.getString(Config.pref_home, home_directory);
		game_directory = mPrefs.getString(Config.pref_games, game_directory);

		Bundle b = getArguments();
		if (b != null) {
			if (games = b.getBoolean("games_entry", false)) {
				if (b.getString("path_entry") != null) {
					home_directory = b.getString("path_entry");
				}
			} else {
				if (b.getString("path_entry") != null) {
					game_directory = b.getString("path_entry");
				}
			}
			if (b.getString("search_params") != null) {
				searchQuery = b.getString("search_params");
			}
		}
	}

	public static HashSet<String> getExternalMounts() {
		final HashSet<String> out = new HashSet<>();
		String reg = "(?i).*vold.*(vfat|ntfs|exfat|fat32|ext3|ext4|fuse|sdfat).*rw.*";
		StringBuilder s = new StringBuilder();
		try {
			final Process process = new ProcessBuilder().command("mount")
					.redirectErrorStream(true).start();
			process.waitFor();
			InputStream is = process.getInputStream();
			byte[] buffer = new byte[1024];
			while (is.read(buffer) != -1) {
				s.append(new String(buffer));
			}
			is.close();

			String[] lines = s.toString().split("\n");
			for (String line : lines) {
				if (StringUtils.containsIgnoreCase(line, "secure"))
					continue;
				if (StringUtils.containsIgnoreCase(line, "asec"))
					continue;
				if (line.matches(reg)) {
					String[] parts = line.split(" ");
					for (String part : parts) {
						if (part.startsWith("/"))
							if (!StringUtils.containsIgnoreCase(part, "vold"))
								out.add(part);
					}
				}
			}
		} catch (final Exception e) {
			e.printStackTrace();
		}
		return out;
	}

	// Container Activity must implement this interface
	public interface OnItemSelectedListener {
		void onGameSelected(Uri uri);
		void onFolderSelected(Uri uri);
	}

	@Override @SuppressWarnings("deprecation")
	public void onAttach(Activity activity) {
		super.onAttach(activity);

		// This makes sure that the container activity has implemented
		// the callback interface. If not, it throws an exception
		try {
			mCallback = (OnItemSelectedListener) activity;
		} catch (ClassCastException e) {
			throw new ClassCastException(activity.toString()
					+ " must implement OnItemSelectedListener");
		}
	}

	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container,
			Bundle savedInstanceState) {
		return inflater.inflate(R.layout.browser_fragment, container, false);
	}

	@Override
	public void onViewCreated(View view, Bundle savedInstanceState) {
		// setContentView(R.layout.activity_main);

		vib = (Vibrator) getActivity().getSystemService(Context.VIBRATOR_SERVICE);

		/*
		 * OnTouchListener viblist=new OnTouchListener() {
		 * 
		 * public boolean onTouch(View v, MotionEvent event) { if
		 * (event.getActionMasked()==MotionEvent.ACTION_DOWN) vib.vibrate(50);
		 * return false; } };
		 * 
		 * findViewById(R.id.config).setOnTouchListener(viblist);
		 * findViewById(R.id.about).setOnTouchListener(viblist);
		 */

		String temp = mPrefs.getString(Config.pref_home, null);
		if (temp == null || !new File(temp).isDirectory()) {
			showToastMessage(getActivity().getString(R.string.config_home), Snackbar.LENGTH_LONG);
		}
		installButtons();
		if (!games) {
			new LocateGames(this, R.array.flash).execute(home_directory);
		} else {
			new LocateGames(this, R.array.images).execute(game_directory);
		}
	}

	private void installButtons() {
		try {
			File buttons = null;
			String theme = mPrefs.getString(Config.pref_button_theme, null);
			if (theme != null) {
				buttons = new File(theme);
			}
			File file = new File(home_directory, "data/buttons.png");
			InputStream in = null;
			if (buttons != null && buttons.exists()) {
				in = new FileInputStream(buttons);
			} else if (!file.exists() || file.length() == 0) {
				try {
					file.createNewFile();
				} catch (Exception e) {
					// N+ files be broken
				}
				in = getActivity().getAssets().open("buttons.png");
			}
			if (in != null) {
				OutputStream out = new FileOutputStream(file);

				// Transfer bytes from in to out
				byte[] buf = new byte[4096];
				int len;
				while ((len = in.read(buf)) != -1) {
					out.write(buf, 0, len);
				}
				in.close();
				out.flush();
				out.close();
			}
		} catch (FileNotFoundException fnf) {
			fnf.printStackTrace();
		} catch (IOException ioe) {
			ioe.printStackTrace();
		}
	}

	private static final class LocateGames extends AsyncTask<String, Integer, List<File>> {

		private WeakReference<FileBrowser> browser;
		private int array;
		
		LocateGames(FileBrowser context, int arrayType) {
			browser = new WeakReference<>(context);
			this.array = arrayType;
		}

		@Override
		protected List<File> doInBackground(String... paths) {
			File storage = new File(paths[0]);

			// array of valid image file extensions
			String[] mediaTypes = browser.get().getActivity().getResources().getStringArray(array);
			FilenameFilter[] filter = new FilenameFilter[mediaTypes.length];

			int i = 0;
			for (final String type : mediaTypes) {
				filter[i] = new FilenameFilter() {

					public boolean accept(File dir, String name) {
						return !dir.getName().equals("obb") && !dir.getName().equals("cache")
								&& !dir.getName().startsWith(".") && !name.startsWith(".")
								&& (array != R.array.flash || name.startsWith("dc_"))
								&& (browser.get().searchQuery == null
								|| name.toLowerCase(Locale.getDefault()).contains(
										browser.get().searchQuery.toLowerCase(Locale.getDefault())))
								&& StringUtils.endsWithIgnoreCase(name, "." + type);
					}
				};
				i++;
			}

			FileUtils fileUtils = new FileUtils();
			int recurse = 2;
			if (array == R.array.flash) {
				recurse = 4;
			}
			Collection<File> files = fileUtils.listFiles(storage, filter, recurse);
			return (List<File>) files;
		}

		@Override
		protected void onPostExecute(List<File> items) {
			LinearLayout list = (LinearLayout) browser.get().getActivity().findViewById(R.id.game_list);
			if (list.getChildCount() > 0) {
				list.removeAllViews();
			}

			String heading = browser.get().getActivity().getString(R.string.games_listing);
			browser.get().createListHeader(heading, list, array == R.array.images);
			if (items != null && !items.isEmpty()) {
				for (int i = 0; i < items.size(); i++) {
					browser.get().createListItem(list, items.get(i), i, array == R.array.images);
				}

			} else if (browser.get().searchQuery != null) {
				final View childview = browser.get().getActivity().getLayoutInflater().inflate(
						R.layout.browser_fragment_item, null, false);
				((TextView) childview.findViewById(R.id.item_name)).setText(R.string.no_games);
				((ImageView) childview.findViewById(R.id.item_icon))
						.setImageResource(R.mipmap.disk_missing);
				list.addView(childview);

			} else {
				browser.get().browseStorage(array == R.array.images);
			}
			list.invalidate();
		}
	}

	private void browseStorage(boolean images) {
		if (images) {
			(new navigate(this)).executeOnExecutor(
					AsyncTask.THREAD_POOL_EXECUTOR, new File(home_directory));
		} else {
			if (game_directory.equals(sdcard.getAbsolutePath())) {
				HashSet<String> extStorage = FileBrowser.getExternalMounts();
				if (extStorage != null && !extStorage.isEmpty()) {
					for (String sd : extStorage) {
						String sdCardPath = sd.replace("mnt/media_rw", "storage");
						if (!sdCardPath.equals(sdcard.getAbsolutePath())) {
							if (new File(sdCardPath).canRead()) {
								(new navigate(this)).execute(new File(sdCardPath));
								return;
							}
						}
					}
				}
			}
			(new navigate(this)).executeOnExecutor(
					AsyncTask.THREAD_POOL_EXECUTOR, new File(game_directory));
		}
	}

	private void createListHeader(String header_text, View view, boolean hasBios) {
		if (hasBios) {
			final View childview = getActivity().getLayoutInflater().inflate(
					R.layout.bios_list_item, null, false);

			((TextView) childview.findViewById(R.id.item_name)).setText(R.string.boot_bios);
			ImageView icon = (ImageView) childview.findViewById(R.id.item_icon);
			icon.setImageResource(R.mipmap.disk_bios);
			configureTheme(childview, true);

			childview.setTag(null);

			childview.findViewById(R.id.childview).setOnClickListener(
					new OnClickListener() {
						public void onClick(View view) {
							vib.vibrate(50);
							mCallback.onGameSelected(Uri.EMPTY);
							vib.vibrate(250);
						}
					});
			((ViewGroup) view).addView(childview);
		}
		if (searchQuery != null) {
			final View childview = getActivity().getLayoutInflater().inflate(
					R.layout.bios_list_item, null, false);

			((TextView) childview.findViewById(R.id.item_name)).setText(R.string.clear_search);
			ImageView icon = (ImageView) childview.findViewById(R.id.item_icon);
			icon.setImageResource(R.mipmap.disk_unknown);
			configureTheme(childview, true);

			childview.setTag(null);

			childview.findViewById(R.id.childview).setOnClickListener(
					new OnClickListener() {
						public void onClick(View view) {
							searchQuery = null;
							new LocateGames(FileBrowser.this,
									R.array.images).execute(game_directory);
						}
					});
			((ViewGroup) view).addView(childview);
		}

		final View headerView = getActivity().getLayoutInflater().inflate(
				R.layout.browser_fragment_header, null, false);
		((ImageView) headerView.findViewById(R.id.item_icon))
				.setImageResource(R.drawable.open_folder);
		((TextView) headerView.findViewById(R.id.item_name))
				.setText(header_text);
		((TextView) headerView.findViewById(R.id.item_name))
				.setTypeface(Typeface.DEFAULT_BOLD);
		((ViewGroup) view).addView(headerView);

	}

	private void createListItem(LinearLayout list, final File game, final int index, final boolean isGame) {				
		final View childview = getActivity().getLayoutInflater().inflate(
				R.layout.browser_fragment_item, null, false);
		
		XMLParser xmlParser = new XMLParser(game, index, mPrefs);
		xmlParser.setViewParent(getActivity(), childview, mCallback);

		childview.findViewById(R.id.childview).setOnClickListener(
				new OnClickListener() {
					public void onClick(View view) {
						if (isGame) {
							vib.vibrate(50);
							Uri gameUri = Uri.EMPTY;
							if (game != null) {
								if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
									gameUri = FileProvider.getUriForFile(getActivity(),
											"com.reicast.emulator.provider", game);
								} else {
									gameUri = Uri.fromFile(game);
								}
							}
							mCallback.onGameSelected(gameUri);
							vib.vibrate(250);
						} else {
							vib.vibrate(50);
							home_directory = game.getAbsolutePath().substring(0,
									game.getAbsolutePath().lastIndexOf(File.separator))
									.replace("/data", "");
							if (requireDataBIOS()) {
								showToastMessage(getActivity().getString(R.string.config_data,
										home_directory), Snackbar.LENGTH_LONG);
							}
							mPrefs.edit().putString(Config.pref_home, home_directory).apply();
							if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
								mCallback.onFolderSelected(FileProvider.getUriForFile(getActivity(),
										"com.reicast.emulator.provider", new File(home_directory)));
							} else {
								mCallback.onFolderSelected(
										Uri.fromFile(new File(home_directory)));
							}
							JNIdc.config(home_directory);
						}
					}
				});
		configureTheme(childview, false);
		list.addView(childview);
		xmlParser.executeOnExecutor(AsyncTask.THREAD_POOL_EXECUTOR, game.getName());
	}

	private static class navigate extends AsyncTask<File, Integer, List<File>> {

		private WeakReference<FileBrowser> browser;
		private String heading;
		private File parent;

		navigate(FileBrowser context) {
			browser = new WeakReference<>(context);
		}

		private final class DirSort implements Comparator<File> {
			@Override
			public int compare(File filea, File fileb) {
				return ((filea.isFile() ? "a" : "b") + filea.getName().toLowerCase(
						Locale.getDefault()))
						.compareTo((fileb.isFile() ? "a" : "b")
								+ fileb.getName().toLowerCase(Locale.getDefault()));
			}
		}

		@Override
		protected void onPreExecute() {
			LinearLayout listView = (LinearLayout)
					browser.get().getActivity().findViewById(R.id.game_list);
			if (listView.getChildCount() > 0)
				listView.removeAllViews();
		}

		@Override
		protected List<File> doInBackground(File... paths) {
			heading = paths[0].getAbsolutePath();

			ArrayList<File> list = new ArrayList<>();

			File flist[] = paths[0].listFiles();
			parent = paths[0].getParentFile();

			list.add(null);

			if (parent != null) {
				list.add(parent);
			}

			if (flist != null) {
				Arrays.sort(flist, new DirSort());
				Collections.addAll(list, flist);
			}
			return list;
		}

		@Override
		protected void onPostExecute(List<File> list) {
			if (list != null && !list.isEmpty()) {
				LinearLayout listView = (LinearLayout)
						browser.get().getActivity().findViewById(R.id.game_list);
				browser.get().createListHeader(heading, listView, false);
				for (final File file : list) {
					if (file != null && !file.isDirectory() && !file.getAbsolutePath().equals("/data"))
						continue;
					final View childview = browser.get().getActivity().getLayoutInflater().inflate(
							R.layout.browser_fragment_item, null, false);

					if (file == null) {
						((TextView) childview.findViewById(R.id.item_name)).setText(R.string.folder_select);
					} else if (file == parent)
						((TextView) childview.findViewById(R.id.item_name)).setText("..");
					else
						((TextView) childview.findViewById(R.id.item_name)).setText(file.getName());

					ImageView icon = (ImageView) childview.findViewById(R.id.item_icon);
					icon.setImageResource(file == null
							? R.drawable.ic_settings: file.isDirectory()
							? R.drawable.ic_folder_black_24dp : R.drawable.disk_unknown);
					browser.get().configureTheme(childview, true);

					childview.setTag(file);

					// vw.findViewById(R.id.childview).setBackgroundColor(0xFFFFFFFF);

					childview.findViewById(R.id.childview).setOnClickListener(
							new OnClickListener() {
								public void onClick(View view) {
									if (file != null && file.isDirectory()) {
										(new navigate(browser.get())).executeOnExecutor(
												AsyncTask.THREAD_POOL_EXECUTOR, file);
										ScrollView sv = (ScrollView) browser.get().getActivity()
												.findViewById(R.id.game_scroller);
										sv.scrollTo(0, 0);
										browser.get().vib.vibrate(50);
									} else if (view.getTag() == null) {
										browser.get().vib.vibrate(250);

										if (browser.get().games) {
											browser.get().game_directory = heading;
											browser.get().mPrefs.edit().putString(
													Config.pref_games, heading).apply();
											if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
												browser.get().mCallback.onFolderSelected(FileProvider
														.getUriForFile(browser.get().getActivity(),
																"com.reicast.emulator.provider",
																new File(browser.get().game_directory)));
											} else {
												browser.get().mCallback.onFolderSelected(Uri.fromFile(
														new File(browser.get().game_directory)));
											}


										} else {
											browser.get().home_directory = heading
													.replace("/data", "");
											browser.get().mPrefs.edit().putString(
													Config.pref_home, browser.get().home_directory).apply();
											if (browser.get().requireDataBIOS()) {
												browser.get().showToastMessage(browser.get().getActivity()
														.getString(R.string.config_data, browser.get()
																.home_directory), Snackbar.LENGTH_LONG);
											}
											if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
												browser.get().mCallback.onFolderSelected(FileProvider
														.getUriForFile(browser.get().getActivity(),
																"com.reicast.emulator.provider",
																new File(browser.get().home_directory)));
											} else {
												browser.get().mCallback.onFolderSelected(Uri.fromFile(
														new File(browser.get().home_directory)));
											}
											JNIdc.config(browser.get().home_directory);
										}

									}
								}
							});
					listView.addView(childview);
				}
				listView.invalidate();
			}
		}
	}

    private boolean requireDataBIOS() {
        File data_directory = new File(home_directory, "data");
        if (data_directory.exists() && data_directory.isDirectory()) {
            File bios = new File(home_directory, "data/dc_boot.bin");
            File flash = new File(home_directory, "data/dc_flash.bin");
            return !(bios.exists() && flash.exists());
        } else {
            if (data_directory.mkdirs()) {
                File bios = new File(home_directory, "dc_boot.bin");
                if (bios.renameTo(new File(home_directory, "data/dc_boot.bin"))) {
                    return !new File(home_directory, "dc_flash.bin").renameTo(
                            new File(home_directory, "data/dc_flash.bin"));
                }
            }
            return true;
        }
    }

	private void configureTheme(View childview, boolean useTint) {
		int app_theme = mPrefs.getInt(Config.pref_app_theme, 0);
		ImageView icon = (ImageView) childview.findViewById(R.id.item_icon);
		if (app_theme == 7) {
			childview.findViewById(R.id.childview)
					.setBackgroundResource(R.drawable.game_selector_dream);
			if (useTint)
				ImageViewCompat.setImageTintList(icon, ColorStateList.valueOf(
						ContextCompat.getColor(getActivity(), R.color.colorDreamTint)));
		} else if (app_theme == 1) {
			childview.findViewById(R.id.childview)
					.setBackgroundResource(R.drawable.game_selector_blue);
			if (useTint)
				ImageViewCompat.setImageTintList(icon, ColorStateList.valueOf(
						ContextCompat.getColor(getActivity(), R.color.colorBlueTint)));
		} else {
			childview.findViewById(R.id.childview)
					.setBackgroundResource(R.drawable.game_selector_dark);
			if (useTint)
				ImageViewCompat.setImageTintList(icon, ColorStateList.valueOf(
						ContextCompat.getColor(getActivity(), R.color.colorDarkTint)));
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
					R.drawable.ic_subdirectory_arrow_right, getActivity().getTheme());
		} else {
			drawable = VectorDrawableCompat.create(getResources(),
					R.drawable.ic_subdirectory_arrow_right, getActivity().getTheme());
		}
		textView.setCompoundDrawablesWithIntrinsicBounds(drawable, null, null, null);
		textView.setCompoundDrawablePadding(getResources()
				.getDimensionPixelOffset(R.dimen.snackbar_icon_padding));
		snackbar.show();
	}
}
