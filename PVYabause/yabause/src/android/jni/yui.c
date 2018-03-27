/*  Copyright 2011 Guillaume Duhamel

    This file is part of Yabause.

    Yabause is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    Yabause is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Yabause; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
*/

#include <jni.h>
#include <android/bitmap.h>
#include <android/log.h>

#include "../../config.h"
#include "yabause.h"
#include "scsp.h"
#include "vidsoft.h"
#include "peripheral.h"
#include "m68kcore.h"
#include "sh2core.h"
#include "sh2int.h"
#include "cdbase.h"
#include "cs2.h"
#include "debug.h"
#include "osdcore.h"
#include "gameinfo.h"

#include <stdio.h>
#include <dlfcn.h>

#define _ANDROID_2_2_
#ifdef _ANDROID_2_2_
#include "miniegl.h"
#else
#include <EGL/egl.h>
#endif

#include <GLES/gl.h>
#include <GLES/glext.h>
#include <pthread.h>

#include "sndaudiotrack.h"
#ifdef HAVE_OPENSL
#include "sndopensl.h"
#endif

JavaVM * yvm;
static jobject yabause;

static char mpegpath[256] = "\0";
static char cartpath[256] = "\0";

EGLDisplay g_Display = EGL_NO_DISPLAY;
EGLSurface g_Surface = EGL_NO_SURFACE;
EGLContext g_Context = EGL_NO_CONTEXT;
GLuint g_FrameBuffer = 0;
GLuint g_VertexBuffer = 0;
int g_buf_width = -1;
int g_buf_height = -1;
pthread_mutex_t g_mtxGlLock = PTHREAD_MUTEX_INITIALIZER;
float vertices [] = {
   0, 0, 0, 0,
   320, 0, 0, 0,
   320, 224, 0, 0,
   0, 224, 0, 0
};


M68K_struct * M68KCoreList[] = {
&M68KDummy,
#ifdef HAVE_C68K
&M68KC68K,
#endif
#ifdef HAVE_Q68
&M68KQ68,
#endif
NULL
};

SH2Interface_struct *SH2CoreList[] = {
&SH2Interpreter,
&SH2DebugInterpreter,
#ifdef SH2_DYNAREC
&SH2Dynarec,
#endif
NULL
};

PerInterface_struct *PERCoreList[] = {
&PERDummy,
NULL
};

CDInterface *CDCoreList[] = {
&DummyCD,
&ISOCD,
NULL
};

SoundInterface_struct *SNDCoreList[] = {
&SNDDummy,
&SNDAudioTrack,
#ifdef HAVE_OPENSL
&SNDOpenSL,
#endif
NULL
};

VideoInterface_struct *VIDCoreList[] = {
&VIDDummy,
&VIDSoft,
NULL
};


#define  LOG_TAG    "yabause"

/* Override printf for debug*/
int yprintf( const char * fmt, ... )
{
   va_list ap;
   va_start(ap, fmt);
   int result = __android_log_vprint(ANDROID_LOG_INFO, LOG_TAG, fmt, ap);
   va_end(ap);
   return result;
}

const char * GetBiosPath()
{
    jclass yclass;
    jmethodID getBiosPath;
    jstring message;
    jboolean dummy;
    JNIEnv * env;
    if ((*yvm)->GetEnv(yvm, (void**) &env, JNI_VERSION_1_6) != JNI_OK)
        return NULL;

    yclass = (*env)->GetObjectClass(env, yabause);
    getBiosPath = (*env)->GetMethodID(env, yclass, "getBiosPath", "()Ljava/lang/String;");
    message = (*env)->CallObjectMethod(env, yabause, getBiosPath);
    if ((*env)->GetStringLength(env, message) == 0)
        return NULL;
    else
        return (*env)->GetStringUTFChars(env, message, &dummy);
}

const char * GetGamePath()
{
    jclass yclass;
    jmethodID getGamePath;
    jstring message;
    jboolean dummy;
    JNIEnv * env;
    if ((*yvm)->GetEnv(yvm, (void**) &env, JNI_VERSION_1_6) != JNI_OK)
        return NULL;

    yclass = (*env)->GetObjectClass(env, yabause);
    getGamePath = (*env)->GetMethodID(env, yclass, "getGamePath", "()Ljava/lang/String;");
    message = (*env)->CallObjectMethod(env, yabause, getGamePath);
    if ((*env)->GetStringLength(env, message) == 0)
        return NULL;
    else
        return (*env)->GetStringUTFChars(env, message, &dummy);
}

const char * GetMemoryPath()
{
    jclass yclass;
    jmethodID getMemoryPath;
    jstring message;
    jboolean dummy;
    JNIEnv * env;
    if ((*yvm)->GetEnv(yvm, (void**) &env, JNI_VERSION_1_6) != JNI_OK)
        return NULL;

    yclass = (*env)->GetObjectClass(env, yabause);
    getMemoryPath = (*env)->GetMethodID(env, yclass, "getMemoryPath", "()Ljava/lang/String;");
    message = (*env)->CallObjectMethod(env, yabause, getMemoryPath);
    if ((*env)->GetStringLength(env, message) == 0)
        return NULL;
    else
        return (*env)->GetStringUTFChars(env, message, &dummy);
}

int GetCartridgeType()
{
    jclass yclass;
    jmethodID getCartridgeType;
    JNIEnv * env;
    if ((*yvm)->GetEnv(yvm, (void**) &env, JNI_VERSION_1_6) != JNI_OK)
        return -1;

    yclass = (*env)->GetObjectClass(env, yabause);
    getCartridgeType = (*env)->GetMethodID(env, yclass, "getCartridgeType", "()I");
    return (*env)->CallIntMethod(env, yabause, getCartridgeType);
}

const char * GetCartridgePath()
{
    jclass yclass;
    jmethodID getCartridgePath;
    jstring message;
    jboolean dummy;
    JNIEnv * env;
    if ((*yvm)->GetEnv(yvm, (void**) &env, JNI_VERSION_1_6) != JNI_OK)
        return NULL;

    yclass = (*env)->GetObjectClass(env, yabause);
    getCartridgePath = (*env)->GetMethodID(env, yclass, "getCartridgePath", "()Ljava/lang/String;");
    message = (*env)->CallObjectMethod(env, yabause, getCartridgePath);
    if ((*env)->GetStringLength(env, message) == 0)
        return NULL;
    else
        return (*env)->GetStringUTFChars(env, message, &dummy);
}

void YuiErrorMsg(const char *string)
{
    jclass yclass;
    jmethodID errorMsg;
    jstring message;
    JNIEnv * env;
    if ((*yvm)->GetEnv(yvm, (void**) &env, JNI_VERSION_1_6) != JNI_OK)
        return;

    yclass = (*env)->GetObjectClass(env, yabause);
    errorMsg = (*env)->GetMethodID(env, yclass, "errorMsg", "(Ljava/lang/String;)V");
    message = (*env)->NewStringUTF(env, string);
    (*env)->CallVoidMethod(env, yabause, errorMsg, message);
}

void YuiSwapBuffers(void)
{
   int buf_width, buf_height;
   int error;


   pthread_mutex_lock(&g_mtxGlLock);
   if( g_Display == EGL_NO_DISPLAY )
   {
      pthread_mutex_unlock(&g_mtxGlLock);
      return;
   }

   if( eglMakeCurrent(g_Display,g_Surface,g_Surface,g_Context) == EGL_FALSE )
   {
         yprintf( "eglMakeCurrent fail %04x",eglGetError());
         pthread_mutex_unlock(&g_mtxGlLock);
         return;
   }

   {
      int swidth, sheight;

      eglQuerySurface(g_Display, g_Surface, EGL_WIDTH, &swidth);
      eglQuerySurface(g_Display, g_Surface, EGL_HEIGHT, &sheight);

      glViewport(0,0,swidth,sheight);
   }

   glClearColor( 0.0f,0.0f,0.0f,1.0f);
   glClear(GL_COLOR_BUFFER_BIT);


   if( g_FrameBuffer == 0 )
   {
      glEnable(GL_TEXTURE_2D);
      glGenTextures(1,&g_FrameBuffer);
      glBindTexture(GL_TEXTURE_2D, g_FrameBuffer);
      glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 1024, 1024, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
      glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST );
      glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST );
      glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
      error = glGetError();
      if( error != GL_NO_ERROR )
      {
         yprintf("gl error %d", error );
         return;
      }
   }else{
      glBindTexture(GL_TEXTURE_2D, g_FrameBuffer);
   }


   VIDCore->GetGlSize(&buf_width, &buf_height);
   glTexSubImage2D(GL_TEXTURE_2D, 0,0,0,buf_width,buf_height,GL_RGBA,GL_UNSIGNED_BYTE,dispbuffer);


   if( g_VertexBuffer == 0 )
   {
      glGenBuffers(1, &g_VertexBuffer);
      glBindBuffer(GL_ARRAY_BUFFER, g_VertexBuffer);
      glBufferData(GL_ARRAY_BUFFER, sizeof(vertices),vertices,GL_STATIC_DRAW);
      error = glGetError();
      if( error != GL_NO_ERROR )
      {
         yprintf("gl error %d", error );
         return;
      }
   }else{
      glBindBuffer(GL_ARRAY_BUFFER, g_VertexBuffer);
   }

  if( buf_width != g_buf_width ||  buf_height != g_buf_height )
  {
     vertices[6]=vertices[10]=(float)buf_width/1024.f;
     vertices[11]=vertices[15]=(float)buf_height/1024.f;
     glBufferData(GL_ARRAY_BUFFER, sizeof(vertices),vertices,GL_STATIC_DRAW);
     glVertexPointer(2, GL_FLOAT, sizeof(float)*4, 0);
     glTexCoordPointer(2, GL_FLOAT, sizeof(float)*4, (void*)(sizeof(float)*2));
     glEnableClientState(GL_VERTEX_ARRAY);
     glEnableClientState(GL_TEXTURE_COORD_ARRAY);
     g_buf_width  = buf_width;
     g_buf_height = buf_height;
  }

   glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
   eglSwapBuffers(g_Display,g_Surface);

   pthread_mutex_unlock(&g_mtxGlLock);
}

int Java_org_yabause_android_YabauseRunnable_initViewport()
{
   int error;
   char * buf;

   g_Display = eglGetCurrentDisplay();
   g_Surface = eglGetCurrentSurface(EGL_READ);
   g_Context = eglGetCurrentContext();

   glMatrixMode(GL_PROJECTION);
   glLoadIdentity();
   glOrthof(0, 320, 224, 0, 1, 0);

   glMatrixMode(GL_MODELVIEW);
   glLoadIdentity();

   glMatrixMode(GL_TEXTURE);
   glLoadIdentity();

   glDisable(GL_BLEND);
   glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

   yprintf(glGetString(GL_VENDOR));
   yprintf(glGetString(GL_RENDERER));
   yprintf(glGetString(GL_VERSION));
   yprintf(glGetString(GL_EXTENSIONS));
   yprintf(eglQueryString(g_Display,EGL_EXTENSIONS));
   eglSwapInterval(g_Display,0);
   eglMakeCurrent(g_Display,EGL_NO_SURFACE,EGL_NO_SURFACE,EGL_NO_CONTEXT);
   return 0;
}

int Java_org_yabause_android_YabauseRunnable_cleanup()
{
    g_FrameBuffer = 0;
    g_VertexBuffer = 0;
    g_buf_width = -1;
    g_buf_height = -1;
}

#ifdef _ANDROID_2_2_
int initEGLFunc()
{
   void * handle;
   char *error;

   handle = dlopen("libEGL.so",RTLD_LAZY);
   if( handle == NULL )
   {
      yprintf(dlerror());
      return -1;
   }

   eglGetCurrentDisplay = dlsym(handle, "eglGetCurrentDisplay");
   if( eglGetCurrentDisplay == NULL){ yprintf(dlerror()); return -1; }

   eglGetCurrentSurface = dlsym(handle, "eglGetCurrentSurface");
   if( eglGetCurrentSurface == NULL){ yprintf(dlerror()); return -1; }

   eglGetCurrentContext = dlsym(handle, "eglGetCurrentContext");
   if( eglGetCurrentContext == NULL){ yprintf(dlerror()); return -1; }

   eglQuerySurface      = dlsym(handle, "eglQuerySurface");
   if( eglQuerySurface == NULL){ yprintf(dlerror()); return -1; }

   eglSwapInterval      = dlsym(handle, "eglSwapInterval");
   if( eglSwapInterval == NULL){ yprintf(dlerror()); return -1; }

   eglMakeCurrent       = dlsym(handle, "eglMakeCurrent");
   if( eglMakeCurrent == NULL){ yprintf(dlerror()); return -1; }

   eglSwapBuffers       = dlsym(handle, "eglSwapBuffers");
   if( eglSwapBuffers == NULL){ yprintf(dlerror()); return -1; }

   eglQueryString       = dlsym(handle, "eglQueryString");
   if( eglQueryString == NULL){ yprintf(dlerror()); return -1; }

   eglGetError          = dlsym(handle, "eglGetError");
   if( eglGetError == NULL){ yprintf(dlerror()); return -1; }

   return 0;
}
#else
int initEGLFunc()
{
   return 0;
}
#endif

int Java_org_yabause_android_YabauseRunnable_lockGL()
{
   pthread_mutex_lock(&g_mtxGlLock);
}

int Java_org_yabause_android_YabauseRunnable_unlockGL()
{
   pthread_mutex_unlock(&g_mtxGlLock);
}


jint
Java_org_yabause_android_YabauseRunnable_init( JNIEnv* env, jobject obj, jobject yab )
{
    yabauseinit_struct yinit;
    int res;
    void * padbits;

    if( initEGLFunc() == -1 ) return -1;

    yabause = (*env)->NewGlobalRef(env, yab);

    memset(&yinit, 0, sizeof(yabauseinit_struct));

    yinit.m68kcoretype = M68KCORE_C68K;
    yinit.percoretype = PERCORE_DUMMY;
#ifdef SH2_DYNAREC
    yinit.sh2coretype = 2;
#else
    yinit.sh2coretype = SH2CORE_DEFAULT;
#endif
    yinit.vidcoretype = VIDCORE_SOFT;
#ifdef HAVE_OPENSL
    yinit.sndcoretype = SNDCORE_OPENSL;
#else
    yinit.sndcoretype = SNDCORE_AUDIOTRACK;
#endif
    yinit.cdcoretype = CDCORE_ISO;
    yinit.carttype = GetCartridgeType();
    yinit.regionid = 0;
    yinit.biospath = GetBiosPath();
    yinit.cdpath = GetGamePath();
    yinit.buppath = GetMemoryPath();
    yinit.mpegpath = mpegpath;
    yinit.cartpath = GetCartridgePath();
    yinit.videoformattype = VIDEOFORMATTYPE_NTSC;
    yinit.frameskip = 0;
    yinit.skip_load = 0;

    res = YabauseInit(&yinit);

    OSDChangeCore(OSDCORE_SOFT);

    PerPortReset();
    padbits = PerPadAdd(&PORTDATA1);
    PerSetKey(PERPAD_UP, PERPAD_UP, padbits);
    PerSetKey(PERPAD_RIGHT, PERPAD_RIGHT, padbits);
    PerSetKey(PERPAD_DOWN, PERPAD_DOWN, padbits);
    PerSetKey(PERPAD_LEFT, PERPAD_LEFT, padbits);
    PerSetKey(PERPAD_START, PERPAD_START, padbits);
    PerSetKey(PERPAD_A, PERPAD_A, padbits);
    PerSetKey(PERPAD_B, PERPAD_B, padbits);
    PerSetKey(PERPAD_C, PERPAD_C, padbits);
    PerSetKey(PERPAD_X, PERPAD_X, padbits);
    PerSetKey(PERPAD_Y, PERPAD_Y, padbits);
    PerSetKey(PERPAD_Z, PERPAD_Z, padbits);

    ScspSetFrameAccurate(1);

    return res;
}

void
Java_org_yabause_android_YabauseRunnable_deinit( JNIEnv* env )
{
    YabauseDeInit();
}

void
Java_org_yabause_android_YabauseRunnable_exec( JNIEnv* env )
{
    YabauseExec();
}

void
Java_org_yabause_android_YabauseRunnable_press( JNIEnv* env, jobject obj, jint key )
{
    PerKeyDown(key);
}

void
Java_org_yabause_android_YabauseRunnable_release( JNIEnv* env, jobject obj, jint key )
{
    PerKeyUp(key);
}

void
Java_org_yabause_android_YabauseRunnable_enableFPS( JNIEnv* env, jobject obj, jint enable )
{
    SetOSDToggle(enable);
}

void
Java_org_yabause_android_YabauseRunnable_enableFrameskip( JNIEnv* env, jobject obj, jint enable )
{
    if (enable)
        EnableAutoFrameSkip();
    else
        DisableAutoFrameSkip();
}

void
Java_org_yabause_android_YabauseRunnable_setVolume( JNIEnv* env, jobject obj, jint volume )
{
    if (0 == volume)
       ScspMuteAudio(SCSP_MUTE_USER);
    else {
       ScspUnMuteAudio(SCSP_MUTE_USER);
       ScspSetVolume(volume);
    }
}

void
Java_org_yabause_android_YabauseRunnable_screenshot( JNIEnv* env, jobject obj, jobject bitmap )
{
    u32 * buffer;
    AndroidBitmapInfo info;
    void * pixels;
    int x, y;

    AndroidBitmap_getInfo(env, bitmap, &info);

    AndroidBitmap_lockPixels(env, bitmap, &pixels);

    buffer = dispbuffer;

    for(y = 0;y < info.height;y++) {
        for(x = 0;x < info.width;x++) {
            *((uint32_t *) pixels + x) = *(buffer + x);
        }
        pixels += info.stride;
        buffer += g_buf_width;
    }

    AndroidBitmap_unlockPixels(env, bitmap);
}

jobject Java_org_yabause_android_YabauseRunnable_gameInfo( JNIEnv* env, jobject obj, jobject path )
{
    jmethodID cons;
    jboolean dummy;
    jclass c;
    jstring system, company, itemnum, version, date, cdinfo, region, peripheral, gamename;
    GameInfo info;
    const char * filename = (*env)->GetStringUTFChars(env, path, &dummy);

    if (! GameInfoFromPath(filename, &info))
    {
       return NULL;
    }

    c = (*env)->FindClass(env, "org/yabause/android/GameInfo");
    cons = (*env)->GetMethodID(env, c, "<init>", "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)V");

    system = (*env)->NewStringUTF(env, info.system);
    company = (*env)->NewStringUTF(env, info.company);
    itemnum = (*env)->NewStringUTF(env, info.itemnum);
    version = (*env)->NewStringUTF(env, info.version);
    date = (*env)->NewStringUTF(env, info.date);
    cdinfo = (*env)->NewStringUTF(env, info.cdinfo);
    region = (*env)->NewStringUTF(env, info.region);
    peripheral = (*env)->NewStringUTF(env, info.peripheral);
    gamename = (*env)->NewStringUTF(env, info.gamename);

    return (*env)->NewObject(env, c, cons, system, company, itemnum, version, date, cdinfo, region, peripheral, gamename);
}

void log_callback(char * message)
{
    __android_log_print(ANDROID_LOG_INFO, "yabause", "%s", message);
}

jint JNI_OnLoad(JavaVM * vm, void * reserved)
{
    JNIEnv * env;
    if ((*vm)->GetEnv(vm, (void**) &env, JNI_VERSION_1_6) != JNI_OK)
        return -1;

    yvm = vm;

    LogStart();
    LogChangeOutput(DEBUG_CALLBACK, (char *) log_callback);

    return JNI_VERSION_1_6;
}

