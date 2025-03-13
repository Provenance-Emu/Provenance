/*
 * Copyright © 2014 Mozilla Foundation
 *
 * This program is made available under an ISC-style license.  See the
 * accompanying file LICENSE for details.
 */
#ifndef NOMINMAX
#define NOMINMAX
#endif // NOMINMAX

#include <algorithm>
#include <cmath>
#include <cassert>
#include <cstring>
#include <cstddef>
#include <cstdio>
#include "cubeb_resampler.h"
#include "cubeb-speex-resampler.h"
#include "cubeb_resampler_internal.h"
#include "cubeb_utils.h"

int
to_speex_quality(cubeb_resampler_quality q)
{
  switch(q) {
  case CUBEB_RESAMPLER_QUALITY_VOIP:
    return SPEEX_RESAMPLER_QUALITY_VOIP;
  case CUBEB_RESAMPLER_QUALITY_DEFAULT:
    return SPEEX_RESAMPLER_QUALITY_DEFAULT;
  case CUBEB_RESAMPLER_QUALITY_DESKTOP:
    return SPEEX_RESAMPLER_QUALITY_DESKTOP;
  default:
    assert(false);
    return 0XFFFFFFFF;
  }
}

uint32_t min_buffered_audio_frame(uint32_t sample_rate)
{
  return sample_rate / 20;
}

template<typename T>
passthrough_resampler<T>::passthrough_resampler(cubeb_stream * s,
                                                cubeb_data_callback cb,
                                                void * ptr,
                                                uint32_t input_channels,
                                                uint32_t sample_rate)
  : processor(input_channels)
  , stream(s)
  , data_callback(cb)
  , user_ptr(ptr)
  , sample_rate(sample_rate)
{
}

template<typename T>
long passthrough_resampler<T>::fill(void * input_buffer, long * input_frames_count,
                                    void * output_buffer, long output_frames)
{
  if (input_buffer) {
    assert(input_frames_count);
  }
  assert((input_buffer && output_buffer &&
         *input_frames_count + static_cast<int>(samples_to_frames(internal_input_buffer.length())) >= output_frames) ||
         (output_buffer && !input_buffer && (!input_frames_count || *input_frames_count == 0)) ||
         (input_buffer && !output_buffer && output_frames == 0));

  if (input_buffer) {
    if (!output_buffer) {
      output_frames = *input_frames_count;
    }
    internal_input_buffer.push(static_cast<T*>(input_buffer),
                               frames_to_samples(*input_frames_count));
  }

  long rv = data_callback(stream, user_ptr, internal_input_buffer.data(),
                          output_buffer, output_frames);

  if (input_buffer) {
    internal_input_buffer.pop(nullptr, frames_to_samples(output_frames));
    *input_frames_count = output_frames;
    drop_audio_if_needed();
  }

  return rv;
}

template<typename T, typename InputProcessor, typename OutputProcessor>
cubeb_resampler_speex<T, InputProcessor, OutputProcessor>
  ::cubeb_resampler_speex(InputProcessor * input_processor,
                          OutputProcessor * output_processor,
                          cubeb_stream * s,
                          cubeb_data_callback cb,
                          void * ptr)
  : input_processor(input_processor)
  , output_processor(output_processor)
  , stream(s)
  , data_callback(cb)
  , user_ptr(ptr)
{
  if (input_processor && output_processor) {
    // Add some delay on the processor that has the lowest delay so that the
    // streams are synchronized.
    uint32_t in_latency = input_processor->latency();
    uint32_t out_latency = output_processor->latency();
    if (in_latency > out_latency) {
      uint32_t latency_diff = in_latency - out_latency;
      output_processor->add_latency(latency_diff);
    } else if (in_latency < out_latency) {
      uint32_t latency_diff = out_latency - in_latency;
      input_processor->add_latency(latency_diff);
    }
    fill_internal = &cubeb_resampler_speex::fill_internal_duplex;
  }  else if (input_processor) {
    fill_internal = &cubeb_resampler_speex::fill_internal_input;
  }  else if (output_processor) {
    fill_internal = &cubeb_resampler_speex::fill_internal_output;
  }
}

template<typename T, typename InputProcessor, typename OutputProcessor>
cubeb_resampler_speex<T, InputProcessor, OutputProcessor>
  ::~cubeb_resampler_speex()
{ }

template<typename T, typename InputProcessor, typename OutputProcessor>
long
cubeb_resampler_speex<T, InputProcessor, OutputProcessor>
::fill(void * input_buffer, long * input_frames_count,
       void * output_buffer, long output_frames_needed)
{
  /* Input and output buffers, typed */
  T * in_buffer = reinterpret_cast<T*>(input_buffer);
  T * out_buffer = reinterpret_cast<T*>(output_buffer);
  return (this->*fill_internal)(in_buffer, input_frames_count,
                                out_buffer, output_frames_needed);
}

template<typename T, typename InputProcessor, typename OutputProcessor>
long
cubeb_resampler_speex<T, InputProcessor, OutputProcessor>
::fill_internal_output(T * input_buffer, long * input_frames_count,
                       T * output_buffer, long output_frames_needed)
{
  assert(!input_buffer && (!input_frames_count || *input_frames_count == 0) &&
         output_buffer && output_frames_needed);

  long got = 0;
  T * out_unprocessed = nullptr;
  long output_frames_before_processing = 0;

  /* fill directly the input buffer of the output processor to save a copy */
  output_frames_before_processing =
    output_processor->input_needed_for_output(output_frames_needed);

  out_unprocessed =
    output_processor->input_buffer(output_frames_before_processing);

  got = data_callback(stream, user_ptr,
                      nullptr, out_unprocessed,
                      output_frames_before_processing);

  if (got < 0) {
    return got;
  }

  output_processor->written(got);

  /* Process the output. If not enough frames have been returned from the
  * callback, drain the processors. */
  return output_processor->output(output_buffer, output_frames_needed);
}

template<typename T, typename InputProcessor, typename OutputProcessor>
long
cubeb_resampler_speex<T, InputProcessor, OutputProcessor>
::fill_internal_input(T * input_buffer, long * input_frames_count,
                      T * output_buffer, long /*output_frames_needed*/)
{
  assert(input_buffer && input_frames_count && *input_frames_count &&
         !output_buffer);

  /* The input data, after eventual resampling. This is passed to the callback. */
  T * resampled_input = nullptr;
  uint32_t resampled_frame_count = input_processor->output_for_input(*input_frames_count);

  /* process the input, and present exactly `output_frames_needed` in the
  * callback. */
  input_processor->input(input_buffer, *input_frames_count);
  resampled_input = input_processor->output(resampled_frame_count, (size_t*)input_frames_count);

  long got = data_callback(stream, user_ptr,
                           resampled_input, nullptr, resampled_frame_count);

  /* Return the number of initial input frames or part of it.
  * Since output_frames_needed == 0 in input scenario, the only
  * available number outside resampler is the initial number of frames. */
  return (*input_frames_count) * (got / resampled_frame_count);
}

template<typename T, typename InputProcessor, typename OutputProcessor>
long
cubeb_resampler_speex<T, InputProcessor, OutputProcessor>
::fill_internal_duplex(T * in_buffer, long * input_frames_count,
                       T * out_buffer, long output_frames_needed)
{
  /* The input data, after eventual resampling. This is passed to the callback. */
  T * resampled_input = nullptr;
  /* The output buffer passed down in the callback, that might be resampled. */
  T * out_unprocessed = nullptr;
  size_t output_frames_before_processing = 0;
  /* The number of frames returned from the callback. */
  long got = 0;

  /* We need to determine how much frames to present to the consumer.
   * - If we have a two way stream, but we're only resampling input, we resample
   * the input to the number of output frames.
   * - If we have a two way stream, but we're only resampling the output, we
   * resize the input buffer of the output resampler to the number of input
   * frames, and we resample it afterwards.
   * - If we resample both ways, we resample the input to the number of frames
   * we would need to pass down to the consumer (before resampling the output),
   * get the output data, and resample it to the number of frames needed by the
   * caller. */

  output_frames_before_processing =
    output_processor->input_needed_for_output(output_frames_needed);
   /* fill directly the input buffer of the output processor to save a copy */
  out_unprocessed =
    output_processor->input_buffer(output_frames_before_processing);

  if (in_buffer) {
    /* process the input, and present exactly `output_frames_needed` in the
    * callback. */
    input_processor->input(in_buffer, *input_frames_count);
    resampled_input =
      input_processor->output(output_frames_before_processing, (size_t*)input_frames_count);
  } else {
    resampled_input = nullptr;
  }

  got = data_callback(stream, user_ptr,
                      resampled_input, out_unprocessed,
                      output_frames_before_processing);

  if (got < 0) {
    return got;
  }

  output_processor->written(got);

  input_processor->drop_audio_if_needed();

  /* Process the output. If not enough frames have been returned from the
   * callback, drain the processors. */
  got = output_processor->output(out_buffer, output_frames_needed);

  output_processor->drop_audio_if_needed();

  return got;
}

/* Resampler C API */

cubeb_resampler *
cubeb_resampler_create(cubeb_stream * stream,
                       cubeb_stream_params * input_params,
                       cubeb_stream_params * output_params,
                       unsigned int target_rate,
                       cubeb_data_callback callback,
                       void * user_ptr,
                       cubeb_resampler_quality quality)
{
  cubeb_sample_format format;

  assert(input_params || output_params);

  if (input_params) {
    format = input_params->format;
  } else {
    format = output_params->format;
  }

  switch(format) {
    case CUBEB_SAMPLE_S16NE:
      return cubeb_resampler_create_internal<short>(stream,
                                                    input_params,
                                                    output_params,
                                                    target_rate,
                                                    callback,
                                                    user_ptr,
                                                    quality);
    case CUBEB_SAMPLE_FLOAT32NE:
      return cubeb_resampler_create_internal<float>(stream,
                                                    input_params,
                                                    output_params,
                                                    target_rate,
                                                    callback,
                                                    user_ptr,
                                                    quality);
    default:
      assert(false);
      return nullptr;
  }
}

long
cubeb_resampler_fill(cubeb_resampler * resampler,
                     void * input_buffer,
                     long * input_frames_count,
                     void * output_buffer,
                     long output_frames_needed)
{
  return resampler->fill(input_buffer, input_frames_count,
                         output_buffer, output_frames_needed);
}

void
cubeb_resampler_destroy(cubeb_resampler * resampler)
{
  delete resampler;
}

long
cubeb_resampler_latency(cubeb_resampler * resampler)
{
  return resampler->latency();
}
