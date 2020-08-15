#define THREAD_SAFETY

#include <cmath>
#include <string>
#include <vector>
#include <deque>
#include <list>
#include <map>

#include <unistd.h>   // mknod, unlink, write
#include <stdio.h>
#include <sys/stat.h> // S_IFIFO
#include <fcntl.h>    // fcntl
#include <sys/poll.h> // poll
#include <stdlib.h>   // setenv
#include <string.h>   // strrchr
#include <sys/file.h> // flock
#include <errno.h>
#include <glob.h>

#ifdef HAVE_GD
#include <gd.h>
#endif

#ifdef HAVE_X264 // don't worry, you really don't need it
extern "C" {
#include <x264.h>
}
#endif

/* Note: This module assumes everyone uses BGR16 as display depth */

//#define LOGO_LENGTH_HEADER  (1.2)
//#define LOGO_LENGTH_OVERLAP (10.0-LOGO_LENGTH_HEADER)
//#define LOGO_LENGTH_HEADER  (1.1)
//#define LOGO_LENGTH_OVERLAP (3.95-LOGO_LENGTH_HEADER)
//#define LOGO_LENGTH_OVERLAP (3-LOGO_LENGTH_HEADER)
//#define LOGO_LENGTH_HEADER  (1.5)
#define LOGO_LENGTH_OVERLAP (0)
#define LOGO_LENGTH_HEADER (0)

static std::string VIDEO_CMD = "";
/*
-rawvideo on:fps=60:format=0x42475220:w=256:h=224:size=$[1024*224]
-audiofile "+AUDIO_FN+"
*/
static std::string AUDIO_FN = "s.log";

static bool Terminate=false;
static unsigned videonumber = 0;

#ifdef THREAD_SAFETY
# include <pthread.h>
static pthread_mutex_t APIlock = PTHREAD_MUTEX_INITIALIZER;
struct ScopedLock
{ ScopedLock() { 
                 pthread_mutex_lock(&APIlock);
                 //fprintf(stderr, "audio start\n"); fflush(stderr);
               }
  ~ScopedLock() {
                 //fprintf(stderr, "audio end\n"); fflush(stderr);
                 pthread_mutex_unlock(&APIlock); }
};
#endif

static unsigned NonblockWrite(FILE* fp, const unsigned char*buf, unsigned length)
{
  Retry:
    int result = write(fileno(fp), buf, length);
    if(result == -1 && errno==EAGAIN)
    {
        return 0;
    }
    if(result == -1 && errno==EINTR) goto Retry;
    if(result == -1)
    {
        perror("write");
        Terminate=true;
        return 0;
    }
    return result;
}
static int WaitUntilOneIsWritable(FILE*f1, FILE*f2)
{
    struct pollfd po[2] = { {fileno(f1),POLLOUT,0}, {fileno(f2),POLLOUT,0} };
    poll(po, 2, -1);
    return ((po[0].revents & POLLOUT) ? 1 : 0)
         | ((po[1].revents & POLLOUT) ? 2 : 0);
}

#define BGR32 0x42475220  // BGR32 fourcc
#define BGR24 0x42475218  // BGR24 fourcc
#define BGR16 0x42475210  // BGR16 fourcc
#define BGR15 0x4247520F  // BGR15 fourcc
#define I420  0x30323449  // I420 fourcc
#define YUY2  0x32595559  // YUY2 fourcc

static unsigned USE_FOURCC = BGR16;
static unsigned INPUT_BPP  = 16;

#define u32(n) (n)&255,((n)>>8)&255,((n)>>16)&255,((n)>>24)&255
#define u16(n) (n)&255,((n)>>8)&255
#define s4(s) s[0],s[1],s[2],s[3]

static const unsigned FPS_SCALE = 0x1000000;

static struct Construct
{
    Construct()
    {
        char Buf[4096];
        getcwd(Buf,sizeof(Buf));
        Buf[sizeof(Buf)-1]=0;
        AUDIO_FN = Buf + std::string("/") + AUDIO_FN;
    }
} Construct;

class AVI
{
public:
    AVI()          { }
    virtual ~AVI() { }

    virtual void Audio
        (unsigned r,unsigned b,unsigned c,
         const unsigned char*d, unsigned nsamples) = 0;

    virtual void Video
        (unsigned w,unsigned h,unsigned f, const unsigned char*d) = 0;
    
    virtual void SaveState(const std::string&) { }
    virtual void LoadState(const std::string&) { }
};

class NormalAVI: public AVI
{
    FILE* vidfp;
    FILE* audfp;
    
    bool KnowVideo;
    unsigned vid_width;
    unsigned vid_height;
    unsigned vid_fps_scaled;
    std::list<std::vector<unsigned char> > VideoBuffer;
    unsigned VidBufSize;
    
    bool KnowAudio;
    unsigned aud_rate;
    unsigned aud_chans;
    unsigned aud_bits;
    std::list<std::vector<unsigned char> > AudioBuffer;
    unsigned AudBufSize;
    
public:
    NormalAVI() :
        vidfp(NULL),
        audfp(NULL),
        KnowVideo(false), VidBufSize(0),
        KnowAudio(false), AudBufSize(0)
    {
    }
    virtual ~NormalAVI()
    {
        while(VidBufSize && AudBufSize)
        {
            CheckFlushing();
        }
        if(audfp) fclose(audfp);
        if(vidfp) pclose(vidfp);
        unlink(AUDIO_FN.c_str());
    }
    
    virtual void Audio
        (unsigned r,unsigned b,unsigned c,
         const unsigned char*d, unsigned nsamples)
    {
        if(Terminate) return;
        if(!KnowAudio)
        {
            aud_rate = r;
            aud_chans = c;
            aud_bits = b;
            KnowAudio = true;
        }
        CheckFlushing();
        
        unsigned bytes = nsamples * aud_chans * (aud_bits / 8);
        
        unsigned wrote = 0;
        if(KnowVideo && AudioBuffer.empty())
        {
            //fprintf(stderr, "Writing %u of %s from %p to %p\t", bytes, "aud", (void*)d, (void*)audfp);
            wrote = NonblockWrite(audfp, d, bytes);
            //fprintf(stderr, "Wrote %u\n", wrote);
        }
        if(wrote < bytes)
        {
            unsigned remain = bytes-wrote;
            //fprintf(stderr, "Buffering %u of %s (%p..%p)\n", remain, "aud", d+wrote, d+bytes);
            AudioBuffer.push_back(std::vector<unsigned char>(d+wrote, d+bytes));
            AudBufSize += remain;
        }
        CheckFlushing();
    }

    virtual void Video
        (unsigned w,unsigned h,unsigned f, const unsigned char*d)
    {
        if(Terminate) return;
        if(!KnowVideo)
        {
            vid_width      = w;
            vid_height     = h;
            vid_fps_scaled = f;
            KnowVideo = true;
        }
        CheckFlushing();
        
        unsigned bpp   = INPUT_BPP; if(bpp == 15 || bpp == 17) bpp = 16;
        unsigned bytes = vid_width * vid_height * bpp / 8;
        
        //std::vector<unsigned char> tmp(bytes, 'k');
        //d = &tmp[0];
        
        unsigned wrote = 0;
        if(KnowAudio && VideoBuffer.empty())
        {
            CheckBegin();
            //fprintf(stderr, "Writing %u of %s from %p to %p\t", bytes, "vid", (void*)d, (void*)vidfp);
            wrote = NonblockWrite(vidfp, d, bytes);
            //fprintf(stderr, "Wrote %u\n", wrote);
        }
        
        if(wrote < bytes)
        {
            unsigned remain = bytes-wrote;
            //fprintf(stderr, "Buffering %u of %s (%p..%p)\n", remain, "vid", d+wrote, d+bytes);

            VideoBuffer.push_back(std::vector<unsigned char>(d+wrote, d+bytes));
            VidBufSize += remain;
        }
        CheckFlushing();
    }

private:
    /* fp is passed as a reference because it may be NULL
     * prior to calling, and this function changes it. */
    template<typename BufType>
    void FlushBufferSome(BufType& List, unsigned& Size, FILE*& fp, const char* what)
    {
        what=what;
        
    Retry:
        if(List.empty() || Terminate) return;
        
        typename BufType::iterator i = List.begin();
        std::vector<unsigned char>& buf = *i;
        
        if(buf.empty())
        {
            List.erase(i);
            goto Retry;
        }
        
        unsigned bytes = buf.size();
        
        CheckBegin();
        //fprintf(stderr, "Writing %u of %s from %p to %p\t", bytes, what, (void*)&buf[0], (void*)fp);
        
        unsigned ate = NonblockWrite(fp, &buf[0], bytes);

        //fprintf(stderr, "Wrote %u\n", ate);
        
        buf.erase(buf.begin(), buf.begin()+ate);
        
        Size -= ate;
        
        if(buf.empty())
        {
            List.erase(i);
        }
    }

    void CheckFlushing()
    {
        //AudioBuffer.clear();
        //VideoBuffer.clear();
        
        if(KnowAudio && KnowVideo && !Terminate)
        {
            if(!AudioBuffer.empty() && !VideoBuffer.empty())
            {
                do {
                    /* vidfp = &1, audfp = &2 */
                    int attempt = WaitUntilOneIsWritable(vidfp, audfp);
                    
                    if(attempt <= 0) break; /* Some kind of error can cause this */

                    // Flush Video
                    if(attempt&1) FlushBufferSome(VideoBuffer, VidBufSize, vidfp, "vid");
                    
                    // Flush Audio
                    if(attempt&2) FlushBufferSome(AudioBuffer, AudBufSize, audfp, "aud");
                } while (!AudioBuffer.empty() && !VideoBuffer.empty());
            }
            else
            {
                FlushBufferSome(VideoBuffer, VidBufSize, vidfp, "vid");
                FlushBufferSome(AudioBuffer, AudBufSize, audfp, "aud");
            }
            /*
            fprintf(stderr, "Buffer Sizes: Audio %u(%u) video %u(%u)\n",
                (unsigned)AudioBuffer.size(), AudBufSize,
                (unsigned)VideoBuffer.size(), VidBufSize);
            */
        }
    }
    std::string GetMEncoderRawvideoParam() const
    {
        char Buf[512];
        unsigned bpp   = INPUT_BPP; if(bpp == 15 || bpp == 17) bpp = 16;
        sprintf(Buf, "fps=%g:format=0x%04X:w=%u:h=%u:size=%u",
            vid_fps_scaled / (double)FPS_SCALE,
            USE_FOURCC,
            vid_width,
            vid_height,
            vid_width*vid_height * bpp/8);
        return Buf;
    }
    std::string GetMEncoderRawaudioParam() const
    {
        char Buf[512];
        sprintf(Buf, "channels=%u:rate=%u:samplesize=%u:bitrate=%u",
            aud_chans,
            aud_rate,
            aud_bits/8,
            aud_rate*aud_chans*(aud_bits/8) );
        return Buf;
    }
    std::string GetMEncoderCommand() const
    {
        std::string mandatory = "-audiofile " + AUDIO_FN
                              + " -audio-demuxer rawaudio"
                              + " -demuxer rawvideo"
                              + " -rawvideo " + GetMEncoderRawvideoParam()
                              + " -rawaudio " + GetMEncoderRawaudioParam()
                              ;
        std::string cmd = VIDEO_CMD;

        std::string::size_type p = cmd.find("NESV""SETTINGS");
        if(p != cmd.npos)
            cmd = cmd.replace(p, 4+8, mandatory);
        else
            fprintf(stderr, "Warning: NESVSETTINGS not found in videocmd\n");
        
        char videonumstr[64];
        sprintf(videonumstr, "%u", videonumber);
        
        for(;;)
        {
            p = cmd.find("VIDEO""NUMBER");
            if(p == cmd.npos) break;
            cmd = cmd.replace(p, 5+6, videonumstr);
        }
        
        fprintf(stderr, "Launch: %s\n", cmd.c_str()); fflush(stderr);
        
        return cmd;
    }

    void CheckBegin()
    {
        if(!audfp)
        {
            unlink(AUDIO_FN.c_str());
            mknod(AUDIO_FN.c_str(), S_IFIFO|0666, 0);
        }
        
        if(!vidfp)
        {
            /* Note: popen does not accept b/t in mode param */
            setenv("LD_PRELOAD", "", 1);
            vidfp = popen(GetMEncoderCommand().c_str(), "w");
            if(!vidfp)
            {
                perror("Launch failed");
            }
            else
            {
                fcntl(fileno(vidfp), F_SETFL, O_WRONLY | O_NONBLOCK);
            }
        }
        
        if(!audfp)
        {
        Retry:
            audfp = fopen(AUDIO_FN.c_str(), "wb");
            
            if(!audfp)
            {
                perror(AUDIO_FN.c_str());
                if(errno == ESTALE) goto Retry;
            }
            else
            {
                fcntl(fileno(audfp), F_SETFL, O_WRONLY | O_NONBLOCK);
            }
        }
    }
};

class RerecordingAVI: public AVI
{
    std::map<std::string, std::pair<off_t, off_t> > FrameStates;
    size_t aud_framesize;
    size_t vid_framesize;
    
    FILE* vidfp;
    FILE* audfp;
    FILE* eventfp;
    FILE* statefp;
    /*
    std::string vidfn;
    std::string audfn;
    std::string eventfn;
    std::string statefn;
    */
    
#ifdef HAVE_X264
    x264_t*        x264;
    x264_param_t   param;
    bool           forcekey;
#endif
    
    class LockF
    {
    public:
        LockF(FILE* f) : fp(f) { flock(fileno(fp), LOCK_EX); }
        ~LockF()               { flock(fileno(fp), LOCK_UN); }
    private:
        LockF(const LockF&);
        LockF& operator=(const LockF&);
        FILE* fp;
    };
    
public:
    RerecordingAVI(long FrameNumber)
        : aud_framesize(0),
          vid_framesize(0)
#ifdef HAVE_X264
          ,x264(0),
          forcekey(true)
#endif
    {
        SetFn();
    }
    virtual ~RerecordingAVI()
    {
        if(eventfp)
        {
            off_t vidpos = ftello(vidfp);
            off_t audpos = ftello(audfp);
            fprintf(eventfp,
                "%llX %llX End\n",
                (long long)vidpos, (long long)audpos);
        }
        if(vidfp) fclose(vidfp);
        if(audfp) fclose(audfp);
        if(eventfp) fclose(eventfp);
        if(statefp) fclose(statefp);
#ifdef HAVE_X264
        if(x264) x264_encoder_close(x264);
#endif
    }

    virtual void Audio
        (unsigned aud_rate,unsigned aud_bits,unsigned aud_chans,
         const unsigned char*data, unsigned nsamples)
    {
        size_t bytes = nsamples     * aud_chans * (aud_bits / 8);
        size_t framesize = aud_rate * aud_chans * (aud_bits / 8);
        
        if(framesize != aud_framesize)
        {
            aud_framesize = framesize;
            LockF el(eventfp);
            fprintf(eventfp, "AudFrameSize %lu\n", (unsigned long)aud_framesize);
            fflush(eventfp);
        }
        
        LockF al(audfp);
        fwrite(data, 1, bytes, audfp);
    }

    virtual void Video
        (unsigned vid_width,unsigned vid_height,
         unsigned vid_fps_scaled, const unsigned char*data)
    {
        unsigned bpp   = INPUT_BPP; if(bpp == 15 || bpp == 17) bpp = 16;
        size_t bytes = vid_width * vid_height * bpp / 8;
        size_t framesize = bytes;

        if(framesize != vid_framesize)
        {
            vid_framesize = framesize;
            LockF el(eventfp);
            fprintf(eventfp, "VidFrameSize %lu\n", (unsigned long)vid_framesize);
            fflush(eventfp);
        }

        LockF vl(vidfp);
        
#ifdef HAVE_X264
        if(bpp == 12) /* For I420, we use a local X264 encoder */
        {
            if(!x264)
            {
                x264_param_default(&param);
                x264_param_parse(&param, "psnr", "no");
                x264_param_parse(&param, "ssim", "no");
                param.i_width  = vid_width;
                param.i_height = vid_height;
                param.i_csp    = X264_CSP_I420;
                //param.i_scenecut_threshold = -1;
                //param.b_bframe_adaptive     = 0;
                //param.rc.i_rc_method      = X264_RC_CRF;
                //param.rc.i_qp_constant    = 0;
                x264_param_parse(&param, "me",       "dia");
                x264_param_parse(&param, "crf",      "6");
                x264_param_parse(&param, "frameref", "8");
                param.i_frame_reference = 1;
                param.analyse.i_subpel_refine = 1;
                param.analyse.i_me_method = X264_ME_DIA;
                /*
                param.analyse.inter = 0;
                param.analyse.b_transform_8x8 = 0;
                param.analyse.b_weighted_bipred = 0;
                param.analyse.i_trellis = 0;
                */
                //param.b_repeat_headers = 1; // guess this might be needed
                
                param.i_fps_num = vid_fps_scaled;
                param.i_fps_den = 1 << 24;
                
                x264 = x264_encoder_open(&param);
                if(!x264)
                {
                    fprintf(stderr, "x264_encoder_open failed.\n");
                    goto raw_fallback;
                }
            }
            
            const size_t npixels = vid_width * vid_height;
            x264_picture_t pic;
            pic.i_type = forcekey ? X264_TYPE_IDR : X264_TYPE_AUTO;
            pic.i_pts  = 0;
            pic.i_qpplus1 = 0;
            pic.img.i_csp = X264_CSP_I420;
            pic.img.i_plane = 3;
            pic.img.i_stride[0] = vid_width;
            pic.img.i_stride[1] = vid_width / 2;
            pic.img.i_stride[2] = vid_width / 2;
            pic.img.plane[0] = const_cast<uint8_t*>(data) + npixels*0/4;
            pic.img.plane[1] = const_cast<uint8_t*>(data) + npixels*4/4;
            pic.img.plane[2] = const_cast<uint8_t*>(data) + npixels*5/4;
            
            x264_nal_t*    nal; int i_nal;
            x264_picture_t pic_out;
            if(x264_encoder_encode(x264, &nal, &i_nal, &pic, &pic_out) < 0)
            {
                fprintf(stderr, "x264_encoder_encode failed\n");
                goto raw_fallback;
            }
            int i_size = 0;
            for(int i=0; i<i_nal; ++i) i_size += nal[i].i_payload * 2 + 4;
            std::vector<unsigned char> muxbuf(i_size);
            i_size = 0;
            for(int i=0; i<i_nal; ++i)
            {
                int room_required = nal[i].i_payload * 3/2 + 4;
                if(muxbuf.size() < i_size + room_required)
                    muxbuf.resize(i_size + room_required);
                
                int i_data = muxbuf.size() - i_size;
                i_size += x264_nal_encode(&muxbuf[i_size], &i_data, 1, &nal[i]);
            }
            if(i_size > 0)
                fwrite(&muxbuf[0], 1, i_size, vidfp);
        }
        else
#endif
        {
        raw_fallback:
            fwrite(data, 1, bytes, vidfp);
        }

        if(eventfp)
        {
            LockF el(eventfp);
            off_t vidpos = ftello(vidfp);
            off_t audpos = ftello(audfp);
            fprintf(eventfp,
                "%llX %llX Mark\n",
                (long long)vidpos, (long long)audpos);
            fflush(eventfp);
        }
    }
    
#ifdef HAVE_X264
    virtual void SaveState(const std::string& slot)
    {
        LockF el(eventfp);
        
        off_t vidpos = ftello(vidfp);
        off_t audpos = ftello(audfp);
    
        fprintf(eventfp,
            "%llX %llX Save %s\n",
             (long long)vidpos, (long long)audpos, slot.c_str());
        fflush(eventfp);
        
        FrameStates[slot] = std::make_pair(vidpos, audpos);
        WriteStates();
        
        forcekey = true;
    }
    
    virtual void LoadState(const std::string& slot)
    {
        LockF el(eventfp);

        const std::pair<off_t, off_t>& old = FrameStates[slot];
        off_t vidpos = ftello(vidfp);
        off_t audpos = ftello(audfp);
        fprintf(eventfp,
            "%llX %llX Load %llX %llX %s\n",
            (long long)vidpos, (long long)audpos,
            (long long)old.first,
            (long long)old.second,
            slot.c_str());
        fflush(eventfp);

        forcekey = true;
    }
#endif
private:
    void SetFn()
    {
        std::string vidfn = VIDEO_CMD + ".vid";
        std::string audfn = VIDEO_CMD + ".aud";
        std::string eventfn = VIDEO_CMD + ".log";
        std::string statefn = VIDEO_CMD + ".state";
        vidfp = fopen(vidfn.c_str(), "ab+");
        audfp = fopen(audfn.c_str(), "ab+");
        eventfp = fopen(eventfn.c_str(), "ab+");
        statefp = fopen2(statefn.c_str(), "rb+", "wb+");
        ReadStates();

        if(eventfp)
        {
            off_t vidpos = ftello(vidfp);
            off_t audpos = ftello(audfp);
            fprintf(eventfp,
                "%llX %llX Begin\n",
                (long long)vidpos, (long long)audpos);
        }
    }
    static FILE* fopen2(const char* fn, const char* mode1, const char* mode2)
    {
        FILE* result = fopen(fn, mode1);
        if(!result) result = fopen(fn, mode2);
        return result;
    }
    void ReadStates()
    {
        LockF sl(statefp);
        
        char Buf[4096];
        rewind(statefp);
        FrameStates.clear();
        while(fgets(Buf, sizeof(Buf), statefp))
        {
            if(*Buf == '-') break;
            char slotname[4096];
            long long vidpos, audpos;
            strtok(Buf, "\r"); strtok(Buf, "\n");
            sscanf(Buf, "%llX %llX %4095s", &vidpos, &audpos, slotname);
            FrameStates[slotname] = std::pair<off_t,off_t> (vidpos, audpos);
        }
    }
    void WriteStates()
    {
        LockF sl(statefp);
        
        rewind(statefp);
        for(std::map<std::string, std::pair<off_t, off_t> >::const_iterator
            i = FrameStates.begin(); i != FrameStates.end(); ++i)
        {
            fprintf(statefp, "%llX %llX %s\n", 
                (long long) i->second.first,
                (long long) i->second.second,
                i->first.c_str());
        }
        fprintf(statefp, "-\n");
        fflush(statefp);
    }
};


static AVI* AVI = 0;

#ifdef HAVE_GD
namespace LogoInfo
{
    unsigned width;
    unsigned height;

    bool SentVideo = false;
    bool SentAudio = false;
    int OverlapSent = 0;
}
#endif

#include "quantize.h"
#include "rgbtorgb.h"

static bool RerecordingMode = false;
static long CurrentFrameNumber = 0;

extern "C"
{
    int LoggingEnabled = 0; /* 0=no, 1=yes, 2=recording! */

    const char* NESVideoGetVideoCmd()
    {
        return VIDEO_CMD.c_str();
    }
    void NESVideoSetVideoCmd(const char *cmd)
    {
#ifdef THREAD_SAFETY
        ScopedLock lock;
#endif

        VIDEO_CMD = cmd;
    }
    
    void NESVideoSetRerecordingMode(long FrameNumber)
    {
        //const int LogoFramesOverlap = (int)( (LOGO_LENGTH_OVERLAP * fps_scaled) / (1 << 24) );
        RerecordingMode = true;
        CurrentFrameNumber = FrameNumber;
#ifdef HAVE_GD
        LogoInfo::SentVideo = FrameNumber > 0;
        LogoInfo::SentAudio = FrameNumber > 0;
        LogoInfo::OverlapSent = FrameNumber;
#endif
    }
    
    static class AVI& GetAVIptr()
    {
        if(!AVI)
        {
            if(RerecordingMode)
            {
                fprintf(stderr, "Beginning rerecording project at frame %ld\n", CurrentFrameNumber);
                AVI = new RerecordingAVI(CurrentFrameNumber);
            }
            else
            {
                fprintf(stderr, "Starting new AVI (num %u)\n", videonumber);
                AVI = new NormalAVI;
            }
        }
        return *AVI;
    }
    
    void NESVideoRerecordingSave(const char* slot)
    {
        GetAVIptr().SaveState(slot);
    }
    
    void NESVideoRerecordingLoad(const char* slot)
    {
        GetAVIptr().LoadState(slot);
    }
    
    void NESVideoNextAVI()
    {
#ifdef THREAD_SAFETY
        ScopedLock lock;
#endif

        if(AVI)
        {
            fprintf(stderr, "Closing AVI (next will be started)\n");
            delete AVI;
            AVI = 0;
            ++videonumber;
        }
    }

 #ifdef HAVE_GD
    static void Overlay32With32(unsigned char* target, const unsigned char* source, int alpha)
    {
        target[0] += ((int)(source[0] - target[0])) * alpha / 255;
        target[1] += ((int)(source[1] - target[1])) * alpha / 255;
        target[2] += ((int)(source[2] - target[2])) * alpha / 255;
    }
    
    static void OverlayLogoFrom(const char* fn, std::vector<unsigned char>& data)
    {
        FILE*fp = fopen(fn, "rb");
        if(!fp) perror(fn);
        if(!fp) return; /* Silently ignore missing frames */
        
        gdImagePtr im = gdImageCreateFromPng(fp);
        if(!gdImageTrueColor(im))
        {
          fprintf(stderr, "'%s': Only true color images are supported\n", fn);
          goto CloseIm;
        }
        {/*scope begin*/
        
        unsigned new_width = gdImageSX(im);
        unsigned new_height= gdImageSY(im);
        
        if(new_width != LogoInfo::width
        || new_height != LogoInfo::height)
        {
            if(new_height < LogoInfo::height || new_height > LogoInfo::height+20)
            fprintf(stderr, "'%s': ERROR, expected %dx%d, got %dx%d\n", fn,
                LogoInfo::width, LogoInfo::height,
                new_width, new_height);
        }

        for(unsigned y=0; y<LogoInfo::height; ++y)
        {
            unsigned char pixbuf[4] = {0,0,0,0};
            for(unsigned x = 0; x < LogoInfo::width; ++x)
            {
                int color = gdImageTrueColorPixel(im, x,y);
                int alpha = 255-gdTrueColorGetAlpha(color)*256/128;
                pixbuf[2] = gdTrueColorGetRed(color);
                pixbuf[1] = gdTrueColorGetGreen(color);
                pixbuf[0] = gdTrueColorGetBlue(color);
                Overlay32With32(&data[(y*LogoInfo::width+x)*3], pixbuf, alpha);
            }
        }
        }/* close scope */
    CloseIm:
        gdImageDestroy(im);
        fclose(fp);
    }
    
    static const std::string GetLogoFileName(unsigned frameno)
    {
        std::string avdir = "/home/you/yourlogo/";
        
        char AvName[512];
        sprintf(AvName, "logo_%d_%d_f%03u.png",
            LogoInfo::width,
            LogoInfo::height,
            frameno);
        
        std::string want = avdir + AvName;
        int ac = access(want.c_str(), R_OK);
        if(ac != 0)
        {
            /* No correct avatar file? Check if there's an approximate match. */
            static std::map<int, std::vector<std::string> > files;
            if(files.empty()) /* Cache the list of logo files. */
            {
                static const char GlobPat[] = "logo_*_*_f*.png";
                glob_t globdata;
                globdata.gl_offs = 0;
                fprintf(stderr, "Loading list of usable logo animation files in %s...\n", avdir.c_str());
                int globres = glob( (avdir + GlobPat).c_str(), GLOB_NOSORT, NULL, &globdata);
                if(globres == 0)
                {
                    for(size_t n=0; n<globdata.gl_pathc; ++n)
                    {
                        const char* fn = globdata.gl_pathv[n];
                        const char* slash = strrchr(fn, '/');
                        if(slash) fn = slash+1;
                        
                        int gotw=0, goth=0, gotf=0;
                        sscanf(fn, "logo_%d_%d_f%d", &gotw,&goth,&gotf);
                        files[gotf].push_back(fn);
                    }
                }
                globfree(&globdata);
            }
            
            std::map<int, std::vector<std::string> >::const_iterator
                i = files.find(frameno);
            if(i != files.end())
            {
                std::string best;
                int bestdist = -1;
                
                const std::vector<std::string>& fnames = i->second;
                for(size_t b=fnames.size(), a=0; a<b; ++a)
                {
                    unsigned gotw=0, goth=0;
                    sscanf(fnames[a].c_str(), "logo_%u_%u", &gotw,&goth);
                    if(gotw < LogoInfo::width || goth < LogoInfo::height) continue;
                    
                    int dist = std::max(gotw - LogoInfo::width,
                                        goth - LogoInfo::height);
                    
                    if(bestdist == -1 || dist < bestdist)
                        { bestdist = dist; best = fnames[a]; }
                }
                
                if(bestdist >= 0) want = avdir + best;
            }
        }
        return want;
    }
    
    static const std::vector<unsigned char> NVConvert24To16Frame
        (const std::vector<unsigned char>& logodata)
    {
        std::vector<unsigned char> result(LogoInfo::width * LogoInfo::height * 2);
        Convert24To16Frame(&logodata[0], &result[0], LogoInfo::width * LogoInfo::height, LogoInfo::width);
        return result;
    }
    static const std::vector<unsigned char> NVConvert24To15Frame
        (const std::vector<unsigned char>& logodata)
    {
        std::vector<unsigned char> result(LogoInfo::width * LogoInfo::height * 2);
        Convert24To15Frame(&logodata[0], &result[0], LogoInfo::width * LogoInfo::height, LogoInfo::width);
        return result;
    }
    
    static const std::vector<unsigned char> NVConvert24To_I420Frame
        (const std::vector<unsigned char>& logodata)
    {
        std::vector<unsigned char> result(LogoInfo::width * LogoInfo::height * 3 / 2);
        Convert24To_I420Frame(&logodata[0], &result[0], LogoInfo::width * LogoInfo::height, LogoInfo::width);
        return result;
    }
    
    static const std::vector<unsigned char> NVConvert24To_YUY2Frame
        (const std::vector<unsigned char>& logodata)
    {
        std::vector<unsigned char> result(LogoInfo::width * LogoInfo::height * 3 / 2);
        Convert24To_YUY2Frame(&logodata[0], &result[0], LogoInfo::width * LogoInfo::height, LogoInfo::width);
        return result;
    }
    
    static const std::vector<unsigned char> NVConvert16To24Frame
        (const void* data, unsigned npixels)
    {
        std::vector<unsigned char> logodata(npixels*3); /* filled with black. */
        Convert16To24Frame(data, &logodata[0], npixels);
        return logodata;
    }
    
    static const std::vector<unsigned char> NVConvert15To24Frame
        (const void* data, unsigned npixels)
    {
        std::vector<unsigned char> logodata(npixels*3); /* filled with black. */
        Convert15To24Frame(data, &logodata[0], npixels);
        return logodata;
    }
    
    static const std::vector<unsigned char> NVConvert_I420To24Frame
        (const void* data, unsigned npixels)
    {
        std::vector<unsigned char> logodata(npixels*3); /* filled with black. */
        Convert_I420To24Frame(data, &logodata[0], npixels, LogoInfo::width);
        return logodata;
    }
    
    static const std::vector<unsigned char> NVConvert_YUY2To24Frame
        (const void* data, unsigned npixels)
    {
        std::vector<unsigned char> logodata(npixels*3); /* filled with black. */
        Convert_YUY2To24Frame(data, &logodata[0], npixels, LogoInfo::width);
        return logodata;
    }
    
    static void SubstituteWithBlackIfNeeded(const void*& data)
    {
        /* If the first frames of the animation consist of a
         * single color (such as gray for NES), replace them
         * with black to avoid ugly backgrounds on logo animations
         */
    
        static bool Deviate = false;
        static short* Replacement = 0;
        static unsigned wid=0, hei=0;
        if(Deviate)
        {
            if(Replacement) { delete[] Replacement; Replacement=0; }
            return;
        }
        
        unsigned dim = LogoInfo::width * LogoInfo::height;
        const short* p = (const short*)data;
        for(unsigned a=0; a<dim; ++a)
            if(p[a] != p[0])
            {
                Deviate = true;
                return;
            }
        
        if(Replacement && (wid != LogoInfo::width || hei != LogoInfo::height))
        {
            delete[] Replacement;
            Replacement = 0;
        }
        
        wid = LogoInfo::width;
        hei = LogoInfo::height;
        
        if(!Replacement)
        {
            Replacement = new short[dim];
            for(unsigned a=0; a<dim; ++a) Replacement[a]=0x0000;
        }
        data = (void*)Replacement;
    }
#endif

    void NESVideoLoggingVideo
        (const void*data, unsigned width,unsigned height,
         unsigned fps_scaled,
         unsigned bpp
        )
    {
        if(LoggingEnabled < 2) return;
        
        ++CurrentFrameNumber;
        
#ifdef THREAD_SAFETY
        ScopedLock lock;
#endif

        if(bpp == 32) /* Convert 32 to 24 */
        {
            bpp = 24;
            
            static std::vector<unsigned char> VideoBuf;
            VideoBuf.resize(width*height * 3);
            
            Convert32To24Frame(data, &VideoBuf[0], width*height);
            data = (void*)&VideoBuf[0];
        }
        
        if(bpp) INPUT_BPP = bpp;
        
        switch(INPUT_BPP)
        {
            case 32: USE_FOURCC = BGR32; break;
            case 24: USE_FOURCC = BGR24; break;
            case 16: USE_FOURCC = BGR16; break;
            case 15: USE_FOURCC = BGR15; break;
            case 12: USE_FOURCC = I420; break;
            case 17: USE_FOURCC = YUY2; break;
        }
        //USE_FOURCC = BGR24; // FIXME TEMPORARY
        
#ifdef HAVE_GD
        const int LogoFramesHeader  = (int)( (LOGO_LENGTH_HEADER  * fps_scaled) / (1 << 24) );
        const int LogoFramesOverlap = (int)( (LOGO_LENGTH_OVERLAP * fps_scaled) / (1 << 24) );
        
        LogoInfo::width  = width;
        LogoInfo::height = height;
        
        if(INPUT_BPP == 16 || INPUT_BPP == 15)
        {
            SubstituteWithBlackIfNeeded(data);
        }
        else if(INPUT_BPP != 24 && INPUT_BPP != 12 && INPUT_BPP != 17)
        {
            fprintf(stderr, "NESVIDEOS_PIECE only supports 16 and 24 bpp, you gave %u bpp\n",
                bpp);
            return;
        }

        if(!LogoInfo::SentVideo)
        {
            /* Send animation frames that do not involve source video? */
            LogoInfo::SentVideo=true;

            if(LogoFramesHeader > 0)
            {
                for(int frame = 0; frame < LogoFramesHeader; ++frame)
                {
                    std::vector<unsigned char> logodata(width*height*3); /* filled with black. */
                    
                    std::string fn = GetLogoFileName(frame);
                    /*fprintf(stderr, "wid=%d(%d), hei=%d(%d),fn=%s\n",
                        width, LogoInfo::width,
                        height, LogoInfo::height,
                        fn.c_str());*/
                    OverlayLogoFrom(fn.c_str(), logodata);
                    
                    //INPUT_BPP = 24; USE_FOURCC = BGR24; // FIXME TEMPORARY
                    
                    if(INPUT_BPP == 16)
                    {
                        std::vector<unsigned char> result = NVConvert24To16Frame(logodata);
                        GetAVIptr().Video(width,height,fps_scaled, &result[0]);
                    }
                    else if(INPUT_BPP == 15)
                    {
                        std::vector<unsigned char> result = NVConvert24To15Frame(logodata);
                        GetAVIptr().Video(width,height,fps_scaled, &result[0]);
                    }
                    else if(INPUT_BPP == 12)
                    {
                        std::vector<unsigned char> result = NVConvert24To_I420Frame(logodata);
                        GetAVIptr().Video(width,height,fps_scaled, &result[0]);
                    }
                    else if(INPUT_BPP == 17)
                    {
                        std::vector<unsigned char> result = NVConvert24To_YUY2Frame(logodata);
                        GetAVIptr().Video(width,height,fps_scaled, &result[0]);
                    }
                    else
                    {
                        GetAVIptr().Video(width,height,fps_scaled, &logodata[0]);
                    }
                }
            }
        }
        
        if(LogoInfo::OverlapSent < LogoFramesOverlap)
        {
            /* Send animation frames that mix source and animation? */

            std::string fn = GetLogoFileName(LogoInfo::OverlapSent + LogoFramesHeader);
            /*
            fprintf(stderr, "wid=%d(%d), hei=%d(%d),fn=%s\n",
                width, LogoInfo::width,
                height, LogoInfo::height,
                fn.c_str());*/

            std::vector<unsigned char> logodata;
            if(INPUT_BPP == 16)
            {
                logodata = NVConvert16To24Frame(data, width*height);
            }
            else if(INPUT_BPP == 15)
            {
                logodata = NVConvert15To24Frame(data, width*height);
            }
            else if(INPUT_BPP == 17)
            {
                logodata = NVConvert_YUY2To24Frame(data, width*height);
            }
            else if(INPUT_BPP == 12)
            {
                logodata = NVConvert_I420To24Frame(data, width*height);
            }
            else
            {
                logodata.resize(width*height*3); /* filled with black. */
                memcpy(&logodata[0], data, width*height*3);
            }

            OverlayLogoFrom(fn.c_str(), logodata);
            
//            INPUT_BPP = 24; USE_FOURCC = BGR24; // FIXME TEMPORARY

            if(INPUT_BPP == 16)
            {
                std::vector<unsigned char> result = NVConvert24To16Frame(logodata);
                GetAVIptr().Video(width,height,fps_scaled, &result[0]);
            }
            else if(INPUT_BPP == 15)
            {
                std::vector<unsigned char> result = NVConvert24To15Frame(logodata);
                GetAVIptr().Video(width,height,fps_scaled, &result[0]);
            }
            else if(INPUT_BPP == 12)
            {
                std::vector<unsigned char> result = NVConvert24To_I420Frame(logodata);
                GetAVIptr().Video(width,height,fps_scaled, &result[0]);
            }
            else if(INPUT_BPP == 17)
            {
                std::vector<unsigned char> result = NVConvert24To_YUY2Frame(logodata);
                GetAVIptr().Video(width,height,fps_scaled, &result[0]);
            }
            else
            {
                GetAVIptr().Video(width,height,fps_scaled, &logodata[0]);
            }

            ++LogoInfo::OverlapSent;
            return;
        }
#endif
        
        GetAVIptr().Video(width,height,fps_scaled,  (const unsigned char*) data);
    }

    void NESVideoLoggingAudio
        (const void*data,
         unsigned rate, unsigned bits, unsigned chans,
         unsigned nsamples)
    {
        if(LoggingEnabled < 2) return;
        
        ++CurrentFrameNumber;
        
#ifdef THREAD_SAFETY
        ScopedLock lock;
#endif
#ifdef HAVE_GD
        if(!LogoInfo::SentAudio && LOGO_LENGTH_HEADER > 0)
        {
            LogoInfo::SentAudio=true;
            
            double HdrLength = LOGO_LENGTH_HEADER; // N64 workaround
            
            const long n = (long)(rate * HdrLength)/*
                - (rate * 0.11)*/;
            
            if(n > 0) {
            unsigned bytes = n*chans*(bits/8);
            unsigned char* buf = (unsigned char*)malloc(bytes);
            if(buf)
            {
                memset(buf,0,bytes);
                GetAVIptr().Audio(rate,bits,chans, buf, n);
                free(buf);
            } }
        }
#endif
        
        /*
        fprintf(stderr, "Writing %u samples (%u bits, %u chans, %u rate)\n",
            nsamples, bits, chans, rate);*/
        
        /*
        static FILE*fp = fopen("audiodump.wav", "wb");
        fwrite(data, 1, nsamples*(bits/8)*chans, fp);
        fflush(fp);*/
        
        GetAVIptr().Audio(rate,bits,chans, (const unsigned char*) data, nsamples);
    }
} /* extern "C" */
