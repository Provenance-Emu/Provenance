//
//  PVLibretro.m
//  PVRetroArch
//
//  Created by Joseph Mattiello on 6/15/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

@import Foundation;
#import "PVLibretro.h"

@import UIKit.UIKeyConstants;
@import AudioToolbox;

#import <PVSupport/PVSupport-Swift.h>

#include "libretro.h"
#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include "dynamic.h"
#include <dynamic/dylib.h>
#include <string/stdstring.h>

#include "command.h"
#include "core_info.h"

#include "managers/state_manager.h"
//#include "audio/audio_driver.h"
//#include "camera/camera_driver.h"
//#include "location/location_driver.h"
//#include "record/record_driver.h"
#include "core.h"
#include "runloop.h"
#include "performance_counters.h"
#include "system.h"
#include "record/record_driver.h"
//#include "queues/message_queue.h"
#include "gfx/video_driver.h"
#include "gfx/video_context_driver.h"
#include "gfx/scaler/scaler.h"
//#include "gfx/video_frame.h"

#include <retro_assert.h>

#include "cores/internal_cores.h"
#include "frontend/frontend_driver.h"
#include "content.h"
#ifdef HAVE_CHEEVOS
#include "cheevos.h"
#endif
#include "retroarch.h"
#include "configuration.h"
#include "general.h"
#include "msg_hash.h"
#include "verbosity.h"

@interface PVLibRetroCore ()
{
    BOOL loaded;
}
@end

video_driver_t video_gl;
video_driver_t video_null;

static struct retro_callbacks   retro_ctx;
static retro_video_refresh_t video_cb;
static retro_audio_sample_t audio_cb;
static retro_audio_sample_batch_t audio_batch_cb;
static retro_environment_t environ_cb;
static retro_input_poll_t input_poll_cb;
static retro_input_state_t input_state_cb;
static struct retro_hw_render_callback* hw_render_callback;
static struct retro_hw_render_context_negotiation_interface* _hw_render_context_negotiation_interface;
static dylib_t lib_handle;

static enum retro_hw_render_context_negotiation_interface_type hw_render_interface_type;
static unsigned hw_render_interface_version;

static retro_frame_time_callback_t frame_time_callback;

static struct retro_camera_callback camera_callbacks;

// MARK: - Runloop
//static rarch_dir_list_t runloop_shader_dir;
static char runloop_fullpath[PATH_MAX_LENGTH];
static char runloop_default_shader_preset[PATH_MAX_LENGTH];
static rarch_system_info_t runloop_system;
static unsigned runloop_pending_windowed_scale;
static struct retro_frame_time_callback runloop_frame_time;
static retro_keyboard_event_t runloop_key_event          = NULL;
static retro_keyboard_event_t runloop_frontend_key_event = NULL;
static retro_usec_t runloop_frame_time_last      = 0;
static unsigned runloop_max_frames               = false;
static bool runloop_force_nonblock               = false;
static bool runloop_frame_time_last_enable       = false;
static bool runloop_set_frame_limit              = false;
static bool runloop_paused                       = false;
static bool runloop_idle                         = false;
static bool runloop_exec                         = false;
static bool runloop_slowmotion                   = false;
static bool runloop_shutdown_initiated           = false;
static bool runloop_core_shutdown_initiated      = false;
static bool runloop_perfcnt_enable               = false;
static bool runloop_overrides_active             = false;
static bool runloop_game_options_active          = false;
//static core_option_manager_t *runloop_core_options = NULL;
#ifdef HAVE_THREADS
static slock_t *_runloop_msg_queue_lock           = NULL;
#endif
//static msg_queue_t *runloop_msg_queue            = NULL;

// MARK: - Config

static char path_libretro[PATH_MAX_LENGTH];

char *config_get_active_core_path_ptr(void) {
    return path_libretro;
}

//const char *config_get_active_core_path(void)
//{
//   return path_libretro;
//}

NSString *privateFrameworkPath(void) {
    NSBundle *bundle = [NSBundle bundleForClass:[_current class]];
    //    const char* path = [bundle.executablePath fileSystemRepresentation];
    NSString *executableName = bundle.infoDictionary[@"CFBundleExecutable"];
    
    NSString *frameworkPath = [NSString stringWithFormat:@"%@/%@", bundle.bundlePath, executableName];
    
    NSArray *fileNames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:frameworkPath error:nil];
    for (NSString *fileName in fileNames) {
        ILOG(@"%@", fileName);
    }
//    NSString *privateFrameworkPath = [[[NSBundle mainBundle] privateFrameworksPath] stringByAppendingPathComponent:frameworkPath];
//    DLOG(@"%@", privateFrameworkPath);
    return frameworkPath;
}

const char *config_get_active_core_path(void) {

    return [privateFrameworkPath() fileSystemRepresentation];
}

bool config_active_core_path_is_empty(void) {
    return !path_libretro[0];
}

size_t config_get_active_core_path_size(void) {
    DLOG(@"");
    return privateFrameworkPath().length; //sizeof(path_libretro);
}

void config_set_active_core_path(const char *path) {
    DLOG(@"%s", path);
    strlcpy(path_libretro, path, sizeof(path_libretro));
}

void config_clear_active_core_path(void) {
    DLOG(@"");
    *path_libretro = '\0';
}

const char *config_get_active_path(void)
{
    //   global_t   *global          = global_get_ptr();
    //
    //   if (!string_is_empty(global->path.config))
    //	  return global->path.config;
    
    
    return NULL;
}

void config_free_state(void)
{
}


// MARK: - Retro typedefs
typedef void *dylib_t;
typedef void (*function_t)(void);

// MARK: - Retro Macros

void retroarch_fail(int error_code, const char *error) {
    ELOG(@"Code: %i, Error: %s", error_code, error);
}

static void load_symbols(enum rarch_core_type type, struct retro_core_t *current_core);
// MARK: - Keyboard

static retro_keyboard_event_t keyboard_event;

// MARK: - Inputs

bool core_set_poll_type(unsigned *type) {
    GET_CURRENT_OR_RETURN(false);
    current->core_poll_type = *type;
    return true;
}

/**
 * input_poll:
 *
 * Input polling callback function.
 **/
void input_poll(void);

/**
 * input_state:
 * @port                 : user number.
 * @device               : device identifier of user.
 * @idx                  : index value of user.
 * @id                   : identifier of key pressed by user.
 *
 * Input state callback function.
 *
 * Returns: Non-zero if the given key (identified by @id) was pressed by the user
 * (assigned to @port).
 **/
int16_t input_state(unsigned port, unsigned device,
                    unsigned idx, unsigned id)
{
    int16_t res                     = 0;
    //   settings_t *settings            = config_get_ptr();
    
    //
    //   device &= RETRO_DEVICE_MASK;
    //
    //   if (bsv_movie_ctl(BSV_MOVIE_CTL_PLAYBACK_ON, NULL))
    //   {
    //      int16_t ret;
    //      if (bsv_movie_ctl(BSV_MOVIE_CTL_GET_INPUT, &ret))
    //         return ret;
    //
    //      bsv_movie_ctl(BSV_MOVIE_CTL_SET_END, NULL);
    //   }
    //
    //   if (settings->input.remap_binds_enable)
    //      input_remapping_state(port, &device, &idx, &id);
    //
    //   if (!input_driver_is_flushing_input()
    //         && !input_driver_is_libretro_input_blocked())
    //   {
    //      if (((id < RARCH_FIRST_META_KEY) || (device == RETRO_DEVICE_KEYBOARD)))
    //         res = current_input->input_state(
    //               current_input_data, libretro_input_binds, port, device, idx, id);
    //
    //#ifdef HAVE_OVERLAY
    //      input_state_overlay(&res, port, device, idx, id);
    //#endif
    //
    //#ifdef HAVE_NETWORKGAMEPAD
    //      input_remote_state(&res, port, device, idx, id);
    //#endif
    //   }
    //
    //   /* Don't allow turbo for D-pad. */
    //   if (device == RETRO_DEVICE_JOYPAD && (id < RETRO_DEVICE_ID_JOYPAD_UP ||
    //            id > RETRO_DEVICE_ID_JOYPAD_RIGHT))
    //   {
    //      /*
    //       * Apply turbo button if activated.
    //       *
    //       * If turbo button is held, all buttons pressed except
    //       * for D-pad will go into a turbo mode. Until the button is
    //       * released again, the input state will be modulated by a
    //       * periodic pulse defined by the configured duty cycle.
    //       */
    //      if (res && input_driver_turbo_btns.frame_enable[port])
    //         input_driver_turbo_btns.enable[port] |= (1 << id);
    //      else if (!res)
    //         input_driver_turbo_btns.enable[port] &= ~(1 << id);
    //
    //      if (input_driver_turbo_btns.enable[port] & (1 << id))
    //      {
    //         /* if turbo button is enabled for this key ID */
    //         res = res && ((input_driver_turbo_btns.count % settings->input.turbo_period)
    //               < settings->input.turbo_duty_cycle);
    //      }
    //   }
    //
    //   if (bsv_movie_ctl(BSV_MOVIE_CTL_PLAYBACK_OFF, NULL))
    //      bsv_movie_ctl(BSV_MOVIE_CTL_SET_INPUT, &res);
    
    return res;
}


static void core_input_state_poll_maybe(void)
{
    GET_CURRENT_OR_RETURN();
    if (current->core_poll_type == POLL_TYPE_NORMAL)
        input_poll();
}

static int16_t core_input_state_poll(unsigned port,
                                     unsigned device, unsigned idx, unsigned id)
{
    GET_CURRENT_OR_RETURN(0);
    if (current->core_poll_type == POLL_TYPE_LATE)
    {
        if (!current->core_input_polled)
            input_poll();
        
        current->core_input_polled = true;
    }
    return input_state(port, device, idx, id);
}

void core_set_input_state(retro_ctx_input_state_info_t *info)
{
    GET_CURRENT_OR_RETURN();
    current->core->retro_set_input_state(info->cb);
}

bool core_set_controller_port_device(retro_ctx_controller_info_t *pad) {
    GET_CURRENT_OR_RETURN(false);
    if (!pad)
        return false;
    current->core->retro_set_controller_port_device(pad->port, pad->device);
    return true;
}

bool core_poll(void) {
    GET_CURRENT_OR_RETURN(false);
    if (!retro_ctx.poll_cb)
        return false;
    retro_ctx.poll_cb();
    return true;
}

static void RETRO_CALLCONV input_poll_callback(void)
{
    VLOG(@"poll callback");
    GET_CURRENT_OR_RETURN();
    [current pollControllers];
}

// MARK: - Sensors

static bool sensor_state(unsigned port,
      enum retro_sensor_action action, unsigned event_rate)
{
    GET_CURRENT_OR_RETURN(false);

   if (event_rate == 0)
      event_rate = 60;

   switch (action)
   {
#if TARGET_OS_TV
#else
       case RETRO_SENSOR_ACCELEROMETER_ENABLE: {
           return [current startAccelerometers];
       }
       case RETRO_SENSOR_ACCELEROMETER_DISABLE: {
           [current stopAccelerometers];
           return true;
       }
       case RETRO_SENSOR_GYROSCOPE_ENABLE: {
           return [current startGyro];
       }
       case RETRO_SENSOR_GYROSCOPE_DISABLE: {
           [current stopGyro];
           return true;
       }
       case RETRO_SENSOR_ILLUMINANCE_ENABLE:
           return [current startIlluminance];
       case RETRO_SENSOR_ILLUMINANCE_DISABLE: {
           [current stopIlluminance];
           return true;
       }
       case RETRO_SENSOR_DUMMY:
           return false;
#endif
      default:
         return false;
   }

   return false;
}

static float get_sensor_input(unsigned port, unsigned id) {
    GET_CURRENT_OR_RETURN(0);
    DLOG(@"port %u, id %u", port, id);
     // TODO: Port to contoller?
#if TARGET_OS_TV
#else
   switch (id)
   {
      case RETRO_SENSOR_ACCELEROMETER_X:
           return [current accelerometerStateX];
      case RETRO_SENSOR_ACCELEROMETER_Y:
           return [current accelerometerStateY];
      case RETRO_SENSOR_ACCELEROMETER_Z:
           return [current accelerometerStateZ];
       case RETRO_SENSOR_GYROSCOPE_X:
           return [current gyroscopeStateX];
       case RETRO_SENSOR_GYROSCOPE_Y:
           return [current gyroscopeStateY];
       case RETRO_SENSOR_GYROSCOPE_Z:
           return [current gyroscopeStateZ];
       case RETRO_SENSOR_ILLUMINANCE:
           return [current illuminance];
   }
#endif

   return 0;
}

// MARK: - Location

static bool location_start() {
    GET_CURRENT_OR_RETURN(false);
    return [current locationStart];
}

static void location_stop() {
    GET_CURRENT_OR_RETURN();
    [current locationStop];
}

static bool location_get_position(double *lat, double *lon,
                                                           double *horiz_accuracy, double *vert_accuracy) {
    GET_CURRENT_OR_RETURN(false);
    return [current locationGetPositionWithLatitude:lat
                                          longitude:lon
                                 horizontalAccuracy:horiz_accuracy
                                   verticleAccuracy:vert_accuracy];
}

static void location_set_interval(unsigned interval_ms,
                                                           unsigned interval_distance) {
    GET_CURRENT_OR_RETURN();
    [_current setLocationInterval:interval_ms distance:interval_distance];
}

static retro_location_lifetime_status_t location_initialized;
static retro_location_lifetime_status_t location_deinitialized;

// MARK: - Camera
/* Starts the camera driver. Can only be called in retro_run(). */
static bool camera_start() {
    GET_CURRENT_OR_RETURN(false);
    return [_current cameraStart];
}

/* Stops the camera driver. Can only be called in retro_run(). */
static void camera_stop() {
    GET_CURRENT_OR_RETURN();
    [_current cameraStop];
}

/* Callback which signals when the camera driver is initialized
 * and/or deinitialized.
 * retro_camera_start_t can be called in initialized callback.
 */
static retro_camera_lifetime_status_t camera_lifetime_status_initialized;
static retro_camera_lifetime_status_t camera_lifetime_status_deinitialized;

/* A callback for raw framebuffer data. buffer points to an XRGB8888 buffer.
 * Width, height and pitch are similar to retro_video_refresh_t.
 * First pixel is top-left origin.
 */
static retro_camera_frame_raw_framebuffer_t camera_raw_framebuffer;

/* A callback for when OpenGL textures are used.
 *
 * texture_id is a texture owned by camera driver.
 * Its state or content should be considered immutable, except for things like
 * texture filtering and clamping.
 *
 * texture_target is the texture target for the GL texture.
 * These can include e.g. GL_TEXTURE_2D, GL_TEXTURE_RECTANGLE, and possibly
 * more depending on extensions.
 *
 * affine points to a packed 3x3 column-major matrix used to apply an affine
 * transform to texture coordinates. (affine_matrix * vec3(coord_x, coord_y, 1.0))
 * After transform, normalized texture coord (0, 0) should be bottom-left
 * and (1, 1) should be top-right (or (width, height) for RECTANGLE).
 *
 * GL-specific typedefs are avoided here to avoid relying on gl.h in
 * the API definition.
 */
static retro_camera_frame_opengl_texture_t camera_raw_frame_opengl_texture;

// MARK: - MIDI

/* Retrieves the current state of the MIDI input.
 * Returns true if it's enabled, false otherwise. */
typedef bool (RETRO_CALLCONV *retro_midi_input_enabled_t)(void);

/* Retrieves the current state of the MIDI output.
 * Returns true if it's enabled, false otherwise */
typedef bool (RETRO_CALLCONV *retro_midi_output_enabled_t)(void);

/* Reads next byte from the input stream.
 * Returns true if byte is read, false otherwise. */
typedef bool (RETRO_CALLCONV *retro_midi_read_t)(uint8_t *byte);

/* Writes byte to the output stream.
 * 'delta_time' is in microseconds and represent time elapsed since previous write.
 * Returns true if byte is written, false otherwise. */
typedef bool (RETRO_CALLCONV *retro_midi_write_t)(uint8_t byte, uint32_t delta_time);

/* Flushes previously written data.
 * Returns true if successful, false otherwise. */
typedef bool (RETRO_CALLCONV *retro_midi_flush_t)(void);

//struct retro_midi_interface
//{
//   retro_midi_input_enabled_t input_enabled;
//   retro_midi_output_enabled_t output_enabled;
//   retro_midi_read_t read;
//   retro_midi_write_t write;
//   retro_midi_flush_t flush;
//};

/* Retrieves the current state of the MIDI input.
 * Returns true if it's enabled, false otherwise. */
static bool midi_input_enabled() {
    GET_CURRENT_OR_RETURN(false);
    return _current.midiInputEnabled;
}

/* Retrieves the current state of the MIDI output.
 * Returns true if it's enabled, false otherwise */
static bool midi_output_enabled() {
    GET_CURRENT_OR_RETURN(false);
    return _current.midiOutputEnabled;
}

/* Reads next byte from the input stream.
 * Returns true if byte is read, false otherwise. */
static bool midi_read(uint8_t *byte) {
    GET_CURRENT_OR_RETURN(false);
    return [_current midiRead:byte];
}

/* Writes byte to the output stream.
 * 'delta_time' is in microseconds and represent time elapsed since previous write.
 * Returns true if byte is written, false otherwise. */
static bool midi_write(uint8_t byte, uint32_t delta_time) {
    GET_CURRENT_OR_RETURN(false);
    return [_current midiWriteWithByte:byte deltaTime:delta_time];
}

/* Flushes previously written data.
 * Returns true if successful, false otherwise. */
static bool midi_flush() {
    GET_CURRENT_OR_RETURN(false);
    return [_current midiFlush];
}

// MARK: - OSD
struct retro_message_ext messageExt;

// MARK: - Rumble
static bool rumble(unsigned port,
                     enum retro_rumble_effect effect, uint16_t strength) {
    ILOG(@"Rumble: %i, %i, %i", port, effect, strength);
    GET_CURRENT_OR_RETURN(false);
    if(!current.supportsRumble) { return false; }
    float sharpness = 0;
    switch(effect) {
        case RETRO_RUMBLE_DUMMY: sharpness = 0.0;
        case RETRO_RUMBLE_STRONG: sharpness = 0.9;
        case RETRO_RUMBLE_WEAK: sharpness = 0.4;
    }

    [current rumbleWithPlayer:port sharpness:sharpness intensity:strength];
    return true;
}


// MARK: - Microphone

// MARK: - VFS

// MARK: - LED

static bool led_set_state(int led, int state) {
    GET_CURRENT_OR_RETURN(false);
    return [_current setLEDWithLed:led state:state];
}

// MARK: - Controllers
const struct retro_controller_info* controller_info;

// MARK: - 3D HW

static retro_hw_get_proc_address_t libretro_get_proc_address(const char *symbol_name) {
    if (symbol_name == NULL)
        return NULL;
    
    CFURLRef bundle_url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault,
          CFSTR
          ("/System/Library/Frameworks/OpenGLES.framework"),
          kCFURLPOSIXPathStyle, true);
    CFBundleRef opengl_bundle_ref  = CFBundleCreate(kCFAllocatorDefault, bundle_url);
    CFStringRef function =  CFStringCreateWithCString(kCFAllocatorDefault, symbol_name,
          kCFStringEncodingASCII);
    retro_hw_get_proc_address_t ret = (gfx_ctx_proc_t)CFBundleGetFunctionPointerForName(
          opengl_bundle_ref, function);

    CFRelease(bundle_url);
    CFRelease(function);
    CFRelease(opengl_bundle_ref);
    return ret;
}

// MARK: - Cheats

bool core_set_cheat(retro_ctx_cheat_info_t *info) {
    GET_CURRENT_OR_RETURN(false);
    current->core->retro_cheat_set(info->index, info->enabled, info->code);
    return true;
}

bool core_reset_cheat(void) {
    GET_CURRENT_OR_RETURN(false);
    current->core->retro_cheat_reset();
    return true;
}

// MARK: - Video
/**
 * video_driver_frame:
 * @data                 : pointer to data of the video frame.
 * @width                : width of the video frame.
 * @height               : height of the video frame.
 * @pitch                : pitch of the video frame.
 *
 * Video frame render callback function.
 **/

extern video_pixel_scaler_t *video_driver_scaler_ptr;
extern bool video_pixel_frame_scale(const void *data,
      unsigned width, unsigned height,
                                    size_t pitch);
//extern video_driver_state_t video_driver_state;
void video_driver_frame(const void *data, unsigned width,
                        unsigned height, size_t pitch)
{
    NAssert(@"Shouldn't be here, or need to impliment");
//       static char video_driver_msg[256];
//       unsigned output_width  = 0;
//       unsigned output_height = 0;
//       unsigned  output_pitch = 0;
//       const char *msg        = NULL;
//       settings_t *settings   = config_get_ptr();
//
//       runloop_ctl(RUNLOOP_CTL_MSG_QUEUE_PULL,   &msg);
//
//       if (!video_driver_is_active())
//          return;
//
//       if (video_driver_scaler_ptr &&
//             video_pixel_frame_scale(data, width, height, pitch))
//       {
//          data                = video_driver_scaler_ptr->scaler_out;
//          pitch               = video_driver_scaler_ptr->scaler->out_stride;
//       }
//
//       video_driver_cached_frame_set(data, width, height, pitch);
//
//       /* Slightly messy code,
//        * but we really need to do processing before blocking on VSync
//        * for best possible scheduling.
//        */
//       if (
//             (
//                 !video_driver_state.filter.filter
//              || !settings->video.post_filter_record
//              || !data
//              || video_driver_has_gpu_record()
//             )
//          )
//          recording_dump_frame(data, width, height, pitch);
//
//       if (video_driver_frame_filter(data, width, height, pitch,
//                &output_width, &output_height, &output_pitch))
//       {
//          data   = video_driver_state.filter.buffer;
//          width  = output_width;
//          height = output_height;
//          pitch  = output_pitch;
//       }
//
//       video_driver_msg[0] = '\0';
//       if (msg)
//          strlcpy(video_driver_msg, msg, sizeof(video_driver_msg));
//
//       if (!current_video || !current_video->frame(
//                video_driver_data, data, width, height,
//                video_driver_frame_count,
//                pitch, video_driver_msg))
//       {
//          video_driver_unset_active();
//       }
//
//       video_driver_frame_count++;
}

typedef uint32_t video_pixel_t;
static void RETRO_CALLCONV video_callback(const void *data, unsigned width, unsigned height, size_t pitch)
{
//    if (!video_driver_is_active())
//       return;
    
    __strong PVLibRetroCore *strongCurrent = _current;
    
    static dispatch_queue_t serialQueue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_queue_attr_t queueAttributes = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_CONCURRENT, QOS_CLASS_USER_INTERACTIVE, 0);
        serialQueue = dispatch_queue_create("com.provenance.video", queueAttributes);
        
        DLOG(@"vid: width: %i height: %i, pitch: %zu. _videoWidth: %f, _videoHeight: %f\n", width, height, pitch, strongCurrent.videoWidth, strongCurrent.videoHeight);
    });
    // 512
    video_pixel_t pitch_shift = strongCurrent->pitch_shift; //PITCH_SHIFT; //pitch % 256; // PITCH_SHIFT
    dispatch_apply(height, serialQueue, ^(size_t y){
        size_t shifted_pitch = pitch >> pitch_shift;              //pitch is in bytes not pixels
        size_t offset = y * shifted_pitch;
        const video_pixel_t *src = (video_pixel_t*)data + offset;
        video_pixel_t *dst = (video_pixel_t*)strongCurrent->videoBuffer + y * width;
        
        memcpy(dst, src, sizeof(video_pixel_t)*width);
    });
    
    strongCurrent = nil;
}

struct retro_system_av_info *video_viewport_get_system_av_info(void)
{
    static struct retro_system_av_info av_info;
    
    return &av_info;
}

bool core_get_system_av_info(struct retro_system_av_info *av_info) {
    GET_CURRENT_OR_RETURN(false);
    if (!av_info)
        return false;
    current->core->retro_get_system_av_info(av_info);
    return true;
}

//
//static void video_configure(const struct retro_game_geometry * geom) {
//    __strong PVLibRetroCore *strongCurrent = _current;
//
//    strongCurrent->_videoWidth  = geom->max_width;
//    strongCurrent->_videoHeight = geom->max_height;
//}

// MARK: - Audio
static retro_audio_callback_t audio_callback_notify;
static retro_audio_set_state_callback_t audio_set_state_notify;

static void RETRO_CALLCONV audio_callback(int16_t left, int16_t right)
{
    __strong PVLibRetroCore *strongCurrent = _current;
    
    [[strongCurrent ringBufferAtIndex:0] write:&left maxLength:2];
    [[strongCurrent ringBufferAtIndex:0] write:&right maxLength:2];
    
    strongCurrent = nil;
}

static retro_audio_set_state_callback_t audio_set_state(bool enabled) {
    GET_CURRENT_OR_RETURN(false);
    // TODO: Turn audio on and off, or maybe just mute?
    STUB(@"enabled: %i", enabled);
    return false;
}

static size_t RETRO_CALLCONV audio_batch_callback(const int16_t *data, size_t frames)
{
    __strong PVLibRetroCore *strongCurrent = _current;
    
    [[strongCurrent ringBufferAtIndex:0] write:data maxLength:frames << 2];
    
    strongCurrent = nil;
    
    return frames;
}

void audio_driver_unset_callback(void)
{
    audio_callback_notify  = NULL;
    audio_set_state_notify = NULL;
}

// MARK: - Serialization

bool core_unserialize(retro_ctx_serialize_info_t *info) {
    GET_CURRENT_OR_RETURN(false);
    if (!info)
        return false;
    if (!current->core->retro_unserialize(info->data_const, info->size))
        return false;
    return true;
}

bool core_serialize(retro_ctx_serialize_info_t *info) {
    GET_CURRENT_OR_RETURN(false);
    if (!info)
        return false;
    if (!current->core->retro_serialize(info->data, info->size))
        return false;
    return true;
}

bool core_serialize_size(retro_ctx_size_info_t *info) {
    GET_CURRENT_OR_RETURN(false);
    if (!info)
        return false;
    info->size = current->core->retro_serialize_size();
    return true;
}


// MARK: - Retro

/**
 * core_init_libretro_cbs:
 * @data           : pointer to retro_callbacks object
 *
 * Initializes libretro callbacks, and binds the libretro callbacks
 * to default callback functions.
 **/
static bool core_init_libretro_cbs(void *data)
{
    GET_CURRENT_OR_RETURN(false);

    struct retro_callbacks *cbs = (struct retro_callbacks*)data;
#ifdef HAVE_NETPLAY
    global_t            *global = global_get_ptr();
#endif
    
    if (!cbs)
        return false;
    
    current->core->retro_set_video_refresh(video_driver_frame);
    //   core->retro_set_audio_sample(audio_driver_sample);
    //   core->retro_set_audio_sample_batch(audio_driver_sample_batch);
    current->core->retro_set_input_state(core_input_state_poll);
    current->core->retro_set_input_poll(core_input_state_poll_maybe);
    
    core_set_default_callbacks(cbs);
    
#ifdef HAVE_NETPLAY
    if (!netplay_driver_ctl(RARCH_NETPLAY_CTL_IS_DATA_INITED, NULL))
        return true;
    
    /* Force normal poll type for netplay. */
    core_poll_type = POLL_TYPE_NORMAL;
    
    if (global->netplay.is_spectate)
    {
        core->retro_set_input_state(
                                   (global->netplay.is_client ?
                                    input_state_spectate_client : input_state_spectate)
                                   );
    }
    else
    {
        core->retro_set_video_refresh(video_frame_net);
        core->retro_set_audio_sample(audio_sample_net);
        core->retro_set_audio_sample_batch(audio_sample_batch_net);
        core->retro_set_input_state(input_state_net);
    }
#endif
    
    return true;
}

int16_t RETRO_CALLCONV input_state_callback(unsigned port, unsigned device, unsigned index, unsigned _id)
{
    //DLOG(@"polled input: port: %d device: %d id: %d", port, device, id);
    
    __strong PVLibRetroCore *strongCurrent = _current;
    int16_t value = 0;
    
    if (port == 0 & device == RETRO_DEVICE_JOYPAD)
    {
        if (strongCurrent.controller1)
        {
            value = [strongCurrent controllerValueForButtonID:_id forPlayer:port];
        }
        
        if (value == 0)
        {
            value = strongCurrent->_pad[0][_id];
        }
    }
    else if(port == 1 & device == RETRO_DEVICE_JOYPAD)
    {
        if (strongCurrent.controller2)
        {
            value = [strongCurrent controllerValueForButtonID:_id forPlayer:port];
        }
        
        if (value == 0)
        {
            value = strongCurrent->_pad[1][_id];
        }
    }
    else if(port == 0 & device == RETRO_DEVICE_MOUSE)
    {
        switch(_id) {
            case RETRO_DEVICE_ID_MOUSE_X:
                value = strongCurrent->mouse_x;
            case RETRO_DEVICE_ID_MOUSE_Y:
                value = strongCurrent->mouse_y;
            case RETRO_DEVICE_ID_MOUSE_LEFT:
                value = strongCurrent->mouseLeft;
            case RETRO_DEVICE_ID_MOUSE_RIGHT:
                value = strongCurrent->mouseRight;
            case RETRO_DEVICE_ID_MOUSE_MIDDLE:
                value = strongCurrent->mouseMiddle;
            case RETRO_DEVICE_ID_MOUSE_WHEELUP:
                value = strongCurrent->mouse_wheel_up;
            case RETRO_DEVICE_ID_MOUSE_WHEELDOWN:
                value = strongCurrent->mouse_wheel_down;
            case RETRO_DEVICE_ID_MOUSE_HORIZ_WHEELUP:
                value = strongCurrent->mouse_horiz_wheel_up;
            case RETRO_DEVICE_ID_MOUSE_HORIZ_WHEELDOWN:
                value = strongCurrent->mouse_horiz_wheel_down;
            case RETRO_DEVICE_ID_MOUSE_BUTTON_4:
                value = strongCurrent->mouse_button_4;
            case RETRO_DEVICE_ID_MOUSE_BUTTON_5:
                value = strongCurrent->mouse_button_5;
        }
    }
    
    strongCurrent = nil;
    
    return value;
}

/**
 * core_set_default_callbacks:
 * @data           : pointer to retro_callbacks object
 *
 * Binds the libretro callbacks to default callback functions.
 **/
bool core_set_default_callbacks(void *data)
{
    struct retro_callbacks *cbs = (struct retro_callbacks*)data;
    
    if (!cbs)
        return false;
    
    cbs->frame_cb        = video_driver_frame;
    cbs->sample_cb       = audio_callback;
    cbs->sample_batch_cb = audio_batch_callback;
    cbs->state_cb        = core_input_state_poll;
    cbs->poll_cb         = input_poll;
    
    return true;
}

bool core_deinit(void *data)
{
    struct retro_callbacks *cbs = (struct retro_callbacks*)data;
    
    if (!cbs)
        return false;
    
    cbs->frame_cb        = NULL;
    cbs->sample_cb       = NULL;
    cbs->sample_batch_cb = NULL;
    cbs->state_cb        = NULL;
    cbs->poll_cb         = NULL;
    
    return true;
}

bool core_uninit_libretro_callbacks(void)
{
    return core_deinit(&retro_ctx);
}

/**
 * core_set_rewind_callbacks:
 *
 * Sets the audio sampling callbacks based on whether or not
 * rewinding is currently activated.
 **/
bool core_set_rewind_callbacks(void)
{
    //   if (state_manager_frame_is_reversed())
    //   {
    //	  core->retro_set_audio_sample(audio_driver_sample_rewind);
    //	  core->retro_set_audio_sample_batch(audio_driver_sample_batch_rewind);
    //   }
    //   else
    //   {
    //	  core->retro_set_audio_sample(audio_driver_sample);
    //	  core->retro_set_audio_sample_batch(audio_driver_sample_batch);
    //   }
    return true;
}

bool core_api_version(retro_ctx_api_info_t *api)
{
    GET_CURRENT_OR_RETURN(false);
    if (!api)
        return false;
    api->version = current->core->retro_api_version();
    return true;
}

void core_uninit_symbols(void)
{
    GET_CURRENT_OR_RETURN();
    uninit_libretro_sym(current->core);
}

bool core_init_symbols(enum rarch_core_type *type)
{
    GET_CURRENT_OR_RETURN(false);
    if (!type)
        return false;
    init_libretro_sym(*type, current->core);
    return true;
}

bool core_get_memory(retro_ctx_memory_info_t *info) {
    GET_CURRENT_OR_RETURN(false);

    if (!info)
        return false;
    info->size  = current->core->retro_get_memory_size(info->id);
    info->data  = current->core->retro_get_memory_data(info->id);
    return true;
}

bool core_load_game(retro_ctx_load_content_info_t *load_info)
{
    GET_CURRENT_OR_RETURN(false);

    if (!load_info)
        return false;
    
    BOOL loaded = false;
    if (load_info->special != nil) {
        loaded = current->core->retro_load_game_special(load_info->special->id, load_info->info, load_info->content->size);
    } else {
//        if(load_info->content != nil && load_info->content->elems != nil) {
//            core->retro_load_game(*load_info->content->elems[0].data);
//        } else {
        loaded = current->core->retro_load_game(load_info->info);
//        }
    }
    
    if (!loaded) {
        ELOG(@"Core failed to load game.");
        return false;
    }
    
    struct retro_system_timing timing = {
        60.0f, 10000.0f
    };
    struct retro_game_geometry geom = {
        100, 100, 100, 100, 1.0f
    };
    struct retro_system_av_info av = {
        geom, timing
    };
    //    struct retro_system_info system = {
    //      0, 0, 0, false, false
    //    };
    //
    //    struct retro_game_info info = {
    //      filename,
    //      0,
    //      0,
    //      NULL
    //    };
    
    
    current->core->retro_get_system_av_info(&av);
    ILOG(@"Video: %ix%i\n", av.geometry.base_width, av.geometry.base_height);
    current->av_info = av;
//    video_configure(&av.geometry);
    return true;
    //    audio_init(av.timing.sample_rate);
}

bool core_get_system_info(struct retro_system_info *system) {
    GET_CURRENT_OR_RETURN(false);
    if (!system)
        return false;
    current->core->retro_get_system_info(system);
    return true;
}

bool core_frame(retro_ctx_frame_info_t *info) {
    GET_CURRENT_OR_RETURN(false);
    if (!info || !retro_ctx.frame_cb)
        return false;
    
    retro_ctx.frame_cb(
                       info->data, info->width, info->height, info->pitch);
    return true;
}

bool core_set_environment(retro_ctx_environ_info_t *info) {
    GET_CURRENT_OR_RETURN(false);
    if (!info)
        return false;
    current->core->retro_set_environment(info->env);
    return true;
}

bool core_reset(void) {
    GET_CURRENT_OR_RETURN(false);
    current->core->retro_reset();
    return true;
}

bool core_init(void) {
    GET_CURRENT_OR_RETURN(false);
    current->core->retro_init();
    return true;
}

bool core_unload(void) {
    GET_CURRENT_OR_RETURN(false);
    current->core->retro_deinit();
    return true;
}

bool core_has_set_input_descriptor(void) {
    GET_CURRENT_OR_RETURN(false);
    return current->core_has_set_input_descriptors;
}

void core_set_input_descriptors(void) {
    GET_CURRENT_OR_RETURN();
    current->core_has_set_input_descriptors = true;
}

void core_unset_input_descriptors(void) {
    GET_CURRENT_OR_RETURN();
    current->core_has_set_input_descriptors = false;
}

static settings_t *configuration_settings = NULL;

settings_t *config_get_ptr(void) {
    return configuration_settings;
}

bool core_load(void) {
    GET_CURRENT_OR_RETURN(false);

    settings_t *settings = config_get_ptr();
    current->core_poll_type = settings->input.poll_type_behavior;
    
    if (!core_verify_api_version())
        return false;
    if (!core_init_libretro_cbs(&retro_ctx))
        return false;
    
    core_get_system_av_info(video_viewport_get_system_av_info());
    runloop_ctl(RUNLOOP_CTL_SET_FRAME_LIMIT, NULL);
    
    return true;
}

bool core_verify_api_version(void) {
    GET_CURRENT_OR_RETURN(false);

    //   unsigned api_version = core->retro_api_version();
    //   RARCH_LOG("%s: %u\n",
    //         msg_hash_to_str(MSG_VERSION_OF_LIBRETRO_API),
    //         api_version);
    //   RARCH_LOG("%s: %u\n",
    //         msg_hash_to_str(MSG_COMPILED_AGAINST_API),
    //         RETRO_API_VERSION);
    //
    //   if (api_version != RETRO_API_VERSION)
    //   {
    //      RARCH_WARN("%s\n", msg_hash_to_str(MSG_LIBRETRO_ABI_BREAK));
    //      return false;
    //   }
    return true;
}

/**
 * init_libretro_sym:
 * @type                        : Type of core to be loaded.
 *                                If CORE_TYPE_DUMMY, will
 *                                load dummy symbols.
 *
 * Initializes libretro symbols and
 * setups environment callback functions.
 **/
//void init_libretro_sym(enum rarch_core_type type, struct retro_core_t *current_core)
//{
/* Guarantee that we can do "dirty" casting.
 * Every OS that this program supports should pass this. */
//   retro_assert(sizeof(void*) == sizeof(void (*)(void)));
//
//   load_symbols(type, current_core);
//}

/**
 * input_poll:
 *
 * Input polling callback function.
 **/
void input_poll(void)
{
    //   size_t i;
    //   settings_t *settings           = config_get_ptr();
    //
    //   input_driver_poll();
    //
    //   for (i = 0; i < MAX_USERS; i++)
    //      libretro_input_binds[i] = settings->input.binds[i];
    //
    //#ifdef HAVE_OVERLAY
    //   input_poll_overlay(NULL, settings->input.overlay_opacity);
    //#endif
    //
    //#ifdef HAVE_COMMAND
    //   if (input_driver_command)
    //      command_poll(input_driver_command);
    //#endif
    //
    //#ifdef HAVE_NETWORKGAMEPAD
    //   if (input_driver_remote)
    //      input_remote_poll(input_driver_remote);
    //#endif
}

/**
 * uninit_libretro_sym:
 *
 * Frees libretro core->
 *
 * Frees all core options,
 * associated state, and
 * unbind all libretro callback symbols.
 **/
void uninit_libretro_sym(struct retro_core_t *current_core)
{
#ifdef HAVE_DYNAMIC
    if (lib_handle)
        dylib_close(lib_handle);
    lib_handle = NULL;
#endif
    
    memset(current_core, 0, sizeof(struct retro_core_t));
    
    runloop_ctl(RUNLOOP_CTL_CORE_OPTIONS_DEINIT, NULL);
    runloop_ctl(RUNLOOP_CTL_SYSTEM_INFO_FREE, NULL);
    runloop_ctl(RUNLOOP_CTL_FRAME_TIME_FREE, NULL);
    //   camera_driver_ctl(RARCH_CAMERA_CTL_UNSET_ACTIVE, NULL);
    ////   location_driver_ctl(RARCH_LOCATION_CTL_UNSET_ACTIVE, NULL);
    //
    //   /* Performance counters no longer valid. */
    //   performance_counters_clear();
}

#ifdef HAVE_ZLIB
#define DEFAULT_EXT "zip"
#else
#define DEFAULT_EXT ""
#endif

bool runloop_ctl(enum runloop_ctl_state state, void *data) {
    VLOG(@"runloop_ctl : %i", state);
    switch (state)
    {
            //       case RUNLOOP_CTL_SHADER_DIR_DEINIT:
            //          shader_dir_free(&runloop_shader_dir);
            //          break;
            //       case RUNLOOP_CTL_SHADER_DIR_INIT:
            //          return shader_dir_init(&runloop_shader_dir);
        case RUNLOOP_CTL_SYSTEM_INFO_INIT:
            core_get_system_info(&runloop_system.info);
            
            //          if (!runloop_system.info.library_name)
            //             runloop_system.info.library_name = msg_hash_to_str(MSG_UNKNOWN);
            if (!runloop_system.info.library_version)
                runloop_system.info.library_version = "v0";
            
            //          video_driver_set_title_buf();
            
            strlcpy(runloop_system.valid_extensions,
                    runloop_system.info.valid_extensions ?
                    runloop_system.info.valid_extensions : DEFAULT_EXT,
                    sizeof(runloop_system.valid_extensions));
            break;
        case RUNLOOP_CTL_GET_CORE_OPTION_SIZE:
            //          {
            //             unsigned *idx = (unsigned*)data;
            //             if (!idx)
            //                return false;
            //             *idx = core_option_manager_size(runloop_core_options);
            //          }
            break;
        case RUNLOOP_CTL_HAS_CORE_OPTIONS:
            return false; //runloop_core_options;
        case RUNLOOP_CTL_CORE_OPTIONS_LIST_GET:
            //          {
            //             core_option_manager_t **coreopts = (core_option_manager_t**)data;
            //             if (!coreopts)
            //                return false;
            //             *coreopts = runloop_core_options;
            //          }
            break;
        case RUNLOOP_CTL_SYSTEM_INFO_GET:
        {
            rarch_system_info_t **system = (rarch_system_info_t**)data;
            if (!system)
                return false;
            *system = &runloop_system;
        }
            break;
        case RUNLOOP_CTL_SYSTEM_INFO_FREE:
            
            /* No longer valid. */
            if (runloop_system.subsystem.data)
                free(runloop_system.subsystem.data);
            runloop_system.subsystem.data = NULL;
            runloop_system.subsystem.size = 0;
            
            if (runloop_system.ports.data)
                free(runloop_system.ports.data);
            runloop_system.ports.data = NULL;
            runloop_system.ports.size = 0;
            
            if (runloop_system.mmaps.descriptors)
                free((void *)runloop_system.mmaps.descriptors);
            runloop_system.mmaps.descriptors     = NULL;
            runloop_system.mmaps.num_descriptors = 0;
            
            runloop_key_event          = NULL;
            runloop_frontend_key_event = NULL;
            
            audio_driver_unset_callback();
            memset(&runloop_system, 0, sizeof(rarch_system_info_t));
            break;
        case RUNLOOP_CTL_SET_FRAME_TIME_LAST:
            runloop_frame_time_last_enable = true;
            break;
        case RUNLOOP_CTL_UNSET_FRAME_TIME_LAST:
            if (!runloop_ctl(RUNLOOP_CTL_IS_FRAME_TIME_LAST, NULL))
                return false;
            runloop_frame_time_last        = 0;
            runloop_frame_time_last_enable = false;
            break;
        case RUNLOOP_CTL_SET_OVERRIDES_ACTIVE:
            runloop_overrides_active = true;
            break;
        case RUNLOOP_CTL_UNSET_OVERRIDES_ACTIVE:
            runloop_overrides_active = false;
            break;
        case RUNLOOP_CTL_IS_OVERRIDES_ACTIVE:
            return runloop_overrides_active;
        case RUNLOOP_CTL_SET_GAME_OPTIONS_ACTIVE:
            runloop_game_options_active = true;
            break;
        case RUNLOOP_CTL_UNSET_GAME_OPTIONS_ACTIVE:
            runloop_game_options_active = false;
            break;
        case RUNLOOP_CTL_IS_GAME_OPTIONS_ACTIVE:
            return runloop_game_options_active;
        case RUNLOOP_CTL_IS_FRAME_TIME_LAST:
            return runloop_frame_time_last_enable;
        case RUNLOOP_CTL_SET_FRAME_LIMIT:
            runloop_set_frame_limit = true;
            break;
        case RUNLOOP_CTL_UNSET_FRAME_LIMIT:
            runloop_set_frame_limit = false;
            break;
        case RUNLOOP_CTL_SHOULD_SET_FRAME_LIMIT:
            return runloop_set_frame_limit;
        case RUNLOOP_CTL_GET_PERFCNT:
        {
            bool **perfcnt = (bool**)data;
            if (!perfcnt)
                return false;
            *perfcnt = &runloop_perfcnt_enable;
        }
            break;
        case RUNLOOP_CTL_SET_PERFCNT_ENABLE:
            runloop_perfcnt_enable = true;
            break;
        case RUNLOOP_CTL_UNSET_PERFCNT_ENABLE:
            runloop_perfcnt_enable = false;
            break;
        case RUNLOOP_CTL_IS_PERFCNT_ENABLE:
            return runloop_perfcnt_enable;
        case RUNLOOP_CTL_SET_NONBLOCK_FORCED:
            runloop_force_nonblock = true;
            break;
        case RUNLOOP_CTL_UNSET_NONBLOCK_FORCED:
            runloop_force_nonblock = false;
            break;
        case RUNLOOP_CTL_IS_NONBLOCK_FORCED:
            return runloop_force_nonblock;
        case RUNLOOP_CTL_SET_FRAME_TIME:
        {
            const struct retro_frame_time_callback *info =
            (const struct retro_frame_time_callback*)data;
#ifdef HAVE_NETPLAY
            global_t *global = global_get_ptr();
            
            /* retro_run() will be called in very strange and
             * mysterious ways, have to disable it. */
            if (global->netplay.enable)
                return false;
#endif
            runloop_frame_time = *info;
        }
            break;
        case RUNLOOP_CTL_GET_WINDOWED_SCALE:
        {
            unsigned **scale = (unsigned**)data;
            if (!scale)
                return false;
            *scale       = (unsigned*)&runloop_pending_windowed_scale;
        }
            break;
        case RUNLOOP_CTL_SET_WINDOWED_SCALE:
        {
            unsigned *idx = (unsigned*)data;
            if (!idx)
                return false;
            runloop_pending_windowed_scale = *idx;
        }
            break;
        case RUNLOOP_CTL_SET_LIBRETRO_PATH:
        {
            const char *fullpath = (const char*)data;
            if (!fullpath)
                return false;
            config_set_active_core_path(fullpath);
        }
            break;
        case RUNLOOP_CTL_CLEAR_CONTENT_PATH:
            *runloop_fullpath = '\0';
            break;
        case RUNLOOP_CTL_GET_CONTENT_PATH:
        {
            char **fullpath = (char**)data;
            if (!fullpath)
                return false;
            *fullpath       = (char*)runloop_fullpath;
        }
            break;
        case RUNLOOP_CTL_SET_CONTENT_PATH:
        {
            const char *fullpath = (const char*)data;
            if (!fullpath)
                return false;
            strlcpy(runloop_fullpath, fullpath, sizeof(runloop_fullpath));
        }
            break;
        case RUNLOOP_CTL_CLEAR_DEFAULT_SHADER_PRESET:
            *runloop_default_shader_preset = '\0';
            break;
        case RUNLOOP_CTL_GET_DEFAULT_SHADER_PRESET:
        {
            char **preset = (char**)data;
            if (!preset)
                return false;
            *preset       = (char*)runloop_default_shader_preset;
        }
            break;
        case RUNLOOP_CTL_SET_DEFAULT_SHADER_PRESET:
        {
            const char *preset = (const char*)data;
            if (!preset)
                return false;
            strlcpy(runloop_default_shader_preset, preset,
                    sizeof(runloop_default_shader_preset));
        }
            break;
        case RUNLOOP_CTL_FRAME_TIME_FREE:
            memset(&runloop_frame_time, 0, sizeof(struct retro_frame_time_callback));
            runloop_frame_time_last           = 0;
            runloop_max_frames                = 0;
            break;
        case RUNLOOP_CTL_STATE_FREE:
            runloop_perfcnt_enable            = false;
            runloop_idle                      = false;
            runloop_paused                    = false;
            runloop_slowmotion                = false;
            runloop_frame_time_last_enable    = false;
            runloop_set_frame_limit           = false;
            runloop_overrides_active          = false;
            runloop_ctl(RUNLOOP_CTL_FRAME_TIME_FREE, NULL);
            break;
        case RUNLOOP_CTL_GLOBAL_FREE:
        {
            global_t *global = NULL;
            //             command_event(CMD_EVENT_TEMPORARY_CONTENT_DEINIT, NULL);
            //             command_event(CMD_EVENT_SUBSYSTEM_FULLPATHS_DEINIT, NULL);
            //             command_event(CMD_EVENT_RECORD_DEINIT, NULL);
            //             command_event(CMD_EVENT_LOG_FILE_DEINIT, NULL);
            
            //             rarch_ctl(RARCH_CTL_UNSET_BLOCK_CONFIG_READ, NULL);
            runloop_ctl(RUNLOOP_CTL_CLEAR_CONTENT_PATH,  NULL);
            runloop_overrides_active   = false;
            
            core_unset_input_descriptors();
            
            //             global = global_get_ptr();
            memset(global, 0, sizeof(struct global));
            //             retroarch_override_setting_free_state();
            //             config_free_state();
        }
            break;
        case RUNLOOP_CTL_CLEAR_STATE:
            //          driver_ctl(RARCH_DRIVER_CTL_DEINIT,  NULL);
            runloop_ctl(RUNLOOP_CTL_STATE_FREE,  NULL);
            runloop_ctl(RUNLOOP_CTL_GLOBAL_FREE, NULL);
            break;
        case RUNLOOP_CTL_SET_MAX_FRAMES:
        {
            unsigned *ptr = (unsigned*)data;
            if (!ptr)
                return false;
            runloop_max_frames = *ptr;
        }
            break;
        case RUNLOOP_CTL_IS_IDLE:
            return runloop_idle;
        case RUNLOOP_CTL_SET_IDLE:
        {
            bool *ptr = (bool*)data;
            if (!ptr)
                return false;
            runloop_idle = *ptr;
        }
            break;
        case RUNLOOP_CTL_IS_SLOWMOTION:
            return runloop_slowmotion;
        case RUNLOOP_CTL_SET_SLOWMOTION:
        {
            bool *ptr = (bool*)data;
            if (!ptr)
                return false;
            runloop_slowmotion = *ptr;
        }
            break;
        case RUNLOOP_CTL_SET_PAUSED:
        {
            bool *ptr = (bool*)data;
            if (!ptr)
                return false;
            runloop_paused = *ptr;
        }
            break;
        case RUNLOOP_CTL_IS_PAUSED:
            return runloop_paused;
        case RUNLOOP_CTL_MSG_QUEUE_PULL:
            //          runloop_msg_queue_lock();
            //          {
            //             const char **ret = (const char**)data;
            //             if (!ret)
            //                return false;
            //             *ret = msg_queue_pull(runloop_msg_queue);
            //          }
            //          runloop_msg_queue_unlock();
            break;
        case RUNLOOP_CTL_MSG_QUEUE_FREE:
#ifdef HAVE_THREADS
            slock_free(_runloop_msg_queue_lock);
            _runloop_msg_queue_lock = NULL;
#endif
            break;
        case RUNLOOP_CTL_MSG_QUEUE_CLEAR:
            //          msg_queue_clear(runloop_msg_queue);
            break;
        case RUNLOOP_CTL_MSG_QUEUE_DEINIT:
            //          if (!runloop_msg_queue)
            //             return true;
            //
            //          runloop_msg_queue_lock();
            //
            //          msg_queue_free(runloop_msg_queue);
            //
            //          runloop_msg_queue_unlock();
            //          runloop_ctl(RUNLOOP_CTL_MSG_QUEUE_FREE, NULL);
            //
            //          runloop_msg_queue = NULL;
            break;
        case RUNLOOP_CTL_MSG_QUEUE_INIT:
            runloop_ctl(RUNLOOP_CTL_MSG_QUEUE_DEINIT, NULL);
            //          runloop_msg_queue = msg_queue_new(8);
            //          retro_assert(runloop_msg_queue);
            
#ifdef HAVE_THREADS
            _runloop_msg_queue_lock = slock_new();
            retro_assert(_runloop_msg_queue_lock);
#endif
            break;
        case RUNLOOP_CTL_TASK_INIT:
        {
            // #ifdef HAVE_THREADS
            //             settings_t *settings = config_get_ptr();
            //             bool threaded_enable = settings->threaded_data_runloop_enable;
            // #else
            //             bool threaded_enable = false;
            // #endif
            //             task_queue_ctl(TASK_QUEUE_CTL_DEINIT, NULL);
            //             task_queue_ctl(TASK_QUEUE_CTL_INIT, &threaded_enable);
        }
            break;
        case RUNLOOP_CTL_SET_CORE_SHUTDOWN:
            runloop_core_shutdown_initiated = true;
            break;
        case RUNLOOP_CTL_UNSET_CORE_SHUTDOWN:
            runloop_core_shutdown_initiated = false;
            break;
        case RUNLOOP_CTL_IS_CORE_SHUTDOWN:
            return runloop_core_shutdown_initiated;
        case RUNLOOP_CTL_SET_SHUTDOWN:
            runloop_shutdown_initiated = true;
            break;
        case RUNLOOP_CTL_UNSET_SHUTDOWN:
            runloop_shutdown_initiated = false;
            break;
        case RUNLOOP_CTL_IS_SHUTDOWN:
            return runloop_shutdown_initiated;
        case RUNLOOP_CTL_SET_EXEC:
            runloop_exec = true;
            break;
        case RUNLOOP_CTL_UNSET_EXEC:
            runloop_exec = false;
            break;
        case RUNLOOP_CTL_IS_EXEC:
            return runloop_exec;
        case RUNLOOP_CTL_DATA_DEINIT:
            //          task_queue_ctl(TASK_QUEUE_CTL_DEINIT, NULL);
            break;
            //       case RUNLOOP_CTL_IS_CORE_OPTION_UPDATED:
            //          if (!runloop_core_options)
            //             return false;
            //          return  core_option_manager_updated(runloop_core_options);
            //       case RUNLOOP_CTL_CORE_OPTION_PREV:
            //          {
            //             unsigned *idx = (unsigned*)data;
            //             if (!idx)
            //                return false;
            //             core_option_manager_prev(runloop_core_options, *idx);
            //             if (ui_companion_is_on_foreground())
            //                ui_companion_driver_notify_refresh();
            //          }
            //          break;
            //       case RUNLOOP_CTL_CORE_OPTION_NEXT:
            //          {
            //             unsigned *idx = (unsigned*)data;
            //             if (!idx)
            //                return false;
            //             core_option_manager_next(runloop_core_options, *idx);
            //             if (ui_companion_is_on_foreground())
            //                ui_companion_driver_notify_refresh();
            //          }
            //          break;
            //       case RUNLOOP_CTL_CORE_OPTIONS_GET:
            //          {
            //             struct retro_variable *var = (struct retro_variable*)data;
            //
            //             if (!runloop_core_options || !var)
            //                return false;
            //
            //             RARCH_LOG("Environ GET_VARIABLE %s:\n", var->key);
            //             core_option_manager_get(runloop_core_options, var);
            //             RARCH_LOG("\t%s\n", var->value ? var->value :
            //                   msg_hash_to_str(MENU_ENUM_LABEL_VALUE_NOT_AVAILABLE));
            //          }
            //          break;
        case RUNLOOP_CTL_CORE_OPTIONS_INIT:
        {
            //             char *game_options_path           = NULL;
            //             bool ret                          = false;
            //             char buf[PATH_MAX_LENGTH]         = {0};
            //             global_t *global                  = global_get_ptr();
            //             settings_t *settings              = config_get_ptr();
            //             const char *options_path          = settings->path.core_options;
            //             const struct retro_variable *vars =
            //                (const struct retro_variable*)data;
            
            //             if (string_is_empty(options_path)
            //                   && !string_is_empty(global->path.config))
            //             {
            //                fill_pathname_resolve_relative(buf, global->path.config,
            //                      file_path_str(FILE_PATH_CORE_OPTIONS_CONFIG), sizeof(buf));
            //                options_path = buf;
            //             }
            //
            //
            //             if (settings->game_specific_options)
            //                ret = rarch_game_specific_options(&game_options_path);
            //
            //             if(ret)
            //             {
            //                runloop_ctl(RUNLOOP_CTL_SET_GAME_OPTIONS_ACTIVE, NULL);
            //                runloop_core_options =
            //                   core_option_manager_new(game_options_path, vars);
            //                free(game_options_path);
            //             }
            //             else
            //             {
            //                runloop_ctl(RUNLOOP_CTL_UNSET_GAME_OPTIONS_ACTIVE, NULL);
            //                runloop_core_options =
            //                   core_option_manager_new(options_path, vars);
            //             }
            
        }
            break;
            //       case RUNLOOP_CTL_CORE_OPTIONS_FREE:
            //          if (runloop_core_options)
            //             core_option_manager_free(runloop_core_options);
            //          runloop_core_options          = NULL;
            //          break;
            //       case RUNLOOP_CTL_CORE_OPTIONS_DEINIT:
            //          {
            //             global_t *global                  = global_get_ptr();
            //             if (!runloop_core_options)
            //                return false;
            //
            //             /* check if game options file was just created and flush
            //                to that file instead */
            //             if(global && !string_is_empty(global->path.core_options_path))
            //             {
            //                core_option_manager_flush_game_specific(runloop_core_options,
            //                      global->path.core_options_path);
            //                global->path.core_options_path[0] = '\0';
            //             }
            //             else
            //                core_option_manager_flush(runloop_core_options);
            //
            //             if (runloop_ctl(RUNLOOP_CTL_IS_GAME_OPTIONS_ACTIVE, NULL))
            //                runloop_ctl(RUNLOOP_CTL_UNSET_GAME_OPTIONS_ACTIVE, NULL);
            //
            //             runloop_ctl(RUNLOOP_CTL_CORE_OPTIONS_FREE, NULL);
            //          }
            //          break;
        case RUNLOOP_CTL_KEY_EVENT_GET:
        {
            retro_keyboard_event_t **key_event =
            (retro_keyboard_event_t**)data;
            if (!key_event)
                return false;
            *key_event = &runloop_key_event;
        }
            break;
        case RUNLOOP_CTL_FRONTEND_KEY_EVENT_GET:
        {
            retro_keyboard_event_t **key_event =
            (retro_keyboard_event_t**)data;
            if (!key_event)
                return false;
            *key_event = &runloop_frontend_key_event;
        }
            break;
        case RUNLOOP_CTL_HTTPSERVER_INIT:
#if defined(HAVE_HTTPSERVER) && defined(HAVE_ZLIB)
            httpserver_init(8888);
#endif
            break;
        case RUNLOOP_CTL_HTTPSERVER_DESTROY:
#if defined(HAVE_HTTPSERVER) && defined(HAVE_ZLIB)
            httpserver_destroy();
#endif
            break;
        case RUNLOOP_CTL_NONE:
        default:
            break;
    }
    
    return true;
}

/**
 * init_libretro_sym:
 * @type                        : Type of core to be loaded.
 *                                If CORE_TYPE_DUMMY, will
 *                                load dummy symbols.
 *
 * Initializes libretro symbols and
 * setups environment callback functions.
 **/
void init_libretro_sym(enum rarch_core_type type, struct retro_core_t *current_core)
{
    /* Guarantee that we can do "dirty" casting.
     * Every OS that this program supports should pass this. */
    retro_assert(sizeof(void*) == sizeof(void (*)(void)));
    
    load_symbols(type, current_core);
}

void retro_set_environment(retro_environment_t cb)
{
    GET_CURRENT_OR_RETURN();
    environ_cb = cb;
    current->core->retro_set_environment(cb);
}

static void core_log(enum retro_log_level level, const char * fmt, ...) {
    char buffer[4096] = {0};
    static const char * levelstr[] = {
        "dbg",
        "inf",
        "wrn",
        "err"
    };
    va_list va;
    
    va_start(va, fmt);
    vsnprintf(buffer, sizeof(buffer), fmt, va);
    va_end(va);
    
    if (level == 0)
        return;
    
    switch (level) {
        case 0:
            DLOG(@"%s", buffer);
            break;
        case 1:
            ILOG(@"%s", buffer);
            break;
        case 2:
            WLOG(@"%s", buffer);
            break;
        case 3:
            ELOG(@"%s", buffer);
            break;
        default:
            break;
    }
    
    fprintf(stderr, "[%s] %s", levelstr[level], buffer);
    fflush(stderr);
    
    if (level == RETRO_LOG_ERROR) {
        exit(EXIT_FAILURE);
    }
}

/*
 TODO:
 make an obj-c version this calls
 and make sure to call the subclass and super(this) classses
 custom core configs are set with keys, search `desmume_advanced_timing`, `desmume_internal_resolution` for example.
 will need to make a list for each core and type those into core options
 */
static bool environment_callback(unsigned cmd, void *data) {
    __strong PVLibRetroCore *strongCurrent = _current;
    
    switch(cmd) {
        case RETRO_ENVIRONMENT_SET_ROTATION:
                                                        /* const unsigned * --
                                                        * Sets screen rotation of graphics.
                                                        * Valid values are 0, 1, 2, 3, which rotates screen by 0, 90, 180,
                                                        * 270 degrees counter-clockwise respectively.
                                                        */
            ILOG(@"%i", *(const unsigned*)data);
            return false;
        case RETRO_ENVIRONMENT_SET_CONTROLLER_INFO: {
            controller_info = (const struct retro_controller_info*)data;
            return true;
        }
        case RETRO_ENVIRONMENT_SET_DISK_CONTROL_INTERFACE:
                                                      /* const struct retro_disk_control_callback * --
                                                       * Sets an interface which frontend can use to eject and insert
                                                       * disk images.
                                                       * This is used for games which consist of multiple images and
                                                       * must be manually swapped out by the user (e.g. PSX).
                                                       */
//            const struct retro_disk_control_callback* cb = (const struct retro_disk_control_callback*)data
//            ILOG(@"%i", cb->data);
            return false;
        case RETRO_ENVIRONMENT_SET_HW_RENDER_CONTEXT_NEGOTIATION_INTERFACE: {
            /* const struct retro_hw_render_context_negotiation_interface * --
             * Sets an interface which lets the libretro core negotiate with frontend how a context is created.
             * The semantics of this interface depends on which API is used in SET_HW_RENDER earlier.
             * This interface will be used when the frontend is trying to create a HW rendering context,
             * so it will be used after SET_HW_RENDER, but before the context_reset callback.
             */
            const struct retro_hw_render_context_negotiation_interface* cb = (const struct retro_hw_render_context_negotiation_interface*)data;
            hw_render_interface_type = cb->interface_type;
            hw_render_interface_version = cb->interface_version;
            ILOG(@"interface_type: %i, interface_version: %i", cb->interface_type, cb->interface_version);
            return true;
        }
        case RETRO_ENVIRONMENT_SET_HW_SHARED_CONTEXT: {
            /* N/A (null) * --
             * The frontend will try to use a 'shared' hardware context (mostly applicable
             * to OpenGL) when a hardware context is being set up.
             *
             * Returns true if the frontend supports shared hardware contexts and false
             * if the frontend does not support shared hardware contexts.
             *
             * This will do nothing on its own until SET_HW_RENDER env callbacks are
             * being used.
             */
            // *(bool*)data;
            return true;
        }
        case RETRO_ENVIRONMENT_SET_HW_RENDER: {
            /* struct retro_hw_render_callback * --
             * Sets an interface to let a libretro core render with
             * hardware acceleration.
             * Should be called in retro_load_game().
             * If successful, libretro cores will be able to render to a
             * frontend-provided framebuffer.
             * The size of this framebuffer will be at least as large as
             * max_width/max_height provided in get_av_info().
             * If HW rendering is used, pass only RETRO_HW_FRAME_BUFFER_VALID or
             * NULL to retro_video_refresh_t.
             */
            struct retro_hw_render_callback* cb = (struct retro_hw_render_callback*)data;
            hw_render_callback = cb;
            cb->get_proc_address = libretro_get_proc_address;

            //            ILOG(@"%i", cb);
            return true;
        }
        case RETRO_ENVIRONMENT_SET_KEYBOARD_CALLBACK: {
            /* const struct retro_keyboard_callback * --
             * Sets a callback function used to notify core about keyboard events.
             */
            const struct retro_keyboard_callback* cb = (const struct retro_keyboard_callback*)data;
            keyboard_event = cb->callback;
            return true;
        }
        case RETRO_ENVIRONMENT_GET_RUMBLE_INTERFACE: {
           /* struct retro_rumble_interface * --
            * Gets an interface which is used by a libretro core to set
            * state of rumble motors in controllers.
            * A strong and weak motor is supported, and they can be
            * controlled indepedently.
            * Should be called from either retro_init() or retro_load_game().
            * Should not be called from retro_set_environment().
            * Returns false if rumble functionality is unavailable.
            */
            BOOL supportsRumble = strongCurrent.supportsRumble;
            if (supportsRumble) {
                struct retro_rumble_interface* rumbleInterface = (struct retro_rumble_interface*)data;
                rumbleInterface->set_rumble_state = rumble;
            }
            return supportsRumble;
        }
//        case RETRO_ENVIRONMENT_GET_VFS_INTERFACE: {
//            /* struct retro_vfs_interface_info * --
//             * Gets access to the VFS interface.
//             * VFS presence needs to be queried prior to load_game or any
//             * get_system/save/other_directory being called to let front end know
//             * core supports VFS before it starts handing out paths.
//             * It is recomended to do so in retro_set_environment
//             */
//            struct retro_vfs_interface_info* vfs = (const struct retro_vfs_interface_info*)data;
//            struct retro_vfs_interface interface;
//            // TODO: set call backs then return true
//            vfs->iface = interface;
//            return false;
//        }
        case RETRO_ENVIRONMENT_GET_LED_INTERFACE: {
            /* struct retro_led_interface * --
             * Gets an interface which is used by a libretro core to set
             * state of LEDs.
             */
        }
//        case RETRO_ENVIRONMENT_GET_AUDIO_VIDEO_ENABLE: {
//        }
        case RETRO_ENVIRONMENT_GET_FASTFORWARDING: {
            /* bool * --
            * Boolean value that indicates whether or not the frontend is in
            * fastforwarding mode.
            */
            *(bool *)data = strongCurrent.isSpeedModified;
            return true;
        }
        case RETRO_ENVIRONMENT_GET_TARGET_REFRESH_RATE: {
            /* float * --
            * Float value that lets us know what target refresh rate
            * is curently in use by the frontend.
            *
            * The core can use the returned value to set an ideal
            * refresh rate/framerate.
            */
            *(float *)data = strongCurrent.frameInterval;
            return true;
        }
//        case RETRO_ENVIRONMENT_GET_INPUT_BITMASKS: {
//            /* bool * --
//            * Boolean value that indicates whether or not the frontend supports
//            * input bitmasks being returned by retro_input_state_t. The advantage
//            * of this is that retro_input_state_t has to be only called once to
//            * grab all button states instead of multiple times.
//            *
//            * If it returns true, you can pass RETRO_DEVICE_ID_JOYPAD_MASK as 'id'
//            * to retro_input_state_t (make sure 'device' is set to RETRO_DEVICE_JOYPAD).
//            * It will return a bitmask of all the digital buttons.
//            */
//#warning "Test this trua and false"
//            *(bool *)data = false;
//            return true;
//        }
        case RETRO_ENVIRONMENT_GET_MIDI_INTERFACE: {
            /* struct retro_midi_interface ** --
             * Returns a MIDI interface that can be used for raw data I/O.
             */

            struct retro_midi_interface* midiInterface = (struct retro_midi_interface*)data;
            midiInterface->read = midi_read;
            midiInterface->write = midi_write;
            midiInterface->flush = midi_flush;
            midiInterface->input_enabled = midi_input_enabled;
            midiInterface->output_enabled = midi_output_enabled;
            return true;
        }
        case RETRO_ENVIRONMENT_GET_INPUT_DEVICE_CAPABILITIES: {
                                           /* uint64_t * --
                                            * Gets a bitmask telling which device type are expected to be
                                            * handled properly in a call to retro_input_state_t.
                                            * Devices which are not handled or recognized always return
                                            * 0 in retro_input_state_t.
                                            * Example bitmask: caps = (1 << RETRO_DEVICE_JOYPAD) | (1 << RETRO_DEVICE_ANALOG).
                                            * Should only be called in retro_run().
                                            */
            // RETRO_DEVICE_MOUSE RETRO_DEVICE_LIGHTGUN RETRO_DEVICE_POINTER RETRO_DEVICE_KEYBOARD
            uint64_t features = (1 << RETRO_DEVICE_JOYPAD) | (1 << RETRO_DEVICE_ANALOG);
            // TODO: set RETRO_DEVICE_ANALOG only if dual shocks exist or other alaogue inputs?
            if ([strongCurrent conformsToProtocol:@protocol(KeyboardResponder)]) {
                features  |= 1 << RETRO_DEVICE_KEYBOARD;
            }
            if ([strongCurrent conformsToProtocol:@protocol(MouseResponder)]) {
                features  |= 1 << RETRO_DEVICE_MOUSE;
            }
            if ([strongCurrent conformsToProtocol:@protocol(TouchPadResponder)]) {
                features  |= 1 << RETRO_DEVICE_POINTER;
            }
            // RETRO_DEVICE_LIGHTGUN 
            *(uint64_t *)data = features;
            return true;
        }
        case RETRO_ENVIRONMENT_GET_SENSOR_INTERFACE: {
            /* struct retro_sensor_interface * --
             * Gets access to the sensor interface.
             * The purpose of this interface is to allow
             * setting state related to sensors such as polling rate,
             * enabling/disable it entirely, etc.
             * Reading sensor state is done via the normal
             * input_state_callback API.
             */
            struct retro_sensor_interface* sensorInterface = (struct retro_sensor_interface*)data;
            sensorInterface->get_sensor_input = get_sensor_input;
            sensorInterface->set_sensor_state = sensor_state;
            return true;
        }
        case RETRO_ENVIRONMENT_GET_CAMERA_INTERFACE: {
            
            /* struct retro_camera_callback * --
             * Gets an interface to a video camera driver.
             * A libretro core can use this interface to get access to a
             * video camera.
             * New video frames are delivered in a callback in same
             * thread as retro_run().
             *
             * GET_CAMERA_INTERFACE should be called in retro_load_game().
             *
             * Depending on the camera implementation used, camera frames
             * will be delivered as a raw framebuffer,
             * or as an OpenGL texture directly.
             *
             * The core has to tell the frontend here which types of
             * buffers can be handled properly.
             * An OpenGL texture can only be handled when using a
             * libretro GL core (SET_HW_RENDER).
             * It is recommended to use a libretro GL core when
             * using camera interface.
             *
             * The camera is not started automatically. The retrieved start/stop
             * functions must be used to explicitly
             * start and stop the camera driver.
             */
            struct retro_camera_callback* cameraInterface = (struct retro_camera_callback*)data;
            cameraInterface->start = camera_start;
            cameraInterface->stop = camera_stop;
            camera_raw_framebuffer = cameraInterface->frame_raw_framebuffer;
            camera_raw_frame_opengl_texture = cameraInterface->frame_opengl_texture;
            camera_lifetime_status_initialized = cameraInterface->initialized;
            camera_lifetime_status_deinitialized = cameraInterface->deinitialized;

            return true;
        }
        case RETRO_ENVIRONMENT_GET_LOCATION_INTERFACE: {
            /* struct retro_location_callback * --
             * Gets access to the location interface.
             * The purpose of this interface is to be able to retrieve
             * location-based information from the host device,
             * such as current latitude / longitude.
             */
            struct retro_location_callback* location_callback = (struct retro_location_callback*)data;
            location_callback->start = location_start;
            location_callback->stop = location_stop;
            location_callback->get_position = location_get_position;
            location_callback->set_interval = location_set_interval;
            location_initialized = location_callback->initialized;
            location_deinitialized = location_callback->deinitialized;

            return true;
        }
        case RETRO_ENVIRONMENT_GET_CAN_DUPE:
            *(bool *)data = true;
            return true;
        case RETRO_ENVIRONMENT_GET_LOG_INTERFACE: {
            struct retro_log_callback* cb = (struct retro_log_callback*)data;
            cb->log = core_log;
            return true;
        }
        case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY : {
            NSString *BIOSPath = [strongCurrent BIOSPath];
            char *buffer = calloc(256, sizeof(char));
            
            strncpy(buffer, [BIOSPath UTF8String], BIOSPath.length);
            *(const char **)data = buffer;
            
            DLOG(@"Environ SYSTEM_DIRECTORY: \"%@\".\n", BIOSPath);
            return true;
        }
        case RETRO_ENVIRONMENT_GET_CURRENT_SOFTWARE_FRAMEBUFFER : {
            /* struct retro_framebuffer * --
             * Returns a preallocated framebuffer which the core can use for rendering
             * the frame into when not using SET_HW_RENDER.
             * The framebuffer returned from this call must not be used
             * after the current call to retro_run() returns.
             *
             * The goal of this call is to allow zero-copy behavior where a core
             * can render directly into video memory, avoiding extra bandwidth cost by copying
             * memory from core to video memory.
             *
             * If this call succeeds and the core renders into it,
             * the framebuffer pointer and pitch can be passed to retro_video_refresh_t.
             * If the buffer from GET_CURRENT_SOFTWARE_FRAMEBUFFER is to be used,
             * the core must pass the exact
             * same pointer as returned by GET_CURRENT_SOFTWARE_FRAMEBUFFER;
             * i.e. passing a pointer which is offset from the
             * buffer is undefined. The width, height and pitch parameters
             * must also match exactly to the values obtained from GET_CURRENT_SOFTWARE_FRAMEBUFFER.
             *
             * It is possible for a frontend to return a different pixel format
             * than the one used in SET_PIXEL_FORMAT. This can happen if the frontend
             * needs to perform conversion.
             *
             * It is still valid for a core to render to a different buffer
             * even if GET_CURRENT_SOFTWARE_FRAMEBUFFER succeeds.
             *
             * A frontend must make sure that the pointer obtained from this function is
             * writeable (and readable).
             */
           /*
            void *data;                      The framebuffer which the core can render into.
                                                Set by frontend in GET_CURRENT_SOFTWARE_FRAMEBUFFER.
                                                The initial contents of data are unspecified.
            unsigned width;                  The framebuffer width used by the core. Set by core.
            unsigned height;                 The framebuffer height used by the core. Set by core.
            size_t pitch;                    The number of bytes between the beginning of a scanline,
                                                and beginning of the next scanline.
                                                Set by frontend in GET_CURRENT_SOFTWARE_FRAMEBUFFER.
            enum retro_pixel_format format;  The pixel format the core must use to render into data.
                                                This format could differ from the format used in
                                                SET_PIXEL_FORMAT.
                                                Set by frontend in GET_CURRENT_SOFTWARE_FRAMEBUFFER.

            unsigned access_flags;           How the core will access the memory in the framebuffer.
                                                RETRO_MEMORY_ACCESS_* flags.
                                                Set by core.
            unsigned memory_flags;           Flags telling core how the memory has been mapped.
                                                RETRO_MEMORY_TYPE_* flags.
                                                Set by frontend in GET_CURRENT_SOFTWARE_FRAMEBUFFER.
            */
            struct retro_framebuffer *fb =
                    (struct retro_framebuffer *)data;
            fb->data = [strongCurrent videoBuffer];
            fb->pitch = strongCurrent->pitch_shift;
            fb->format = strongCurrent.internalPixelFormat;
            /*
             #define RETRO_MEMORY_ACCESS_WRITE (1 << 0)
                The core will write to the buffer provided by retro_framebuffer::data.
             #define RETRO_MEMORY_ACCESS_READ (1 << 1)
                The core will read from retro_framebuffer::data.
             #define RETRO_MEMORY_TYPE_CACHED (1 << 0)
                The memory in data is cached.
                 * If not cached, random writes and/or reading from the buffer is expected to be very slow.
            */
            fb->memory_flags = RETRO_MEMORY_TYPE_CACHED;
            return true;
        }
//            // TODO: When/if vulkan support add this
//        case RETRO_ENVIRONMENT_GET_HW_RENDER_INTERFACE : {
//            struct retro_hw_render_interface* rend = (struct retro_hw_render_interface*)data;
//            rend->interface_version = 3.1;
//            rend->interface_type = RETRO_HW_RENDER_INTERFACE_DUMMY;
//            return true;
//        }
        case RETRO_ENVIRONMENT_SET_SUPPORT_ACHIEVEMENTS: {
            strongCurrent->supportsAchievements = *(bool*)data;
            return true;
        }
//        case RETRO_ENVIRONMENT_SET_CORE_OPTIONS: {
//            /* const struct retro_core_option_definition ** --
//             * Allows an implementation to signal the environment
//             * which variables it might want to check for later using
//             * GET_VARIABLE.
//             * This allows the frontend to present these variables to
//             * a user dynamically.
//             * This should only be called if RETRO_ENVIRONMENT_GET_CORE_OPTIONS_VERSION
//             * returns an API version of >= 1.
//             * This should be called instead of RETRO_ENVIRONMENT_SET_VARIABLES.
//             * This should be called the first time as early as
//             * possible (ideally in retro_set_environment).
//             * Afterwards it may be called again for the core to communicate
//             * updated options to the frontend, but the number of core
//             * options must not change from the number in the initial call.
//             *
//             * 'data' points to an array of retro_core_option_definition structs
//             * terminated by a { NULL, NULL, NULL, {{0}}, NULL } element.
//             * retro_core_option_definition::key should be namespaced to not collide
//             * with other implementations' keys. e.g. A core called
//             * 'foo' should use keys named as 'foo_option'.
//             * retro_core_option_definition::desc should contain a human readable
//             * description of the key.
//             * retro_core_option_definition::info should contain any additional human
//             * readable information text that a typical user may need to
//             * understand the functionality of the option.
//             * retro_core_option_definition::values is an array of retro_core_option_value
//             * structs terminated by a { NULL, NULL } element.
//             * > retro_core_option_definition::values[index].value is an expected option
//             *   value.
//             * > retro_core_option_definition::values[index].label is a human readable
//             *   label used when displaying the value on screen. If NULL,
//             *   the value itself is used.
//             * retro_core_option_definition::default_value is the default core option
//             * setting. It must match one of the expected option values in the
//             * retro_core_option_definition::values array. If it does not, or the
//             * default value is NULL, the first entry in the
//             * retro_core_option_definition::values array is treated as the default.
//             *
//             * The number of possible option values should be very limited,
//             * and must be less than RETRO_NUM_CORE_OPTION_VALUES_MAX.
//             * i.e. it should be feasible to cycle through options
//             * without a keyboard.
//             *
//             * Example entry:
//             * {
//             *     "foo_option",
//             *     "Speed hack coprocessor X",
//             *     "Provides increased performance at the expense of reduced accuracy",
//             *       {
//             *         { "false",    NULL },
//             *         { "true",     NULL },
//             *         { "unstable", "Turbo (Unstable)" },
//             *         { NULL, NULL },
//             *     },
//             *     "false"
//             * }
//             *
//             * Only strings are operated on. The possible values will
//             * generally be displayed and stored as-is by the frontend.
//             */
//            const struct retro_core_option_definition ** options = (retro_core_option_definition **)data;
//            // TODO: Core options dynamically here
//            options->
//            return true;
//        }
        case RETRO_ENVIRONMENT_GET_PREFERRED_HW_RENDER: {
            /* unsigned * --
             *
             * Allows an implementation to ask frontend preferred hardware
             * context to use. Core should use this information to deal
             * with what specific context to request with SET_HW_RENDER.
             *
             * 'data' points to an unsigned variable
             */
            *(unsigned*)data = RETRO_HW_CONTEXT_OPENGLES3; // RETRO_HW_CONTEXT_OPENGLES3
            return true;
        }
//        case RETRO_ENVIRONMENT_SET_DISK_CONTROL_EXT_INTERFACE: {
//            /* const struct retro_disk_control_ext_callback * --
//             * Sets an interface which frontend can use to eject and insert
//             * disk images, and also obtain information about individual
//             * disk image files registered by the core.
//             * This is used for games which consist of multiple images and
//             * must be manually swapped out by the user (e.g. PSX, floppy disk
//             * based systems).
//             */
//            enum retro_disk_control_ext_callback ext =
//               *(const struct retro_disk_control_ext_callback*)data;
//            // TODO: THIS
//            /*    retro_set_eject_state_t set_eject_state;
//             retro_get_eject_state_t get_eject_state;
//
//             retro_get_image_index_t get_image_index;
//             retro_set_image_index_t set_image_index;
//             retro_get_num_images_t  get_num_images;
//
//             retro_replace_image_index_t replace_image_index;
//             retro_add_image_index_t add_image_index;
//
//             /* NOTE: Frontend will only attempt to record/restore
//              * last used disk index if both set_initial_image()
//              * and get_image_path() are implemented
//             retro_set_initial_image_t set_initial_image; /* Optional - may be NULL
//
//             retro_get_image_path_t get_image_path;       /* Optional - may be NULL
//             retro_get_image_label_t get_image_label;     /* Optional - may be NULL
//            */
//            ext->
//            return true;
//        }
        case RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY : {
            NSString *appSupportPath = [strongCurrent saveStatesPath];
            
            *(const char **)data = [appSupportPath UTF8String];
            DLOG(@"Environ SAVE_DIRECTORY: \"%s\".\n",  (const char *)data);
            return true;
        }
        case RETRO_ENVIRONMENT_GET_CORE_ASSETS_DIRECTORY : {
            NSString *batterySavesPath = [strongCurrent batterySavesPath];
            
            *(const char **)data = [batterySavesPath UTF8String];
            DLOG(@"Environ CONTENT_DIRECTORY: \"%@\".\n", batterySavesPath);
            return true;
        }
        case RETRO_ENVIRONMENT_SET_FRAME_TIME_CALLBACK: {
            /* const struct retro_frame_time_callback * --
             * Lets the core know how much time has passed since last
             * invocation of retro_run().
             * The frontend can tamper with the timing to fake fast-forward,
             * slow-motion, frame stepping, etc.
             * In this case the delta time will use the reference value
             * in frame_time_callback..
             */
            const struct retro_frame_time_callback* frame_time =
               (const struct retro_frame_time_callback*)data;
            frame_time_callback = frame_time->callback;

            return true;
        }
        case RETRO_ENVIRONMENT_SET_AUDIO_CALLBACK: {
            /* const struct retro_audio_callback * --
             * Sets an interface which is used to notify a libretro core about audio
             * being available for writing.
             * The callback can be called from any thread, so a core using this must
             * have a thread safe audio implementation.
             * It is intended for games where audio and video are completely
             * asynchronous and audio can be generated on the fly.
             * This interface is not recommended for use with emulators which have
             * highly synchronous audio.
             *
             * The callback only notifies about writability; the libretro core still
             * has to call the normal audio callbacks
             * to write audio. The audio callbacks must be called from within the
             * notification callback.
             * The amount of audio data to write is up to the implementation.
             * Generally, the audio callback will be called continously in a loop.
             *
             * Due to thread safety guarantees and lack of sync between audio and
             * video, a frontend  can selectively disallow this interface based on
             * internal configuration. A core using this interface must also
             * implement the "normal" audio interface.
             *
             * A libretro core using SET_AUDIO_CALLBACK should also make use of
             * SET_FRAME_TIME_CALLBACK.
             */
            const struct retro_audio_callback* audio =
               (const struct retro_audio_callback*)data;
            audio_callback_notify = audio->callback;
            audio_set_state_notify = audio->set_state ;
            return true;
        }
        case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT: {
            enum retro_pixel_format pix_fmt =
               *(const enum retro_pixel_format*)data;

            switch (pix_fmt)
            {
               case RETRO_PIXEL_FORMAT_0RGB1555:
                    DLOG(@"Environ SET_PIXEL_FORMAT: 0RGB1555.\n");
                  break;

               case RETRO_PIXEL_FORMAT_RGB565:
                    DLOG(@"Environ SET_PIXEL_FORMAT: RGB565.\n");
//                    return false;
                  break;
               case RETRO_PIXEL_FORMAT_XRGB8888:
                    DLOG(@"Environ SET_PIXEL_FORMAT: XRGB8888.\n");
                  break;
               default:
                    ELOG(@"Environ SET_PIXEL_FORMAT: UNKNOWN.\n");
                  return false;
            }
            // TODO: Remake gl or metal contexts if changed?
            strongCurrent->pix_fmt = pix_fmt;
            return true;
            break;
         }
        case RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS: {
            const struct retro_input_descriptor *descriptor = (const struct retro_input_descriptor*)data;
            /*    unsigned port;
             unsigned device;
             unsigned index;
             unsigned id;

             /* Human readable description for parameters.
              * The pointer must remain valid until
              * retro_unload_game() is called.
             const char *description;
            */
            VLOG(@"RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS: device:%i index:%i id:%i desc: %s\n", descriptor->device, descriptor->index, descriptor->id, descriptor->description);
            return true;
        }
        case RETRO_ENVIRONMENT_SET_VARIABLES:
        {
            // We could potentionally ask the user what options they want
            const struct retro_variable* envs = (const struct retro_variable*)data;
            int i=0;
            const struct retro_variable *currentEnv;
            do {
                currentEnv = &envs[i];
                ILOG(@"Environ SET_VARIABLES: {\"%s\",\"%s\"}.\n", currentEnv->key, currentEnv->value);
                i++;
            } while(currentEnv->key != NULL && currentEnv->value != NULL);

            break;

        }
//        case RETRO_ENVIRONMENT_SET_PROC_ADDRESS_CALLBACK: {
//            /* const struct retro_get_proc_address_interface * --
//             * Allows a libretro core to announce support for the
//             * get_proc_address() interface.
//             * This interface allows for a standard way to extend libretro where
//             * use of environment calls are too indirect,
//             * e.g. for cases where the frontend wants to call directly into the core.
//             *
//             * If a core wants to expose this interface, SET_PROC_ADDRESS_CALLBACK
//             * **MUST** be called from within retro_set_environment().
//             */
//            const struct retro_get_proc_address_interface* get_proc_address_interface = (const struct retro_get_proc_address_interface*)data;
//            get_proc_address_interface->get_proc_address = get_proc_address_interface;
//        }
        case RETRO_ENVIRONMENT_SET_SUBSYSTEM_INFO: {
            /* const struct retro_subsystem_info * --
             * This environment call introduces the concept of libretro "subsystems".
             * A subsystem is a variant of a libretro core which supports
             * different kinds of games.
             * The purpose of this is to support e.g. emulators which might
             * have special needs, e.g. Super Nintendo's Super GameBoy, Sufami Turbo.
             * It can also be used to pick among subsystems in an explicit way
             * if the libretro implementation is a multi-system emulator itself.
             *
             * Loading a game via a subsystem is done with retro_load_game_special(),
             * and this environment call allows a libretro core to expose which
             * subsystems are supported for use with retro_load_game_special().
             * A core passes an array of retro_game_special_info which is terminated
             * with a zeroed out retro_game_special_info struct.
             *
             * If a core wants to use this functionality, SET_SUBSYSTEM_INFO
             * **MUST** be called from within retro_set_environment().
             */
            const struct retro_subsystem_info *l_subsystem_info =
                    (const struct retro_subsystem_info *)data;
            subsystem_info = l_subsystem_info;
            return true;
        }
        case RETRO_ENVIRONMENT_GET_GAME_INFO_EXT:
        {
            const struct retro_game_info_ext **game_info_ext =
                    (const struct retro_game_info_ext **)data;
            
//            content_state_t *p_content                       =
//                  content_state_get_ptr();
//
//            const struct retro_game_info_ext **game_info_ext =
//                  (const struct retro_game_info_ext **)data;
//
            if (!game_info_ext) {
                ELOG(@"`game_info_ext` is nil.")
                return false;
            }
            // TODO: Zip support?
            ////            struct retro_game_info_ext *game_info = (struct retro_game_info_ext*)data;
            //            // TODO: Is there a way to pass `retro_game_info_ext` before callbacks?
            struct retro_game_info_ext *game_info = malloc(sizeof(struct retro_game_info_ext));
            game_info->persistent_data = true;
            
            //            void *buffer = malloc(romData.length);
            //            [romData getBytes:buffer length:romData.length];
            //
            //            game_info->data = buffer;
            NSString *romPath = strongCurrent.romPath;
            NSData *romData = [NSData dataWithContentsOfFile:romPath];
            game_info->data = romData.bytes;
            game_info->size = romData.length;
            
            const char *c_full_path = [strongCurrent.romPath cStringUsingEncoding:NSUTF8StringEncoding];
            game_info->full_path = c_full_path;
            
            const char *c_dir = [[strongCurrent.romPath stringByDeletingLastPathComponent] cStringUsingEncoding:NSUTF8StringEncoding];
            game_info->dir = c_dir;
            
            const char *c_rom_name = [[strongCurrent.romPath.lastPathComponent stringByDeletingPathExtension] cStringUsingEncoding:NSUTF8StringEncoding];
            game_info->name = c_rom_name;
            
            const char *c_extension = [[strongCurrent.romPath.lastPathComponent pathExtension] cStringUsingEncoding:NSUTF8StringEncoding];
            game_info->ext = c_extension;

            *game_info_ext = game_info;
//            *game_info_ext = &game_info;
            return true;
            break;
        }
        case RETRO_ENVIRONMENT_GET_VARIABLE:
        {
            struct retro_variable *var = (struct retro_variable*)data;

           void *value = [strongCurrent getVariable:var->key];
            var->value = value;
            return true;
            break;
        }
        case RETRO_ENVIRONMENT_SET_CORE_OPTIONS_V2: {
            const struct retro_core_options_v2* options = (const struct retro_core_options_v2*)data;
            core_options = options;
            
            return true;
        }
        case RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE: {
            // TODO: if somethig is set this should return true
            return false;
        }
        case RETRO_ENVIRONMENT_GET_THROTTLE_STATE: {
            /* struct retro_throttle_state * --
             * Allows an implementation to get details on the actual rate
             * the frontend is attempting to call retro_run().
             */
            struct retro_throttle_state *throttle_state = (struct retro_throttle_state*)data;
            /* During normal operation. Rate will be equal to the core's internal FPS.
            #define RETRO_THROTTLE_NONE              0

               While paused or stepping single frames. Rate will be 0.
            #define RETRO_THROTTLE_FRAME_STEPPING    1

               During fast forwarding.
             * Rate will be 0 if not specifically limited to a maximum speed.
            #define RETRO_THROTTLE_FAST_FORWARD      2

               During slow motion. Rate will be less than the core's internal FPS.
            #define RETRO_THROTTLE_SLOW_MOTION       3

               While rewinding recorded save states. Rate can vary depending on the rewind
             * speed or be 0 if the frontend is not aiming for a specific rate.
            #define RETRO_THROTTLE_REWINDING         4

               While vsync is active in the video driver and the target refresh rate is
             * lower than the core's internal FPS. Rate is the target refresh rate.
            #define RETRO_THROTTLE_VSYNC             5

               When the frontend does not throttle in any way. Rate will be 0.
             * An example could be if no vsync or audio output is active.
            #define RETRO_THROTTLE_UNBLOCKED         6 */
            if(strongCurrent.gameSpeed == GameSpeedSlow) {
                throttle_state->mode = RETRO_THROTTLE_SLOW_MOTION;
            } else if(strongCurrent.gameSpeed == GameSpeedFast) {
                throttle_state->mode = RETRO_THROTTLE_FAST_FORWARD;
            } else {
                // TODO:
                throttle_state->mode = RETRO_THROTTLE_VSYNC;
                // RETRO_THROTTLE_NONE normal
                // RETRO_THROTTLE_UNBLOCKEDif no audio
                // RETRO_THROTTLE_VSYNC if vsync
            }
            return true;
        }
        case RETRO_ENVIRONMENT_GET_LIBRETRO_PATH: {
            /* const char ** --
             * Retrieves the absolute path from where this libretro
             * implementation was loaded.
             * NULL is returned if the libretro was loaded statically
             * (i.e. linked statically to frontend), or if the path cannot be
             * determined.
             * Mostly useful in cooperation with SET_SUPPORT_NO_GAME as assets can
             * be loaded without ugly hacks.
             */

            /* Environment 20 was an obsolete version of SET_AUDIO_CALLBACK.
             * It was not used by any known core at the time,
             * and was removed from the API. */
//            const char **
            const char **path = (const char**)data;
            Class myClass = [strongCurrent class];
            NSString *fPath = [NSBundle bundleForClass:myClass].bundleURL.path;
            *path = [fPath cStringUsingEncoding:NSUTF8StringEncoding];
            return false;
        }
        case RETRO_ENVIRONMENT_SET_MINIMUM_AUDIO_LATENCY: {
            /* const unsigned * --
             * Sets minimum frontend audio latency in milliseconds.
             * Resultant audio latency may be larger than set value,
             * or smaller if a hardware limit is encountered. A frontend
             * is expected to honour requests up to 512 ms.
             *
             * - If value is less than current frontend
             *   audio latency, callback has no effect
             * - If value is zero, default frontend audio
             *   latency is set
             *
             * May be used by a core to increase audio latency and
             * therefore decrease the probability of buffer under-runs
             * (crackling) when performing 'intensive' operations.
             * A core utilising RETRO_ENVIRONMENT_SET_AUDIO_BUFFER_STATUS_CALLBACK
             * to implement audio-buffer-based frame skipping may achieve
             * optimal results by setting the audio latency to a 'high'
             * (typically 6x or 8x) integer multiple of the expected
             * frame time.
             *
             * WARNING: This can only be called from within retro_run().
             * Calling this can require a full reinitialization of audio
             * drivers in the frontend, so it is important to call it very
             * sparingly, and usually only with the users explicit consent.
             * An eventual driver reinitialize will happen so that audio
             * callbacks happening after this call within the same retro_run()
             * call will target the newly initialized driver.
             */
#if TARGET_OS_TV
            return false;
#else
            const unsigned latency = *((const unsigned*)data);
            ILOG(@"Set latency <STUB> %f", latency);
            UInt32 propSize = sizeof(Float32);
            AudioSessionSetProperty(kAudioSessionProperty_CurrentHardwareIOBufferDuration,
                                    propSize,
                                    &latency);
            return true;
#endif
        }
        case RETRO_ENVIRONMENT_SET_FASTFORWARDING_OVERRIDE: {
            /* const struct retro_fastforwarding_override * --
             * Used by a libretro core to override the current
             * fastforwarding mode of the frontend.
             * If NULL is passed to this function, the frontend
             * will return true if fastforwarding override
             * functionality is supported (no change in
             * fastforwarding state will occur in this case).
             */
            const struct retro_fastforwarding_override* fastforwarding_override = (const struct retro_fastforwarding_override*)data;
            if(fastforwarding_override == nil) {
                return true;
            }
            if(fastforwarding_override->fastforward) {
                if (fastforwarding_override->ratio < 1.0) {
                    strongCurrent.gameSpeed = GameSpeedSlow;
                } else {
                    strongCurrent.gameSpeed = GameSpeedFast;
                }
            } else  {
                strongCurrent.gameSpeed = GameSpeedNormal;
            }
            return true;
        }
        case RETRO_ENVIRONMENT_SET_AUDIO_BUFFER_STATUS_CALLBACK: {
            /* const struct retro_audio_buffer_status_callback * --
             * Lets the core know the occupancy level of the frontend
             * audio buffer. Can be used by a core to attempt frame
             * skipping in order to avoid buffer under-runs.
             * A core may pass NULL to disable buffer status reporting
             * in the frontend.
             */

            return true;
        }
        case RETRO_ENVIRONMENT_GET_INPUT_MAX_USERS: {
            *((unsigned*)data) = (unsigned)[strongCurrent numberOfUsers];
            return true;
        }
        case RETRO_ENVIRONMENT_GET_MESSAGE_INTERFACE_VERSION:
        {
            *((unsigned*)data) = 1;
            return true;
        }
        case RETRO_ENVIRONMENT_GET_USERNAME:
        {
            *((const char**)data) = "usename";
            return true;
        }
        case RETRO_ENVIRONMENT_GET_LANGUAGE:
        {
            NSString * languageCode = [NSLocale currentLocale].languageCode;
            enum retro_language language = RETRO_LANGUAGE_ENGLISH;
            if([languageCode isEqualToString:@"en"]) {
                language = RETRO_LANGUAGE_ENGLISH;
            } else if([languageCode isEqualToString:@"jp"]) {
                language = RETRO_LANGUAGE_JAPANESE;
            } else if([languageCode isEqualToString:@"fr"]) {
                language = RETRO_LANGUAGE_FRENCH;
            } else if([languageCode isEqualToString:@"es"]) {
                language = RETRO_LANGUAGE_SPANISH;
            } else if([languageCode isEqualToString:@"de"]) {
                language = RETRO_LANGUAGE_GERMAN;
            } else if([languageCode isEqualToString:@"it"]) {
                language = RETRO_LANGUAGE_ITALIAN;
            } else if([languageCode isEqualToString:@"nl"]) {
                language = RETRO_LANGUAGE_DUTCH;
            } else if([languageCode isEqualToString:@"pt-br"]) {
                language = RETRO_LANGUAGE_PORTUGUESE_BRAZIL;
            } else if([languageCode isEqualToString:@"pt"]) {
                language = RETRO_LANGUAGE_PORTUGUESE_PORTUGAL;
            } else if([languageCode isEqualToString:@"ru"]) {
                language = RETRO_LANGUAGE_RUSSIAN;
            } else if([languageCode isEqualToString:@"cn"]) {
                language = RETRO_LANGUAGE_CHINESE_SIMPLIFIED;
            } else if([languageCode isEqualToString:@"zh-CHT"] || [languageCode isEqualToString:@"zh-Hant"] || [languageCode isEqualToString:@"zh-HK"]) {
                language = RETRO_LANGUAGE_CHINESE_TRADITIONAL;
            } else if([languageCode isEqualToString:@"ko"]) {
                language = RETRO_LANGUAGE_KOREAN;
            } else if([languageCode isEqualToString:@"pl"]) {
                language = RETRO_LANGUAGE_POLISH;
            } else if([languageCode isEqualToString:@"ar"]) {
                language = RETRO_LANGUAGE_ARABIC;
            } else if([languageCode isEqualToString:@"el"]) {
                language = RETRO_LANGUAGE_GREEK;
            } else if([languageCode isEqualToString:@"he"]) {
                language = RETRO_LANGUAGE_HEBREW;
            } else if([languageCode isEqualToString:@"tr"]) {
                language = RETRO_LANGUAGE_TURKISH;
            } else if([languageCode isEqualToString:@"fas"]) {
                language = RETRO_LANGUAGE_PERSIAN;
            } else if([languageCode isEqualToString:@"vie"]) {
                language = RETRO_LANGUAGE_VIETNAMESE;
            }
            *((unsigned*)data) = language;
            ILOG(@"Get lang: %i, %@", language, languageCode);
            return true;
        }
        case RETRO_ENVIRONMENT_SET_MESSAGE:
        case RETRO_ENVIRONMENT_SET_MESSAGE_EXT:
        {
            struct retro_message* msg = (struct retro_message*)data;
            unsigned int frames = msg->frames;
            const char* txt = msg->msg;
            // TODO: Make an OSD for number of frames
            ILOG(@"msg: %s, frames:%i", txt, frames);
            return [_current osdSetMessage:[NSString stringWithCString:txt encoding:NSUTF8StringEncoding]
                                 forFrames:frames];
        }
        case RETRO_ENVIRONMENT_SET_SYSTEM_AV_INFO:
        {
                                                       /* const struct retro_system_av_info * --
                                                        * Sets a new av_info structure. This can only be called from
                                                        * within retro_run().
                                                        * This should *only* be used if the core is completely altering the
                                                        * internal resolutions, aspect ratios, timings, sampling rate, etc.
                                                        * Calling this can require a full reinitialization of video/audio
                                                        * drivers in the frontend,
                                                        *
                                                        * so it is important to call it very sparingly, and usually only with
                                                        * the users explicit consent.
                                                        * An eventual driver reinitialize will happen so that video and
                                                        * audio callbacks
                                                        * happening after this call within the same retro_run() call will
                                                        * target the newly initialized driver.
                                                        *
                                                        * This callback makes it possible to support configurable resolutions
                                                        * in games, which can be useful to
                                                        * avoid setting the "worst case" in max_width/max_height.
                                                        *
                                                        * ***HIGHLY RECOMMENDED*** Do not call this callback every time
                                                        * resolution changes in an emulator core if it's
                                                        * expected to be a temporary change, for the reasons of possible
                                                        * driver reinitialization.
                                                        * This call is not a free pass for not trying to provide
                                                        * correct values in retro_get_system_av_info(). If you need to change
                                                        * things like aspect ratio or nominal width/height,
                                                        * use RETRO_ENVIRONMENT_SET_GEOMETRY, which is a softer variant
                                                        * of SET_SYSTEM_AV_INFO.
                                                        *
                                                        * If this returns false, the frontend does not acknowledge a
                                                        * changed av_info struct.
                                                        */
#warning "May need to review or remove this, read cmments above"
            struct retro_system_av_info info = *(const struct retro_system_av_info*)data;
            strongCurrent->av_info = info;
            ILOG(@"max_width: %i, max_height: %i, base_width: %i, base_height: %i, aspect_ratio: %f, sample_rate: %f, timing.fps: %f", info.geometry.max_width, info.geometry.max_height, info.geometry.base_width, info.geometry.base_height, info.geometry.aspect_ratio, info.timing.sample_rate, info.timing.fps);
            return true;
        }
        default : {
            DLOG(@"Environ UNSUPPORTED (#%u).\n", cmd);
            return false;
        }
    }
    
    strongCurrent = nil;
    
    return true;
}

@import Darwin.POSIX;

static void load_dynamic_core(void)
{
    const char* corepath = config_get_active_core_path();

    ILOG(@"Loading dynamic libretro core from: \"%s\"\n",
         corepath);
    lib_handle = dylib_load(corepath);
    
    //    function_t sym       = dylib_proc(lib_handle, "retro_init");
    
    //    if (sym)
    //    {
    //        /* Try to verify that -lretro was not linked in from other modules
    //         * since loading it dynamically and with -l will fail hard. */
    //        ELOG(@"Serious problem. RetroArch wants to load libretro cores"
    //             "dyamically, but it is already linked.\n");
    //        ELOG(@"This could happen if other modules RetroArch depends on "
    //             "link against libretro directly.\n");
    //        ELOG(@"Proceeding could cause a crash. Aborting ...\n");
    //        retroarch_fail(1, "init_libretro_sym()");
    //    }
    //
    //    if (string_is_empty(config_get_active_core_path()))
    //    {
    //        ELOG(@"RetroArch is built for dynamic libretro cores, but "
    //             "libretro_path is not set. Cannot continue.\n");
    //        retroarch_fail(1, "init_libretro_sym()");
    //    }
    //
    /* Need to use absolute path for this setting. It can be
     * saved to content history, and a relative path would
     * break in that scenario. */
    //   path_resolve_realpath(
    //         config_get_active_core_path_ptr(),
    //         config_get_active_core_path_size());
    //
    //   ILOG(@"Loading dynamic libretro core from: \"%s\"\n",
    //         config_get_active_core_path());
    //   lib_handle = dylib_load(config_get_active_core_path());
    if (!lib_handle)
    {
        ELOG(@"Failed to open libretro core: \"%s\"\n",
             config_get_active_core_path());
        ELOG(@"Error(s): %s\n", dylib_error());
        retroarch_fail(1, "load_dynamic()");
    }
}

/**
 * load_symbols:
 * @type                        : Type of core to be loaded.
 *                                If CORE_TYPE_DUMMY, will
 *                                load dummy symbols.
 *
 * Setup libretro callback symbols.
 **/
static void load_symbols(enum rarch_core_type type, struct retro_core_t *current_core)
{
    
    switch (type)
    {
        case CORE_TYPE_PLAIN:
#ifdef HAVE_DYNAMIC
            load_dynamic_core();
#endif
            ILOG(@"type:%x, current_core: %x, lib_handle: %x", type, current_core, lib_handle);
            
            SYMBOL(retro_init);
            SYMBOL(retro_deinit);
            
            SYMBOL(retro_api_version);
            SYMBOL(retro_get_system_info);
            SYMBOL(retro_get_system_av_info);
            
            SYMBOL(retro_set_environment);
            SYMBOL(retro_set_video_refresh);
            SYMBOL(retro_set_audio_sample);
            SYMBOL(retro_set_audio_sample_batch);
            SYMBOL(retro_set_input_poll);
            SYMBOL(retro_set_input_state);
            
            SYMBOL(retro_set_controller_port_device);
            
            SYMBOL(retro_reset);
            SYMBOL(retro_run);
            
            SYMBOL(retro_serialize_size);
            SYMBOL(retro_serialize);
            SYMBOL(retro_unserialize);
            
            SYMBOL(retro_cheat_reset);
            SYMBOL(retro_cheat_set);
            
            SYMBOL(retro_load_game);
            SYMBOL(retro_load_game_special);
            
            SYMBOL(retro_unload_game);
            SYMBOL(retro_get_region);
            SYMBOL(retro_get_memory_data);
            SYMBOL(retro_get_memory_size);
            break;
        case CORE_TYPE_DUMMY:
            SYMBOL_DUMMY(retro_init);
            SYMBOL_DUMMY(retro_deinit);
            
            SYMBOL_DUMMY(retro_api_version);
            SYMBOL_DUMMY(retro_get_system_info);
            SYMBOL_DUMMY(retro_get_system_av_info);
            
            SYMBOL_DUMMY(retro_set_environment);
            SYMBOL_DUMMY(retro_set_video_refresh);
            SYMBOL_DUMMY(retro_set_audio_sample);
            SYMBOL_DUMMY(retro_set_audio_sample_batch);
            SYMBOL_DUMMY(retro_set_input_poll);
            SYMBOL_DUMMY(retro_set_input_state);
            
            SYMBOL_DUMMY(retro_set_controller_port_device);
            
            SYMBOL_DUMMY(retro_reset);
            SYMBOL_DUMMY(retro_run);
            
            SYMBOL_DUMMY(retro_serialize_size);
            SYMBOL_DUMMY(retro_serialize);
            SYMBOL_DUMMY(retro_unserialize);
            
            SYMBOL_DUMMY(retro_cheat_reset);
            SYMBOL_DUMMY(retro_cheat_set);
            
            SYMBOL_DUMMY(retro_load_game);
            SYMBOL_DUMMY(retro_load_game_special);
            
            SYMBOL_DUMMY(retro_unload_game);
            SYMBOL_DUMMY(retro_get_region);
            SYMBOL_DUMMY(retro_get_memory_data);
            SYMBOL_DUMMY(retro_get_memory_size);
            break;
        case CORE_TYPE_FFMPEG:
#ifdef HAVE_FFMPEG
            SYMBOL_FFMPEG(retro_init);
            SYMBOL_FFMPEG(retro_deinit);
            
            SYMBOL_FFMPEG(retro_api_version);
            SYMBOL_FFMPEG(retro_get_system_info);
            SYMBOL_FFMPEG(retro_get_system_av_info);
            
            SYMBOL_FFMPEG(retro_set_environment);
            SYMBOL_FFMPEG(retro_set_video_refresh);
            SYMBOL_FFMPEG(retro_set_audio_sample);
            SYMBOL_FFMPEG(retro_set_audio_sample_batch);
            SYMBOL_FFMPEG(retro_set_input_poll);
            SYMBOL_FFMPEG(retro_set_input_state);
            
            SYMBOL_FFMPEG(retro_set_controller_port_device);
            
            SYMBOL_FFMPEG(retro_reset);
            SYMBOL_FFMPEG(retro_run);
            
            SYMBOL_FFMPEG(retro_serialize_size);
            SYMBOL_FFMPEG(retro_serialize);
            SYMBOL_FFMPEG(retro_unserialize);
            
            SYMBOL_FFMPEG(retro_cheat_reset);
            SYMBOL_FFMPEG(retro_cheat_set);
            
            SYMBOL_FFMPEG(retro_load_game);
            SYMBOL_FFMPEG(retro_load_game_special);
            
            SYMBOL_FFMPEG(retro_unload_game);
            SYMBOL_FFMPEG(retro_get_region);
            SYMBOL_FFMPEG(retro_get_memory_data);
            SYMBOL_FFMPEG(retro_get_memory_size);
#endif
            break;
        case CORE_TYPE_IMAGEVIEWER:
#ifdef HAVE_IMAGEVIEWER
            SYMBOL_IMAGEVIEWER(retro_init);
            SYMBOL_IMAGEVIEWER(retro_deinit);
            
            SYMBOL_IMAGEVIEWER(retro_api_version);
            SYMBOL_IMAGEVIEWER(retro_get_system_info);
            SYMBOL_IMAGEVIEWER(retro_get_system_av_info);
            
            SYMBOL_IMAGEVIEWER(retro_set_environment);
            SYMBOL_IMAGEVIEWER(retro_set_video_refresh);
            SYMBOL_IMAGEVIEWER(retro_set_audio_sample);
            SYMBOL_IMAGEVIEWER(retro_set_audio_sample_batch);
            SYMBOL_IMAGEVIEWER(retro_set_input_poll);
            SYMBOL_IMAGEVIEWER(retro_set_input_state);
            
            SYMBOL_IMAGEVIEWER(retro_set_controller_port_device);
            
            SYMBOL_IMAGEVIEWER(retro_reset);
            SYMBOL_IMAGEVIEWER(retro_run);
            
            SYMBOL_IMAGEVIEWER(retro_serialize_size);
            SYMBOL_IMAGEVIEWER(retro_serialize);
            SYMBOL_IMAGEVIEWER(retro_unserialize);
            
            SYMBOL_IMAGEVIEWER(retro_cheat_reset);
            SYMBOL_IMAGEVIEWER(retro_cheat_set);
            
            SYMBOL_IMAGEVIEWER(retro_load_game);
            SYMBOL_IMAGEVIEWER(retro_load_game_special);
            
            SYMBOL_IMAGEVIEWER(retro_unload_game);
            SYMBOL_IMAGEVIEWER(retro_get_region);
            SYMBOL_IMAGEVIEWER(retro_get_memory_data);
            SYMBOL_IMAGEVIEWER(retro_get_memory_size);
#endif
            break;
        case CORE_TYPE_NETRETROPAD:
#if defined(HAVE_NETWORKGAMEPAD) && defined(HAVE_NETPLAY)
            SYMBOL_NETRETROPAD(retro_init);
            SYMBOL_NETRETROPAD(retro_deinit);
            
            SYMBOL_NETRETROPAD(retro_api_version);
            SYMBOL_NETRETROPAD(retro_get_system_info);
            SYMBOL_NETRETROPAD(retro_get_system_av_info);
            
            SYMBOL_NETRETROPAD(retro_set_environment);
            SYMBOL_NETRETROPAD(retro_set_video_refresh);
            SYMBOL_NETRETROPAD(retro_set_audio_sample);
            SYMBOL_NETRETROPAD(retro_set_audio_sample_batch);
            SYMBOL_NETRETROPAD(retro_set_input_poll);
            SYMBOL_NETRETROPAD(retro_set_input_state);
            
            SYMBOL_NETRETROPAD(retro_set_controller_port_device);
            
            SYMBOL_NETRETROPAD(retro_reset);
            SYMBOL_NETRETROPAD(retro_run);
            
            SYMBOL_NETRETROPAD(retro_serialize_size);
            SYMBOL_NETRETROPAD(retro_serialize);
            SYMBOL_NETRETROPAD(retro_unserialize);
            
            SYMBOL_NETRETROPAD(retro_cheat_reset);
            SYMBOL_NETRETROPAD(retro_cheat_set);
            
            SYMBOL_NETRETROPAD(retro_load_game);
            SYMBOL_NETRETROPAD(retro_load_game_special);
            
            SYMBOL_NETRETROPAD(retro_unload_game);
            SYMBOL_NETRETROPAD(retro_get_region);
            SYMBOL_NETRETROPAD(retro_get_memory_data);
            SYMBOL_NETRETROPAD(retro_get_memory_size);
#endif
            break;
        case CORE_TYPE_VIDEO_PROCESSOR:
#if defined(HAVE_VIDEO_PROCESSOR)
            SYMBOL_VIDEOPROCESSOR(retro_init);
            SYMBOL_VIDEOPROCESSOR(retro_deinit);
            
            SYMBOL_VIDEOPROCESSOR(retro_api_version);
            SYMBOL_VIDEOPROCESSOR(retro_get_system_info);
            SYMBOL_VIDEOPROCESSOR(retro_get_system_av_info);
            
            SYMBOL_VIDEOPROCESSOR(retro_set_environment);
            SYMBOL_VIDEOPROCESSOR(retro_set_video_refresh);
            SYMBOL_VIDEOPROCESSOR(retro_set_audio_sample);
            SYMBOL_VIDEOPROCESSOR(retro_set_audio_sample_batch);
            SYMBOL_VIDEOPROCESSOR(retro_set_input_poll);
            SYMBOL_VIDEOPROCESSOR(retro_set_input_state);
            
            SYMBOL_VIDEOPROCESSOR(retro_set_controller_port_device);
            
            SYMBOL_VIDEOPROCESSOR(retro_reset);
            SYMBOL_VIDEOPROCESSOR(retro_run);
            
            SYMBOL_VIDEOPROCESSOR(retro_serialize_size);
            SYMBOL_VIDEOPROCESSOR(retro_serialize);
            SYMBOL_VIDEOPROCESSOR(retro_unserialize);
            
            SYMBOL_VIDEOPROCESSOR(retro_cheat_reset);
            SYMBOL_VIDEOPROCESSOR(retro_cheat_set);
            
            SYMBOL_VIDEOPROCESSOR(retro_load_game);
            SYMBOL_VIDEOPROCESSOR(retro_load_game_special);
            
            SYMBOL_VIDEOPROCESSOR(retro_unload_game);
            SYMBOL_VIDEOPROCESSOR(retro_get_region);
            SYMBOL_VIDEOPROCESSOR(retro_get_memory_data);
            SYMBOL_VIDEOPROCESSOR(retro_get_memory_size);
#endif
            break;
    }
}
#define PITCH_SHIFT 2

@implementation PVLibRetroCore

- (instancetype)init {
    if((self = [super init])) {
        virtualPhysicalKeyMap = @{
            @(UIKeyboardHIDUsageKeypad0) : @(RETROK_KP0),
            @(UIKeyboardHIDUsageKeypad1) : @(RETROK_KP1),
            @(UIKeyboardHIDUsageKeypad2) : @(RETROK_KP2),
            @(UIKeyboardHIDUsageKeypad3) : @(RETROK_KP3),
            @(UIKeyboardHIDUsageKeypad4) : @(RETROK_KP4),
            @(UIKeyboardHIDUsageKeypad5) : @(RETROK_KP5),
            @(UIKeyboardHIDUsageKeypad6) : @(RETROK_KP6),
            @(UIKeyboardHIDUsageKeypad7) : @(RETROK_KP7),
            @(UIKeyboardHIDUsageKeypad8) : @(RETROK_KP8),
            @(UIKeyboardHIDUsageKeypad9) : @(RETROK_KP9),

            @(UIKeyboardHIDUsageKeyboard0) : @(RETROK_0),
            @(UIKeyboardHIDUsageKeyboard1) : @(RETROK_1),
            @(UIKeyboardHIDUsageKeyboard2) : @(RETROK_2),
            @(UIKeyboardHIDUsageKeyboard3) : @(RETROK_3),
            @(UIKeyboardHIDUsageKeyboard4) : @(RETROK_4),
            @(UIKeyboardHIDUsageKeyboard5) : @(RETROK_5),
            @(UIKeyboardHIDUsageKeyboard6) : @(RETROK_6),
            @(UIKeyboardHIDUsageKeyboard7) : @(RETROK_7),
            @(UIKeyboardHIDUsageKeyboard8) : @(RETROK_8),
            @(UIKeyboardHIDUsageKeyboard9) : @(RETROK_9),
            
            @(UIKeyboardHIDUsageKeyboardA) : @(RETROK_a),
            @(UIKeyboardHIDUsageKeyboardB) : @(RETROK_b),
            @(UIKeyboardHIDUsageKeyboardC) : @(RETROK_c),
            @(UIKeyboardHIDUsageKeyboardD) : @(RETROK_d),
            @(UIKeyboardHIDUsageKeyboardE) : @(RETROK_e),
            @(UIKeyboardHIDUsageKeyboardF) : @(RETROK_f),
            @(UIKeyboardHIDUsageKeyboardG) : @(RETROK_g),
            @(UIKeyboardHIDUsageKeyboardH) : @(RETROK_h),
            @(UIKeyboardHIDUsageKeyboardI) : @(RETROK_i),
            @(UIKeyboardHIDUsageKeyboardJ) : @(RETROK_j),
            @(UIKeyboardHIDUsageKeyboardK) : @(RETROK_k),
            @(UIKeyboardHIDUsageKeyboardL) : @(RETROK_l),
            @(UIKeyboardHIDUsageKeyboardM) : @(RETROK_m),
            @(UIKeyboardHIDUsageKeyboardN) : @(RETROK_n),
            @(UIKeyboardHIDUsageKeyboardO) : @(RETROK_o),
            @(UIKeyboardHIDUsageKeyboardP) : @(RETROK_p),
            @(UIKeyboardHIDUsageKeyboardQ) : @(RETROK_q),
            @(UIKeyboardHIDUsageKeyboardR) : @(RETROK_r),
            @(UIKeyboardHIDUsageKeyboardS) : @(RETROK_s),
            @(UIKeyboardHIDUsageKeyboardT) : @(RETROK_t),
            @(UIKeyboardHIDUsageKeyboardU) : @(RETROK_u),
            @(UIKeyboardHIDUsageKeyboardV) : @(RETROK_v),
            @(UIKeyboardHIDUsageKeyboardW) : @(RETROK_w),
            @(UIKeyboardHIDUsageKeyboardX) : @(RETROK_x),
            @(UIKeyboardHIDUsageKeyboardY) : @(RETROK_y),
            @(UIKeyboardHIDUsageKeyboardZ) : @(RETROK_z),
            
            @(UIKeyboardHIDUsageKeypadAsterisk) : @(RETROK_KP_MULTIPLY),
            @(UIKeyboardHIDUsageKeypadEnter) : @(RETROK_KP_ENTER),
            @(UIKeyboardHIDUsageKeypadEqualSign) : @(RETROK_EQUALS),
            @(UIKeyboardHIDUsageKeypadPlus) : @(RETROK_KP_PLUS),
            @(UIKeyboardHIDUsageKeypadHyphen) : @(RETROK_KP_MINUS),
            @(UIKeyboardHIDUsageKeypadComma) : @(RETROK_COMMA),
            @(UIKeyboardHIDUsageKeypadPeriod) : @(RETROK_KP_PERIOD),
            @(UIKeyboardHIDUsageKeypadSlash) : @(RETROK_KP_DIVIDE),
            
            @(UIKeyboardHIDUsageKeyboardScrollLock) : @(RETROK_SCROLLOCK),
            @(UIKeyboardHIDUsageKeyboardCapsLock) : @(RETROK_CAPSLOCK),
            @(UIKeyboardHIDUsageKeypadNumLock) : @(RETROK_NUMLOCK),

            @(UIKeyboardHIDUsageKeyboardSpacebar) : @(RETROK_SPACE),
            @(UIKeyboardHIDUsageKeyboardDeleteOrBackspace) : @(RETROK_BACKSPACE),
            @(UIKeyboardHIDUsageKeyboardGraveAccentAndTilde) : @(RETROK_TILDE),
            @(UIKeyboardHIDUsageKeyboardDeleteForward) : @(RETROK_DELETE),
            @(UIKeyboardHIDUsageKeyboardTab) : @(RETROK_TAB),
            @(UIKeyboardHIDUsageKeyboardPause) : @(RETROK_PAUSE),
        //            @(UIKeyboardHIDUsageKeyboardSlash) : @(RETROK_QUESTION),
            @(UIKeyboardHIDUsageKeyboardPeriod) : @(RETROK_PERIOD),
            @(UIKeyboardHIDUsageKeyboardReturnOrEnter) : @(RETROK_RETURN),
            @(UIKeyboardHIDUsageKeyboardHyphen) : @(RETROK_MINUS),
            @(UIKeyboardHIDUsageKeyboardSlash) : @(RETROK_SLASH),

            @(UIKeyboardHIDUsageKeyboardOpenBracket) : @(RETROK_LEFTBRACE),
            @(UIKeyboardHIDUsageKeyboardBackslash) : @(RETROK_BACKSLASH),
        //            @(UIKeyboardHIDUsageKeyboardBackslash) : @(RETROK_BAR), // |
            @(UIKeyboardHIDUsageKeyboardCloseBracket) : @(RETROK_RIGHTBRACE),
            @(UIKeyboardHIDUsageKeyboardQuote) : @(RETROK_QUOTE),

            @(UIKeyboardHIDUsageKeyboardLeftAlt) : @(RETROK_LALT),
            @(UIKeyboardHIDUsageKeyboardLeftGUI) : @(RETROK_LMETA), // RETROK_LSUPER
            @(UIKeyboardHIDUsageKeyboardLeftShift) : @(RETROK_LSHIFT),
            @(UIKeyboardHIDUsageKeyboardLeftControl) : @(RETROK_LCTRL),

            @(UIKeyboardHIDUsageKeyboardRightAlt) : @(RETROK_RALT),
            @(UIKeyboardHIDUsageKeyboardRightGUI) : @(RETROK_RMETA),
            @(UIKeyboardHIDUsageKeyboardRightShift) : @(RETROK_RSHIFT),
            @(UIKeyboardHIDUsageKeyboardRightControl) : @(RETROK_RCTRL),
            
            @(UIKeyboardHIDUsageKeyboardLeftArrow) : @(RETROK_LEFT),
            @(UIKeyboardHIDUsageKeyboardRightArrow) : @(RETROK_RIGHT),
            @(UIKeyboardHIDUsageKeyboardUpArrow) : @(RETROK_UP),
            @(UIKeyboardHIDUsageKeyboardDownArrow) : @(RETROK_DOWN),

            @(UIKeyboardHIDUsageKeyboardF1) : @(RETROK_F1),
            @(UIKeyboardHIDUsageKeyboardF2) : @(RETROK_F2),
            @(UIKeyboardHIDUsageKeyboardF3) : @(RETROK_F3),
            @(UIKeyboardHIDUsageKeyboardF4) : @(RETROK_F4),
            @(UIKeyboardHIDUsageKeyboardF5) : @(RETROK_F5),
            @(UIKeyboardHIDUsageKeyboardF6) : @(RETROK_F6),
            @(UIKeyboardHIDUsageKeyboardF7) : @(RETROK_F7),
            @(UIKeyboardHIDUsageKeyboardF8) : @(RETROK_F8),
            @(UIKeyboardHIDUsageKeyboardF9) : @(RETROK_F9),
            @(UIKeyboardHIDUsageKeyboardF10) : @(RETROK_F10),
            @(UIKeyboardHIDUsageKeyboardF11) : @(RETROK_F11),
            @(UIKeyboardHIDUsageKeyboardF12) : @(RETROK_F12),
            @(UIKeyboardHIDUsageKeyboardF13) : @(RETROK_F13),
            @(UIKeyboardHIDUsageKeyboardF14) : @(RETROK_F14),
            @(UIKeyboardHIDUsageKeyboardF15) : @(RETROK_F15),
            
            @(UIKeyboardHIDUsageKeyboardHelp) : @(RETROK_HELP),
            @(UIKeyboardHIDUsageKeyboardPrintScreen) : @(RETROK_PRINT),
            
            @(UIKeyboardHIDUsageKeyboardUndo) : @(RETROK_UNDO),
            
            @(UIKeyboardHIDUsageKeyboardPageUp) : @(RETROK_PAGEUP),
            @(UIKeyboardHIDUsageKeyboardPageDown) : @(RETROK_PAGEDOWN),
            @(UIKeyboardHIDUsageKeyboardInsert) : @(RETROK_INSERT),
            @(UIKeyboardHIDUsageKeyboardHome) : @(RETROK_HOME),
            @(UIKeyboardHIDUsageKeyboardEnd) : @(RETROK_END),
            
            @(UIKeyboardHIDUsageKeyboardPower) : @(RETROK_POWER),
            @(UIKeyboardHIDUsageKeyboardMenu) : @(RETROK_MENU),
            @(UIKeyboardHIDUsageKeyboardClearOrAgain) : @(RETROK_CLEAR),

            // TODO: There's more codes to add if you want 100%
        };
        
        pitch_shift = PITCH_SHIFT;
        _current = self;
        const char* path = [[NSBundle bundleForClass:[self class]].bundlePath fileSystemRepresentation];
        config_set_active_core_path(path);
        //        load_dynamic_core();
        core = malloc(sizeof(retro_core_t));
        init_libretro_sym(CORE_TYPE_PLAIN, core);
        
        memset(_pad, 0, sizeof(int16_t) * 24);

        struct retro_system_info info;
        core_get_system_info(&info);
        ILOG(@"Loaded %s version %s \n" \
             "Core needs fullpath %i\n",  info.library_name, info.library_version, info.need_fullpath);

        //        libretro_get_system_info(path,
        //        libretro_get_system_info_lib
        
        videoBufferA = (uint32_t *)malloc(2560 * 2560 * sizeof(uint32_t));
        videoBufferB = (uint32_t *)malloc(2560 * 2560 * sizeof(uint32_t));
        videoBuffer = videoBufferA;
    }
    
    return self;
}

- (void)dealloc {
    core_unload();
}

-(void)coreInit {
    core->retro_set_audio_sample(audio_callback);
    core->retro_set_audio_sample_batch(audio_batch_callback);
    core->retro_set_video_refresh(video_callback);
    core->retro_set_input_poll(input_poll_callback);
    core->retro_set_input_state(input_state_callback);
    core->retro_set_environment(environment_callback);
    
    core->retro_init();
}

- (BOOL)loadFileAtPath:(NSString *)path error:(NSError**)error {
    self.romPath = path;
    NSURL *batterySavesDirectory = [NSURL fileURLWithPath:[self batterySavesPath]];
    NSError *localError;
    BOOL status = [[NSFileManager defaultManager] createDirectoryAtURL:batterySavesDirectory
                             withIntermediateDirectories:YES
                                              attributes:nil
                                                   error:&localError];
    if(!status) {
        *error = localError;
        return NO;
    }

    [self coreInit];
    
    struct retro_game_info info;
    info.data = [NSData dataWithContentsOfFile:path].bytes;
    info.path = [path fileSystemRepresentation];
    // TODO:: retro_load_game
//    BOOL loaded = core->retro_load_game(&info); // retro_load_game(&info);
    
    struct retro_ctx_load_content_info info2;
    info2.info = &info;
    info2.content = nil;
    info2.special = nil;
    BOOL loaded = core_load_game(&info2);
   
    if(loaded) {
        core->retro_reset();
    }
    
    self->loaded = loaded;

    return loaded;
}

- (void)executeFrame {
    [self executeFrameSkippingFrame:NO];
}

- (void)executeFrameSkippingFrame:(BOOL)skip {
    switch (core_poll_type)
    {
        case POLL_TYPE_EARLY:
            input_poll();
            break;
        case POLL_TYPE_LATE:
            core_input_polled = false;
            break;
    }
//    frame_time_callback(glViewController.timeSinceLastDraw
    if (core->retro_run)
        core->retro_run();
    if (core_poll_type == POLL_TYPE_LATE && !core_input_polled)
        input_poll();
    //	return true;
    //    retro_run();
    //    for (unsigned y = 0; y < HEIGHT; y++)
    //        for (unsigned x = 0; x < WIDTH; x++, pXBuf++)
    //            videoBuffer[y * WIDTH + x] = palette[*pXBuf];
    //
    //    for (int i = 0; i < soundSize; i++)
    //        soundBuffer[i] = (soundBuffer[i] << 16) | (soundBuffer[i] & 0xffff);
    //
    //    [[self ringBufferAtIndex:0] write:soundBuffer maxLength:soundSize << 2];
    
}

- (void)resetEmulation {
    core->retro_reset();
}

- (void)stopEmulation {
    [super stopEmulation];

    core->retro_unload_game();
    
//    if (self->loaded) {
//        core->retro_reset();
//    }
//    core->retro_deinit();
}

@end

unsigned retro_api_version(void)
{
    return RETRO_API_VERSION;
}
