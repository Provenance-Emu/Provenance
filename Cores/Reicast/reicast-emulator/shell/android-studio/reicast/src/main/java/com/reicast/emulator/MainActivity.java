package com.reicast.emulator;

import android.Manifest;
import android.app.AlertDialog;
import android.app.UiModeManager;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.content.res.Configuration;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.preference.PreferenceManager;
import android.support.annotation.NonNull;
import android.support.constraint.ConstraintLayout;
import android.support.design.widget.NavigationView;
import android.support.design.widget.Snackbar;
import android.support.v4.app.ActivityCompat;
import android.support.v4.app.Fragment;
import android.support.v4.view.GravityCompat;
import android.support.v4.widget.DrawerLayout;
import android.support.v7.app.AppCompatActivity;
import android.support.v7.widget.SearchView;
import android.support.v7.widget.Toolbar;
import android.util.Log;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.MenuItem;
import android.view.View;
import android.view.View.OnSystemUiVisibilityChangeListener;
import android.view.WindowManager;
import android.widget.TextView;

import com.reicast.emulator.config.Config;
import com.reicast.emulator.config.EditVJoyActivity;
import com.reicast.emulator.config.InputFragment;
import com.reicast.emulator.config.OptionsFragment;
import com.reicast.emulator.config.PGConfigFragment;
import com.reicast.emulator.debug.GenerateLogs;
import com.reicast.emulator.cloud.CloudFragment;
import com.reicast.emulator.emu.JNIdc;

import java.lang.Thread.UncaughtExceptionHandler;
import java.util.List;

public class MainActivity extends AppCompatActivity implements
		NavigationView.OnNavigationItemSelectedListener, FileBrowser.OnItemSelectedListener,
		OptionsFragment.OnClickListener, InputFragment.OnClickListener  {
	private static final int PERMISSION_REQUEST = 1001;

	private SharedPreferences mPrefs;
	private boolean hasAndroidMarket = false;

	@Override
	public void onCreate(Bundle savedInstanceState) {
        mPrefs = PreferenceManager.getDefaultSharedPreferences(this);
        int app_theme = mPrefs.getInt(Config.pref_app_theme, 0);
        if (app_theme == 7) {
			setTheme(R.style.AppTheme_Dream);
		} else if (app_theme == 1) {
        	setTheme(R.style.AppTheme_Blue);
        } else {
            setTheme(R.style.AppTheme);
        }
		super.onCreate(savedInstanceState);
		setContentView(R.layout.activity_main);

		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
			getWindow().getDecorView().setOnSystemUiVisibilityChangeListener (new OnSystemUiVisibilityChangeListener() {
				public void onSystemUiVisibilityChange(int visibility) {
					if ((visibility & View.SYSTEM_UI_FLAG_FULLSCREEN) == 0) {
						getWindow().getDecorView().setSystemUiVisibility(
								View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
										| View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
										| View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
										| View.SYSTEM_UI_FLAG_FULLSCREEN
										| View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY);
					}
				}
			});
		} else {
			getWindow().setFlags (WindowManager.LayoutParams.FLAG_FULLSCREEN,
					WindowManager.LayoutParams.FLAG_FULLSCREEN);
		}

		String prior_error = mPrefs.getString("prior_error", null);
		if (prior_error != null) {
			displayLogOutput(prior_error);
			mPrefs.edit().remove("prior_error").apply();
		} else {
			UncaughtExceptionHandler mUEHandler = new Thread.UncaughtExceptionHandler() {
				public void uncaughtException(Thread t, Throwable error) {
					if (error != null) {
						StringBuilder output = new StringBuilder();
						for (StackTraceElement trace : error.getStackTrace()) {
							output.append(trace.toString());
							output.append("\n");
						}
						mPrefs.edit().putString("prior_error", output.toString()).apply();
						error.printStackTrace();
						android.os.Process.killProcess(android.os.Process.myPid());
						System.exit(0);
					}
				}
			};
			Thread.setDefaultUncaughtExceptionHandler(mUEHandler);
		}

		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
			ActivityCompat.requestPermissions(MainActivity.this,
					new String[] {
							Manifest.permission.READ_EXTERNAL_STORAGE,
							Manifest.permission.WRITE_EXTERNAL_STORAGE
					},
					PERMISSION_REQUEST);
		}

		Intent market = new Intent(Intent.ACTION_VIEW, Uri.parse("market://search?q=dummy"));
		if (isCallable(market)) {
			hasAndroidMarket = true;
		}

		if (!getFilesDir().exists()) {
			getFilesDir().mkdir();
		}

		// When viewing a resource, pass its URI to the native code for opening
		Intent intent = getIntent();
		if (intent.getAction() != null) {
			if (intent.getAction().equals(Intent.ACTION_VIEW)) {
				onGameSelected(Uri.parse(intent.getData().toString()));
				// Flush the intent to prevent multiple calls
				getIntent().setData(null);
				setIntent(null);
				Config.externalIntent = true;
			}
		}

		// Check that the activity is using the layout version with
		// the fragment_container FrameLayout
		if (findViewById(R.id.fragment_container) != null) {
			onMainBrowseSelected(null, true, null);
		}

		Toolbar toolbar = (Toolbar) findViewById(R.id.toolbar);
		setSupportActionBar(toolbar);

		DrawerLayout drawer = (DrawerLayout) findViewById(R.id.drawer_layout);
		android.support.v7.app.ActionBarDrawerToggle toggle = new android.support.v7.app.ActionBarDrawerToggle(
				this, drawer, toolbar, R.string.drawer_open, R.string.drawer_shut) {
			@Override
			public void onDrawerOpened(View drawerView) {

			}
			@Override
			public void onDrawerClosed(View drawerView) {

			}
		};
		//noinspection deprecation
		drawer.setDrawerListener(toggle);
		toggle.syncState();

		NavigationView navigationView = (NavigationView) findViewById(R.id.nav_view);
		if (!hasAndroidMarket) {
			navigationView.getMenu().findItem(R.id.rateme_menu).setEnabled(false);
			navigationView.getMenu().findItem(R.id.rateme_menu).setVisible(false);
		}
		try {
			UiModeManager uiModeManager = (UiModeManager) getSystemService(UI_MODE_SERVICE);
			if (uiModeManager.getCurrentModeType() == Configuration.UI_MODE_TYPE_TELEVISION) {
				View header = navigationView.getHeaderView(0);
				((TextView) header.findViewById(R.id.project_link)).setVisibility(View.GONE);
			}
		} catch (Exception e) {
			// They require a check, so they can fix their API
		}
		navigationView.setNavigationItemSelectedListener(this);

		final SearchView searchView = (SearchView) findViewById(R.id.searchView);
		if (searchView != null) {
			searchView.setQueryHint(getString(R.string.search_hint));
			searchView.setOnQueryTextListener(new SearchView.OnQueryTextListener() {
				@Override
				public boolean onQueryTextSubmit(String query) {
					onMainBrowseSelected(mPrefs.getString(Config.pref_games,
							Environment.getExternalStorageDirectory().getAbsolutePath()),
							true, query);
					searchView.onActionViewCollapsed();
					return false;
				}
				@Override
				public boolean onQueryTextChange(String query) {
					return false;
				}
			});
		}

		try {
			String versionName = getPackageManager()
					.getPackageInfo(getPackageName(), 0).versionName;
			int versionCode = getPackageManager()
					.getPackageInfo(getPackageName(), 0).versionCode;
			((TextView) navigationView.findViewById(R.id.version)).setText(
					getString(R.string.revision_text, versionName, String.valueOf(versionCode)));
		} catch (PackageManager.NameNotFoundException e) {
			e.printStackTrace();
		}
	}

	public void generateErrorLog() {
		new GenerateLogs(MainActivity.this).execute(getFilesDir().getAbsolutePath());
	}

	/**
	 * Display a dialog to notify the user of prior crash
	 *
	 * @param error
	 *            A generalized summary of the crash cause
	 */
	private void displayLogOutput(final String error) {
		AlertDialog.Builder builder = new AlertDialog.Builder(MainActivity.this);
		builder.setTitle(R.string.report_issue);
		builder.setMessage(error);
		builder.setPositiveButton(R.string.report,
				new DialogInterface.OnClickListener() {
					public void onClick(DialogInterface dialog, int which) {
						generateErrorLog();
					}
				});
		builder.setNegativeButton(R.string.dismiss,
				new DialogInterface.OnClickListener() {
					public void onClick(DialogInterface dialog, int which) {
						dialog.dismiss();
					}
				});
		builder.create();
		builder.show();
	}

	public void onEditorSelected(Uri uri) {
		String home_directory = mPrefs.getString(Config.pref_home,
				Environment.getExternalStorageDirectory().getAbsolutePath());

		JNIdc.config(home_directory);

		startActivity(new Intent("com.reicast.EMULATOR", uri,
				getApplicationContext(), EditVJoyActivity.class));
	}

	public void onGameSelected(Uri uri) {
		String home_directory = mPrefs.getString(Config.pref_home,
				Environment.getExternalStorageDirectory().getAbsolutePath());

		JNIdc.config(home_directory);

		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
			uri = Uri.parse(uri.toString().replace("content://"
					+ uri.getAuthority() + "/external_files", "/storage"));
		}

		Intent intent = new Intent("com.reicast.EMULATOR",
				uri, getApplicationContext(), GL2JNIActivity.class);
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N)
			intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION
					| Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
		startActivity(intent);
	}

	public void onFolderSelected(Uri uri) {
		FileBrowser browserFrag = (FileBrowser) getSupportFragmentManager()
				.findFragmentByTag("MAIN_BROWSER");
		if (browserFrag != null) {
			if (browserFrag.isVisible()) {
				Log.d("reicast", "Main folder: " + uri.toString());
				// return;
			}
		}

		OptionsFragment optsFrag = new OptionsFragment();
		getSupportFragmentManager().beginTransaction().replace(
				R.id.fragment_container, optsFrag, "OPTIONS_FRAG").commit();
		setTitle(R.string.settings);
	}

	/**
	 * Launch the browser activity with specified parameters
	 *
	 * @param path
	 *            The root path of the browser fragment
	 * @param games
	 *            Conditional for viewing games or BIOS
	 * @param query
	 *            Search parameters to limit list items
	 */
	public void onMainBrowseSelected(String path, boolean games, String query) {
		FileBrowser firstFragment = new FileBrowser();
		Bundle args = new Bundle();
		args.putString("browse_entry", path);
		// specify a path for selecting folder options
		args.putBoolean("games_entry", games);
		// specify if the desired path is for games or data
		args.putString("search_params", query);

		firstFragment.setArguments(args);
		// In case this activity was started with special instructions from
		// an Intent, pass the Intent's extras to the fragment as arguments
		// firstFragment.setArguments(getIntent().getExtras());

		// Add the fragment to the 'fragment_container' FrameLayout
		getSupportFragmentManager()
				.beginTransaction()
				.replace(R.id.fragment_container, firstFragment, "MAIN_BROWSER")
				.addToBackStack(null).commit();
		setTitle(R.string.browser);
	}

	public void launchBIOSdetection() {
		AlertDialog.Builder builder = new AlertDialog.Builder(this);
		builder.setTitle(R.string.bios_selection);
		builder.setPositiveButton(R.string.browse,
				new DialogInterface.OnClickListener() {
					public void onClick(DialogInterface dialog, int which) {
						String home_directory = mPrefs.getString(Config.pref_home,
								Environment.getExternalStorageDirectory().getAbsolutePath());
						onMainBrowseSelected(home_directory, false, null);
					}
				});
		builder.setNegativeButton(R.string.gdrive,
				new DialogInterface.OnClickListener() {
					public void onClick(DialogInterface dialog, int which) {
						showToastMessage(getString(R.string.require_bios),
								Snackbar.LENGTH_SHORT);
					}
				});
		builder.create();
		builder.show();
	}

	@Override
	public void onConfigurationChanged(Configuration newConfig) {
		super.onConfigurationChanged(newConfig);
	}

	@Override
	public boolean onKeyDown(int keyCode, KeyEvent event) {
		if (keyCode == KeyEvent.KEYCODE_BACK) {
			Fragment fragment = getSupportFragmentManager().findFragmentByTag("MAIN_BROWSER");
			if (fragment != null && fragment.isVisible()) {
				boolean readyToQuit = true;
				if (fragment.getArguments() != null) {
					readyToQuit = fragment.getArguments().getBoolean(
							"games_entry", true);
				}
				if (readyToQuit) {
					MainActivity.this.finish();
				} else {
					launchMainFragment();
				}
				return true;
			} else {
				launchMainFragment();
				return true;
			}

		}

		return super.onKeyDown(keyCode, event);
	}

	private void launchMainFragment() {
		onMainBrowseSelected(null, true, null);
	}

	@Override
	protected void onPause() {
		super.onPause();
	}

	@Override
	protected void onDestroy() {
		super.onDestroy();
	}

	@Override
	protected void onResume() {
		super.onResume();
		CloudFragment cloudfragment = (CloudFragment) getSupportFragmentManager()
				.findFragmentByTag("CLOUD_FRAG");
		if (cloudfragment != null && cloudfragment.isVisible()) {
			cloudfragment.onResume();
		}
	}

	@Override
	public void onPostCreate(Bundle savedInstanceState) {
		super.onPostCreate(savedInstanceState);
	}

	public void recreateActivity() {
		this.recreate();
		OptionsFragment optionsFrag = new OptionsFragment();
		getSupportFragmentManager()
				.beginTransaction()
				.replace(R.id.fragment_container, optionsFrag, "OPTIONS_FRAG")
				.addToBackStack(null).commit();
		// Prevents a crash, but actually just reloads the FileBrowser fragment
	}

	@Override
	public boolean onNavigationItemSelected(@NonNull MenuItem item) {
		// Handle navigation view item clicks here.
		DrawerLayout drawer = (DrawerLayout) findViewById(R.id.drawer_layout);

		switch (item.getItemId()) {

			case R.id.browser_menu:
				FileBrowser browseFrag = (FileBrowser) getSupportFragmentManager()
						.findFragmentByTag("MAIN_BROWSER");
				if (browseFrag != null) {
					if (browseFrag.isVisible()) {
						drawer.closeDrawer(GravityCompat.START);
						return true;
					}
				}
				browseFrag = new FileBrowser();
				Bundle args = new Bundle();
				args.putString("browse_entry", null);
				// specify a path for selecting folder options
				args.putBoolean("games_entry", true);
				// specify if the desired path is for games or data
				browseFrag.setArguments(args);
				getSupportFragmentManager()
						.beginTransaction()
						.replace(R.id.fragment_container, browseFrag, "MAIN_BROWSER")
						.addToBackStack(null).commit();
				setTitle(R.string.browser);
				drawer.closeDrawer(GravityCompat.START);
				return true;

			case R.id.settings_menu:
				OptionsFragment optionsFrag = (OptionsFragment) getSupportFragmentManager()
						.findFragmentByTag("OPTIONS_FRAG");
				if (optionsFrag != null) {
					if (optionsFrag.isVisible()) {
						drawer.closeDrawer(GravityCompat.START);
						return true;
					}
				}
				optionsFrag = new OptionsFragment();
				getSupportFragmentManager()
						.beginTransaction()
						.replace(R.id.fragment_container, optionsFrag, "OPTIONS_FRAG")
						.addToBackStack(null).commit();
				setTitle(R.string.settings);
				drawer.closeDrawer(GravityCompat.START);
				return true;

			case R.id.pgconfig_menu:
				PGConfigFragment pgconfigFrag = (PGConfigFragment) getSupportFragmentManager()
						.findFragmentByTag("PGCONFIG_FRAG");
				if (pgconfigFrag != null) {
					if (pgconfigFrag.isVisible()) {
						drawer.closeDrawer(GravityCompat.START);
						return true;
					}
				}
				pgconfigFrag = new PGConfigFragment();
				getSupportFragmentManager()
						.beginTransaction()
						.replace(R.id.fragment_container, pgconfigFrag, "PGCONFIG_FRAG")
						.addToBackStack(null).commit();
				setTitle(R.string.pgconfig);
				drawer.closeDrawer(GravityCompat.START);
				return true;

			case R.id.input_menu:
				InputFragment inputFrag = (InputFragment) getSupportFragmentManager()
						.findFragmentByTag("INPUT_FRAG");
				if (inputFrag != null) {
					if (inputFrag.isVisible()) {
						drawer.closeDrawer(GravityCompat.START);
						return true;
					}
				}
				inputFrag = new InputFragment();
				getSupportFragmentManager()
						.beginTransaction()
						.replace(R.id.fragment_container, inputFrag, "INPUT_FRAG")
						.addToBackStack(null).commit();
				setTitle(R.string.input);
				drawer.closeDrawer(GravityCompat.START);
				return true;

			case R.id.about_menu:
				AboutFragment aboutFrag = (AboutFragment) getSupportFragmentManager()
						.findFragmentByTag("ABOUT_FRAG");
				if (aboutFrag != null) {
					if (aboutFrag.isVisible()) {
						drawer.closeDrawer(GravityCompat.START);
						return true;
					}
				}
				aboutFrag = new AboutFragment();
				getSupportFragmentManager()
						.beginTransaction()
						.replace(R.id.fragment_container, aboutFrag, "ABOUT_FRAG")
						.addToBackStack(null).commit();
				setTitle(R.string.about);
				drawer.closeDrawer(GravityCompat.START);
				return true;

			case R.id.cloud_menu:
				CloudFragment cloudFrag = (CloudFragment) getSupportFragmentManager()
						.findFragmentByTag("CLOUD_FRAG");
				if (cloudFrag != null) {
					if (cloudFrag.isVisible()) {
						drawer.closeDrawer(GravityCompat.START);
						return true;
					}
				}
				cloudFrag = new CloudFragment();
				getSupportFragmentManager()
						.beginTransaction()
						.replace(R.id.fragment_container, cloudFrag, "CLOUD_FRAG")
						.addToBackStack(null).commit();
				setTitle(R.string.cloud);
				drawer.closeDrawer(GravityCompat.START);
				return true;

			case R.id.rateme_menu:
				// vib.vibrate(50);
				startActivity(new Intent(Intent.ACTION_VIEW,
						Uri.parse("market://details?id=" + getPackageName())));
				//setTitle(R.string.rateme);
				drawer.closeDrawer(GravityCompat.START);
				return true;

			case R.id.message_menu:
				generateErrorLog();
				drawer.closeDrawer(GravityCompat.START);
				return true;

			default:
				drawer.closeDrawer(GravityCompat.START);
				return true;

		}
	}

	@Override
	public void onWindowFocusChanged(boolean hasFocus) {
		super.onWindowFocusChanged(hasFocus);
		if (hasFocus && Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
			getWindow().getDecorView().setSystemUiVisibility(
					View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
							| View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
							| View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
							| View.SYSTEM_UI_FLAG_FULLSCREEN
							| View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY);
		}
	}

	@Override
	public void onRequestPermissionsResult(
			int requestCode, @NonNull String permissions[], @NonNull int[] grantResults) {
		if (requestCode == PERMISSION_REQUEST) {
			if (!(grantResults.length > 0 && grantResults[0]
					== PackageManager.PERMISSION_GRANTED)) {
				StringBuilder disabled = new StringBuilder();
				for (String permission : permissions) {
					disabled.append("\n");
					disabled.append(permission);
				}
				showToastMessage(getString(R.string.permission_blocked,
						disabled.toString()), Snackbar.LENGTH_LONG);
			}
		}
	}

	public boolean isCallable(Intent intent) {
		List<ResolveInfo> list = getPackageManager().queryIntentActivities(
				intent, PackageManager.MATCH_DEFAULT_ONLY);
		return list.size() > 0;
	}

	private void showToastMessage(String message, int duration) {
		ConstraintLayout layout = (ConstraintLayout) findViewById(R.id.mainui_layout);
		Snackbar snackbar = Snackbar.make(layout, message, duration);
		View snackbarLayout = snackbar.getView();
		TextView textView = (TextView) snackbarLayout.findViewById(
				android.support.design.R.id.snackbar_text);
		textView.setGravity(Gravity.CENTER_VERTICAL);
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR1)
			textView.setTextAlignment(View.TEXT_ALIGNMENT_GRAVITY);
		textView.setCompoundDrawablesWithIntrinsicBounds(R.drawable.ic_notification, 0, 0, 0);
		textView.setCompoundDrawablePadding(getResources()
				.getDimensionPixelOffset(R.dimen.snackbar_icon_padding));
		snackbar.show();
	}
}
