package com.example;

import android.content.Context;
import com.NSLogger.NSLoggerClient;

import java.util.Formatter;

public final class DroidLogger extends NSLoggerClient
{
	public DroidLogger(Context ctx)
	{
		super(ctx);
	}

	private void taggedLog(final int level, final String tag, final String message)
	{
		final StackTraceElement[] st = Thread.currentThread().getStackTrace();
		if (st != null && st.length > 4)
		{
			// log with originating source code info
			final StackTraceElement e = st[4];
			log(e.getFileName(), e.getLineNumber(), e.getClassName() + "." + e.getMethodName() + "()", tag, level, message);
		}
		else
		{
			// couldn't obtain stack trace? log without source code info
			log(tag, level, message);
		}
	}

	public void LOG_MARK(String mark)
	{
		logMark(mark);
	}

	public void LOG_EXCEPTION(Exception exc)
	{
		final StackTraceElement[] st = exc.getStackTrace();
		if (st != null && st.length != 0)
		{
			// a stack trace was attached to exception, report the most recent callsite in file/line/function
			// information, and append the full stack trace to the message
			StringBuilder sb = new StringBuilder(256);
			sb.append("Exception: ");
			sb.append(exc.toString());
			sb.append("\n\nStack trace:\n");
			for (int i=0, n=st.length; i < n; i++)
			{
				final StackTraceElement e = st[i];
				sb.append(e.getFileName());
				if (e.getLineNumber() < 0)
					sb.append(" (native)");
				else
				{
					sb.append(":");
					sb.append(Integer.toString(e.getLineNumber()));
				}
				sb.append(" ");
				sb.append(e.getClassName());
				sb.append(".");
				sb.append(e.getMethodName());
				sb.append("\n");
			}
			final StackTraceElement e = st[0];
			log(e.getFileName(), e.getLineNumber(), e.getClassName() + "." + e.getMethodName() + "()", "exception", 0, sb.toString());
		}
		else
		{
			// no stack trace attached to exception (should not happen)
			taggedLog(0, "exception", exc.toString());
		}
	}

	public void LOG_APP(int level, String format, Object ... args)
	{
		taggedLog(level, "app", new Formatter().format(format, args).toString());
	}

	public void LOG_DYNAMIC_IMAGES(int level, String format, Object ... args)
	{
		taggedLog(level, "images", new Formatter().format(format, args).toString());
	}

	public void LOG_WEBVIEW(int level, String format, Object ... args)
	{
		taggedLog(level, "webview", new Formatter().format(format, args).toString());
	}

	public void LOG_CACHE(int level, String format, Object ... args)
	{
		taggedLog(level, "cache", new Formatter().format(format, args).toString());
	}

	public void LOG_NETWORK(int level, String format, Object ... args)
	{
		taggedLog(level, "network", new Formatter().format(format, args).toString());
	}

	public void LOG_SERVICE(int level, String format, Object ... args)
	{
		taggedLog(level, "service", new Formatter().format(format, args).toString());
	}

	public void LOG_UI(int level, String format, Object ... args)
	{
		taggedLog(level, "ui", new Formatter().format(format, args).toString());
	}
}
