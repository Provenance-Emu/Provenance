#include <jni.h>
#include <signal.h>
#include <string.h>
#include <stdio.h>
#include <stdarg.h>
#include <android/log.h>
#include <unistd.h>

#include <EGL/egl.h>
#include <GLES2/gl2.h>
#include <types.h>

#include "hw/maple/maple_cfg.h"
#include "profiler/profiler.h"
#include "rend/TexCache.h"
#include "hw/maple/maple_devs.h"
#include "hw/maple/maple_if.h"
#include "oslib/audiobackend_android.h"
#include "reios/reios.h"
#include "imgread/common.h"

extern "C"
{
JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_config(JNIEnv *env,jobject obj,jstring dirName)  __attribute__((visibility("default")));
JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_init(JNIEnv *env,jobject obj,jstring fileName)  __attribute__((visibility("default")));
JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_query(JNIEnv *env,jobject obj,jobject emu_thread)  __attribute__((visibility("default")));
JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_run(JNIEnv *env,jobject obj,jobject emu_thread)  __attribute__((visibility("default")));
JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_pause(JNIEnv *env,jobject obj)  __attribute__((visibility("default")));
JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_destroy(JNIEnv *env,jobject obj)  __attribute__((visibility("default")));

JNIEXPORT jint JNICALL Java_com_reicast_emulator_emu_JNIdc_send(JNIEnv *env,jobject obj,jint id, jint v)  __attribute__((visibility("default")));
JNIEXPORT jint JNICALL Java_com_reicast_emulator_emu_JNIdc_data(JNIEnv *env,jobject obj,jint id, jbyteArray d)  __attribute__((visibility("default")));

JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_rendinit(JNIEnv *env,jobject obj,jint w,jint h)  __attribute__((visibility("default")));
JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_rendframe(JNIEnv *env,jobject obj)  __attribute__((visibility("default")));

JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_kcode(JNIEnv * env, jobject obj, jintArray k_code, jintArray l_t, jintArray r_t, jintArray jx, jintArray jy)  __attribute__((visibility("default")));
JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_vjoy(JNIEnv * env, jobject obj,u32 id,float x, float y, float w, float h)  __attribute__((visibility("default")));
//JNIEXPORT jint JNICALL Java_com_reicast_emulator_emu_JNIdc_play(JNIEnv *env,jobject obj,jshortArray result,jint size);

JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_initControllers(JNIEnv *env, jobject obj, jbooleanArray controllers, jobjectArray peripherals)  __attribute__((visibility("default")));

JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_setupMic(JNIEnv *env,jobject obj,jobject sip)  __attribute__((visibility("default")));
JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_diskSwap(JNIEnv *env,jobject obj,jstring disk)  __attribute__((visibility("default")));
JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_vmuSwap(JNIEnv *env,jobject obj)  __attribute__((visibility("default")));
JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_setupVmu(JNIEnv *env,jobject obj,jobject sip)  __attribute__((visibility("default")));

JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_dynarec(JNIEnv *env,jobject obj, jint dynarec)  __attribute__((visibility("default")));
JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_idleskip(JNIEnv *env,jobject obj, jint idleskip)  __attribute__((visibility("default")));
JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_unstable(JNIEnv *env,jobject obj, jint unstable)  __attribute__((visibility("default")));
JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_safemode(JNIEnv *env,jobject obj, jint safemode)  __attribute__((visibility("default")));
JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_cable(JNIEnv *env,jobject obj, jint cable)  __attribute__((visibility("default")));
JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_region(JNIEnv *env,jobject obj, jint region)  __attribute__((visibility("default")));
JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_broadcast(JNIEnv *env,jobject obj, jint broadcast)  __attribute__((visibility("default")));
JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_limitfps(JNIEnv *env,jobject obj, jint limiter)  __attribute__((visibility("default")));
JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_nobatch(JNIEnv *env,jobject obj, jint nobatch)  __attribute__((visibility("default")));
JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_nosound(JNIEnv *env,jobject obj, jint noaudio)  __attribute__((visibility("default")));
JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_mipmaps(JNIEnv *env,jobject obj, jint mipmaps)  __attribute__((visibility("default")));
JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_widescreen(JNIEnv *env,jobject obj, jint stretch)  __attribute__((visibility("default")));
JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_subdivide(JNIEnv *env,jobject obj, jint subdivide)  __attribute__((visibility("default")));
JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_frameskip(JNIEnv *env,jobject obj, jint frames)  __attribute__((visibility("default")));
JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_pvrrender(JNIEnv *env,jobject obj, jint render)  __attribute__((visibility("default")));
JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_syncedrender(JNIEnv *env,jobject obj, jint sync)  __attribute__((visibility("default")));
JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_modvols(JNIEnv *env,jobject obj, jint volumes)  __attribute__((visibility("default")));
JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_bootdisk(JNIEnv *env,jobject obj, jstring disk)  __attribute__((visibility("default")));
JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_usereios(JNIEnv *env,jobject obj, jint reios)  __attribute__((visibility("default")));
JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_dreamtime(JNIEnv *env,jobject obj, jlong clock)  __attribute__((visibility("default")));
};

JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_dynarec(JNIEnv *env,jobject obj, jint dynarec)
{
    settings.dynarec.Enable = dynarec;
}

JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_idleskip(JNIEnv *env,jobject obj, jint idleskip)
{
    settings.dynarec.idleskip = idleskip;
}

JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_unstable(JNIEnv *env,jobject obj, jint unstable)
{
    settings.dynarec.unstable_opt = unstable;
}

JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_safemode(JNIEnv *env,jobject obj, jint safemode)
{
    settings.dynarec.safemode = safemode;
}

JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_cable(JNIEnv *env,jobject obj, jint cable)
{
    settings.dreamcast.cable = cable;
}

JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_region(JNIEnv *env,jobject obj, jint region)
{
    settings.dreamcast.region = region;
}

JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_broadcast(JNIEnv *env,jobject obj, jint broadcast)
{
    settings.dreamcast.broadcast = broadcast;
}

JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_limitfps(JNIEnv *env,jobject obj, jint limiter)
{
    settings.aica.LimitFPS = limiter;
}

JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_nobatch(JNIEnv *env,jobject obj, jint nobatch)
{
    settings.aica.NoBatch = nobatch;
}

JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_nosound(JNIEnv *env,jobject obj, jint noaudio)
{
    settings.aica.NoSound = noaudio;
}

JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_mipmaps(JNIEnv *env,jobject obj, jint mipmaps)
{
    settings.rend.UseMipmaps = mipmaps;
}

JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_widescreen(JNIEnv *env,jobject obj, jint stretch)
{
    settings.rend.WideScreen = stretch;
}

JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_subdivide(JNIEnv *env,jobject obj, jint subdivide)
{
    settings.pvr.subdivide_transp = subdivide;
}

JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_frameskip(JNIEnv *env,jobject obj, jint frames)
{
    settings.pvr.ta_skip = frames;
}

JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_pvrrender(JNIEnv *env,jobject obj, jint render)
{
    settings.pvr.rend = render;
}

JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_syncedrender(JNIEnv *env,jobject obj, jint sync)
{
    settings.pvr.SynchronousRender = sync;
}


JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_modvols(JNIEnv *env,jobject obj, jint volumes)
{
    settings.rend.ModifierVolumes = volumes;
}

JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_usereios(JNIEnv *env,jobject obj, jint reios)
{
    settings.bios.UseReios = reios;
}

JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_dreamtime(JNIEnv *env,jobject obj, jlong clock)
{
    settings.dreamcast.RTC = (u32)(clock);
}

void egl_stealcntx();
void SetApplicationPath(wchar *path);
void reios_init(int argc,wchar* argv[]);
int dc_init();
void dc_run();
void dc_pause();
void dc_term();
void mcfg_Create(MapleDeviceType type,u32 bus,u32 port);

bool VramLockedWrite(u8* address);

bool rend_single_frame();
bool gles_init();

//extern cResetEvent rs,re;
extern int screen_width,screen_height;

static u64 tvs_base;
static char gamedisk[256];

// Additonal controllers 2, 3 and 4 connected ?
static bool add_controllers[3] = { false, false, false };
int **controller_periphs;

u16 kcode[4];
u32 vks[4];
s8 joyx[4],joyy[4];
u8 rt[4],lt[4];
float vjoy_pos[14][8];

extern bool print_stats;



void os_DoEvents()
{
    // @@@ Nothing here yet
}

//
// Native thread that runs the actual nullDC emulator
//
static void *ThreadHandler(void *UserData)
{
    char *Args[3];
    const char *P;

    // Make up argument list
    P       = (const char *)UserData;
    Args[0] = (char*)"dc";
    Args[1] = (char*)"-config";
    Args[2] = P&&P[0]? (char *)malloc(strlen(P)+32):0;

    if(Args[2])
    {
        strcpy(Args[2],"config:image=");
        strcat(Args[2],P);
    }

    // Run nullDC emulator
    reios_init(Args[2]? 3:1,Args);
    return 0;
}

//
// Platform-specific NullDC functions
//


void UpdateInputState(u32 Port)
{
    // @@@ Nothing here yet
}

void UpdateVibration(u32 port, u32 value)
{

}

void *libPvr_GetRenderTarget()
{
    // No X11 window in Android
    return(0);
}

void *libPvr_GetRenderSurface()
{
    // No X11 display in Android
    return(0);
}

void common_linux_setup();

MapleDeviceType GetMapleDeviceType(int value)
{
    switch (value)
    {
        case 1:
            return MDT_SegaVMU;
        case 2:
            return MDT_Microphone;
        case 3:
            return MDT_PurupuruPack;
        default:
            return MDT_None;
    }
}

void os_SetupInput()
{
    // Create first controller
    mcfg_CreateController(0, MDT_SegaVMU, GetMapleDeviceType(controller_periphs[0][1]));

    // Add additonal controllers
    for (int i = 0; i < 3; i++)
    {
        if (add_controllers[i])
            mcfg_CreateController(i + 1,
                                  GetMapleDeviceType(controller_periphs[i + 1][0]),
                                  GetMapleDeviceType(controller_periphs[i + 1][1]));
    }
}

void os_SetWindowText(char const *Text)
{
    putinf("%s",Text);
}
JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_config(JNIEnv *env,jobject obj,jstring dirName)
{
    // Set home directory based on User config
    const char* D = dirName? env->GetStringUTFChars(dirName,0):0;
    set_user_config_dir(D);
    set_user_data_dir(D);
    printf("Config dir is: %s\n", get_writable_config_path("/").c_str());
    printf("Data dir is:   %s\n", get_writable_data_path("/").c_str());
    env->ReleaseStringUTFChars(dirName,D);
}

JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_bootdisk(JNIEnv *env,jobject obj, jstring disk) {
    if (disk != NULL) {
        settings.imgread.LoadDefaultImage = true;
        const char *P = env->GetStringUTFChars(disk, 0);
        if (!P) settings.imgread.DefaultImage[0] = '\0';
        else {
            printf("Boot Disk URI: '%s'\n", P);
            strncpy(settings.imgread.DefaultImage,(strlen(P)>=7)&&!memcmp(
                    P,"file://",7)? P+7:P,sizeof(settings.imgread.DefaultImage));
            settings.imgread.DefaultImage[sizeof(settings.imgread.DefaultImage) - 1] = '\0';
        }
    }
}

JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_init(JNIEnv *env,jobject obj,jstring fileName)
{
    // Get filename string from Java
    const char* P = fileName ? env->GetStringUTFChars(fileName,0) : 0;
    if (!P) gamedisk[0] = '\0';
    else
    {
        printf("Game Disk URI: '%s'\n",P);
        strncpy(gamedisk,(strlen(P)>=7)&&!memcmp(P,"file://",7)? P+7:P,sizeof(gamedisk));
        gamedisk[sizeof(gamedisk)-1] = '\0';
        env->ReleaseStringUTFChars(fileName,P);
    }

    // Initialize platform-specific stuff
    common_linux_setup();

    // Set configuration
    settings.profile.run_counts = 0;


/*
  // Start native thread
  pthread_attr_init(&PTAttr);
  pthread_attr_setdetachstate(&PTAttr,PTHREAD_CREATE_DETACHED);
  pthread_create(&PThread,&PTAttr,ThreadHandler,CurFileName);
  pthread_attr_destroy(&PTAttr);
  */

    ThreadHandler(gamedisk);
}

JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_diskSwap(JNIEnv *env,jobject obj,jstring disk)
{
    if (settings.imgread.LoadDefaultImage) {
        strncpy(settings.imgread.DefaultImage, gamedisk, sizeof(settings.imgread.DefaultImage));
        settings.imgread.DefaultImage[sizeof(settings.imgread.DefaultImage) - 1] = '\0';
        DiscSwap();
    } else if (disk != NULL) {
        settings.imgread.LoadDefaultImage = true;
        const char *P = env->GetStringUTFChars(disk, 0);
        if (!P) settings.imgread.DefaultImage[0] = '\0';
        else {
            printf("Swap Disk URI: '%s'\n", P);
            strncpy(settings.imgread.DefaultImage,(strlen(P)>=7)&&!memcmp(
                    P,"file://",7)? P+7:P,sizeof(settings.imgread.DefaultImage));
            settings.imgread.DefaultImage[sizeof(settings.imgread.DefaultImage) - 1] = '\0';
            env->ReleaseStringUTFChars(disk, P);
        }
        DiscSwap();
    }
}

#define SAMPLE_COUNT 512

JNIEnv* jenv; //we are abusing the f*** out of this poor guy
//JavaVM* javaVM = NULL; //this seems like the right way to go
//stuff for audio
jshortArray jsamples;
jmethodID writemid;
jmethodID coreMessageMid;
jmethodID dieMid;
jobject emu;
//stuff for microphone
jobject sipemu;
jmethodID getmicdata;
//stuff for vmu lcd
jobject vmulcd = NULL;
jbyteArray jpix = NULL;
jmethodID updatevmuscreen;

JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_query(JNIEnv *env,jobject obj,jobject emu_thread)
{
    jmethodID reiosInfoMid=env->GetMethodID(env->GetObjectClass(emu_thread),"reiosInfo","(Ljava/lang/String;Ljava/lang/String;)V");

    char *id = (char*)malloc(11);
    // Verify that there is an ID assigned
    if ((id != NULL) && (id[0] == '\0')) {
        strcpy(id, reios_disk_id());
        jstring reios_id = env->NewStringUTF(id);
        char *name = (char *) malloc(129);
        strcpy(name, reios_software_name);
        jstring reios_name = env->NewStringUTF(name);

        env->CallVoidMethod(emu_thread, reiosInfoMid, reios_id, reios_name);
    }

    dc_init();
}

JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_run(JNIEnv *env,jobject obj,jobject emu_thread)
{
    install_prof_handler(0);

    jenv=env;
    emu=emu_thread;

    jsamples=env->NewShortArray(SAMPLE_COUNT*2);
    writemid=env->GetMethodID(env->GetObjectClass(emu),"WriteBuffer","([SI)I");
    coreMessageMid=env->GetMethodID(env->GetObjectClass(emu),"coreMessage","([B)I");
    dieMid=env->GetMethodID(env->GetObjectClass(emu),"Die","()V");

    dc_run();
}

int msgboxf(const wchar* text,unsigned int type,...) {
    va_list args;

    wchar temp[2048];
    va_start(args, type);
    vsprintf(temp, text, args);
    va_end(args);

    int byteCount = strlen(temp);
    jbyteArray bytes = jenv->NewByteArray(byteCount);
    jenv->SetByteArrayRegion(bytes, 0, byteCount, (jbyte *) temp);

    return jenv->CallIntMethod(emu, coreMessageMid, bytes);
}

JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_setupMic(JNIEnv *env,jobject obj,jobject sip)
{
    sipemu = env->NewGlobalRef(sip);
    getmicdata = env->GetMethodID(env->GetObjectClass(sipemu),"getData","()[B");
}

JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_setupVmu(JNIEnv *env,jobject obj,jobject vmu)
{
    //env->GetJavaVM(&javaVM);
    vmulcd = env->NewGlobalRef(vmu);
    updatevmuscreen = env->GetMethodID(env->GetObjectClass(vmu),"updateBytes","([B)V");
    //jpix=env->NewByteArray(1536);
}

JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_pause(JNIEnv *env,jobject obj)
{
    dc_pause();
}

JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_destroy(JNIEnv *env,jobject obj)
{
    dc_term();
}

JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_vmuSwap(JNIEnv *env,jobject obj)
{
    maple_device* olda = MapleDevices[0][0];
    maple_device* oldb = MapleDevices[0][1];
    MapleDevices[0][0] = NULL;
    MapleDevices[0][1] = NULL;
    usleep(50000);//50 ms, wait for host to detect disconnect

    MapleDevices[0][0] = oldb;
    MapleDevices[0][1] = olda;
}

JNIEXPORT jint JNICALL Java_com_reicast_emulator_emu_JNIdc_send(JNIEnv *env,jobject obj,jint cmd, jint param)
{
    if (cmd==0)
    {
        if (param==0)
        {
            KillTex=true;
            printf("Killing texture cache\n");
        }

        if (param==1)
        {
            settings.pvr.ta_skip^=1;
            printf("settings.pvr.ta_skip: %d\n",settings.pvr.ta_skip);
        }
        if (param==2)
        {
#if FEAT_SHREC != DYNAREC_NONE
            print_stats=true;
            printf("Storing blocks ...\n");
#endif
        }
    }
    else if (cmd==1)
    {
        if (param==0)
            sample_Stop();
        else
            sample_Start(param);
    }
    else if (cmd==2)
    {
    }
}

JNIEXPORT jint JNICALL Java_com_reicast_emulator_emu_JNIdc_data(JNIEnv *env, jobject obj, jint id, jbyteArray d)
{
    if (id==1)
    {
        printf("Loading symtable (%p,%p,%d,%p)\n",env,obj,id,d);
        jsize len=env->GetArrayLength(d);
        u8* syms=(u8*)malloc((size_t)len);
        printf("Loading symtable to %8s, %d\n",syms,len);
        env->GetByteArrayRegion(d,0,len,(jbyte*)syms);
        sample_Syms(syms, (size_t)len);
    }
}


JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_rendframe(JNIEnv *env,jobject obj)
{
    while(!rend_single_frame()) ;
}

JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_kcode(JNIEnv * env, jobject obj, jintArray k_code, jintArray l_t, jintArray r_t, jintArray jx, jintArray jy)
{
    jint *k_code_body = env->GetIntArrayElements(k_code, 0);
    jint *l_t_body = env->GetIntArrayElements(l_t, 0);
    jint *r_t_body = env->GetIntArrayElements(r_t, 0);
    jint *jx_body = env->GetIntArrayElements(jx, 0);
    jint *jy_body = env->GetIntArrayElements(jy, 0);

    for(int i = 0; i < 4; i++)
    {
        kcode[i] = k_code_body[i];
        lt[i] = l_t_body[i];
        rt[i] = r_t_body[i];
        joyx[i] = jx_body[i];
        joyy[i] = jy_body[i];
    }

    env->ReleaseIntArrayElements(k_code, k_code_body, 0);
    env->ReleaseIntArrayElements(l_t, l_t_body, 0);
    env->ReleaseIntArrayElements(r_t, r_t_body, 0);
    env->ReleaseIntArrayElements(jx, jx_body, 0);
    env->ReleaseIntArrayElements(jy, jy_body, 0);
}

JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_rendinit(JNIEnv * env, jobject obj, jint w,jint h)
{
    screen_width  = w;
    screen_height = h;

    //gles_term();

    egl_stealcntx();

    if (!gles_init())
    die("OPENGL FAILED");

    install_prof_handler(1);
}

JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_vjoy(JNIEnv * env, jobject obj,u32 id,float x, float y, float w, float h)
{
    if(id<sizeof(vjoy_pos)/sizeof(vjoy_pos[0]))
    {
        vjoy_pos[id][0] = x;
        vjoy_pos[id][1] = y;
        vjoy_pos[id][2] = w;
        vjoy_pos[id][3] = h;
    }
}

JNIEXPORT void JNICALL Java_com_reicast_emulator_emu_JNIdc_initControllers(JNIEnv *env, jobject obj, jbooleanArray controllers, jobjectArray peripherals)
{
    jboolean *controllers_body = env->GetBooleanArrayElements(controllers, 0);
    memcpy(add_controllers, controllers_body, 3);
    env->ReleaseBooleanArrayElements(controllers, controllers_body, 0);

    int obj_len = env->GetArrayLength(peripherals);
    jintArray port = (jintArray) env->GetObjectArrayElement(peripherals, 0);
    int port_len = env->GetArrayLength(port);
    controller_periphs = new int*[obj_len];
    for (int i = 0; i < obj_len; ++i) {
        port = (jintArray) env->GetObjectArrayElement(peripherals, i);
        jint *items = env->GetIntArrayElements(port, 0);
        controller_periphs[i] = new int[port_len];
        for (int j = 0; j < port_len; ++j) {
            controller_periphs[i][j]= items[j];
        }
    }
    for (int i = 0; i < obj_len; i++) {
        jintArray port = (jintArray) env->GetObjectArrayElement(peripherals, i);
        jint *items = env->GetIntArrayElements(port, 0);
        env->ReleaseIntArrayElements(port, items, 0);
        env->DeleteLocalRef(port);
    }
}

// Audio Stuff
u32 androidaudio_push(void* frame, u32 amt, bool wait)
{
    verify(amt==SAMPLE_COUNT);
    //yeah, do some audio piping magic here !
    jenv->SetShortArrayRegion(jsamples,0,amt*2,(jshort*)frame);
    return jenv->CallIntMethod(emu,writemid,jsamples,wait);
}

void androidaudio_init()
{
    // Nothing to do here...
}

void androidaudio_term()
{
    // Move along, there is nothing to see here!
}

bool os_IsAudioBuffered()
{
    return jenv->CallIntMethod(emu,writemid,jsamples,-1)==0;
}

audiobackend_t audiobackend_android = {
        "android", // Slug
        "Android Audio", // Name
        &androidaudio_init,
        &androidaudio_push,
        &androidaudio_term
};

int get_mic_data(u8* buffer)
{
    jbyteArray jdata = (jbyteArray)jenv->CallObjectMethod(sipemu,getmicdata);
    if(jdata==NULL){
        //LOGW("get_mic_data NULL");
        return 0;
    }
    jenv->GetByteArrayRegion(jdata, 0, SIZE_OF_MIC_DATA, (jbyte*)buffer);
    jenv->DeleteLocalRef(jdata);
    return 1;
}

int push_vmu_screen(u8* buffer)
{
    if(vmulcd==NULL){
        return 0;
    }
    JNIEnv *env = jenv;
    //javaVM->AttachCurrentThread(&env, NULL);
    if(jpix==NULL){
        jpix=env->NewByteArray(1536);
    }
    env->SetByteArrayRegion(jpix,0,1536,(jbyte*)buffer);
    env->CallVoidMethod(vmulcd,updatevmuscreen,jpix);
    return 1;
}

void os_DebugBreak()
{
    // TODO: notify the parent thread about it ...

    // Attach debugger here to figure out what went wrong
    for(;;) ;
}
