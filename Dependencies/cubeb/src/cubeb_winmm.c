/*
 * Copyright © 2011 Mozilla Foundation
 *
 * This program is made available under an ISC-style license.  See the
 * accompanying file LICENSE for details.
 */
#define __MSVCRT_VERSION__ 0x0700
#undef WINVER
#define WINVER 0x0501
#undef WIN32_LEAN_AND_MEAN

#include <malloc.h>
#include <windows.h>
#include <mmreg.h>
#include <mmsystem.h>
#include <process.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "cubeb/cubeb.h"
#include "cubeb-internal.h"

/* This is missing from the MinGW headers. Use a safe fallback. */
#if !defined(MEMORY_ALLOCATION_ALIGNMENT)
#define MEMORY_ALLOCATION_ALIGNMENT 16
#endif

/**This is also missing from the MinGW headers. It  also appears to be undocumented by Microsoft.*/
#ifndef WAVE_FORMAT_48M08
#define WAVE_FORMAT_48M08      0x00001000       /* 48     kHz, Mono, 8-bit */
#endif
#ifndef WAVE_FORMAT_48M16
#define WAVE_FORMAT_48M16      0x00002000       /* 48     kHz, Mono, 16-bit */
#endif
#ifndef WAVE_FORMAT_48S08
#define WAVE_FORMAT_48S08      0x00004000       /* 48     kHz, Stereo, 8-bit */
#endif
#ifndef WAVE_FORMAT_48S16
#define WAVE_FORMAT_48S16      0x00008000       /* 48     kHz, Stereo, 16-bit */
#endif
#ifndef WAVE_FORMAT_96M08
#define WAVE_FORMAT_96M08      0x00010000       /* 96     kHz, Mono, 8-bit */
#endif
#ifndef WAVE_FORMAT_96M16
#define WAVE_FORMAT_96M16      0x00020000       /* 96     kHz, Mono, 16-bit */
#endif
#ifndef WAVE_FORMAT_96S08
#define WAVE_FORMAT_96S08      0x00040000       /* 96     kHz, Stereo, 8-bit */
#endif
#ifndef WAVE_FORMAT_96S16
#define WAVE_FORMAT_96S16      0x00080000       /* 96     kHz, Stereo, 16-bit */
#endif

/**Taken from winbase.h, also not in MinGW.*/
#ifndef STACK_SIZE_PARAM_IS_A_RESERVATION
#define STACK_SIZE_PARAM_IS_A_RESERVATION   0x00010000    // Threads only
#endif

#ifndef DRVM_MAPPER
#define DRVM_MAPPER             (0x2000)
#endif
#ifndef DRVM_MAPPER_PREFERRED_GET
#define DRVM_MAPPER_PREFERRED_GET                 (DRVM_MAPPER+21)
#endif
#ifndef DRVM_MAPPER_CONSOLEVOICECOM_GET
#define DRVM_MAPPER_CONSOLEVOICECOM_GET           (DRVM_MAPPER+23)
#endif

#define CUBEB_STREAM_MAX 32
#define NBUFS 4

const GUID KSDATAFORMAT_SUBTYPE_PCM =
{ 0x00000001, 0x0000, 0x0010, { 0x80, 0x00, 0x00, 0xaa, 0x00, 0x38, 0x9b, 0x71 } };
const GUID KSDATAFORMAT_SUBTYPE_IEEE_FLOAT =
{ 0x00000003, 0x0000, 0x0010, { 0x80, 0x00, 0x00, 0xaa, 0x00, 0x38, 0x9b, 0x71 } };

struct cubeb_stream_item {
  SLIST_ENTRY head;
  cubeb_stream * stream;
};

static struct cubeb_ops const winmm_ops;

struct cubeb {
  struct cubeb_ops const * ops;
  HANDLE event;
  HANDLE thread;
  int shutdown;
  PSLIST_HEADER work;
  CRITICAL_SECTION lock;
  unsigned int active_streams;
  unsigned int minimum_latency_ms;
};

struct cubeb_stream {
  cubeb * context;
  cubeb_stream_params params;
  cubeb_data_callback data_callback;
  cubeb_state_callback state_callback;
  void * user_ptr;
  WAVEHDR buffers[NBUFS];
  size_t buffer_size;
  int next_buffer;
  int free_buffers;
  int shutdown;
  int draining;
  HANDLE event;
  HWAVEOUT waveout;
  CRITICAL_SECTION lock;
  uint64_t written;
  float soft_volume;
};

static size_t
bytes_per_frame(cubeb_stream_params params)
{
  size_t bytes;

  switch (params.format) {
  case CUBEB_SAMPLE_S16LE:
    bytes = sizeof(signed short);
    break;
  case CUBEB_SAMPLE_FLOAT32LE:
    bytes = sizeof(float);
    break;
  default:
    XASSERT(0);
  }

  return bytes * params.channels;
}

static WAVEHDR *
winmm_get_next_buffer(cubeb_stream * stm)
{
  WAVEHDR * hdr = NULL;

  XASSERT(stm->free_buffers > 0 && stm->free_buffers <= NBUFS);
  hdr = &stm->buffers[stm->next_buffer];
  XASSERT(hdr->dwFlags & WHDR_PREPARED ||
          (hdr->dwFlags & WHDR_DONE && !(hdr->dwFlags & WHDR_INQUEUE)));
  stm->next_buffer = (stm->next_buffer + 1) % NBUFS;
  stm->free_buffers -= 1;

  return hdr;
}

static void
winmm_refill_stream(cubeb_stream * stm)
{
  WAVEHDR * hdr;
  long got;
  long wanted;
  MMRESULT r;

  EnterCriticalSection(&stm->lock);
  stm->free_buffers += 1;
  XASSERT(stm->free_buffers > 0 && stm->free_buffers <= NBUFS);

  if (stm->draining) {
    LeaveCriticalSection(&stm->lock);
    if (stm->free_buffers == NBUFS) {
      stm->state_callback(stm, stm->user_ptr, CUBEB_STATE_DRAINED);
    }
    SetEvent(stm->event);
    return;
  }

  if (stm->shutdown) {
    LeaveCriticalSection(&stm->lock);
    SetEvent(stm->event);
    return;
  }

  hdr = winmm_get_next_buffer(stm);

  wanted = (DWORD) stm->buffer_size / bytes_per_frame(stm->params);

  /* It is assumed that the caller is holding this lock.  It must be dropped
     during the callback to avoid deadlocks. */
  LeaveCriticalSection(&stm->lock);
  got = stm->data_callback(stm, stm->user_ptr, NULL, hdr->lpData, wanted);
  EnterCriticalSection(&stm->lock);
  if (got < 0) {
    LeaveCriticalSection(&stm->lock);
    /* XXX handle this case */
    XASSERT(0);
    return;
  } else if (got < wanted) {
    stm->draining = 1;
  }
  stm->written += got;

  XASSERT(hdr->dwFlags & WHDR_PREPARED);

  hdr->dwBufferLength = got * bytes_per_frame(stm->params);
  XASSERT(hdr->dwBufferLength <= stm->buffer_size);

  if (stm->soft_volume != -1.0) {
    if (stm->params.format == CUBEB_SAMPLE_FLOAT32NE) {
      float * b = (float *) hdr->lpData;
      uint32_t i;
      for (i = 0; i < got * stm->params.channels; i++) {
        b[i] *= stm->soft_volume;
      }
    } else {
      short * b = (short *) hdr->lpData;
      uint32_t i;
      for (i = 0; i < got * stm->params.channels; i++) {
        b[i] = (short) (b[i] * stm->soft_volume);
      }
    }
  }

  r = waveOutWrite(stm->waveout, hdr, sizeof(*hdr));
  if (r != MMSYSERR_NOERROR) {
    LeaveCriticalSection(&stm->lock);
    stm->state_callback(stm, stm->user_ptr, CUBEB_STATE_ERROR);
    return;
  }

  LeaveCriticalSection(&stm->lock);
}

static unsigned __stdcall
winmm_buffer_thread(void * user_ptr)
{
  cubeb * ctx = (cubeb *) user_ptr;
  XASSERT(ctx);

  for (;;) {
    DWORD r;
    PSLIST_ENTRY item;

    r = WaitForSingleObject(ctx->event, INFINITE);
    XASSERT(r == WAIT_OBJECT_0);

    /* Process work items in batches so that a single stream can't
       starve the others by continuously adding new work to the top of
       the work item stack. */
    item = InterlockedFlushSList(ctx->work);
    while (item != NULL) {
      PSLIST_ENTRY tmp = item;
      winmm_refill_stream(((struct cubeb_stream_item *) tmp)->stream);
      item = item->Next;
      _aligned_free(tmp);
    }

    if (ctx->shutdown) {
      break;
    }
  }

  return 0;
}

static void CALLBACK
winmm_buffer_callback(HWAVEOUT waveout, UINT msg, DWORD_PTR user_ptr, DWORD_PTR p1, DWORD_PTR p2)
{
  cubeb_stream * stm = (cubeb_stream *) user_ptr;
  struct cubeb_stream_item * item;

  if (msg != WOM_DONE) {
    return;
  }

  item = _aligned_malloc(sizeof(struct cubeb_stream_item), MEMORY_ALLOCATION_ALIGNMENT);
  XASSERT(item);
  item->stream = stm;
  InterlockedPushEntrySList(stm->context->work, &item->head);

  SetEvent(stm->context->event);
}

static unsigned int
calculate_minimum_latency(void)
{
  OSVERSIONINFOEX osvi;
  DWORDLONG mask;

  /* Running under Terminal Services results in underruns with low latency. */
  if (GetSystemMetrics(SM_REMOTESESSION) == TRUE) {
    return 500;
  }

  /* Vista's WinMM implementation underruns when less than 200ms of audio is buffered. */
  memset(&osvi, 0, sizeof(OSVERSIONINFOEX));
  osvi.dwOSVersionInfoSize = sizeof(OSVERSIONINFOEX);
  osvi.dwMajorVersion = 6;
  osvi.dwMinorVersion = 0;

  mask = 0;
  VER_SET_CONDITION(mask, VER_MAJORVERSION, VER_EQUAL);
  VER_SET_CONDITION(mask, VER_MINORVERSION, VER_EQUAL);

  if (VerifyVersionInfo(&osvi, VER_MAJORVERSION | VER_MINORVERSION, mask) != 0) {
    return 200;
  }

  return 100;
}

static void winmm_destroy(cubeb * ctx);

/*static*/ int
winmm_init(cubeb ** context, char const * context_name)
{
  cubeb * ctx;

  XASSERT(context);
  *context = NULL;

  /* Don't initialize a context if there are no devices available. */
  if (waveOutGetNumDevs() == 0) {
    return CUBEB_ERROR;
  }

  ctx = calloc(1, sizeof(*ctx));
  XASSERT(ctx);

  ctx->ops = &winmm_ops;

  ctx->work = _aligned_malloc(sizeof(*ctx->work), MEMORY_ALLOCATION_ALIGNMENT);
  XASSERT(ctx->work);
  InitializeSListHead(ctx->work);

  ctx->event = CreateEvent(NULL, FALSE, FALSE, NULL);
  if (!ctx->event) {
    winmm_destroy(ctx);
    return CUBEB_ERROR;
  }

  ctx->thread = (HANDLE) _beginthreadex(NULL, 256 * 1024, winmm_buffer_thread, ctx, STACK_SIZE_PARAM_IS_A_RESERVATION, NULL);
  if (!ctx->thread) {
    winmm_destroy(ctx);
    return CUBEB_ERROR;
  }

  SetThreadPriority(ctx->thread, THREAD_PRIORITY_TIME_CRITICAL);

  InitializeCriticalSection(&ctx->lock);
  ctx->active_streams = 0;

  ctx->minimum_latency_ms = calculate_minimum_latency();

  *context = ctx;

  return CUBEB_OK;
}

static char const *
winmm_get_backend_id(cubeb * ctx)
{
  return "winmm";
}

static void
winmm_destroy(cubeb * ctx)
{
  DWORD r;

  XASSERT(ctx->active_streams == 0);
  XASSERT(!InterlockedPopEntrySList(ctx->work));

  DeleteCriticalSection(&ctx->lock);

  if (ctx->thread) {
    ctx->shutdown = 1;
    SetEvent(ctx->event);
    r = WaitForSingleObject(ctx->thread, INFINITE);
    XASSERT(r == WAIT_OBJECT_0);
    CloseHandle(ctx->thread);
  }

  if (ctx->event) {
    CloseHandle(ctx->event);
  }

  _aligned_free(ctx->work);

  free(ctx);
}

static void winmm_stream_destroy(cubeb_stream * stm);

static int
winmm_stream_init(cubeb * context, cubeb_stream ** stream, char const * stream_name,
                  cubeb_devid input_device,
                  cubeb_stream_params * input_stream_params,
                  cubeb_devid output_device,
                  cubeb_stream_params * output_stream_params,
                  unsigned int latency_frames,
                  cubeb_data_callback data_callback,
                  cubeb_state_callback state_callback,
                  void * user_ptr)
{
  MMRESULT r;
  WAVEFORMATEXTENSIBLE wfx;
  cubeb_stream * stm;
  int i;
  size_t bufsz;

  XASSERT(context);
  XASSERT(stream);

  if (input_stream_params) {
    /* Capture support not yet implemented. */
    return CUBEB_ERROR_NOT_SUPPORTED;
  }

  if (input_device || output_device) {
    /* Device selection not yet implemented. */
    return CUBEB_ERROR_DEVICE_UNAVAILABLE;
  }

  *stream = NULL;

  memset(&wfx, 0, sizeof(wfx));
  if (output_stream_params->channels > 2) {
    wfx.Format.wFormatTag = WAVE_FORMAT_EXTENSIBLE;
    wfx.Format.cbSize = sizeof(wfx) - sizeof(wfx.Format);
  } else {
    wfx.Format.wFormatTag = WAVE_FORMAT_PCM;
    if (output_stream_params->format == CUBEB_SAMPLE_FLOAT32LE) {
      wfx.Format.wFormatTag = WAVE_FORMAT_IEEE_FLOAT;
    }
    wfx.Format.cbSize = 0;
  }
  wfx.Format.nChannels = output_stream_params->channels;
  wfx.Format.nSamplesPerSec = output_stream_params->rate;

  /* XXX fix channel mappings */
  wfx.dwChannelMask = SPEAKER_FRONT_LEFT | SPEAKER_FRONT_RIGHT;

  switch (output_stream_params->format) {
  case CUBEB_SAMPLE_S16LE:
    wfx.Format.wBitsPerSample = 16;
    wfx.SubFormat = KSDATAFORMAT_SUBTYPE_PCM;
    break;
  case CUBEB_SAMPLE_FLOAT32LE:
    wfx.Format.wBitsPerSample = 32;
    wfx.SubFormat = KSDATAFORMAT_SUBTYPE_IEEE_FLOAT;
    break;
  default:
    return CUBEB_ERROR_INVALID_FORMAT;
  }

  wfx.Format.nBlockAlign = (wfx.Format.wBitsPerSample * wfx.Format.nChannels) / 8;
  wfx.Format.nAvgBytesPerSec = wfx.Format.nSamplesPerSec * wfx.Format.nBlockAlign;
  wfx.Samples.wValidBitsPerSample = wfx.Format.wBitsPerSample;

  EnterCriticalSection(&context->lock);
  /* CUBEB_STREAM_MAX is a horrible hack to avoid a situation where, when
     many streams are active at once, a subset of them will not consume (via
     playback) or release (via waveOutReset) their buffers. */
  if (context->active_streams >= CUBEB_STREAM_MAX) {
    LeaveCriticalSection(&context->lock);
    return CUBEB_ERROR;
  }
  context->active_streams += 1;
  LeaveCriticalSection(&context->lock);

  stm = calloc(1, sizeof(*stm));
  XASSERT(stm);

  stm->context = context;

  stm->params = *output_stream_params;

  stm->data_callback = data_callback;
  stm->state_callback = state_callback;
  stm->user_ptr = user_ptr;
  stm->written = 0;

  uint32_t latency_ms = latency_frames * 1000 / output_stream_params->rate;

  if (latency_ms < context->minimum_latency_ms) {
    latency_ms = context->minimum_latency_ms;
  }

  bufsz = (size_t) (stm->params.rate / 1000.0 * latency_ms * bytes_per_frame(stm->params) / NBUFS);
  if (bufsz % bytes_per_frame(stm->params) != 0) {
    bufsz += bytes_per_frame(stm->params) - (bufsz % bytes_per_frame(stm->params));
  }
  XASSERT(bufsz % bytes_per_frame(stm->params) == 0);

  stm->buffer_size = bufsz;

  InitializeCriticalSection(&stm->lock);

  stm->event = CreateEvent(NULL, FALSE, FALSE, NULL);
  if (!stm->event) {
    winmm_stream_destroy(stm);
    return CUBEB_ERROR;
  }

  stm->soft_volume = -1.0;

  /* winmm_buffer_callback will be called during waveOutOpen, so all
     other initialization must be complete before calling it. */
  r = waveOutOpen(&stm->waveout, WAVE_MAPPER, &wfx.Format,
                  (DWORD_PTR) winmm_buffer_callback, (DWORD_PTR) stm,
                  CALLBACK_FUNCTION);
  if (r != MMSYSERR_NOERROR) {
    winmm_stream_destroy(stm);
    return CUBEB_ERROR;
  }

  r = waveOutPause(stm->waveout);
  if (r != MMSYSERR_NOERROR) {
    winmm_stream_destroy(stm);
    return CUBEB_ERROR;
  }

  for (i = 0; i < NBUFS; ++i) {
    WAVEHDR * hdr = &stm->buffers[i];

    hdr->lpData = calloc(1, bufsz);
    XASSERT(hdr->lpData);
    hdr->dwBufferLength = bufsz;
    hdr->dwFlags = 0;

    r = waveOutPrepareHeader(stm->waveout, hdr, sizeof(*hdr));
    if (r != MMSYSERR_NOERROR) {
      winmm_stream_destroy(stm);
      return CUBEB_ERROR;
    }

    winmm_refill_stream(stm);
  }

  *stream = stm;

  return CUBEB_OK;
}

static void
winmm_stream_destroy(cubeb_stream * stm)
{
  int i;

  if (stm->waveout) {
    MMTIME time;
    MMRESULT r;
    int device_valid;
    int enqueued;

    EnterCriticalSection(&stm->lock);
    stm->shutdown = 1;

    waveOutReset(stm->waveout);

    /* Don't need this value, we just want the result to detect invalid
       handle/no device errors than waveOutReset doesn't seem to report. */
    time.wType = TIME_SAMPLES;
    r = waveOutGetPosition(stm->waveout, &time, sizeof(time));
    device_valid = !(r == MMSYSERR_INVALHANDLE || r == MMSYSERR_NODRIVER);

    enqueued = NBUFS - stm->free_buffers;
    LeaveCriticalSection(&stm->lock);

    /* Wait for all blocks to complete. */
    while (device_valid && enqueued > 0) {
      DWORD rv = WaitForSingleObject(stm->event, INFINITE);
      XASSERT(rv == WAIT_OBJECT_0);

      EnterCriticalSection(&stm->lock);
      enqueued = NBUFS - stm->free_buffers;
      LeaveCriticalSection(&stm->lock);
    }

    EnterCriticalSection(&stm->lock);

    for (i = 0; i < NBUFS; ++i) {
      if (stm->buffers[i].dwFlags & WHDR_PREPARED) {
        waveOutUnprepareHeader(stm->waveout, &stm->buffers[i], sizeof(stm->buffers[i]));
      }
    }

    waveOutClose(stm->waveout);

    LeaveCriticalSection(&stm->lock);
  }

  if (stm->event) {
    CloseHandle(stm->event);
  }

  DeleteCriticalSection(&stm->lock);

  for (i = 0; i < NBUFS; ++i) {
    free(stm->buffers[i].lpData);
  }

  EnterCriticalSection(&stm->context->lock);
  XASSERT(stm->context->active_streams >= 1);
  stm->context->active_streams -= 1;
  LeaveCriticalSection(&stm->context->lock);

  free(stm);
}

static int
winmm_get_max_channel_count(cubeb * ctx, uint32_t * max_channels)
{
  XASSERT(ctx && max_channels);

  /* We don't support more than two channels in this backend. */
  *max_channels = 2;

  return CUBEB_OK;
}

static int
winmm_get_min_latency(cubeb * ctx, cubeb_stream_params params, uint32_t * latency)
{
  // 100ms minimum, if we are not in a bizarre configuration.
  *latency = ctx->minimum_latency_ms * params.rate / 1000;

  return CUBEB_OK;
}

static int
winmm_get_preferred_sample_rate(cubeb * ctx, uint32_t * rate)
{
  WAVEOUTCAPS woc;
  MMRESULT r;

  r = waveOutGetDevCaps(WAVE_MAPPER, &woc, sizeof(WAVEOUTCAPS));
  if (r != MMSYSERR_NOERROR) {
    return CUBEB_ERROR;
  }

  /* Check if we support 48kHz, but not 44.1kHz. */
  if (!(woc.dwFormats & WAVE_FORMAT_4S16) &&
      woc.dwFormats & WAVE_FORMAT_48S16) {
    *rate = 48000;
    return CUBEB_OK;
  }
  /* Prefer 44.1kHz between 44.1kHz and 48kHz. */
  *rate = 44100;

  return CUBEB_OK;
}

static int
winmm_stream_start(cubeb_stream * stm)
{
  MMRESULT r;

  EnterCriticalSection(&stm->lock);
  r = waveOutRestart(stm->waveout);
  LeaveCriticalSection(&stm->lock);

  if (r != MMSYSERR_NOERROR) {
    return CUBEB_ERROR;
  }

  stm->state_callback(stm, stm->user_ptr, CUBEB_STATE_STARTED);

  return CUBEB_OK;
}

static int
winmm_stream_stop(cubeb_stream * stm)
{
  MMRESULT r;

  EnterCriticalSection(&stm->lock);
  r = waveOutPause(stm->waveout);
  LeaveCriticalSection(&stm->lock);

  if (r != MMSYSERR_NOERROR) {
    return CUBEB_ERROR;
  }

  stm->state_callback(stm, stm->user_ptr, CUBEB_STATE_STOPPED);

  return CUBEB_OK;
}

static int
winmm_stream_get_position(cubeb_stream * stm, uint64_t * position)
{
  MMRESULT r;
  MMTIME time;

  EnterCriticalSection(&stm->lock);
  time.wType = TIME_SAMPLES;
  r = waveOutGetPosition(stm->waveout, &time, sizeof(time));
  LeaveCriticalSection(&stm->lock);

  if (r != MMSYSERR_NOERROR || time.wType != TIME_SAMPLES) {
    return CUBEB_ERROR;
  }

  *position = time.u.sample;

  return CUBEB_OK;
}

static int
winmm_stream_get_latency(cubeb_stream * stm, uint32_t * latency)
{
  MMRESULT r;
  MMTIME time;
  uint64_t written;

  EnterCriticalSection(&stm->lock);
  time.wType = TIME_SAMPLES;
  r = waveOutGetPosition(stm->waveout, &time, sizeof(time));
  written = stm->written;
  LeaveCriticalSection(&stm->lock);

  if (r != MMSYSERR_NOERROR || time.wType != TIME_SAMPLES) {
    return CUBEB_ERROR;
  }

  XASSERT(written - time.u.sample <= UINT32_MAX);
  *latency = (uint32_t) (written - time.u.sample);

  return CUBEB_OK;
}

static int
winmm_stream_set_volume(cubeb_stream * stm, float volume)
{
  EnterCriticalSection(&stm->lock);
  stm->soft_volume = volume;
  LeaveCriticalSection(&stm->lock);
  return CUBEB_OK;
}

#define MM_11025HZ_MASK (WAVE_FORMAT_1M08 | WAVE_FORMAT_1M16 | WAVE_FORMAT_1S08 | WAVE_FORMAT_1S16)
#define MM_22050HZ_MASK (WAVE_FORMAT_2M08 | WAVE_FORMAT_2M16 | WAVE_FORMAT_2S08 | WAVE_FORMAT_2S16)
#define MM_44100HZ_MASK (WAVE_FORMAT_4M08 | WAVE_FORMAT_4M16 | WAVE_FORMAT_4S08 | WAVE_FORMAT_4S16)
#define MM_48000HZ_MASK (WAVE_FORMAT_48M08 | WAVE_FORMAT_48M16 | WAVE_FORMAT_48S08 | WAVE_FORMAT_48S16)
#define MM_96000HZ_MASK (WAVE_FORMAT_96M08 | WAVE_FORMAT_96M16 | WAVE_FORMAT_96S08 | WAVE_FORMAT_96S16)
static void
winmm_calculate_device_rate(cubeb_device_info * info, DWORD formats)
{
  if (formats & MM_11025HZ_MASK) {
    info->min_rate = 11025;
    info->default_rate = 11025;
    info->max_rate = 11025;
  }
  if (formats & MM_22050HZ_MASK) {
    if (info->min_rate == 0) info->min_rate = 22050;
    info->max_rate = 22050;
    info->default_rate = 22050;
  }
  if (formats & MM_44100HZ_MASK) {
    if (info->min_rate == 0) info->min_rate = 44100;
    info->max_rate = 44100;
    info->default_rate = 44100;
  }
  if (formats & MM_48000HZ_MASK) {
    if (info->min_rate == 0) info->min_rate = 48000;
    info->max_rate = 48000;
    info->default_rate = 48000;
  }
  if (formats & MM_96000HZ_MASK) {
    if (info->min_rate == 0) {
      info->min_rate = 96000;
      info->default_rate = 96000;
    }
    info->max_rate = 96000;
  }
}

#define MM_S16_MASK (WAVE_FORMAT_1M16 | WAVE_FORMAT_1S16 | WAVE_FORMAT_2M16 | WAVE_FORMAT_2S16 | WAVE_FORMAT_4M16 | \
    WAVE_FORMAT_4S16 | WAVE_FORMAT_48M16 | WAVE_FORMAT_48S16 | WAVE_FORMAT_96M16 | WAVE_FORMAT_96S16)
static int
winmm_query_supported_formats(UINT devid, DWORD formats,
    cubeb_device_fmt * supfmt, cubeb_device_fmt * deffmt)
{
  WAVEFORMATEXTENSIBLE wfx;

  if (formats & MM_S16_MASK)
    *deffmt = *supfmt = CUBEB_DEVICE_FMT_S16LE;
  else
    *deffmt = *supfmt = 0;

  ZeroMemory(&wfx, sizeof(WAVEFORMATEXTENSIBLE));
  wfx.Format.wFormatTag = WAVE_FORMAT_EXTENSIBLE;
  wfx.Format.nChannels = 2;
  wfx.Format.nSamplesPerSec = 44100;
  wfx.Format.wBitsPerSample = 32;
  wfx.Format.nBlockAlign = (wfx.Format.wBitsPerSample * wfx.Format.nChannels) / 8;
  wfx.Format.nAvgBytesPerSec = wfx.Format.nSamplesPerSec * wfx.Format.nBlockAlign;
  wfx.Format.cbSize = 22;
  wfx.Samples.wValidBitsPerSample = wfx.Format.wBitsPerSample;
  wfx.dwChannelMask = SPEAKER_FRONT_LEFT | SPEAKER_FRONT_RIGHT;
  wfx.SubFormat = KSDATAFORMAT_SUBTYPE_IEEE_FLOAT;
  if (waveOutOpen(NULL, devid, &wfx.Format, 0, 0, WAVE_FORMAT_QUERY) == MMSYSERR_NOERROR)
    *supfmt = (cubeb_device_fmt)(*supfmt | CUBEB_DEVICE_FMT_F32LE);

  return (*deffmt != 0) ? CUBEB_OK : CUBEB_ERROR;
}

static char *
guid_to_cstr(LPGUID guid)
{
  char * ret = malloc(40);
  if (!ret) {
    return NULL;
  }
  _snprintf_s(ret, 40, _TRUNCATE,
      "{%08X-%04X-%04X-%02X%02X-%02X%02X%02X%02X%02X%02X}",
      guid->Data1, guid->Data2, guid->Data3,
      guid->Data4[0], guid->Data4[1], guid->Data4[2], guid->Data4[3],
      guid->Data4[4], guid->Data4[5], guid->Data4[6], guid->Data4[7]);
  return ret;
}

static cubeb_device_pref
winmm_query_preferred_out_device(UINT devid)
{
  DWORD mmpref = WAVE_MAPPER, compref = WAVE_MAPPER, status;
  cubeb_device_pref ret = CUBEB_DEVICE_PREF_NONE;

  if (waveOutMessage((HWAVEOUT) WAVE_MAPPER, DRVM_MAPPER_PREFERRED_GET,
        (DWORD_PTR)&mmpref, (DWORD_PTR)&status) == MMSYSERR_NOERROR &&
      devid == mmpref)
    ret |= CUBEB_DEVICE_PREF_MULTIMEDIA | CUBEB_DEVICE_PREF_NOTIFICATION;

  if (waveOutMessage((HWAVEOUT) WAVE_MAPPER, DRVM_MAPPER_CONSOLEVOICECOM_GET,
        (DWORD_PTR)&compref, (DWORD_PTR)&status) == MMSYSERR_NOERROR &&
      devid == compref)
    ret |= CUBEB_DEVICE_PREF_VOICE;

  return ret;
}

static char *
device_id_idx(UINT devid)
{
  char * ret = malloc(16);
  if (!ret) {
    return NULL;
  }
  _snprintf_s(ret, 16, _TRUNCATE, "%u", devid);
  return ret;
}

static void
winmm_create_device_from_outcaps2(cubeb_device_info * ret, LPWAVEOUTCAPS2A caps, UINT devid)
{
  XASSERT(ret);
  ret->devid = (cubeb_devid) devid;
  ret->device_id = device_id_idx(devid);
  ret->friendly_name = _strdup(caps->szPname);
  ret->group_id = guid_to_cstr(&caps->ProductGuid);
  ret->vendor_name = guid_to_cstr(&caps->ManufacturerGuid);

  ret->type = CUBEB_DEVICE_TYPE_OUTPUT;
  ret->state = CUBEB_DEVICE_STATE_ENABLED;
  ret->preferred = winmm_query_preferred_out_device(devid);

  ret->max_channels = caps->wChannels;
  winmm_calculate_device_rate(ret, caps->dwFormats);
  winmm_query_supported_formats(devid, caps->dwFormats,
      &ret->format, &ret->default_format);

  /* Hardcoded latency estimates... */
  ret->latency_lo = 100 * ret->default_rate / 1000;
  ret->latency_hi = 200 * ret->default_rate / 1000;
}

static void
winmm_create_device_from_outcaps(cubeb_device_info * ret, LPWAVEOUTCAPSA caps, UINT devid)
{
  XASSERT(ret);
  ret->devid = (cubeb_devid) devid;
  ret->device_id = device_id_idx(devid);
  ret->friendly_name = _strdup(caps->szPname);
  ret->group_id = NULL;
  ret->vendor_name = NULL;

  ret->type = CUBEB_DEVICE_TYPE_OUTPUT;
  ret->state = CUBEB_DEVICE_STATE_ENABLED;
  ret->preferred = winmm_query_preferred_out_device(devid);

  ret->max_channels = caps->wChannels;
  winmm_calculate_device_rate(ret, caps->dwFormats);
  winmm_query_supported_formats(devid, caps->dwFormats,
      &ret->format, &ret->default_format);

  /* Hardcoded latency estimates... */
  ret->latency_lo = 100 * ret->default_rate / 1000;
  ret->latency_hi = 200 * ret->default_rate / 1000;
}

static cubeb_device_pref
winmm_query_preferred_in_device(UINT devid)
{
  DWORD mmpref = WAVE_MAPPER, compref = WAVE_MAPPER, status;
  cubeb_device_pref ret = CUBEB_DEVICE_PREF_NONE;

  if (waveInMessage((HWAVEIN) WAVE_MAPPER, DRVM_MAPPER_PREFERRED_GET,
        (DWORD_PTR)&mmpref, (DWORD_PTR)&status) == MMSYSERR_NOERROR &&
      devid == mmpref)
    ret |= CUBEB_DEVICE_PREF_MULTIMEDIA | CUBEB_DEVICE_PREF_NOTIFICATION;

  if (waveInMessage((HWAVEIN) WAVE_MAPPER, DRVM_MAPPER_CONSOLEVOICECOM_GET,
        (DWORD_PTR)&compref, (DWORD_PTR)&status) == MMSYSERR_NOERROR &&
      devid == compref)
    ret |= CUBEB_DEVICE_PREF_VOICE;

  return ret;
}

static void
winmm_create_device_from_incaps2(cubeb_device_info * ret, LPWAVEINCAPS2A caps, UINT devid)
{
  XASSERT(ret);
  ret->devid = (cubeb_devid) devid;
  ret->device_id = device_id_idx(devid);
  ret->friendly_name = _strdup(caps->szPname);
  ret->group_id = guid_to_cstr(&caps->ProductGuid);
  ret->vendor_name = guid_to_cstr(&caps->ManufacturerGuid);

  ret->type = CUBEB_DEVICE_TYPE_INPUT;
  ret->state = CUBEB_DEVICE_STATE_ENABLED;
  ret->preferred = winmm_query_preferred_in_device(devid);

  ret->max_channels = caps->wChannels;
  winmm_calculate_device_rate(ret, caps->dwFormats);
  winmm_query_supported_formats(devid, caps->dwFormats,
      &ret->format, &ret->default_format);

  /* Hardcoded latency estimates... */
  ret->latency_lo = 100 * ret->default_rate / 1000;
  ret->latency_hi = 200 * ret->default_rate / 1000;
}

static void
winmm_create_device_from_incaps(cubeb_device_info * ret, LPWAVEINCAPSA caps, UINT devid)
{
  XASSERT(ret);
  ret->devid = (cubeb_devid) devid;
  ret->device_id = device_id_idx(devid);
  ret->friendly_name = _strdup(caps->szPname);
  ret->group_id = NULL;
  ret->vendor_name = NULL;

  ret->type = CUBEB_DEVICE_TYPE_INPUT;
  ret->state = CUBEB_DEVICE_STATE_ENABLED;
  ret->preferred = winmm_query_preferred_in_device(devid);

  ret->max_channels = caps->wChannels;
  winmm_calculate_device_rate(ret, caps->dwFormats);
  winmm_query_supported_formats(devid, caps->dwFormats,
      &ret->format, &ret->default_format);

  /* Hardcoded latency estimates... */
  ret->latency_lo = 100 * ret->default_rate / 1000;
  ret->latency_hi = 200 * ret->default_rate / 1000;
}

static int
winmm_enumerate_devices(cubeb * context, cubeb_device_type type,
                        cubeb_device_collection * collection)
{
  UINT i, incount, outcount, total;
  cubeb_device_info * devices;
  cubeb_device_info * dev;

  outcount = waveOutGetNumDevs();
  incount = waveInGetNumDevs();
  total = outcount + incount;

  devices = calloc(total, sizeof(cubeb_device_info));
  collection->count = 0;

  if (type & CUBEB_DEVICE_TYPE_OUTPUT) {
    WAVEOUTCAPSA woc;
    WAVEOUTCAPS2A woc2;

    ZeroMemory(&woc, sizeof(woc));
    ZeroMemory(&woc2, sizeof(woc2));

    for (i = 0; i < outcount; i++) {
      dev = &devices[collection->count];
      if (waveOutGetDevCapsA(i, (LPWAVEOUTCAPSA)&woc2, sizeof(woc2)) == MMSYSERR_NOERROR) {
        winmm_create_device_from_outcaps2(dev, &woc2, i);
        collection->count += 1;
      } else if (waveOutGetDevCapsA(i, &woc, sizeof(woc)) == MMSYSERR_NOERROR) {
        winmm_create_device_from_outcaps(dev, &woc, i);
        collection->count += 1;
      }
    }
  }

  if (type & CUBEB_DEVICE_TYPE_INPUT) {
    WAVEINCAPSA wic;
    WAVEINCAPS2A wic2;

    ZeroMemory(&wic, sizeof(wic));
    ZeroMemory(&wic2, sizeof(wic2));

    for (i = 0; i < incount; i++) {
      dev = &devices[collection->count];
      if (waveInGetDevCapsA(i, (LPWAVEINCAPSA)&wic2, sizeof(wic2)) == MMSYSERR_NOERROR) {
        winmm_create_device_from_incaps2(dev, &wic2, i);
        collection->count += 1;
      } else if (waveInGetDevCapsA(i, &wic, sizeof(wic)) == MMSYSERR_NOERROR) {
        winmm_create_device_from_incaps(dev, &wic, i);
        collection->count += 1;
      }
    }
  }

  collection->device = devices;

  return CUBEB_OK;
}

static int
winmm_device_collection_destroy(cubeb * ctx,
                                cubeb_device_collection * collection)
{
  uint32_t i;
  XASSERT(collection);

  (void) ctx;

  for (i = 0; i < collection->count; i++) {
    free((void *) collection->device[i].device_id);
    free((void *) collection->device[i].friendly_name);
    free((void *) collection->device[i].group_id);
    free((void *) collection->device[i].vendor_name);
  }

  free(collection->device);
  return CUBEB_OK;
}

static struct cubeb_ops const winmm_ops = {
  /*.init =*/ winmm_init,
  /*.get_backend_id =*/ winmm_get_backend_id,
  /*.get_max_channel_count=*/ winmm_get_max_channel_count,
  /*.get_min_latency=*/ winmm_get_min_latency,
  /*.get_preferred_sample_rate =*/ winmm_get_preferred_sample_rate,
  /*.get_preferred_channel_layout =*/ NULL,
  /*.enumerate_devices =*/ winmm_enumerate_devices,
  /*.device_collection_destroy =*/ winmm_device_collection_destroy,
  /*.destroy =*/ winmm_destroy,
  /*.stream_init =*/ winmm_stream_init,
  /*.stream_destroy =*/ winmm_stream_destroy,
  /*.stream_start =*/ winmm_stream_start,
  /*.stream_stop =*/ winmm_stream_stop,
  /*.stream_reset_default_device =*/ NULL,
  /*.stream_get_position =*/ winmm_stream_get_position,
  /*.stream_get_latency = */ winmm_stream_get_latency,
  /*.stream_set_volume =*/ winmm_stream_set_volume,
  /*.stream_set_panning =*/ NULL,
  /*.stream_get_current_device =*/ NULL,
  /*.stream_device_destroy =*/ NULL,
  /*.stream_register_device_changed_callback=*/ NULL,
  /*.register_device_collection_changed =*/ NULL
};
