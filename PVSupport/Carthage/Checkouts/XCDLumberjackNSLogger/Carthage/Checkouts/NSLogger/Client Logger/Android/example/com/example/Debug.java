package com.example;

import android.content.Context;

public class Debug
{
	public static final boolean D = true;		// set to false to disable debug
	public static DroidLogger L = null;

	public static void assert_(boolean condition)
	{
		if (D && !condition)
			throw new AssertionError("assertion failed");
	}

	public static void enableDebug(Context ctx, boolean flushEachMessage)
	{
		if (L == null)
		{
			L = new DroidLogger(ctx);
			L.setMessageFlushing(flushEachMessage);
		}
	}
}
