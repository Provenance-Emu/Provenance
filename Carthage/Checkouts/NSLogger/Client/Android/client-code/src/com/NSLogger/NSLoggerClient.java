/*
 * NSLoggerClient.java
 *
 * Android version 1.0.1 2015-04-15
 *
 * Android port of the NSLogger client code
 * https://github.com/fpillet/NSLogger
 *
 * BSD license follows (http://www.opensource.org/licenses/bsd-license.php)
 *
 * Copyright (c) 2011-2015 Florent Pillet All Rights Reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 * Redistributions of  source code  must retain  the above  copyright notice,
 * this list of  conditions and the following  disclaimer. Redistributions in
 * binary  form must  reproduce  the  above copyright  notice,  this list  of
 * conditions and the following disclaimer  in the documentation and/or other
 * materials  provided with  the distribution.  Neither the  name of  Florent
 * Pillet nor the names of its contributors may be used to endorse or promote
 * products  derived  from  this  software  without  specific  prior  written
 * permission.  THIS  SOFTWARE  IS  PROVIDED BY  THE  COPYRIGHT  HOLDERS  AND
 * CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT
 * NOT LIMITED TO, THE IMPLIED  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A  PARTICULAR PURPOSE  ARE DISCLAIMED.  IN  NO EVENT  SHALL THE  COPYRIGHT
 * HOLDER OR  CONTRIBUTORS BE  LIABLE FOR  ANY DIRECT,  INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY,  OR CONSEQUENTIAL DAMAGES (INCLUDING,  BUT NOT LIMITED
 * TO, PROCUREMENT  OF SUBSTITUTE GOODS  OR SERVICES;  LOSS OF USE,  DATA, OR
 * PROFITS; OR  BUSINESS INTERRUPTION)  HOWEVER CAUSED AND  ON ANY  THEORY OF
 * LIABILITY,  WHETHER  IN CONTRACT,  STRICT  LIABILITY,  OR TORT  (INCLUDING
 * NEGLIGENCE  OR OTHERWISE)  ARISING  IN ANY  WAY  OUT OF  THE  USE OF  THIS
 * SOFTWARE,   EVEN  IF   ADVISED  OF   THE  POSSIBILITY   OF  SUCH   DAMAGE.
 *
 */
package com.NSLogger;

import android.content.Context;
import android.content.pm.ApplicationInfo;
import android.net.SSLCertificateSocketFactory;
import android.net.wifi.WifiManager;
import android.os.*;
import android.os.Process;
import android.provider.Settings.Secure;
import android.util.Log;

import javax.net.ssl.*;
import java.io.*;
import java.net.InetAddress;
import java.net.Socket;
import java.net.UnknownHostException;
import java.nio.charset.Charset;
import java.util.ArrayList;
import java.util.Date;
import java.util.Properties;
import java.util.Queue;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.locks.Condition;
import java.util.concurrent.locks.LockSupport;
import java.util.concurrent.locks.ReentrantLock;
import java.util.logging.LogRecord;

/**
 * NSLoggerClient maintain one connection to the remote NSLogger desktop viewer (or log to a log file)
 * You can use multiple NSLoggerClient instances if you need to, this will open multiple windows
 * in the desktop viewer.
 *
 * Your application's AndroidManifest.xml needs to make use of the following permission:
 *
 * <uses-permission android:name="android.permission.INTERNET" />
 *
 * In addition, if you are going to use NSLoggerClient with Bonjour to automatically locate the desktop viewer
 * (this is the default), make sure your application's AndroidManifest.xml uses the following permissions:
 *
 * <uses-permission android:name="android.permission.CHANGE_WIFI_MULTICAST_STATE" />
 *
 */
public class NSLoggerClient
{
	// DEBUG MODE. Only set to true when debugging NSLogger itself, to output logs to (sigh) logcat
	// this generates a quite verbose log of what's happening internally in NSLogger.
	private final boolean DEBUG_LOGGER = false;

	// Options
	public static final int
		OPT_FLUSH_EACH_MESSAGE = 1,		// If set, NSLogger waits for each message to be sent to the desktop viewer (this includes connecting to the viewer)
		OPT_BROWSE_BONJOUR = 2,
		OPT_USE_SSL = 4,
		OPT_ROUTE_TO_LOGCAT = 8;

	// A global lock that we use to tell the OS that we need to use multicasting
	// when we need to use Bonjour. Each NSLogger instance willing to use Bonjour
	// will acquire() the lock when needed. Lock is created on-demand the first
	private static WifiManager.MulticastLock multicastLock;

	// Instance variables
	Context currentContext;
	protected int options;
	String bufferFile;			// buffer file to write to. We use this when not connected if OPT_BUFFER_UNTIL_CONNECTION, and when no remote host defined and no OPT_LOG_TO_CONSOLE
	String bonjourServiceName;	// when browsing for Bonjour services, the bonjour service name to use. If not customized by the user, we will use the first service found
	String bonjourServiceType;	// the service type to use. If not customized by the user, we will use either the SSL or non-SSL service type
	String remoteHost;			// the remote host we're talking to
	int remotePort;				// the remote port
	InetAddress remoteAddress;	// or use a full-fledged InetAddress
	final AtomicInteger nextSequenceNumber = new AtomicInteger(0); // the unique message-sequence number we use to differentiate and order message on the viewer side

	LoggingWorker loggingThread;
	Handler loggingThreadHandler;

	// Message types for communicating with the logger thread
	protected static final int
		MSG_TRY_CONNECT = 1,
		MSG_CONNECT_COMPLETE = 2,
		MSG_ADDLOG = 3,
		MSG_ADDLOGRECORD = 4,
		MSG_OPTCHANGE = 5,
		MSG_QUIT = 10;

	// The charset we use for transmitting strings
	protected static Charset stringsCharset = Charset.forName("utf-8");

	/**
	 * Create a new NSLoggerClient instance. Multiple instances will create multiple log windows on
	 * the desktop viewer, or you can have instances that log to a file and others that
	 * log to the desktop viewer. Typically, you will use only one instance.
	 * Default options are to lookup for a desktop viewer on Bonjour, and use SSL
	 * @param ctx	the current context, which is used to extract and send information about the client application
	 */
	public NSLoggerClient(Context ctx)
	{
		if (DEBUG_LOGGER)
			Log.i("NSLogger", "NSLoggerClient created");
		currentContext = ctx.getApplicationContext();

		// create the multicast lock (for Bonjour) if needed, otherwise the WiFi adapter
		// doesn't process multicast packets when needed. We will acquire the lock ONLY
		// while looking for a Bonjour service to connect to, and will release it as soon
		// as we acquire an actual connection to the service.
		if (multicastLock == null)
		{
			synchronized (this.getClass())
			{
				if (multicastLock == null)
				{
					WifiManager wifi = (WifiManager)ctx.getSystemService(Context.WIFI_SERVICE);
					multicastLock = wifi.createMulticastLock("NSLoggerBonjourLock");
					multicastLock.setReferenceCounted(true);
				}
			}
		}

		options = (OPT_BROWSE_BONJOUR | OPT_USE_SSL);
	}

	/**
	 * Enables of disable messages flushing. When enabled, NSLogger will wait for each
	 * message to have been sent to the desktop viewer. This includes waiting for connection
	 * if we are not currently connected to the desktop viewer
	 * @param flushEachMessage	set to true to enable flushing
	 */
	public final synchronized void setMessageFlushing(boolean flushEachMessage)
	{
		if (flushEachMessage)
			options |= OPT_FLUSH_EACH_MESSAGE;
		else
			options &= ~OPT_FLUSH_EACH_MESSAGE;
	}

	/**
	 * Setup NSLogger to write logs to a buffer file. Calling this method automatically
	 * shuts down any current connection to the desktop viewer and switches to writing
	 * to a file instead
	 * @param filePath an absolute path to the buffer file
	 */
	public final synchronized void setBufferFile(String filePath)
	{
		if (loggingThreadHandler != null)
		{
			Properties opts = new Properties();
			opts.setProperty("filename", filePath);
			loggingThreadHandler.sendMessage(loggingThreadHandler.obtainMessage(MSG_OPTCHANGE, opts));
		}
		else
		{
			if (filePath == null)
				throw new NullPointerException("buffer file path is null");
			bufferFile = filePath;
		}
	}

	/**
	 * Setup NSLogger for Bonjour browsing with specific parameters. By default, the
	 * service name and service type are null. You can elect to connect to a specific
	 * service type (although it is not recommended to customize this -- this is useful
	 * only if you have customized the desktop side of NSLogger) and if you specify a
	 * service name (the machine name), you can direct logs to a specific machine on
	 * your network in the case there are multiple instances of the NSLogger viewer
	 * running there.
	 * @param serviceType	a type of service, or null (NSLogger uses "_nslogger-ssl._tcp" for secure connections,
	 * 						and "_nslogger._tcp" for insecure connections)
	 * @param serviceName	the name of the service to look for, or null. In the desktop viewer,
	 * 						you can give a specific name for an instance of NSLogger.
	 * 						Passing the same name here guarantees that your logger will only connect to this instance.
	 * @param useSSL		set to true to use the secure transport to desktop viewer
	 */
	public final synchronized void setupBonjour(String serviceType, String serviceName, boolean useSSL)
	{
		if (loggingThreadHandler != null)
		{
			Properties opts = new Properties();
			opts.setProperty("bonjourService", serviceName);
			opts.setProperty("bonjourType", serviceType);
			opts.setProperty("useSSL", useSSL ? "1" : "0");
			loggingThreadHandler.sendMessage(loggingThreadHandler.obtainMessage(MSG_OPTCHANGE, opts));
		}
		else
		{
			bonjourServiceName = serviceName;
			bonjourServiceType = serviceType;
			if (useSSL)
				options |= OPT_USE_SSL;
			else
				options &= ~OPT_USE_SSL;
		}
	}

	/**
	 * Set the remote host and port to connect to. Setting these to valid values
	 * (non-null hostname, non-zero port) automatically invalidates Bonjour browsing,
	 * and NSLogger will only try to connect. If you pass null hostname and/or zero
	 * port value, NSLogger will automatically revert to using Bonjour.
	 * @param hostname		non-null hostname, or null to cancel and use Bonjour
	 * @param port			non-zero port, or zero to cancel and use Bonjour
	 * @param useSSL		set to true to select SSL transport to desktop viewer
	 */
	public final synchronized void setRemoteHost(String hostname, int port, boolean useSSL)
	{
		if (DEBUG_LOGGER)
			Log.i("NSLogger", String.format("setRemoteHost host=%s port=%d useSSL=%b", hostname, port, useSSL));

		if (loggingThreadHandler != null)
		{
			Properties opts = new Properties();
			opts.setProperty("remoteHost", hostname);
			opts.setProperty("remotePort", Integer.toString(port));
			opts.setProperty("useSSL", useSSL ? "1" : "0");
			loggingThreadHandler.sendMessage(loggingThreadHandler.obtainMessage(MSG_OPTCHANGE, opts));
		}
		else
		{
			remoteHost = hostname;
			remotePort = port;
			if (useSSL)
				options |= OPT_USE_SSL;
			else
				options &= ~OPT_USE_SSL;
		}
	}

	private void startLoggingThreadIfNeeded()
	{
		try
		{
			boolean waiting = false;
			if (loggingThread == null)
			{
				synchronized (this)
				{
					if (loggingThread == null)
					{
						loggingThread = new LoggingWorker();
						loggingThread.readyWaiters.add(Thread.currentThread());
						loggingThread.start();
						waiting = true;
					}
				}
			}
			while (!loggingThread.ready.get())
			{
				if (!waiting)
				{
					loggingThread.readyWaiters.add(Thread.currentThread());
					waiting = true;
				}
				LockSupport.parkUntil(this, System.currentTimeMillis() + 100);
				if (Thread.interrupted())
					Thread.currentThread().interrupt();
			}
		}
		catch (Exception e)
		{
			Log.e("NSLogger", "Exception caught in startLoggingThreadIfNeeded: " + e.toString());
		}
	}

	/**
	 * Log a message with full information (if provided)
	 * @param filename		the filename (or class name), or null
	 * @param method		the method that emitted the message, or null
	 * @param tag			a tag attributed to the message, or empty string or null
	 * @param level			a level >= 0
	 * @param message		the message to send
	 */
	public final void log(String filename, int lineNumber, String method, String tag, int level, String message)
	{
		startLoggingThreadIfNeeded();
		if (loggingThreadHandler == null)
			return;

		final LogMessage lm = new LogMessage(LogMessage.LOGMSG_TYPE_LOG, nextSequenceNumber.getAndIncrement());
		lm.addInt16(level, LogMessage.PART_KEY_LEVEL);
		if (filename != null)
		{
			lm.addString(filename, LogMessage.PART_KEY_FILENAME);
			if (lineNumber != 0)
				lm.addInt32(lineNumber, LogMessage.PART_KEY_LINENUMBER);
		}
		if (method != null)
			lm.addString(method, LogMessage.PART_KEY_FUNCTIONNAME);
		if (tag != null && !tag.isEmpty())
			lm.addString(tag, LogMessage.PART_KEY_TAG);
		lm.addString(message, LogMessage.PART_KEY_MESSAGE);

		final boolean needsFlush = ((options & OPT_FLUSH_EACH_MESSAGE) != 0);
		if (needsFlush)
			lm.prepareForFlush();

		loggingThreadHandler.sendMessage(loggingThreadHandler.obtainMessage(MSG_ADDLOG, lm));

		if (needsFlush)
			lm.waitFlush();
	}

	/**
	 * Log a message, attributing a tag and level to the message
	 * @param tag			a tag attributed to the message, or empty string or null
	 * @param level			a level >= 0
	 * @param message		the message to send
	 */
	public final void log(String tag, int level, String message)
	{
		log(null, 0, null, tag, level, message);
	}

	/**
	 * Log a message with no tag and default level (0)
	 * @param message		the message to send
	 */
	public final void log(String message)
	{
		log(null, 0, message);
	}

	/**
	 * Log a message that you built yourself
	 * @param message
	 */
	public final void log(LogMessage message)
	{
		startLoggingThreadIfNeeded();
		if (loggingThreadHandler != null)
			loggingThreadHandler.sendMessage(loggingThreadHandler.obtainMessage(MSG_ADDLOG, message));
	}

	/**
	 * Log a block of data
	 * @param filename		the filename (or class name), or null
	 * @param method		the method that emitted the message, or null
	 * @param lineNumber	the line number in the source code file where this method was called
	 * @param tag			a tag attributed to the message, or empty string or null
	 * @param level			a level >= 0
	 * @param data			a block of data
	 */
	public final void logData(String filename, int lineNumber, String method, String tag, int level, byte[] data)
	{
		startLoggingThreadIfNeeded();
		if (loggingThreadHandler == null)
			return;

		final LogMessage lm = new LogMessage(LogMessage.LOGMSG_TYPE_LOG, nextSequenceNumber.getAndIncrement());
		lm.addInt16(level, LogMessage.PART_KEY_LEVEL);
		if (filename != null)
		{
			lm.addString(filename, LogMessage.PART_KEY_FILENAME);
			if (lineNumber != 0)
				lm.addInt32(lineNumber, LogMessage.PART_KEY_LINENUMBER);
		}
		if (method != null)
			lm.addString(method, LogMessage.PART_KEY_FUNCTIONNAME);
		if (tag != null && tag.length() != 0)
			lm.addString(tag, LogMessage.PART_KEY_TAG);
		lm.addBinaryData(data, LogMessage.PART_KEY_MESSAGE);

		final boolean needsFlush = ((options & OPT_FLUSH_EACH_MESSAGE) != 0);
		if (needsFlush)
			lm.prepareForFlush();

		loggingThreadHandler.sendMessage(loggingThreadHandler.obtainMessage(MSG_ADDLOG, lm));

		if (needsFlush)
			lm.waitFlush();
	}

	/**
	 * Log an image
	 *
	 * @param filename		the filename (or class name), or null
	 * @param method		the method that emitted the message, or null
	 * @param lineNumber	the line number in the source code file where this method was called
	 * @param tag			a tag attributed to the message, or empty string or null
	 * @param level			a level >= 0
	 * @param data			raw image data. Most image file formats are automatically decoded and recognized
	 * 						by the desktop viewer
	 */
	public final void logImage(String filename, int lineNumber, String method, String tag, int level, byte[] data)
	{
		startLoggingThreadIfNeeded();
		if (loggingThreadHandler == null)
			return;

		final LogMessage lm = new LogMessage(LogMessage.LOGMSG_TYPE_LOG, nextSequenceNumber.getAndIncrement());
		lm.addInt16(level, LogMessage.PART_KEY_LEVEL);
		if (filename != null)
		{
			lm.addString(filename, LogMessage.PART_KEY_FILENAME);
			if (lineNumber != 0)
				lm.addInt32(lineNumber, LogMessage.PART_KEY_LINENUMBER);
		}
		if (method != null)
			lm.addString(method, LogMessage.PART_KEY_FUNCTIONNAME);
		if (tag != null && tag.length() != 0)
			lm.addString(tag, LogMessage.PART_KEY_TAG);
		lm.addImageData(data, LogMessage.PART_KEY_MESSAGE);

		final boolean needsFlush = ((options & OPT_FLUSH_EACH_MESSAGE) != 0);
		if (needsFlush)
			lm.prepareForFlush();

		loggingThreadHandler.sendMessage(loggingThreadHandler.obtainMessage(MSG_ADDLOG, lm));

		if (needsFlush)
			lm.waitFlush();
	}

	/**
	 * Log a mark to the desktop viewer. Marks are important points that you can jump to directly
	 * in the desktop viewer. Message is optional, if null or empty it will be replaced with the
	 * current date / time
	 * @param message	optional message
	 */
	public final void logMark(String message)
	{
		startLoggingThreadIfNeeded();
		if (loggingThreadHandler == null)
			return;

		final LogMessage lm = new LogMessage(LogMessage.LOGMSG_TYPE_MARK, nextSequenceNumber.getAndIncrement());
		lm.addInt16(0, LogMessage.PART_KEY_LEVEL);
		if (message != null && message.length() != 0)
			lm.addString(message, LogMessage.PART_KEY_MESSAGE);
		else
			lm.addString(new Date().toString(), LogMessage.PART_KEY_MESSAGE);

		final boolean needsFlush = ((options & OPT_FLUSH_EACH_MESSAGE) != 0);
		if (needsFlush)
			lm.prepareForFlush();

		loggingThreadHandler.sendMessage(loggingThreadHandler.obtainMessage(MSG_ADDLOG, lm));

		if (needsFlush)
			lm.waitFlush();
	}

	/**
	 * A class that encapsulates a log message and can produce a binary representation
	 * to send to the desktop NSLogger viewer. Methods are provided to gradually build
	 * the various parts of the messsage. Once building is complete, a call to the
	 * getBytes() method returns a full-fledged binary message to send to the desktop
	 * viewer.
	 */
	public final class LogMessage
	{
		// Constants for the "part key" field
		static final int
			PART_KEY_MESSAGE_TYPE = 0,		// defines the type of message (see LOGMSG_TYPE_*)
			PART_KEY_TIMESTAMP_S = 1,	// "seconds" component of timestamp
			PART_KEY_TIMESTAMP_MS = 2,		// milliseconds component of timestamp (optional, mutually exclusive with PART_KEY_TIMESTAMP_US)
			PART_KEY_TIMESTAMP_US = 3,		// microseconds component of timestamp (optional, mutually exclusive with PART_KEY_TIMESTAMP_MS)
			PART_KEY_THREAD_ID = 4,
			PART_KEY_TAG = 5,
			PART_KEY_LEVEL = 6,
			PART_KEY_MESSAGE = 7,
			PART_KEY_IMAGE_WIDTH = 8,		// messages containing an image should also contain a part with the image size
			PART_KEY_IMAGE_HEIGHT = 9,		// (this is mainly for the desktop viewer to compute the cell size without having to immediately decode the image)
			PART_KEY_MESSAGE_SEQ = 10,		// the sequential number of this message which indicates the order in which messages are generated
			PART_KEY_FILENAME = 11,			// when logging, message can contain a file name
			PART_KEY_LINENUMBER = 12,		// as well as a line number
			PART_KEY_FUNCTIONNAME = 13;		// and a function or method name

		// Constants for parts in LOGMSG_TYPE_CLIENTINFO
		static final int
			PART_KEY_CLIENT_NAME = 20,
			PART_KEY_CLIENT_VERSION = 21,
			PART_KEY_OS_NAME = 22,
			PART_KEY_OS_VERSION = 23,
			PART_KEY_CLIENT_MODEL = 24,		// For iPhone, device model (i.e 'iPhone', 'iPad', etc)
			PART_KEY_UNIQUEID = 25;			// for remote device identification, part of LOGMSG_TYPE_CLIENTINFO

		// Area starting at which you may define your own constants
		static final int
			PART_KEY_USER_DEFINED = 100;

		// Constants for the "partType" field
		static final int
			PART_TYPE_STRING = 0,			// Strings are stored as UTF-8 data
			PART_TYPE_BINARY = 1,			// A block of binary data
			PART_TYPE_INT16 = 2,
			PART_TYPE_INT32 = 3,
			PART_TYPE_INT64 = 4,
			PART_TYPE_IMAGE = 5;			// An image, stored in PNG format

		// Data values for the PART_KEY_MESSAGE_TYPE parts
		static final int
			LOGMSG_TYPE_LOG = 0,			// A standard log message
			LOGMSG_TYPE_BLOCKSTART = 1,		// The start of a "block" (a group of log entries)
			LOGMSG_TYPE_BLOCKEND = 2,		// The end of the last started "block"
			LOGMSG_TYPE_CLIENTINFO = 3,		// Information about the client app
			LOGMSG_TYPE_DISCONNECT = 4,		// Pseudo-message on the desktop side to identify client disconnects
			LOGMSG_TYPE_MARK = 5;			// Pseudo-message that defines a "mark" that users can place in the log flow

		// Instance variables
		private byte[] data;
		private int dataUsed;
		private final int sequenceNumber;
		private short numParts;

		// Flushing support
		private ReentrantLock doneLock;
		private Condition doneCondition;

		/**
		 * Create a new binary log record from an existing LogRecord instance
		 * @param record		the LogRecord instance we want to send
		 * @param seq			the message's sequence number
		 */
		public LogMessage(LogRecord record, int seq)
		{
			sequenceNumber = seq;
			String msg = record.getMessage();
			data = new byte[msg.length() + 64];			// gross approximation
			dataUsed = 6;
			addTimestamp(record.getMillis());
			addInt32(LOGMSG_TYPE_LOG, PART_KEY_MESSAGE_TYPE);
			addInt32(sequenceNumber, PART_KEY_MESSAGE_SEQ);
			addString(Long.toString(record.getThreadID()), PART_KEY_THREAD_ID);
			addInt16(record.getLevel().intValue(), PART_KEY_LEVEL);
			addString(record.getSourceClassName() + "." + record.getSourceMethodName(), PART_KEY_FUNCTIONNAME);
			addString(record.getMessage(), PART_KEY_MESSAGE);
		}

		/**
		 * Prepare an empty log message that can be filled
		 * @param messageType		the message type (i.e. LOGMSG_TYPE_LOG)
		 * @param seq				the message's sequence number
		 */
		public LogMessage(int messageType, int seq)
		{
			sequenceNumber = seq;
			data = new byte[256];
			dataUsed = 6;
			addInt32(messageType, PART_KEY_MESSAGE_TYPE);
			addInt32(sequenceNumber, PART_KEY_MESSAGE_SEQ);
			addTimestamp(0);
			addThreadID(Thread.currentThread().getId());
		}

		/**
		 * Obtain this message's sequence number (should be a unique number that orders messages sent)
		 * @return the sequence number
		 */
		public int getSequenceNumber()
		{
			return sequenceNumber;
		}

		/**
		 * Internally used to indicate that the client thread will wait for this
		 * message to have been sent before continuing
		 */
		protected void prepareForFlush()
		{
			doneLock = new ReentrantLock();
			doneCondition = doneLock.newCondition();
			doneLock.lock();
		}

		/**
		 * Internally used by the client thread to wait for the logging thread
		 * to have successfully sent the message. Thread is blocked in the
		 * meantime.
		 */
		protected void waitFlush()
		{
			try {
				if (DEBUG_LOGGER)
					Log.v("NSLogger", String.format("waiting for flush of message %d", sequenceNumber));
				doneCondition.await();
			} catch (InterruptedException e) {
				// nothing here
			} finally {
				doneLock.unlock();
			}
		}

		/**
		 * Internally used by the logging thread to mark this message as "flushed"
		 * (sent to the desktop viewer or written to the log file)
		 */
		protected void markFlushed()
		{
			if (doneLock != null)
			{
				if (DEBUG_LOGGER)
					Log.v("NSLogger", String.format("marking message %d as flushed", sequenceNumber));
				doneLock.lock();
				doneCondition.signal();
				doneLock.unlock();
			}
		}

		/**
		 * Return the generated binary message
		 *
		 * @return bytes to send to desktop NSLogger
		 */
		byte[] getBytes()
		{
			int size = dataUsed - 4;
			data[0] = (byte) (size >> 24);
			data[1] = (byte) (size >> 16);
			data[2] = (byte) (size >> 8);
			data[3] = (byte) size;
			data[4] = (byte) (numParts >> 8);
			data[5] = (byte) numParts;

			if (dataUsed == data.length)
				return data;

			byte[] b = new byte[dataUsed];
			System.arraycopy(data, 0, b, 0, dataUsed);
			data = null;
			return b;
		}

		void addTimestamp(long ts)
		{
			if (ts == 0)
				ts = System.currentTimeMillis();
			addInt64(ts / 1000, PART_KEY_TIMESTAMP_S);
			addInt16((int) (ts % 1000), PART_KEY_TIMESTAMP_MS);
		}

		void addThreadID(long threadID)
		{
			String s = null;
			// If the thread is part if our thread group, we can extract its
			// name. Otherwise, just use a thread number
			Thread t = Thread.currentThread();
			if (t.getId() == threadID)
				s = t.getName();
			else
			{
				Thread array[] = new Thread[Thread.activeCount()];
				Thread.enumerate(array);
				for (Thread th : array)
				{
					if (th.getId() == threadID)
					{
						s = t.getName();
						break;
					}
				}
			}
			if (s == null || s.isEmpty())
				s = Long.toString(threadID);
			addString(s, PART_KEY_THREAD_ID);
		}

		private void grow(int nBytes)
		{
			final int n = data.length;
			if (n >= dataUsed + nBytes)
				return;

			byte b[] = new byte[Math.max(n + n / 2, dataUsed + nBytes + 64)];
			System.arraycopy(data, 0, b, 0, dataUsed);
			data = b;
		}

		public void addInt16(int value, int key)
		{
			grow(4);
			int n = dataUsed;
			data[n++] = (byte)key;
			data[n++] = (byte)PART_TYPE_INT16;
			data[n++] = (byte)(value >> 8);
			data[n++] = (byte)value;
			dataUsed = n;
			numParts++;
		}

		public void addInt32(int value, int key)
		{
			grow(6);
			int n = dataUsed;
			data[n++] = (byte)key;
			data[n++] = (byte)PART_TYPE_INT32;
			data[n++] = (byte)(value >> 24);
			data[n++] = (byte)(value >> 16);
			data[n++] = (byte)(value >> 8);
			data[n++] = (byte)value;
			dataUsed = n;
			numParts++;
		}

		public void addInt64(long value, int key)
		{
			grow(10);
			int n = dataUsed;
			data[n++] = (byte)key;
			data[n++] = (byte)PART_TYPE_INT64;
			data[n++] = (byte)(value >> 56);
			data[n++] = (byte)(value >> 48);
			data[n++] = (byte)(value >> 40);
			data[n++] = (byte)(value >> 32);
			data[n++] = (byte)(value >> 24);
			data[n++] = (byte)(value >> 16);
			data[n++] = (byte)(value >> 8);
			data[n++] = (byte)value;
			dataUsed = n;
			numParts++;
		}

		public void addBytes(int key, int type, byte[] bytes)
		{
			final int l = bytes.length;
			grow(l + 6);
			int n = dataUsed;
			data[n++] = (byte)key;
			data[n++] = (byte)type;
			data[n++] = (byte)(l >> 24);
			data[n++] = (byte)(l >> 16);
			data[n++] = (byte)(l >> 8);
			data[n++] = (byte)l;
			System.arraycopy(bytes, 0, data, n, l);
			dataUsed = n + l;
			numParts++;
		}

		public void addString(String s, int key)
		{
			byte[] sb = s.getBytes(stringsCharset);
			addBytes(key, PART_TYPE_STRING, sb);
		}

		public void addBinaryData(byte[] d, int key)
		{
			addBytes(key, PART_TYPE_BINARY, d);
		}

		public void addImageData(byte[] img, int key)
		{
			addBytes(key, PART_TYPE_IMAGE, img);
		}
	}

	/**
	 * The class encapsulating the actual worker thread for NSLogger
	 */
	private class LoggingWorker extends Thread
	{
		ArrayList<LogMessage> logs = new ArrayList<LogMessage>(64);

		boolean connecting;				// a connection attempt is already in progress
		boolean reconnectionScheduled;	// a reconnection message has been scheduled
		boolean clientInfoAdded;		// info about us has been queued (reset after each disconnect)

		Socket remoteSocket;			// the remote socket we're talking to
		int socketSendBufferSize;		// the size of the socket's send buffer
		boolean connected;				// only set to true when the connect complete message has been received

		OutputStream writeStream;		// the write stream we use to write to either socket or file
		InputStream readStream;			// when flushing file contents, temporarily hold a readStream
		byte[] incompleteSend;			// if last message could not be sent in one batch, the full message here
		int incompleteSendOffset;		// and the offset from which to continue sending here

		String bonjourListeningType;

		// Startup locking mechanism
		final AtomicBoolean ready = new AtomicBoolean(false);
		final Queue<Thread> readyWaiters = new ConcurrentLinkedQueue<Thread>();

		/**
		 * Our private class which handles messages sent from other threads
		 */
		private class InternalMsgHandler extends Handler
		{
			public void handleMessage(Message msg)
			{
				switch (msg.what)
				{
					case MSG_ADDLOG:
						if (DEBUG_LOGGER)
							Log.v("NSLogger", String.format("add log %d to the queue", ((LogMessage)msg.obj).getSequenceNumber()));
						logs.add((LogMessage) msg.obj);
						if (connected)
							processLogQueue();
						break;

					case MSG_ADDLOGRECORD:
						if (DEBUG_LOGGER)
							Log.v("NSLogger", "add LogRecord to the queue");
						logs.add(new LogMessage((LogRecord) msg.obj, nextSequenceNumber.getAndIncrement()));
						if (connected)
							processLogQueue();
						break;

					case MSG_OPTCHANGE:
						if (DEBUG_LOGGER)
							Log.v("NSLogger", "options change message received");
						changeOptions((Properties)msg.obj);
						break;

					case MSG_CONNECT_COMPLETE:
						if (DEBUG_LOGGER)
							Log.v("NSLogger", "connect complete message received");
						connecting = false;
						connected = true;
						processLogQueue();
						break;

					case MSG_TRY_CONNECT:
						if (DEBUG_LOGGER)
							Log.v("NSLogger", String.format("try connect message received, remote socket is %s, writeStream is %s, connecting=%d", remoteSocket==null?"null":"not null", writeStream==null?"null":"not null", connecting ? 1 : 0));
						reconnectionScheduled = false;
						if (remoteSocket == null && writeStream == null)
						{
							if (!connecting && remoteHost != null && remotePort != 0)
								connectToRemote();
						}
						break;

					case MSG_QUIT:
						Looper.myLooper().quit();
						break;
				}
			}
		}

		LoggingWorker()
		{
			// We want NSLogger to leave as much CPU as possible for the app to run
			// TODO: when flushing is turned ON, change priority to normal
			super("NSLogger");
			setPriority(Process.THREAD_PRIORITY_LESS_FAVORABLE);
		}

		@Override
		public void run()
		{
			// create the buffer file if needed
			try
			{
				if (DEBUG_LOGGER)
					Log.i("NSLogger", "Logging thread starting up");

				// Prepare to receive messages
				Looper.prepare();
				loggingThreadHandler = new InternalMsgHandler();

				// We are ready to run. Unpark the waiting threads now
				// (there may be multiple thread trying to start logging at the same time)
				ready.set(true);
				while (!readyWaiters.isEmpty())
					LockSupport.unpark(readyWaiters.poll());

				// Initial setup according to current parameters
				if (bufferFile != null)
					createBufferWriteStream();
				else if (remoteHost != null && remotePort != 0)
					connectToRemote();
				else if ((options & OPT_BROWSE_BONJOUR) != 0)
					setupBonjour();

				if (DEBUG_LOGGER)
					Log.i("NSLogger", "Logging thread looper starting");

				// Process messages
				Looper.loop();

				if (DEBUG_LOGGER)
					Log.i("NSLogger", "Logging thread looper ended");

				// Once loop exists, reset the variable (in case of problem we'll recreate a thread)
				closeBonjour();
				loggingThread = null;
				loggingThreadHandler = null;
			}
			catch (Exception e)
			{
				if (DEBUG_LOGGER)
					Log.e("NSLogger", "Exception caught in LoggingWorker.run(): " + e.toString());

				// In case an exception was caused before run, make sure waiters are unblocked
				ready.set(true);
				while (!readyWaiters.isEmpty())
					LockSupport.unpark(readyWaiters.peek());
			}
		}

		void changeOptions(Properties newOptions)
		{
			// We received an options change message. If options were actually change,
			// we will interrupt the current logging stream, switch options and the
			// next message sent will trigger a reconnect with the new options
			if (newOptions.containsKey("filename"))
			{
				String filename = newOptions.getProperty("filename");
				if (bufferFile == null || !bufferFile.equalsIgnoreCase(filename))
				{
					if (bufferFile == null)
						disconnectFromRemote();
					else if (writeStream != null)
						closeBufferWriteStream();
					bufferFile = filename;
					createBufferWriteStream();
				}
			}
			else
			{
				boolean change = (bufferFile != null);
				String host = "";
				int port = 0, newFlags = 0;
				if (newOptions.getProperty("useSSL", "0").equals("1"))
					newFlags = OPT_USE_SSL;
				if (newOptions.containsKey("bonjourService"))
					newFlags = OPT_BROWSE_BONJOUR;
				else
				{
					host = newOptions.getProperty("remoteHost");
					port = Integer.parseInt(newOptions.getProperty("remotePort", "0"));
					if (!change && (options & OPT_BROWSE_BONJOUR) == 0)
					{
						// Check if changing host or port
						change = (remoteHost == null || remoteHost.equalsIgnoreCase(host) || remotePort != port);
					}
				}
				if (newFlags != options || change)
				{
					if (DEBUG_LOGGER)
						Log.i("NSLogger", "Options changed, closing/restarting");

					if (bufferFile != null)
						closeBufferWriteStream();
					else
						disconnectFromRemote();
					options = newFlags;
					if ((newFlags & OPT_BROWSE_BONJOUR) == 0)
					{
						remoteHost = host;
						remotePort = port;
						connectToRemote();
					}
					else
						setupBonjour();
				}
			}
		}

		void processLogQueue()
		{
			if (logs.isEmpty())
				return;

			if (!clientInfoAdded)
				pushClientInfoToFrontOfQueue();

			if (writeStream == null)
			{
				if (bufferFile != null)
					createBufferWriteStream();
				else if (!(connecting || reconnectionScheduled || (options & OPT_BROWSE_BONJOUR) != 0) &&
						 remoteHost != null && remotePort != 0)
					connectToRemote();
				return;
			}

			if (remoteSocket == null)
			{
				flushQueueToBufferStream();
			}
			else if (!remoteSocket.isConnected())
			{
				disconnectFromRemote();
				tryReconnecting();
			}
			else if (connected)
			{
				int written = 0, remaining = socketSendBufferSize;
				try
				{
					if (incompleteSend != null)
					{
						int n = Math.min(remaining, incompleteSend.length - incompleteSendOffset);
						writeStream.write(incompleteSend, incompleteSendOffset, n);
						written += n;
						incompleteSendOffset += n;
						remaining -= n;
						if (incompleteSendOffset == incompleteSend.length)
						{
							incompleteSend = null;
							incompleteSendOffset = 0;
						}
					}
					if (DEBUG_LOGGER)
					{
						if (!logs.isEmpty())
							Log.v("NSLogger", String.format("processLogQueue: %d bytes available on socket, %d queued messages", remaining, logs.size()));
					}
					while (remaining > 0 && !logs.isEmpty())
					{
						LogMessage log = logs.get(0);
						byte[] msg = log.getBytes();
						int length = msg.length;
						if (length > socketSendBufferSize)
						{
							incompleteSend = msg;
							writeStream.write(msg, 0, socketSendBufferSize);
							incompleteSendOffset = socketSendBufferSize;
						}
						else
						{
							// TODO: take the socketSendBufferSize into account
							writeStream.write(msg);
						}
						log.markFlushed();
						logs.remove(0);
					}
				}
				catch (IOException e)
				{
					if (DEBUG_LOGGER)
						Log.d("NSLogger", "processLogQueue(): remote socket disconnected - exception: " + e.toString());
					disconnectFromRemote();
					tryReconnecting();
				}
			}
		}

		void connectToRemote()
		{
			// Connect to the remote logging host
			if (writeStream != null)
				throw new NullPointerException("internal error: writeStream should be null");
			if (remoteSocket != null)
				throw new NullPointerException("internal error: remoteSocket should be null");

			try
			{
				closeBonjour();

				if (DEBUG_LOGGER)
					Log.d("NSLogger", String.format("connecting to %s:%d", remoteHost, remotePort));

				remoteSocket = new Socket(remoteHost, remotePort);
				if ((options & OPT_USE_SSL) != 0)
				{
					if (DEBUG_LOGGER)
						Log.v("NSLogger", "activating SSL connection");

					SSLSocketFactory sf = SSLCertificateSocketFactory.getInsecure(5000, null);
					remoteSocket = sf.createSocket(remoteSocket, remoteHost, remotePort, true);
					if (remoteSocket != null)
					{
						if (DEBUG_LOGGER)
							Log.v("NSLogger", String.format("starting SSL handshake with %s:%d", remoteSocket.getInetAddress().toString(), remoteSocket.getPort()));

						SSLSocket socket = (SSLSocket) remoteSocket;
						socket.setUseClientMode(true);
						writeStream = remoteSocket.getOutputStream();
						socketSendBufferSize = remoteSocket.getSendBufferSize();
						loggingThreadHandler.sendMessage(loggingThreadHandler.obtainMessage(MSG_CONNECT_COMPLETE));
					}
				}
				else
				{
					// non-SSL sockets are immediately ready for use
					socketSendBufferSize = remoteSocket.getSendBufferSize();
					writeStream = remoteSocket.getOutputStream();
					loggingThreadHandler.sendMessage(loggingThreadHandler.obtainMessage(MSG_CONNECT_COMPLETE));
				}
			}
			catch (UnknownHostException e)
			{
				Log.e("NSLogger", String.format("can't connect to %s:%d (unknown host)", remoteHost, remotePort));
				disconnectFromRemote();
			}
			catch (Exception e)
			{
				Log.e("NSLogger", String.format("exception while trying to connect to %s:%d: %s", remoteHost, remotePort, e.toString()));
				disconnectFromRemote();
				tryReconnecting();
			}
		}

		void disconnectFromRemote()
		{
			connected = false;
			if (remoteSocket != null)
			{
				try
				{
					if (DEBUG_LOGGER)
						Log.d("NSLogger", "disconnectFromRemote()");

					if (writeStream != null)
						writeStream.close();
					remoteSocket.close();
				}
				catch (Exception e)
				{
					Log.e("NSLogger", "Exception caught in disconnectFromRemote: " + e.toString());
				}
				finally
				{
					writeStream = null;
					remoteSocket = null;
					socketSendBufferSize = 0;
					connecting = false;
					clientInfoAdded = false;
				}
			}
		}

		void tryReconnecting()
		{
			if (reconnectionScheduled)
				return;

			if (DEBUG_LOGGER)
				Log.d("NSLogger", "tryReconnecting");

			if ((options & OPT_BROWSE_BONJOUR) != 0)
			{
				// TODO: Bonjour
				/*
				if (bonjourBrowser == null)
					setupBonjour();
					*/
			}
			else
			{
				reconnectionScheduled = true;
				loggingThreadHandler.sendMessageDelayed(loggingThreadHandler.obtainMessage(MSG_TRY_CONNECT), 2000);
			}
		}


		void pushClientInfoToFrontOfQueue()
		{
			if (DEBUG_LOGGER)
				Log.v("NSLogger", "Pushing client info to front of queue");

			LogMessage lm = new LogMessage(LogMessage.LOGMSG_TYPE_CLIENTINFO, nextSequenceNumber.getAndIncrement());
			lm.addString(Build.MANUFACTURER + " " + Build.MODEL, LogMessage.PART_KEY_CLIENT_MODEL);
			lm.addString("Android", LogMessage.PART_KEY_OS_NAME);
			lm.addString(Build.VERSION.RELEASE, LogMessage.PART_KEY_OS_VERSION);
			lm.addString(Secure.getString(currentContext.getContentResolver(), Secure.ANDROID_ID), LogMessage.PART_KEY_UNIQUEID);
			ApplicationInfo ai = currentContext.getApplicationInfo();
			String appName = ai.packageName;
			if (appName == null)
			{
				appName = ai.processName;
				if (appName == null)
				{
					appName = ai.taskAffinity;
					if (appName == null)
						appName = ai.toString();
				}
			}
			lm.addString(appName, LogMessage.PART_KEY_CLIENT_NAME);
			logs.add(0, lm);
			clientInfoAdded = true;
		}

		void createBufferWriteStream()
		{
			// Create the write stream that writes to a log file,
			// and if needed flush the current logs to the log file
			if (bufferFile == null || bufferFile.isEmpty())
				return;

			try
			{
				if (DEBUG_LOGGER)
					Log.d("NSLogger", String.format("Creating file buffer stream to %s", bufferFile));

				writeStream = new BufferedOutputStream(new FileOutputStream(bufferFile, true));
				flushQueueToBufferStream();
			}
			catch (Exception e)
			{
				Log.e("NSLogger", "Exception caught while trying to create file stream: " + e.toString());
				bufferFile = null;
			}
		}

		void closeBufferWriteStream()
		{
			if (DEBUG_LOGGER)
				Log.d("NSLogger", "Closing file buffer stream");

			try
			{
				writeStream.flush();
				writeStream.close();
			}
			catch (Exception e)
			{
				Log.e("NSLogger", "Exception caught in closeBufferWriteStream: " + e.toString());
			}
			writeStream = null;
		}

		/**
		 * Write outstanding messages to the buffer file (streams don't detect disconnection
		 * until the next write, where we could lose one or more messages)
		 */
		void flushQueueToBufferStream()
		{
			if (DEBUG_LOGGER)
				Log.v("NSLogger", "flushQueueToBufferStream");

			incompleteSendOffset = 0;

			if (incompleteSend != null)
			{
				try
				{
					writeStream.write(incompleteSend,
									  incompleteSendOffset,
									  incompleteSend.length - incompleteSendOffset);
					incompleteSend = null;
					incompleteSendOffset = 0;
				}
				catch (IOException e)
				{
					Log.e("NSLogger", "Exception caught while trying to write to file stream: " + e.toString());
				}
			}
			try
			{
				while (!logs.isEmpty())
				{
					LogMessage log = logs.get(0);
					byte[] message = log.getBytes();
					if (message == null)
						break;
					writeStream.write(message);
					log.markFlushed();
					logs.remove(0);
				}
			}
			catch (IOException e)
			{
				Log.e("NSLogger", "Exception caught in flushQueueToBufferStream: " + e.toString());
			}
		}

		void setupBonjour()
		{
			if ((options & OPT_BROWSE_BONJOUR) != 0)
			{
				/*
				if (bonjourBrowser == null)
				{
					try
					{
						if (DEBUG_LOGGER)
							Log.d("NSLogger", "setupBonjour(): creating JmDNS instance");

						// acquire the wifi multicasting lock, so that the WiFi interface
						// starts processing multicast packets. This uses more battery,
						// but Bonjour can't work without it
						multicastLock.acquire();

						bonjourBrowser = JmDNS.create();
						bonjourBrowser.setDelegate(this);
						bonjourListeningType = bonjourServiceType;
						if (bonjourListeningType == null || bonjourListeningType.isEmpty())
							bonjourListeningType = ((options & OPT_USE_SSL) != 0) ? "_nslogger-ssl._tcp.local." : "_nslogger._tcp.local.";
						bonjourBrowser.addServiceListener(bonjourListeningType, this);
					}
					catch (Exception e)
					{
						Log.e("NSLogger", "Exception caught in setupBonjour(): " + e.toString());
						bonjourListeningType = null;
					}
				}
				*/
			}
			else
			{
				closeBonjour();
			}
		}

		void closeBonjour()
		{
			try
			{
				/*
				if (bonjourBrowser != null)
				{
					if (DEBUG_LOGGER)
						Log.d("NSLogger", "closeBonjour()");

					if (bonjourListeningType != null)
					{
						bonjourBrowser.removeServiceListener(bonjourListeningType, this);
						bonjourListeningType = null;
					}
					bonjourBrowser.unregisterAllServices();
					bonjourBrowser.setDelegate(null);
					bonjourBrowser = null;

					// release the wifi multicasting lock for this instance
					// when count drops to 0, wifi stops processing multicasting
					// packets so as to save battery
					multicastLock.release();
				}
				*/
			}
			catch (Exception e)
			{
				Log.e("NSLogger", "Exception caught in closeBonjour(): " + e.toString());
			}
		}
/*
		public void serviceAdded(ServiceEvent event)
		{
			if (DEBUG_LOGGER)
				Log.v("NSLogger", "Bonjour service found: " + event.getType() + " " + event.getName());

			bonjourBrowser.requestServiceInfo(event.getType(), event.getName(), false, 1);
		}

		public void serviceRemoved(ServiceEvent event)
		{
			if (DEBUG_LOGGER)
				Log.v("NSLogger", "Bonjour service removed: " + event.toString());
		}

		public void serviceResolved(ServiceEvent event)
		{
			if (DEBUG_LOGGER)
				Log.v("NSLogger", "Bonjour service resolved: " + event.toString());

			if (remoteSocket == null)
			{
				if (DEBUG_LOGGER)
					Log.v("NSLogger", "-> retrieving service info");

				ServiceInfo info = event.getInfo();
				InetAddress[] addrs = info.getInetAddresses();
				if (addrs.length > 0)
				{
					remoteHost = addrs[0].getHostAddress();
					remotePort = info.getPort();

					if (DEBUG_LOGGER)
						Log.v("NSLogger", String.format("-> will try to connect to Bonjour service %s:%d", remoteHost, remotePort));

					loggingThreadHandler.sendMessage(loggingThreadHandler.obtainMessage(MSG_TRY_CONNECT));
				}
			}
		}

		public void cannotRecoverFromIOError(JmDNS dns, Collection<ServiceInfo> infos)
		{
			if (DEBUG_LOGGER)
				Log.e("NSLogger", "JmDNS can't record from IOError: infos=" + infos.toString());
		}
		*/
	}
}
