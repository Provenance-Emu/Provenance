package com.reicast.emulator.emu;


public final class JNIdc
{
	static { System.loadLibrary("dc"); }

	public static native void config(String dirName);
	public static native void init(String fileName);
	public static native void query(Object thread);
	public static native void run(Object track);
	public static native void pause();
	public static native void destroy();

	public static native int send(int cmd, int opt);
	public static native int data(int cmd, byte[] data);

	public static native void rendinit(int w, int y);
	public static native void rendframe();

	public static native void kcode(int[] kcode, int[] lt, int[] rt, int[] jx, int[] jy);

	public static native void vjoy(int id,float x, float y, float w, float h);
	//public static native int play(short result[],int size);

	public static native void initControllers(boolean[] controllers, int[][] peripherals);

	public static native void setupMic(Object sip);
	public static native void diskSwap(String disk);
	public static native void vmuSwap();
	public static native void setupVmu(Object sip);
	public static native void dynarec(int dynarec);
	public static native void idleskip(int idleskip);
	public static native void unstable(int unstable);
	public static native void safemode(int safemode);
	public static native void cable(int cable);
	public static native void region(int region);
	public static native void broadcast(int broadcast);
	public static native void limitfps(int limiter);
	public static native void nobatch(int nobatch);
	public static native void nosound(int noaudio);
	public static native void mipmaps(int mipmaps);
	public static native void widescreen(int stretch);
	public static native void subdivide(int subdivide);
	public static native void frameskip(int frames);
	public static native void pvrrender(int render);
	public static native void syncedrender(int sync);
	public static native void modvols(int volumes);
	public static native void bootdisk(String disk);
	public static native void usereios(int reios);
	public static native void dreamtime(long clock);

	public static void show_osd() {
		JNIdc.vjoy(13, 1,0,0,0);
	}

	public static void hide_osd() {
		JNIdc.vjoy(13, 0,0,0,0);
	}
}
