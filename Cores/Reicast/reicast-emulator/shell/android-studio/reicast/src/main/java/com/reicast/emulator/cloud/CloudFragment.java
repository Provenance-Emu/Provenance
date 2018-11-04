package com.reicast.emulator.cloud;

/*
 *  Author: Luca D'Amico (Luca91)
 *  Rewrite: AbandonedCart
 *  Last Edit: 02 Oct 2018
 *  Reference: http://forums.reicast.com/index.php?topic=160.msg422
 */

import android.app.AlertDialog;
import android.app.ProgressDialog;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.SharedPreferences;
import android.net.Uri;
import android.os.AsyncTask;
import android.os.Bundle;
import android.os.Environment;
import android.preference.PreferenceManager;
import android.support.v4.app.Fragment;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.Toast;

import com.dropbox.core.DbxException;
import com.dropbox.core.android.Auth;
import com.dropbox.core.v2.DbxClientV2;
import com.dropbox.core.v2.files.FileMetadata;
import com.dropbox.core.v2.files.ListFolderResult;
import com.dropbox.core.v2.files.Metadata;
import com.dropbox.core.v2.files.WriteMode;
import com.reicast.emulator.R;
import com.reicast.emulator.config.Config;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.lang.ref.WeakReference;


public class CloudFragment extends Fragment {

    private final static String APP_KEY = "lowa9ps6h5k7zbo";
	private String mPath = ""; // Dropbox folder

	Button uploadBtn;
	Button downloadBtn;
	AlertDialog.Builder confirmDialog = null;
	private String home_directory;

	String[] vmus = {"vmu_save_A1.bin", "vmu_save_A2.bin",
			"vmu_save_B1.bin", "vmu_save_B2.bin",
			"vmu_save_C1.bin", "vmu_save_C2.bin",
			"vmu_save_D1.bin", "vmu_save_D2.bin"};

	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
		return inflater.inflate(R.layout.cloud_fragment, container, false);
	}

	@Override
	public void onViewCreated(View view, Bundle savedInstanceState) {
		SharedPreferences mPrefs = PreferenceManager.getDefaultSharedPreferences(getActivity());
		home_directory = mPrefs.getString(Config.pref_home,
				Environment.getExternalStorageDirectory().getAbsolutePath());
		buttonListener();
		confirmDialog = new AlertDialog.Builder(getActivity());
	}

	@Override
	public void onResume() {
		super.onResume();
		SharedPreferences mPrefs = PreferenceManager.getDefaultSharedPreferences(getActivity());
		String accessToken = mPrefs.getString("access-token", null);
		if (accessToken == null) {
			accessToken = Auth.getOAuth2Token();
			if (accessToken != null) {
				mPrefs.edit().putString("access-token", accessToken).apply();
				DbxClientFactory.init(accessToken);
			}
		} else {
			DbxClientFactory.init(accessToken);
		}
	}

	public void buttonListener() {
		Auth.startOAuth2Authentication(getActivity(), APP_KEY);
		uploadBtn = (Button) getView().findViewById(R.id.uploadBtn);
		uploadBtn.setOnClickListener(new View.OnClickListener() {
			@Override
			public void onClick(View arg0) {
				confirmDialog.setMessage(R.string.uploadWarning);
				confirmDialog.setPositiveButton(android.R.string.ok, new DialogInterface.OnClickListener() {
					public void onClick(DialogInterface dialog, int which) {
						getPathForFiles("Upload");
					}
				});
				confirmDialog.setNegativeButton(R.string.cancel, null);
				confirmDialog.show();

			}
		});


		downloadBtn = (Button) getView().findViewById(R.id.downloadBtn);
		downloadBtn.setOnClickListener(new View.OnClickListener() {
			@Override
			public void onClick(View arg0) {
				confirmDialog.setMessage(R.string.downloadWarning);
				confirmDialog.setPositiveButton(android.R.string.ok, new DialogInterface.OnClickListener() {
					public void onClick(DialogInterface dialog, int which) {
						getPathForFiles("Download");
					}
				});
				confirmDialog.setNegativeButton(R.string.cancel, null);
				confirmDialog.show();
			}
		});
	}

	private void uploadFile(String filePath) {
		final ProgressDialog dialog = new ProgressDialog(getActivity());
		dialog.setProgressStyle(ProgressDialog.STYLE_SPINNER);
		dialog.setCancelable(false);
		dialog.setMessage("Uploading");
		dialog.show();

		try {
			new UploadFileTask(getActivity(), DbxClientFactory.getClient(), new UploadFileTask.Callback() {
				@Override
				public void onUploadComplete(FileMetadata result) {
					dialog.dismiss();
				}

				@Override
				public void onError(Exception e) {
					dialog.dismiss();

					Log.e(getActivity().getLocalClassName(), "Failed to upload file.", e);
					Toast.makeText(getActivity(),
							"Failed to upload file", Toast.LENGTH_SHORT).show();
				}
			}).execute(filePath, mPath);
		} catch (IllegalStateException s) {
			dialog.dismiss();
			Log.e(getActivity().getLocalClassName(), "Failed to upload file.", s);
			Toast.makeText(getActivity(),
					"Failed to upload file", Toast.LENGTH_SHORT).show();
		}
	}

	private void retrieveFiles(final String vmu) {
		final ProgressDialog dialog = new ProgressDialog(getActivity());
		dialog.setProgressStyle(ProgressDialog.STYLE_SPINNER);
		dialog.setCancelable(false);
		dialog.setMessage("Loading");
		dialog.show();

		try {
			new ListFolderTask(DbxClientFactory.getClient(), new ListFolderTask.Callback() {
				@Override
				public void onDataLoaded(ListFolderResult result) {
					dialog.dismiss();
					for (Metadata item : result.getEntries()) {
						if (item.getName().equals(vmu)) {
							if (item instanceof FileMetadata) {
								downloadFile((FileMetadata) item);
							}
						}
					}
				}

				@Override
				public void onError(Exception e) {
					dialog.dismiss();

					Log.e(getActivity().getLocalClassName(), "Failed to list folder.", e);
					Toast.makeText(getActivity(),
							"Failed to list folder", Toast.LENGTH_SHORT).show();
				}
			}).execute(mPath);
		} catch (IllegalStateException s) {
			dialog.dismiss();
			Log.e(getActivity().getLocalClassName(), "Failed to list folder.", s);
			Toast.makeText(getActivity(),
					"Failed to list folder", Toast.LENGTH_SHORT).show();
		}
	}

	private void downloadFile(FileMetadata file) {
		final ProgressDialog dialog = new ProgressDialog(getActivity());
		dialog.setProgressStyle(ProgressDialog.STYLE_SPINNER);
		dialog.setCancelable(false);
		dialog.setMessage("Downloading");
		dialog.show();

		try {
			new DownloadFileTask(this, DbxClientFactory.getClient(), new DownloadFileTask.Callback() {
				@Override
				public void onDownloadComplete(File result) {
					dialog.dismiss();
				}

				@Override
				public void onError(Exception e) {
					dialog.dismiss();

					Log.e(getActivity().getLocalClassName(), "Failed to download file.", e);
					Toast.makeText(getActivity(),
							"Failed to download file\n" + e, Toast.LENGTH_SHORT).show();
				}
			}).execute(file);
		} catch (IllegalStateException s) {
			dialog.dismiss();
			Log.e(getActivity().getLocalClassName(), "Failed to download file.", s);
			Toast.makeText(getActivity(),
					"Failed to download file", Toast.LENGTH_SHORT).show();
		}
	}

	static class UploadFileTask extends AsyncTask<String, Void, FileMetadata> {

		private WeakReference<Context> mContext;
		private final DbxClientV2 mDbxClient;
		private final Callback mCallback;
		private Exception mException;

		public interface Callback {
			void onUploadComplete(FileMetadata result);
			void onError(Exception e);
		}

		UploadFileTask(Context context, DbxClientV2 dbxClient, Callback callback) {
			mContext = new WeakReference<>(context);
			mDbxClient = dbxClient;
			mCallback = callback;
		}

		@Override
		protected void onPostExecute(FileMetadata result) {
			super.onPostExecute(result);
			if (mException != null) {
				mCallback.onError(mException);
			} else if (result == null) {
				mCallback.onError(null);
			} else {
				mCallback.onUploadComplete(result);
			}
		}

		@Override
		protected FileMetadata doInBackground(String... params) {
			File localFile = new File(params[0]);
			String remoteFolderPath = params[1];

			// Note - does not verify a valid dropbox file name
			String remoteFileName = localFile.getName();

			try {
				InputStream inputStream = new FileInputStream(localFile);
				return mDbxClient.files().uploadBuilder(
						remoteFolderPath + "/" + remoteFileName)
						.withMode(WriteMode.OVERWRITE)
						.uploadAndFinish(inputStream);
			} catch (DbxException | IOException e) {
				mException = e;
			}

			return null;
		}
	}

	static class ListFolderTask extends AsyncTask<String, Void, ListFolderResult> {

		private final DbxClientV2 mDbxClient;
		private final Callback mCallback;
		private Exception mException;

		public interface Callback {
			void onDataLoaded(ListFolderResult result);
			void onError(Exception e);
		}

		ListFolderTask(DbxClientV2 dbxClient, Callback callback) {
			mDbxClient = dbxClient;
			mCallback = callback;
		}

		@Override
		protected void onPostExecute(ListFolderResult result) {
			super.onPostExecute(result);

			if (mException != null) {
				mCallback.onError(mException);
			} else {
				mCallback.onDataLoaded(result);
			}
		}

		@Override
		protected ListFolderResult doInBackground(String... params) {
			try {
				return mDbxClient.files().listFolder(params[0]);
			} catch (DbxException e) {
				mException = e;
			}

			return null;
		}
	}

	static class DownloadFileTask extends AsyncTask<FileMetadata, Void, File> {

		private WeakReference<CloudFragment> mCloud;
		private final DbxClientV2 mDbxClient;
		private final Callback mCallback;
		private Exception mException;

		public interface Callback {
			void onDownloadComplete(File result);
			void onError(Exception e);
		}

		DownloadFileTask(CloudFragment context, DbxClientV2 dbxClient, Callback callback) {
            mCloud = new WeakReference<>(context);
			mDbxClient = dbxClient;
			mCallback = callback;
		}

		@Override
		protected void onPostExecute(File result) {
			super.onPostExecute(result);
			if (mException != null) {
				mCallback.onError(mException);
			} else {
				mCallback.onDownloadComplete(result);
			}
		}

		@Override
		protected File doInBackground(FileMetadata... params) {
			FileMetadata metadata = params[0];
			try {
				File path = new File(mCloud.get().home_directory);
				File file = new File(path, metadata.getName());

				// Make sure the Downloads directory exists.
				if (!path.exists()) {
					if (!path.mkdirs()) {
						mException = new RuntimeException("Unable to create directory: " + path);
					}
				} else if (!path.isDirectory()) {
					mException = new IllegalStateException("Download path is not a directory: " + path);
					return null;
				}

				// Download the file.
				OutputStream outputStream = new FileOutputStream(file);
				mDbxClient.files().download(metadata.getPathLower(), metadata.getRev())
						.download(outputStream);

				// Tell android about the file
				Intent intent = new Intent(Intent.ACTION_MEDIA_SCANNER_SCAN_FILE);
				intent.setData(Uri.fromFile(file));
				mCloud.get().getActivity().sendBroadcast(intent);

				return file;
			} catch (DbxException | IOException e) {
				mException = e;
			}

			return null;
		}
	}

	private void getPathForFiles(String task) {
		for (String vmu : vmus) {
			File vmuFile = new File(home_directory, vmu);
			if (task.equals("Download")) {
				if (vmuFile.exists())
					createBackupOfVmu(vmuFile.getName());
				else
                    retrieveFiles(vmuFile.getName());
			}
			if (task.equals("Upload")) {
				if (vmuFile.exists())
					uploadFile(vmuFile.toString());
			}
		}
	}

	void createBackupOfVmu(String vmuName) {
		File backupDir = new File(home_directory, "vmu_backup");
		if (!backupDir.exists()) {
			backupDir.mkdirs();
		}

		File source = new File(home_directory, vmuName);
		File destination = new File(home_directory, "vmu_backup/" + vmuName);
		if (!destination.exists()) {
			try {
				destination.createNewFile();
			} catch (IOException e) {
				e.printStackTrace();
			}
		}
		try {
			InputStream in = new FileInputStream(source);
			OutputStream out = new FileOutputStream(destination);
			byte[] buffer = new byte[1024];
			int length;
			while ((length = in.read(buffer)) > 0) {
				out.write(buffer, 0, length);
			}
			in.close();
			out.close();
		} catch (FileNotFoundException e) {
			e.printStackTrace();
		} catch (IOException e) {
			e.printStackTrace();
		}
        retrieveFiles(vmuName);
	}
}
