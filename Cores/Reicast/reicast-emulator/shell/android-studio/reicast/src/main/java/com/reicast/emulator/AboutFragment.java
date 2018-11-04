package com.reicast.emulator;

import android.content.SharedPreferences;
import android.content.pm.PackageManager.NameNotFoundException;
import android.graphics.drawable.Drawable;
import android.os.AsyncTask;
import android.os.Build;
import android.os.Bundle;
import android.preference.PreferenceManager;
import android.support.constraint.ConstraintLayout;
import android.support.design.widget.Snackbar;
import android.support.graphics.drawable.VectorDrawableCompat;
import android.support.v4.app.Fragment;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ListView;
import android.widget.TextView;

import com.reicast.emulator.config.Config;
import com.reicast.emulator.debug.GitAdapter;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.lang.ref.WeakReference;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.ArrayList;
import java.util.HashMap;

import javax.net.ssl.HttpsURLConnection;

public class AboutFragment extends Fragment {

	String buildId = "";

	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container,
							 Bundle savedInstanceState) {
		// Inflate the layout for this fragment
		return inflater.inflate(R.layout.about_fragment, container, false);
	}

	@Override
	public void onViewCreated(View view, Bundle savedInstanceState) {

		try {
			String versionName = getActivity().getPackageManager()
					.getPackageInfo(getActivity().getPackageName(), 0).versionName;
			int versionCode = getActivity().getPackageManager()
					.getPackageInfo(getActivity().getPackageName(), 0).versionCode;
			TextView version = (TextView) getView().findViewById(R.id.revision_text);
			version.setText(getString(R.string.revision_text,
					versionName, String.valueOf(versionCode)));
			if (versionName.contains("-")) {
				int start = versionName.lastIndexOf("-");
				buildId = versionName.substring(start + 2, start + 9);
			}
		} catch (NameNotFoundException e) {
			e.printStackTrace();
		}

		new retrieveGitTask(this).execute(Config.git_api);
	}

	private static class retrieveGitTask extends
			AsyncTask<String, Integer, ArrayList<HashMap<String, String>>> {

		private WeakReference<AboutFragment> ref;

		retrieveGitTask(AboutFragment context) {
			ref = new WeakReference<>(context);
		}

		@Override
		protected ArrayList<HashMap<String, String>> doInBackground(
				String... paths) {
			ArrayList<HashMap<String, String>> commitList = new ArrayList<>();
			try {
				JSONArray gitObject = getContent(paths[0]);
				for (int i = 0; i < gitObject.length(); i++) {
					JSONObject jsonObject = gitObject.getJSONObject(i);

					JSONObject commitArray = jsonObject.getJSONObject("commit");

					String date = commitArray.getJSONObject("committer")
							.getString("date").replace("T", " ").replace("Z", "");
					String author = commitArray.getJSONObject("author").getString("name");
					String committer = commitArray.getJSONObject("committer").getString("name");

					String avatar;
					if (!jsonObject.getString("committer").equals("null")) {
						avatar = jsonObject.getJSONObject("committer").getString("avatar_url");
						committer = committer + " (" + jsonObject
								.getJSONObject("committer").getString("login") + ")";
						if (avatar.equals("null")) {
							avatar = "https://github.com/apple-touch-icon-144.png";
						}
					} else {
						avatar = "https://github.com/apple-touch-icon-144.png";
					}
					if (!jsonObject.getString("author").equals("null")) {
						author = author + " (" + jsonObject.getJSONObject(
								"author").getString("login") + ")";
					}
					String sha = jsonObject.getString("sha");
					String curl = jsonObject.getString("url")
							.replace("https://api.github.com/repos", "https://github.com")
							.replace("commits", "commit");

					String title;
					String message = "No commit message attached";

					if (commitArray.getString("message").contains("\n\n")) {
						String fullOutput = commitArray.getString("message");
						title = fullOutput.substring(0, fullOutput.indexOf("\n\n"));
						message = fullOutput.substring(
								fullOutput.indexOf("\n\n") + 1, fullOutput.length());
					} else {
						title = commitArray.getString("message");
					}

					HashMap<String, String> map = new HashMap<>();
					map.put("Date", date);
					map.put("Committer", committer);
					map.put("Title", title);
					map.put("Message", message);
					map.put("Sha", sha);
					map.put("Url", curl);
					map.put("Author", author);
					map.put("Avatar", avatar);
					map.put("Build", ref.get().buildId);
					commitList.add(map);
				}

			} catch (JSONException e) {
				e.printStackTrace();
			} catch (Exception e) {
				e.printStackTrace();
			}
			return commitList;
		}

		@Override
		protected void onPostExecute(
				ArrayList<HashMap<String, String>> commitList) {
			if (commitList != null && commitList.size() > 0) {
				ListView list = (ListView) ref.get().getView().findViewById(R.id.list);
				SharedPreferences mPrefs = PreferenceManager
						.getDefaultSharedPreferences(ref.get().getActivity());
				int app_theme = mPrefs.getInt(Config.pref_app_theme, 0);
				if (app_theme == 7) {
					list.setSelector(R.drawable.list_selector_dream);
				} else if (app_theme == 7) {
					list.setSelector(R.drawable.list_selector_blue);
				} else {
					list.setSelector(R.drawable.list_selector_dark);
				}
				list.setChoiceMode(ListView.CHOICE_MODE_SINGLE);
				GitAdapter adapter = new GitAdapter(ref.get().getActivity(), commitList);
				// Set adapter as specified collection
				list.setAdapter(adapter);
			} else {
				ref.get().showToastMessage(ref.get().getActivity().getString(
						R.string.git_broken), Snackbar.LENGTH_SHORT);
			}

		}

		private JSONArray getContent(String urlString) throws IOException, JSONException {
			HttpURLConnection conn = (HttpURLConnection) new URL(urlString).openConnection();
			conn.setRequestMethod("GET");
			conn.setDoInput(true);

			int responseCode = conn.getResponseCode();
			if (responseCode == HttpsURLConnection.HTTP_OK) {
				InputStream in = conn.getInputStream();
				BufferedReader streamReader = new BufferedReader(
						new InputStreamReader(in, "UTF-8"));
				StringBuilder responseStrBuilder = new StringBuilder();

				String inputStr;
				while ((inputStr = streamReader.readLine()) != null)
					responseStrBuilder.append(inputStr);

				in.close();
				return new JSONArray(responseStrBuilder.toString());
			}
			return null;
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
					R.drawable.ic_info_outline, getActivity().getTheme());
		} else {
			drawable = VectorDrawableCompat.create(getResources(),
					R.drawable.ic_info_outline, getActivity().getTheme());
		}
		textView.setCompoundDrawablesWithIntrinsicBounds(drawable, null, null, null);
		textView.setCompoundDrawablePadding(getResources()
				.getDimensionPixelOffset(R.dimen.snackbar_icon_padding));
		snackbar.show();
	}
}
