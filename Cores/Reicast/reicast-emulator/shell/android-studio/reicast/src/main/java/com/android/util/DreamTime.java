package com.android.util;

import java.util.Calendar;

public class DreamTime {

	public static long getDreamtime() {
		long dreamRTC = ((20 * 365 + 5) * 86400) - 1;
		Calendar cal = Calendar.getInstance();
		int utcOffset = cal.get(Calendar.ZONE_OFFSET) + cal.get(Calendar.DST_OFFSET);
		return (System.currentTimeMillis() / 1000) + dreamRTC + (utcOffset / 1000);
	}
}
