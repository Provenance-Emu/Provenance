/*
 * Copyright © 2011 Mozilla Foundation
 *
 * This program is made available under an ISC-style license.  See the
 * accompanying file LICENSE for details.
 */
#if !defined(CUBEB_c2f983e9_c96f_e71c_72c3_bbf62992a382)
#define CUBEB_c2f983e9_c96f_e71c_72c3_bbf62992a382

#include <stdint.h>
#include <stdlib.h>
#include "cubeb_export.h"

#if defined(__cplusplus)
extern "C" {
#endif

/** @mainpage

    @section intro Introduction

    This is the documentation for the <tt>libcubeb</tt> C API.
    <tt>libcubeb</tt> is a callback-based audio API library allowing the
    authoring of portable multiplatform audio playback and recording.

    @section example Example code

    This example shows how to create a duplex stream that pipes the microphone
    to the speakers, with minimal latency and the proper sample-rate for the
    platform.

    @code
    cubeb * app_ctx;
    cubeb_init(&app_ctx, "Example Application");
    int rv;
    uint32_t rate;
    uint32_t latency_frames;
    uint64_t ts;

    rv = cubeb_get_min_latency(app_ctx, &output_params, &latency_frames);
    if (rv != CUBEB_OK) {
      fprintf(stderr, "Could not get minimum latency");
      return rv;
    }

    rv = cubeb_get_preferred_sample_rate(app_ctx, output_params, &rate);
    if (rv != CUBEB_OK) {
      fprintf(stderr, "Could not get preferred sample-rate");
      return rv;
    }

    cubeb_stream_params output_params;
    output_params.format = CUBEB_SAMPLE_FLOAT32NE;
    output_params.rate = rate;
    output_params.channels = 2;

    cubeb_stream_params input_params;
    output_params.format = CUBEB_SAMPLE_FLOAT32NE;
    output_params.rate = rate;
    output_params.channels = 1;

    cubeb_stream * stm;
    rv = cubeb_stream_init(app_ctx, &stm, "Example Stream 1",
                           NULL, input_params,
                           NULL, output_params,
                           latency_frames,
                           data_cb, state_cb,
                           NULL);
    if (rv != CUBEB_OK) {
      fprintf(stderr, "Could not open the stream");
      return rv;
    }

    rv = cubeb_stream_start(stm);
    if (rv != CUBEB_OK) {
      fprintf(stderr, "Could not start the stream");
      return rv;
    }
    for (;;) {
      cubeb_stream_get_position(stm, &ts);
      printf("time=%llu\n", ts);
      sleep(1);
    }
    rv = cubeb_stream_stop(stm);
    if (rv != CUBEB_OK) {
      fprintf(stderr, "Could not stop the stream");
      return rv;
    }

    cubeb_stream_destroy(stm);
    cubeb_destroy(app_ctx);
    @endcode

    @code
    long data_cb(cubeb_stream * stm, void * user,
                 void * input_buffer, void * output_buffer, long nframes)
    {
      float * in  = input_buffer;
      float * out = output_buffer;

      for (i = 0; i < nframes; ++i) {
        for (c = 0; c < 2; ++c) {
          buf[i][c] = in[i];
        }
      }
      return nframes;
    }
    @endcode

    @code
    void state_cb(cubeb_stream * stm, void * user, cubeb_state state)
    {
      printf("state=%d\n", state);
    }
    @endcode
*/

/** @file
    The <tt>libcubeb</tt> C API. */

typedef struct cubeb cubeb;               /**< Opaque handle referencing the application state. */
typedef struct cubeb_stream cubeb_stream; /**< Opaque handle referencing the stream state. */

/** Sample format enumeration. */
typedef enum {
  /**< Little endian 16-bit signed PCM. */
  CUBEB_SAMPLE_S16LE,
  /**< Big endian 16-bit signed PCM. */
  CUBEB_SAMPLE_S16BE,
  /**< Little endian 32-bit IEEE floating point PCM. */
  CUBEB_SAMPLE_FLOAT32LE,
  /**< Big endian 32-bit IEEE floating point PCM. */
  CUBEB_SAMPLE_FLOAT32BE,
#if defined(WORDS_BIGENDIAN) || defined(__BIG_ENDIAN__)
  /**< Native endian 16-bit signed PCM. */
  CUBEB_SAMPLE_S16NE = CUBEB_SAMPLE_S16BE,
  /**< Native endian 32-bit IEEE floating point PCM. */
  CUBEB_SAMPLE_FLOAT32NE = CUBEB_SAMPLE_FLOAT32BE
#else
  /**< Native endian 16-bit signed PCM. */
  CUBEB_SAMPLE_S16NE = CUBEB_SAMPLE_S16LE,
  /**< Native endian 32-bit IEEE floating point PCM. */
  CUBEB_SAMPLE_FLOAT32NE = CUBEB_SAMPLE_FLOAT32LE
#endif
} cubeb_sample_format;

/** An opaque handle used to refer a particular input or output device
 *  across calls. */
typedef void const * cubeb_devid;

/** Level (verbosity) of logging for a particular cubeb context. */
typedef enum {
  CUBEB_LOG_DISABLED = 0, /** < Logging disabled */
  CUBEB_LOG_NORMAL = 1, /**< Logging lifetime operation (creation/destruction). */
  CUBEB_LOG_VERBOSE = 2, /**< Verbose logging of callbacks, can have performance implications. */
} cubeb_log_level;

/** SMPTE channel layout (also known as wave order)
 * DUAL-MONO      L   R
 * DUAL-MONO-LFE  L   R   LFE
 * MONO           M
 * MONO-LFE       M   LFE
 * STEREO         L   R
 * STEREO-LFE     L   R   LFE
 * 3F             L   R   C
 * 3F-LFE         L   R   C    LFE
 * 2F1            L   R   S
 * 2F1-LFE        L   R   LFE  S
 * 3F1            L   R   C    S
 * 3F1-LFE        L   R   C    LFE S
 * 2F2            L   R   LS   RS
 * 2F2-LFE        L   R   LFE  LS   RS
 * 3F2            L   R   C    LS   RS
 * 3F2-LFE        L   R   C    LFE  LS   RS
 * 3F3R-LFE       L   R   C    LFE  RC   LS   RS
 * 3F4-LFE        L   R   C    LFE  RLS  RRS  LS   RS
 *
 * The abbreviation of channel name is defined in following table:
 * Abbr  Channel name
 * ---------------------------
 * M     Mono
 * L     Left
 * R     Right
 * C     Center
 * LS    Left Surround
 * RS    Right Surround
 * RLS   Rear Left Surround
 * RC    Rear Center
 * RRS   Rear Right Surround
 * LFE   Low Frequency Effects
 */

typedef enum {
  CUBEB_LAYOUT_UNDEFINED, // Indicate the speaker's layout is undefined.
  CUBEB_LAYOUT_DUAL_MONO,
  CUBEB_LAYOUT_DUAL_MONO_LFE,
  CUBEB_LAYOUT_MONO,
  CUBEB_LAYOUT_MONO_LFE,
  CUBEB_LAYOUT_STEREO,
  CUBEB_LAYOUT_STEREO_LFE,
  CUBEB_LAYOUT_3F,
  CUBEB_LAYOUT_3F_LFE,
  CUBEB_LAYOUT_2F1,
  CUBEB_LAYOUT_2F1_LFE,
  CUBEB_LAYOUT_3F1,
  CUBEB_LAYOUT_3F1_LFE,
  CUBEB_LAYOUT_2F2,
  CUBEB_LAYOUT_2F2_LFE,
  CUBEB_LAYOUT_3F2,
  CUBEB_LAYOUT_3F2_LFE,
  CUBEB_LAYOUT_3F3R_LFE,
  CUBEB_LAYOUT_3F4_LFE,
  CUBEB_LAYOUT_MAX
} cubeb_channel_layout;

/** Stream format initialization parameters. */
typedef struct {
  cubeb_sample_format format;   /**< Requested sample format.  One of
                                     #cubeb_sample_format. */
  uint32_t rate;                /**< Requested sample rate.  Valid range is [1000, 192000]. */
  uint32_t channels;            /**< Requested channel count.  Valid range is [1, 8]. */
  cubeb_channel_layout layout;  /**< Requested channel layout. This must be consistent with the provided channels. */
} cubeb_stream_params;

/** Audio device description */
typedef struct {
  char * output_name; /**< The name of the output device */
  char * input_name; /**< The name of the input device */
} cubeb_device;

/** Stream states signaled via state_callback. */
typedef enum {
  CUBEB_STATE_STARTED, /**< Stream started. */
  CUBEB_STATE_STOPPED, /**< Stream stopped. */
  CUBEB_STATE_DRAINED, /**< Stream drained. */
  CUBEB_STATE_ERROR    /**< Stream disabled due to error. */
} cubeb_state;

/** Result code enumeration. */
enum {
  CUBEB_OK = 0,                       /**< Success. */
  CUBEB_ERROR = -1,                   /**< Unclassified error. */
  CUBEB_ERROR_INVALID_FORMAT = -2,    /**< Unsupported #cubeb_stream_params requested. */
  CUBEB_ERROR_INVALID_PARAMETER = -3, /**< Invalid parameter specified. */
  CUBEB_ERROR_NOT_SUPPORTED = -4,     /**< Optional function not implemented in current backend. */
  CUBEB_ERROR_DEVICE_UNAVAILABLE = -5 /**< Device specified by #cubeb_devid not available. */
};

/**
 * Whether a particular device is an input device (e.g. a microphone), or an
 * output device (e.g. headphones). */
typedef enum {
  CUBEB_DEVICE_TYPE_UNKNOWN,
  CUBEB_DEVICE_TYPE_INPUT,
  CUBEB_DEVICE_TYPE_OUTPUT
} cubeb_device_type;

/**
 * The state of a device.
 */
typedef enum {
  CUBEB_DEVICE_STATE_DISABLED, /**< The device has been disabled at the system level. */
  CUBEB_DEVICE_STATE_UNPLUGGED, /**< The device is enabled, but nothing is plugged into it. */
  CUBEB_DEVICE_STATE_ENABLED /**< The device is enabled. */
} cubeb_device_state;

/**
 * Architecture specific sample type.
 */
typedef enum {
  CUBEB_DEVICE_FMT_S16LE          = 0x0010, /**< 16-bit integers, Little Endian. */
  CUBEB_DEVICE_FMT_S16BE          = 0x0020, /**< 16-bit integers, Big Endian. */
  CUBEB_DEVICE_FMT_F32LE          = 0x1000, /**< 32-bit floating point, Little Endian. */
  CUBEB_DEVICE_FMT_F32BE          = 0x2000  /**< 32-bit floating point, Big Endian. */
} cubeb_device_fmt;

#if defined(WORDS_BIGENDIAN) || defined(__BIG_ENDIAN__)
/** 16-bit integers, native endianess, when on a Big Endian environment. */
#define CUBEB_DEVICE_FMT_S16NE     CUBEB_DEVICE_FMT_S16BE
/** 32-bit floating points, native endianess, when on a Big Endian environment. */
#define CUBEB_DEVICE_FMT_F32NE     CUBEB_DEVICE_FMT_F32BE
#else
/** 16-bit integers, native endianess, when on a Little Endian environment. */
#define CUBEB_DEVICE_FMT_S16NE     CUBEB_DEVICE_FMT_S16LE
/** 32-bit floating points, native endianess, when on a Little Endian
 *  environment. */
#define CUBEB_DEVICE_FMT_F32NE     CUBEB_DEVICE_FMT_F32LE
#endif
/** All the 16-bit integers types. */
#define CUBEB_DEVICE_FMT_S16_MASK  (CUBEB_DEVICE_FMT_S16LE | CUBEB_DEVICE_FMT_S16BE)
/** All the 32-bit floating points types. */
#define CUBEB_DEVICE_FMT_F32_MASK  (CUBEB_DEVICE_FMT_F32LE | CUBEB_DEVICE_FMT_F32BE)
/** All the device formats types. */
#define CUBEB_DEVICE_FMT_ALL       (CUBEB_DEVICE_FMT_S16_MASK | CUBEB_DEVICE_FMT_F32_MASK)

/** Channel type for a `cubeb_stream`. Depending on the backend and platform
 * used, this can control inter-stream interruption, ducking, and volume
 * control.
 */
typedef enum {
  CUBEB_DEVICE_PREF_NONE          = 0x00,
  CUBEB_DEVICE_PREF_MULTIMEDIA    = 0x01,
  CUBEB_DEVICE_PREF_VOICE         = 0x02,
  CUBEB_DEVICE_PREF_NOTIFICATION  = 0x04,
  CUBEB_DEVICE_PREF_ALL           = 0x0F
} cubeb_device_pref;

/** This structure holds the characteristics
 *  of an input or output audio device. It is obtained using
 *  `cubeb_enumerate_devices`, which returns these structures via
 *  `cubeb_device_collection` and must be destroyed via
 *  `cubeb_device_collection_destroy`. */
typedef struct {
  cubeb_devid devid;          /**< Device identifier handle. */
  char const * device_id;     /**< Device identifier which might be presented in a UI. */
  char const * friendly_name; /**< Friendly device name which might be presented in a UI. */
  char const * group_id;      /**< Two devices have the same group identifier if they belong to the same physical device; for example a headset and microphone. */
  char const * vendor_name;   /**< Optional vendor name, may be NULL. */

  cubeb_device_type type;     /**< Type of device (Input/Output). */
  cubeb_device_state state;   /**< State of device disabled/enabled/unplugged. */
  cubeb_device_pref preferred;/**< Preferred device. */

  cubeb_device_fmt format;    /**< Sample format supported. */
  cubeb_device_fmt default_format; /**< The default sample format for this device. */
  uint32_t max_channels;      /**< Channels. */
  uint32_t default_rate;      /**< Default/Preferred sample rate. */
  uint32_t max_rate;          /**< Maximum sample rate supported. */
  uint32_t min_rate;          /**< Minimum sample rate supported. */

  uint32_t latency_lo;        /**< Lowest possible latency in frames. */
  uint32_t latency_hi;        /**< Higest possible latency in frames. */
} cubeb_device_info;

/** Device collection.
 *  Returned by `cubeb_enumerate_devices` and destroyed by
 *  `cubeb_device_collection_destroy`. */
typedef struct {
  cubeb_device_info * device; /**< Array of pointers to device info. */
  size_t count;               /**< Device count in collection. */
} cubeb_device_collection;

/** User supplied data callback.
    - Calling other cubeb functions from this callback is unsafe.
    - The code in the callback should be non-blocking.
    - Returning less than the number of frames this callback asks for or
      provides puts the stream in drain mode. This callback will not be called
      again, and the state callback will be called with CUBEB_STATE_DRAINED when
      all the frames have been output.
    @param stream The stream for which this callback fired.
    @param user_ptr The pointer passed to cubeb_stream_init.
    @param input_buffer A pointer containing the input data, or nullptr
                        if this is an output-only stream.
    @param output_buffer A pointer to a buffer to be filled with audio samples,
                         or nullptr if this is an input-only stream.
    @param nframes The number of frames of the two buffer.
    @retval Number of frames written to the output buffer. If this number is
            less than nframes, then the stream will start to drain.
    @retval CUBEB_ERROR on error, in which case the data callback will stop
            and the stream will enter a shutdown state. */
typedef long (* cubeb_data_callback)(cubeb_stream * stream,
                                     void * user_ptr,
                                     void const * input_buffer,
                                     void * output_buffer,
                                     long nframes);

/** User supplied state callback.
    @param stream The stream for this this callback fired.
    @param user_ptr The pointer passed to cubeb_stream_init.
    @param state The new state of the stream. */
typedef void (* cubeb_state_callback)(cubeb_stream * stream,
                                      void * user_ptr,
                                      cubeb_state state);

/**
 * User supplied callback called when the underlying device changed.
 * @param user The pointer passed to cubeb_stream_init. */
typedef void (* cubeb_device_changed_callback)(void * user_ptr);

/**
 * User supplied callback called when the underlying device collection changed.
 * @param context A pointer to the cubeb context.
 * @param user_ptr The pointer passed to cubeb_register_device_collection_changed. */
typedef void (* cubeb_device_collection_changed_callback)(cubeb * context,
                                                          void * user_ptr);

/** User supplied callback called when a message needs logging. */
typedef void (* cubeb_log_callback)(char const * fmt, ...);

/** Initialize an application context.  This will perform any library or
    application scoped initialization.
    @param context A out param where an opaque pointer to the application
                   context will be returned.
    @param context_name A name for the context. Depending on the platform this
                        can appear in different locations.
    @param backend_name The name of the cubeb backend user desires to select.
                        Accepted values self-documented in cubeb.c: init_oneshot
                        If NULL, a default ordering is used for backend choice.
                        A valid choice overrides all other possible backends,
                        so long as the backend was included at compile time.
    @retval CUBEB_OK in case of success.
    @retval CUBEB_ERROR in case of error, for example because the host
                        has no audio hardware. */
CUBEB_EXPORT int cubeb_init(cubeb ** context, char const * context_name,
                                              char const * backend_name);

/** Get a read-only string identifying this context's current backend.
    @param context A pointer to the cubeb context.
    @retval Read-only string identifying current backend. */
CUBEB_EXPORT char const * cubeb_get_backend_id(cubeb * context);

/** Get the maximum possible number of channels.
    @param context A pointer to the cubeb context.
    @param max_channels The maximum number of channels.
    @retval CUBEB_OK
    @retval CUBEB_ERROR_INVALID_PARAMETER
    @retval CUBEB_ERROR_NOT_SUPPORTED
    @retval CUBEB_ERROR */
CUBEB_EXPORT int cubeb_get_max_channel_count(cubeb * context, uint32_t * max_channels);

/** Get the minimal latency value, in frames, that is guaranteed to work
    when creating a stream for the specified sample rate. This is platform,
    hardware and backend dependent.
    @param context A pointer to the cubeb context.
    @param params On some backends, the minimum achievable latency depends on
                  the characteristics of the stream.
    @param latency_frames The latency value, in frames, to pass to
                          cubeb_stream_init.
    @retval CUBEB_OK
    @retval CUBEB_ERROR_INVALID_PARAMETER
    @retval CUBEB_ERROR_NOT_SUPPORTED */
CUBEB_EXPORT int cubeb_get_min_latency(cubeb * context,
                                       cubeb_stream_params * params,
                                       uint32_t * latency_frames);

/** Get the preferred sample rate for this backend: this is hardware and
    platform dependent, and can avoid resampling, and/or trigger fastpaths.
    @param context A pointer to the cubeb context.
    @param rate The samplerate (in Hz) the current configuration prefers.
    @retval CUBEB_OK
    @retval CUBEB_ERROR_INVALID_PARAMETER
    @retval CUBEB_ERROR_NOT_SUPPORTED */
CUBEB_EXPORT int cubeb_get_preferred_sample_rate(cubeb * context, uint32_t * rate);

/** Get the preferred layout for this backend: this is hardware and
    platform dependent.
    @param context A pointer to the cubeb context.
    @param layout The layout of the current speaker configuration.
    @retval CUBEB_OK
    @retval CUBEB_ERROR_INVALID_PARAMETER
    @retval CUBEB_ERROR_NOT_SUPPORTED */
CUBEB_EXPORT int cubeb_get_preferred_channel_layout(cubeb * context, cubeb_channel_layout * layout);

/** Destroy an application context. This must be called after all stream have
 *  been destroyed.
    @param context A pointer to the cubeb context.*/
CUBEB_EXPORT void cubeb_destroy(cubeb * context);

/** Initialize a stream associated with the supplied application context.
    @param context A pointer to the cubeb context.
    @param stream An out parameter to be filled with the an opaque pointer to a
                  cubeb stream.
    @param stream_name A name for this stream.
    @param input_device Device for the input side of the stream. If NULL the
                        default input device is used.
    @param input_stream_params Parameters for the input side of the stream, or
                               NULL if this stream is output only.
    @param output_device Device for the output side of the stream. If NULL the
                         default output device is used.
    @param output_stream_params Parameters for the output side of the stream, or
                                NULL if this stream is input only.
    @param latency_frames Stream latency in frames.  Valid range
                          is [1, 96000].
    @param data_callback Will be called to preroll data before playback is
                         started by cubeb_stream_start.
    @param state_callback A pointer to a state callback.
    @param user_ptr A pointer that will be passed to the callbacks. This pointer
                    must outlive the life time of the stream.
    @retval CUBEB_OK
    @retval CUBEB_ERROR
    @retval CUBEB_ERROR_INVALID_FORMAT
    @retval CUBEB_ERROR_DEVICE_UNAVAILABLE */
CUBEB_EXPORT int cubeb_stream_init(cubeb * context,
                                   cubeb_stream ** stream,
                                   char const * stream_name,
                                   cubeb_devid input_device,
                                   cubeb_stream_params * input_stream_params,
                                   cubeb_devid output_device,
                                   cubeb_stream_params * output_stream_params,
                                   uint32_t latency_frames,
                                   cubeb_data_callback data_callback,
                                   cubeb_state_callback state_callback,
                                   void * user_ptr);

/** Destroy a stream. `cubeb_stream_stop` MUST be called before destroying a
    stream.
    @param stream The stream to destroy. */
CUBEB_EXPORT void cubeb_stream_destroy(cubeb_stream * stream);

/** Start playback.
    @param stream
    @retval CUBEB_OK
    @retval CUBEB_ERROR */
CUBEB_EXPORT int cubeb_stream_start(cubeb_stream * stream);

/** Stop playback.
    @param stream
    @retval CUBEB_OK
    @retval CUBEB_ERROR */
CUBEB_EXPORT int cubeb_stream_stop(cubeb_stream * stream);

/** Reset stream to the default device.
    @param stream
    @retval CUBEB_OK
    @retval CUBEB_ERROR_INVALID_PARAMETER
    @retval CUBEB_ERROR_NOT_SUPPORTED
    @retval CUBEB_ERROR */
CUBEB_EXPORT int cubeb_stream_reset_default_device(cubeb_stream * stream);

/** Get the current stream playback position.
    @param stream
    @param position Playback position in frames.
    @retval CUBEB_OK
    @retval CUBEB_ERROR */
CUBEB_EXPORT int cubeb_stream_get_position(cubeb_stream * stream, uint64_t * position);

/** Get the latency for this stream, in frames. This is the number of frames
    between the time cubeb acquires the data in the callback and the listener
    can hear the sound.
    @param stream
    @param latency Current approximate stream latency in frames.
    @retval CUBEB_OK
    @retval CUBEB_ERROR_NOT_SUPPORTED
    @retval CUBEB_ERROR */
CUBEB_EXPORT int cubeb_stream_get_latency(cubeb_stream * stream, uint32_t * latency);

/** Set the volume for a stream.
    @param stream the stream for which to adjust the volume.
    @param volume a float between 0.0 (muted) and 1.0 (maximum volume)
    @retval CUBEB_OK
    @retval CUBEB_ERROR_INVALID_PARAMETER volume is outside [0.0, 1.0] or
            stream is an invalid pointer
    @retval CUBEB_ERROR_NOT_SUPPORTED */
CUBEB_EXPORT int cubeb_stream_set_volume(cubeb_stream * stream, float volume);

/** If the stream is stereo, set the left/right panning. If the stream is mono,
    this has no effect.
    @param stream the stream for which to change the panning
    @param panning a number from -1.0 to 1.0. -1.0 means that the stream is
           fully mixed in the left channel, 1.0 means the stream is fully
           mixed in the right channel. 0.0 is equal power in the right and
           left channel (default).
    @retval CUBEB_OK
    @retval CUBEB_ERROR_INVALID_PARAMETER if stream is null or if panning is
            outside the [-1.0, 1.0] range.
    @retval CUBEB_ERROR_NOT_SUPPORTED
    @retval CUBEB_ERROR stream is not mono nor stereo */
CUBEB_EXPORT int cubeb_stream_set_panning(cubeb_stream * stream, float panning);

/** Get the current output device for this stream.
    @param stm the stream for which to query the current output device
    @param device a pointer in which the current output device will be stored.
    @retval CUBEB_OK in case of success
    @retval CUBEB_ERROR_INVALID_PARAMETER if either stm, device or count are
            invalid pointers
    @retval CUBEB_ERROR_NOT_SUPPORTED */
CUBEB_EXPORT int cubeb_stream_get_current_device(cubeb_stream * stm,
                                                 cubeb_device ** const device);

/** Destroy a cubeb_device structure.
    @param stream the stream passed in cubeb_stream_get_current_device
    @param devices the devices to destroy
    @retval CUBEB_OK in case of success
    @retval CUBEB_ERROR_INVALID_PARAMETER if devices is an invalid pointer
    @retval CUBEB_ERROR_NOT_SUPPORTED */
CUBEB_EXPORT int cubeb_stream_device_destroy(cubeb_stream * stream,
                                             cubeb_device * devices);

/** Set a callback to be notified when the output device changes.
    @param stream the stream for which to set the callback.
    @param device_changed_callback a function called whenever the device has
           changed. Passing NULL allow to unregister a function
    @retval CUBEB_OK
    @retval CUBEB_ERROR_INVALID_PARAMETER if either stream or
            device_changed_callback are invalid pointers.
    @retval CUBEB_ERROR_NOT_SUPPORTED */
CUBEB_EXPORT int cubeb_stream_register_device_changed_callback(cubeb_stream * stream,
                                                               cubeb_device_changed_callback device_changed_callback);

/** Returns enumerated devices.
    @param context
    @param devtype device type to include
    @param collection output collection. Must be destroyed with cubeb_device_collection_destroy
    @retval CUBEB_OK in case of success
    @retval CUBEB_ERROR_INVALID_PARAMETER if collection is an invalid pointer
    @retval CUBEB_ERROR_NOT_SUPPORTED */
CUBEB_EXPORT int cubeb_enumerate_devices(cubeb * context,
                                         cubeb_device_type devtype,
                                         cubeb_device_collection * collection);

/** Destroy a cubeb_device_collection, and its `cubeb_device_info`.
    @param context
    @param collection collection to destroy
    @retval CUBEB_OK
    @retval CUBEB_ERROR_INVALID_PARAMETER if collection is an invalid pointer */
CUBEB_EXPORT int cubeb_device_collection_destroy(cubeb * context,
                                                 cubeb_device_collection * collection);

/** Registers a callback which is called when the system detects
    a new device or a device is removed.
    @param context
    @param devtype device type to include
    @param callback a function called whenever the system device list changes.
           Passing NULL allow to unregister a function
    @param user_ptr pointer to user specified data which will be present in
           subsequent callbacks.
    @retval CUBEB_ERROR_NOT_SUPPORTED */
CUBEB_EXPORT int cubeb_register_device_collection_changed(cubeb * context,
                                                          cubeb_device_type devtype,
                                                          cubeb_device_collection_changed_callback callback,
                                                          void * user_ptr);

/** Set a callback to be called with a message.
    @param log_level CUBEB_LOG_VERBOSE, CUBEB_LOG_NORMAL.
    @param log_callback A function called with a message when there is
                        something to log. Pass NULL to unregister.
    @retval CUBEB_OK in case of success.
    @retval CUBEB_ERROR_INVALID_PARAMETER if either context or log_callback are
                                          invalid pointers, or if level is not
                                          in cubeb_log_level. */
CUBEB_EXPORT int cubeb_set_log_callback(cubeb_log_level log_level,
                                        cubeb_log_callback log_callback);

#if defined(__cplusplus)
}
#endif

#endif /* CUBEB_c2f983e9_c96f_e71c_72c3_bbf62992a382 */
