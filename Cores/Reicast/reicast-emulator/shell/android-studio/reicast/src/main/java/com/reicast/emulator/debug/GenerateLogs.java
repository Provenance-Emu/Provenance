package com.reicast.emulator.debug;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.graphics.drawable.Drawable;
import android.net.Uri;
import android.os.AsyncTask;
import android.os.Build;
import android.support.constraint.ConstraintLayout;
import android.support.design.widget.Snackbar;
import android.support.graphics.drawable.VectorDrawableCompat;
import android.view.Gravity;
import android.view.View;
import android.widget.TextView;

import com.reicast.emulator.R;
import com.reicast.emulator.config.Config;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileWriter;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.lang.ref.WeakReference;

public class GenerateLogs extends AsyncTask<String, Integer, String> {
	private WeakReference<Context> mContext;

	private static final String build_device = android.os.Build.DEVICE;
	private static final String build_board = android.os.Build.BOARD;
	private static final int build_sdk = android.os.Build.VERSION.SDK_INT;

	private static final String DN = "Donut";
	private static final String EC = "Eclair";
	private static final String FR = "Froyo";
	private static final String GB = "Gingerbread";
	private static final String HC = "Honeycomb";
	private static final String IC = "Ice Cream Sandwich";
	private static final String JB = "JellyBean";
	private static final String KK = "KitKat";
	private static final String LL = "Lollipop";
	private static final String MM = "Marshmallow";
	private static final String NT = "Nougat";
	private static final String NL = "New / No Label";
	private static final String NF = "Not Found";

	private String currentTime;
	private String unHandledIOE;

	public GenerateLogs(Context reference) {
		this.mContext = new WeakReference<>(reference);
		this.currentTime = String.valueOf(System.currentTimeMillis());
	}

	/**
	 * Obtain the specific parameters of the current device
	 *
	 */
	private String discoverCPUData() {
		String s = "MODEL: " + Build.MODEL;
		s += "\r\n";
		s += "DEVICE: " + build_device;
		s += "\r\n";
		s += "BOARD: " + build_board;
		s += "\r\n";
		if (!String.valueOf(build_sdk).equals("")) {
			String build_version = NF;
			if (String.valueOf(build_sdk).equals("L")) {
				build_version = "LP";
			} else if (build_sdk >= 4 && build_sdk < 7) {
				build_version = DN;
			} else if (build_sdk == 7) {
				build_version = EC;
			} else if (build_sdk == 8) {
				build_version = FR;
			} else if (build_sdk >= 9 && build_sdk < 11) {
				build_version = GB;
			} else if (build_sdk >= 11 && build_sdk < 14) {
				build_version = HC;
			} else if (build_sdk >= 14 && build_sdk < 16) {
				build_version = IC;
			} else if (build_sdk >= 16 && build_sdk < 19) {
				build_version = JB;
			} else if (build_sdk >= 19 && build_sdk < 21) {
				build_version = KK;
			} else if (build_sdk >= 21 && build_sdk < 23) {
				build_version = LL;
			} else if (build_sdk >= 23 && build_sdk < 24) {
				build_version = MM;
			} else if (build_sdk >= 24 && build_sdk < 26) {
				build_version = NT;
			} else if (build_sdk >= 26) {
				build_version = NL;
			}
			s += build_version + " (" + build_sdk + ")";
		} else {
			String prop_build_version = "ro.build.version.release";
			String prop_sdk_version = "ro.build.version.sdk";
			String build_version = readOutput("/system/bin/getprop "
					+ prop_build_version);
			String sdk_version = readOutput("/system/bin/getprop "
					+ prop_sdk_version);
			s += build_version + " (" + sdk_version + ")";
		}
		return s;
	}

	/**
	 * Read the output of a shell command
	 *
	 * @param command
	 *            The shell command being issued to the terminal
	 */
	public static String readOutput(String command) {
		try {
			Process p = Runtime.getRuntime().exec(command);
			InputStream is = null;
			if (p.waitFor() == 0) {
				is = p.getInputStream();
			} else {
				is = p.getErrorStream();
			}
			BufferedReader br = new BufferedReader(new InputStreamReader(is),
					2048);
			String line = br.readLine();
			br.close();
			return line;
		} catch (Exception ex) {
			return "ERROR: " + ex.getMessage();
		}
	}

	public void setUnhandled(String unHandledIOE) {
		this.unHandledIOE = unHandledIOE;
	}

	@Override
	protected String doInBackground(String... params) {
		File logFile = new File(params[0], currentTime + ".txt");
		Process mLogcatProc = null;
		BufferedReader reader = null;
		final StringBuilder log = new StringBuilder();
		String separator = System.getProperty("line.separator");
		log.append(discoverCPUData());
		if (unHandledIOE != null) {
			log.append(separator);
			log.append(separator);
			log.append("Unhandled Exceptions");
			log.append(separator);
			log.append(separator);
			log.append(unHandledIOE);
		}
		try {
			String line;
			mLogcatProc = Runtime.getRuntime().exec(
					new String[] { "logcat", "-ds", "reicast:V" });
			reader = new BufferedReader(new InputStreamReader(
					mLogcatProc.getInputStream()));
			log.append(separator);
			log.append(separator);
			log.append("Native Interface Output");
			log.append(separator);
			log.append(separator);
			while ((line = reader.readLine()) != null) {
				log.append(line);
				log.append(separator);
			}
			reader.close();
			File memory = new File(mContext.get().getFilesDir(), "mem_alloc.txt");
			if (memory.exists()) {
				log.append(separator);
				log.append(separator);
				log.append("Memory Allocation Table");
				log.append(separator);
				log.append(separator);
				FileInputStream fis = new FileInputStream(memory);
				reader = new BufferedReader(new InputStreamReader(fis));
				while ((line = reader.readLine()) != null) {
					log.append(line);
					log.append(separator);
				}
				fis.close();
				reader.close();
			}
			BufferedWriter writer = new BufferedWriter(new FileWriter(logFile));
			writer.write(log.toString());
			writer.flush();
			writer.close();
			return log.toString();
		} catch (IOException e) {
			// Could not generate log file
			// Writing a log is redundant
		}
		return null;
	}

	@Override
	protected void onPostExecute(final String response) {
		if (response != null) {
			showToastMessage(mContext.get().getString(R.string.log_saved), Snackbar.LENGTH_LONG);
			android.content.ClipboardManager clipboard = (android.content.ClipboardManager) mContext.get()
					.getSystemService(Context.CLIPBOARD_SERVICE);
			android.content.ClipData clip = android.content.ClipData.newPlainText("logcat", response);
			clipboard.setPrimaryClip(clip);
			Intent browserIntent = new Intent(Intent.ACTION_VIEW, Uri.parse(Config.git_issues));
			mContext.get().startActivity(browserIntent);
		}
	}

	private void showToastMessage(String message, int duration) {
		ConstraintLayout layout = (ConstraintLayout)
				((Activity) mContext.get()).findViewById(R.id.mainui_layout);
		Snackbar snackbar = Snackbar.make(layout, message, duration);
		View snackbarLayout = snackbar.getView();
		ConstraintLayout.LayoutParams lp = new ConstraintLayout.LayoutParams(
				ConstraintLayout.LayoutParams.MATCH_PARENT,
				ConstraintLayout.LayoutParams.WRAP_CONTENT
		);
		lp.setMargins(0, 0, 0, 0);
		snackbarLayout.setLayoutParams(lp);
		TextView textView = (TextView) snackbarLayout.findViewById(
				android.support.design.R.id.snackbar_text);
		textView.setGravity(Gravity.CENTER_VERTICAL);
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR1)
			textView.setTextAlignment(View.TEXT_ALIGNMENT_GRAVITY);
		Drawable drawable;
		if (android.os.Build.VERSION.SDK_INT > Build.VERSION_CODES.M) {
			drawable = mContext.get().getResources().getDrawable(
					R.drawable.ic_send, ((Activity) mContext.get()).getTheme());
		} else {
			drawable = VectorDrawableCompat.create(mContext.get().getResources(),
					R.drawable.ic_send, ((Activity) mContext.get()).getTheme());
		}
		textView.setCompoundDrawablesWithIntrinsicBounds(drawable, null, null, null);
		textView.setCompoundDrawablePadding(mContext.get().getResources()
				.getDimensionPixelOffset(R.dimen.snackbar_icon_padding));
		snackbar.show();
	}
}
