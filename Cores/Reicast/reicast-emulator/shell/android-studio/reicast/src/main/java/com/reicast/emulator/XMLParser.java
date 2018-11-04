package com.reicast.emulator;

import android.app.AlertDialog;
import android.content.Context;
import android.content.SharedPreferences;
import android.content.res.ColorStateList;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import android.os.AsyncTask;
import android.os.Build;
import android.support.v4.content.ContextCompat;
import android.support.v4.widget.ImageViewCompat;
import android.view.View;
import android.view.View.OnLongClickListener;
import android.widget.ImageView;
import android.widget.TextView;

import com.reicast.emulator.FileBrowser.OnItemSelectedListener;
import com.reicast.emulator.config.Config;

import org.apache.commons.io.FilenameUtils;
import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;
import org.xml.sax.InputSource;
import org.xml.sax.SAXException;

import java.io.BufferedInputStream;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.io.StringReader;
import java.io.UnsupportedEncodingException;
import java.lang.ref.WeakReference;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLConnection;
import java.net.URLEncoder;
import java.util.Locale;

import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.parsers.ParserConfigurationException;

public class XMLParser extends AsyncTask<String, Integer, String> {

	private SharedPreferences mPrefs;
	private File game;
	private int index;
	private OnItemSelectedListener mCallback;
	private String game_name;
	private Drawable game_icon;
	private String gameId;
	private String game_details;

	private WeakReference<Context> mContext;
	private WeakReference<View> childview;

	XMLParser(File game, int index, SharedPreferences mPrefs) {
		this.mPrefs = mPrefs;
		this.game = game;
		this.index = index;
	}

	public void setViewParent(Context reference, View childview, OnItemSelectedListener mCallback) {
		this.mContext = new WeakReference<>(reference);
		this.childview = new WeakReference<>(childview);
		this.mCallback = mCallback;
		initializeDefaults();
	}

	private void setGameID(String id) {
		this.gameId = id;
	}

	@Override
	protected String doInBackground(String... params) {
		String filename = game_name = params[0];
		if (isNetworkAvailable() && mPrefs.getBoolean(Config.pref_gamedetails, false)) {
			String xmlUrl;
			if (gameId != null) {
				xmlUrl = "http://legacy.thegamesdb.net/api/GetGame.php?platform=sega+dreamcast&id=" + gameId;
			} else {
				filename = filename.substring(0, filename.lastIndexOf("."));
				try {
					filename = URLEncoder.encode(filename, "UTF-8");
				} catch (UnsupportedEncodingException e) {
					filename = filename.replace(" ", "+");
				}
				xmlUrl = "http://legacy.thegamesdb.net/api/GetGamesList.php?platform=sega+dreamcast&name=" + filename;
			}

			try {
				HttpURLConnection conn = (HttpURLConnection) new URL(xmlUrl).openConnection();
				conn.setRequestMethod("POST");
				conn.setDoInput(true);

				InputStream in = conn.getInputStream();
				BufferedReader streamReader = new BufferedReader(
						new InputStreamReader(in, "UTF-8"));
				StringBuilder responseStrBuilder = new StringBuilder();

				String inputStr;
				while ((inputStr = streamReader.readLine()) != null)
					responseStrBuilder.append(inputStr);

				in.close();
				return responseStrBuilder.toString();
			} catch (UnsupportedEncodingException e) {
				e.printStackTrace();
			} catch (IOException e) {
				e.printStackTrace();
			}
		}
		return null;
	}

	@Override
	protected void onPostExecute(String gameData) {
		if (gameData != null) {
			try {
				Document doc = getDomElement(gameData);
				if (doc.getElementsByTagName("Game") != null) {
					Element root = (Element) doc.getElementsByTagName("Game").item(0);
					if (gameId == null) {
						XMLParser xmlParser = new XMLParser(game, index, mPrefs);
						xmlParser.setViewParent(mContext.get(), childview.get(), mCallback);
						xmlParser.setGameID(getValue(root, "id"));
						xmlParser.execute(game_name);
					} else if (root != null) {
						String name = getValue(root, "GameTitle");
						if (!name.equals(""))
							game_name = name + " [" + FilenameUtils.getExtension(
									game.getName()).toUpperCase(Locale.getDefault()) + "]";
						game_details = getValue(root, "Overview");
						getBoxart((Element) root.getElementsByTagName("Images").item(0));
					}
				}
			} catch (Exception e) {
				e.printStackTrace();
			}
		}

		if (childview.get() != null) {
			((TextView) childview.get().findViewById(R.id.item_name)).setText(game_name);

			if (mPrefs.getBoolean(Config.pref_gamedetails, false)) {
				childview.get().findViewById(R.id.childview).setOnLongClickListener(
						new OnLongClickListener() {
							public boolean onLongClick(View view) {
								new AlertDialog.Builder(mContext.get()).setCancelable(true).setIcon(game_icon)
										.setTitle(mContext.get().getString(R.string.game_details, game_name))
										.setMessage(game_details).create().show();
								return true;
							}
						});
			}

			childview.get().setTag(game_name);
		}
	}

	private void getBoxart(Element images) {
		Element boxart = null;
		if (images.getElementsByTagName("boxart").getLength() > 1) {
			boxart = (Element) images.getElementsByTagName("boxart").item(1);
		} else if (images.getElementsByTagName("boxart").getLength() == 1) {
			boxart = (Element) images.getElementsByTagName("boxart").item(0);
		}
		if (boxart != null) {
			decodeBitmapIcon icon = new decodeBitmapIcon(mContext.get());
			icon.setListener(new decodeBitmapIcon.decodeBitmapIconListener() {
				@Override
				public void onDecodeBitmapIconFinished(Bitmap gameImage) {
					if (childview.get() != null && gameImage != null) {
						if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
							((ImageView) childview.get().findViewById(
									R.id.item_icon)).setImageTintList(null);
						}
						if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN) {
							game_icon = new BitmapDrawable(
									mContext.get().getResources(), gameImage);
						} else {
							//noinspection deprecation
							game_icon = new BitmapDrawable(gameImage);
						}
						((ImageView) childview.get().findViewById(
								R.id.item_icon)).setImageDrawable(game_icon);
					}
				}
			});
			icon.executeOnExecutor(AsyncTask.THREAD_POOL_EXECUTOR,
					"https://cdn.thegamesdb.net/images/thumb/"
							+ getElementValue(boxart)
							.replace("original/", ""));
		}
	}

	private void initializeDefaults() {
		game_details = mContext.get().getString(R.string.info_unavailable);
		final String nameLower = game.getName().toLowerCase(Locale.getDefault());
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
			game_icon = mContext.get().getResources().getDrawable(
					game.isDirectory() ? R.drawable.open_folder
							: nameLower.endsWith(".gdi") ? R.mipmap.disk_gdi
							: nameLower.endsWith(".chd") ? R.mipmap.disk_chd
							: nameLower.endsWith(".cdi") ? R.mipmap.disk_cdi
							: R.mipmap.disk_unknown);
		} else {
			game_icon = mContext.get().getResources().getDrawable(
					game.isDirectory() ? R.drawable.open_folder
							: nameLower.endsWith(".gdi") ? R.drawable.gdi
							: nameLower.endsWith(".chd") ? R.drawable.chd
							: nameLower.endsWith(".cdi") ? R.drawable.cdi
							: R.drawable.disk_unknown);
		}
		ImageView icon = (ImageView) childview.get().findViewById(R.id.item_icon);
		icon.setImageDrawable(game_icon);
		int app_theme = mPrefs.getInt(Config.pref_app_theme, 0);
		if (app_theme == 7) {
			childview.get().setBackgroundResource(R.drawable.game_selector_dream);
			ImageViewCompat.setImageTintList(icon, ColorStateList.valueOf(
					ContextCompat.getColor(mContext.get(), R.color.colorDreamTint)));
		} else if (app_theme == 1) {
			childview.get().setBackgroundResource(R.drawable.game_selector_blue);
			ImageViewCompat.setImageTintList(icon, ColorStateList.valueOf(
					ContextCompat.getColor(mContext.get(), R.color.colorBlueTint)));
		} else {
			childview.get().setBackgroundResource(R.drawable.game_selector_dark);
			ImageViewCompat.setImageTintList(icon, ColorStateList.valueOf(
					ContextCompat.getColor(mContext.get(), R.color.colorDarkTint)));
		}
	}

	private boolean isNetworkAvailable() {
		ConnectivityManager connectivityManager = (ConnectivityManager) mContext.get()
				.getSystemService(Context.CONNECTIVITY_SERVICE);
		NetworkInfo mWifi = connectivityManager.getNetworkInfo(ConnectivityManager.TYPE_WIFI);
		NetworkInfo mMobile = connectivityManager.getNetworkInfo(ConnectivityManager.TYPE_MOBILE);
		NetworkInfo activeNetworkInfo = connectivityManager.getActiveNetworkInfo();
		if (mMobile != null && mWifi != null) {
			return mMobile.isAvailable() || mWifi.isAvailable();
		} else {
			return activeNetworkInfo != null && activeNetworkInfo.isConnected();
		}
	}

	private Document getDomElement(String xml) {
		Document doc = null;
		DocumentBuilderFactory dbf = DocumentBuilderFactory.newInstance();
		try {

			DocumentBuilder db = dbf.newDocumentBuilder();

			InputSource is = new InputSource();
			is.setCharacterStream(new StringReader(xml));
			doc = db.parse(is);

		} catch (ParserConfigurationException e) {

			return null;
		} catch (SAXException e) {

			return null;
		} catch (IOException e) {

			return null;
		}

		return doc;
	}

	private String getValue(Element item, String str) {
		if (item != null) {
			NodeList n = item.getElementsByTagName(str);
			return this.getElementValue(n.item(0));
		} else {
			return "";
		}
	}

	private String getElementValue(Node elem) {
		Node child;
		if (elem != null) {
			if (elem.hasChildNodes()) {
				for (child = elem.getFirstChild(); child != null; child = child
						.getNextSibling()) {
					if (child.getNodeType() == Node.TEXT_NODE) {
						return child.getNodeValue();
					}
				}
			}
		}
		return "";
	}

	private static class decodeBitmapIcon extends AsyncTask<String, Integer, Bitmap> {
		private WeakReference<Context> mContext;
		private decodeBitmapIconListener listener;

		decodeBitmapIcon(Context reference) {
			this.mContext = new WeakReference<>(reference);
		}

		@Override
		protected Bitmap doInBackground(String... params) {
			try {
				String index = params[0].substring(params[0].lastIndexOf(
						"/") + 1, params[0].lastIndexOf("."));
				File file = new File(mContext.get().getExternalFilesDir(
						null) + "/images", index + ".png");
				if (file.exists()) {
					return BitmapFactory.decodeFile(file.getAbsolutePath());
				} else {
					URL updateURL = new URL(params[0]);
					URLConnection conn1 = updateURL.openConnection();
					InputStream im = conn1.getInputStream();
					BufferedInputStream bis = new BufferedInputStream(im, 512);
					BitmapFactory.Options options = new BitmapFactory.Options();
					options.inJustDecodeBounds = true;
					BitmapFactory.decodeStream(bis, null, options);
					int heightRatio = (int) Math.ceil(options.outHeight / (float) 72);
					int widthRatio = (int) Math.ceil(options.outWidth / (float) 72);
					if (heightRatio > 1 || widthRatio > 1) {
						if (heightRatio > widthRatio) {
							options.inSampleSize = heightRatio;
						} else {
							options.inSampleSize = widthRatio;
						}
					}
					options.inJustDecodeBounds = false;
					bis.close();
					im.close();
					conn1 = updateURL.openConnection();
					im = conn1.getInputStream();
					bis = new BufferedInputStream(im, 512);
					Bitmap bitmap = BitmapFactory.decodeStream(bis, null, options);
					bis.close();
					im.close();
					OutputStream fOut;
					if (!file.getParentFile().exists()) {
						file.getParentFile().mkdir();
					}
					try {
						fOut = new FileOutputStream(file, false);
						bitmap.compress(Bitmap.CompressFormat.PNG, 100, fOut);
						fOut.flush();
						fOut.close();
					} catch (Exception ex) {
						ex.printStackTrace();
					}
					return bitmap;
				}
			} catch (IOException e) {
				e.printStackTrace();
			}
			return null;
		}

		@Override
		protected void onPostExecute(Bitmap gameImage) {
			super.onPostExecute(gameImage);
			if (listener != null) {
				listener.onDecodeBitmapIconFinished(gameImage);
			}
		}

		void setListener(decodeBitmapIconListener listener) {
			this.listener = listener;
		}

		public interface decodeBitmapIconListener {
			void onDecodeBitmapIconFinished(Bitmap gameImage);
		}
	}
}
