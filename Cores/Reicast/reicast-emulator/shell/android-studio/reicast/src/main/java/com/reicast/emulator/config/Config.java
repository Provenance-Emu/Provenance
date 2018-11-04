package com.reicast.emulator.config;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;

public class Config {

	public static final String pref_home = "home_directory";
	public static final String pref_games = "game_directory";
	public static final String pref_button_theme = "button_theme";

	public static final String pref_app_theme = "app_theme";

	public static final String pref_gamedetails = "game_details";

	public static final String pref_showfps = "show_fps";
	public static final String pref_rendertype = "render_type";
	public static final String pref_renderdepth = "depth_render";

	public static final String pref_touchvibe = "touch_vibration_enabled";
	public static final String pref_vibrationDuration = "vibration_duration";

	public static final String game_title = "game_title";

	public static final String bios_code = "localized";

	public static int vibrationDuration = 20;

	public static final String pref_vmu = "vmu_floating";

	public static String git_api = "https://api.github.com/repos/reicast/reicast-emulator/commits";
	public static String git_issues = "https://github.com/reicast/reicast-emulator/issues/";

	public static boolean externalIntent = false;

	/**
	 * Read the output of a shell command
	 *
	 * @param command
	 *            The shell command being issued to the terminal
	 */
	public static String readOutput(String command) {
		try {
			Process p = Runtime.getRuntime().exec(command);
			InputStream is;
			if (p.waitFor() == 0) {
				is = p.getInputStream();
			} else {
				is = p.getErrorStream();
			}
			BufferedReader br = new BufferedReader(new InputStreamReader(is),2048);
			String line = br.readLine();
			br.close();
			return line;
		} catch (Exception ex) {
			return "ERROR: " + ex.getMessage();
		}
	}

}
