//============================================================================
//
//   SSSS    tt          lll  lll
//  SS  SS   tt           ll   ll
//  SS     tttttt  eeee   ll   ll   aaaa
//   SSSS    tt   ee  ee  ll   ll      aa
//      SS   tt   eeeeee  ll   ll   aaaaa  --  "An Atari 2600 VCS Emulator"
//  SS  SS   tt   ee      ll   ll  aa  aa
//   SSSS     ttt  eeeee llll llll  aaaaa
//
// Copyright (c) 1995-2024 by Bradford W. Mott, Stephen Anthony
// and the Stella Team
//
// See the file "License.txt" for information on usage and redistribution of
// this file, and for a DISCLAIMER OF ALL WARRANTIES.
//============================================================================

#include <thread>
#include "AtariNTSC.hxx"
#include "PhosphorHandler.hxx"

// blitter related
#ifndef restrict
  #if defined (__GNUC__)
    #define restrict __restrict__
  #elif defined (_MSC_VER) && _MSC_VER > 1300
    #define restrict __restrict
  #else
    /* no support for restricted pointers */
    #define restrict
  #endif
#endif

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AtariNTSC::initialize(const Setup& setup)
{
  init(myImpl, setup);
  generateKernels();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AtariNTSC::setPalette(const PaletteArray& palette)
{
  uInt8* ptr = myRGBPalette.data();
  for(auto p: palette)
  {
    *ptr++ = (p >> 16) & 0xff;
    *ptr++ = (p >> 8) & 0xff;
    *ptr++ = p & 0xff;
  }
  generateKernels();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AtariNTSC::generateKernels()
{
  const uInt8* ptr = myRGBPalette.data();
  for(size_t entry = 0; entry < myRGBPalette.size() / 3; ++entry)
  {
    const float r = (*ptr++) / 255.F * rgb_unit + rgb_offset,
                g = (*ptr++) / 255.F * rgb_unit + rgb_offset,
                b = (*ptr++) / 255.F * rgb_unit + rgb_offset;
    float y, i, q;  RGB_TO_YIQ( r, g, b, y, i, q );  // NOLINT

    // Generate kernel
    int ir, ig, ib;  YIQ_TO_RGB( y, i, q, myImpl.to_rgb.data(), ir, ig, ib );  //NOLINT
    const uInt32 rgb = PACK_RGB( ir, ig, ib );

    uInt32* kernel = myColorTable[entry].data();
    genKernel(myImpl, y, i, q, kernel);

    for ( uInt32 c = 0; c < rgb_kernel_size / 2; ++c )
    {
      const uInt32 error = rgb -
          kernel [c    ] - kernel [(c+10)%14+14] -
          kernel [c + 7] - kernel [c + 3    +14];
      kernel [c + 3 + 14] += error;
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AtariNTSC::enableThreading(bool enable)
{
  uInt32 systemThreads = enable ? std::thread::hardware_concurrency() : 0;
  if(systemThreads <= 1)
  {
    myWorkerThreads = 0;
    myTotalThreads  = 1;
  }
  else
  {
    systemThreads = std::max<uInt32>(1, std::min<uInt32>(4, systemThreads - 1));

    myWorkerThreads = systemThreads - 1;
    myTotalThreads  = systemThreads;

    myThreads = make_unique<std::thread[]>(myWorkerThreads);  // NOLINT
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AtariNTSC::render(const uInt8* atari_in, const uInt32 in_width,
                       const uInt32 in_height, void* rgb_out,
                       const uInt32 out_pitch, uInt32* rgb_in)
{
  // Spawn the threads...
  for(uInt32 i = 0; i < myWorkerThreads; ++i)
  {
    myThreads[i] = std::thread([=] // NOLINT (cppcoreguidelines-misleading-capture-default-by-value
    {
      rgb_in == nullptr ?
        renderThread(atari_in, in_width, in_height, myTotalThreads,
                     i+1, rgb_out, out_pitch) :
        renderWithPhosphorThread(atari_in, in_width, in_height, myTotalThreads,
                                 i+1, rgb_in, rgb_out, out_pitch);
    });
  }
  // Make the main thread busy too
  rgb_in == nullptr ?
    renderThread(atari_in, in_width, in_height, myTotalThreads, 0, rgb_out, out_pitch) :
    renderWithPhosphorThread(atari_in, in_width, in_height, myTotalThreads, 0, rgb_in, rgb_out, out_pitch);
  // ...and make them join again
  for(uInt32 i = 0; i < myWorkerThreads; ++i)
    myThreads[i].join();

  // Copy phosphor values into out buffer
  if(rgb_in != nullptr)
    memcpy(rgb_out, rgb_in, static_cast<size_t>(in_height) * out_pitch);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AtariNTSC::renderThread(const uInt8* atari_in, const uInt32 in_width,
  const uInt32 in_height, const uInt32 numThreads, const uInt32 threadNum,
  void* rgb_out, const uInt32 out_pitch)
{
  // Adapt parameters to thread number
  const uInt32 yStart = in_height * threadNum / numThreads;
  const uInt32 yEnd = in_height * (threadNum + 1) / numThreads;
  atari_in += static_cast<size_t>(in_width) * yStart;
  rgb_out  = static_cast<char*>(rgb_out) + static_cast<size_t>(out_pitch) * yStart;

  uInt32 const chunk_count = (in_width - 1) / PIXEL_in_chunk;

  for(uInt32 y = yStart; y < yEnd; ++y)
  {
    const uInt8* line_in = atari_in;
    ATARI_NTSC_BEGIN_ROW(NTSC_black, line_in[0]);
    auto* restrict line_out = static_cast<uInt32*>(rgb_out);
    ++line_in;

    // shift right by 2 pixel
    line_out[0] = line_out[1] = 0;
    line_out += 2;

    for(uInt32 n = chunk_count; n; --n)
    {
      // order of input and output pixels must not be altered
      ATARI_NTSC_COLOR_IN(0, line_in[0])
      ATARI_NTSC_RGB_OUT_8888(0, line_out[0])
      ATARI_NTSC_RGB_OUT_8888(1, line_out[1])
      ATARI_NTSC_RGB_OUT_8888(2, line_out[2])
      ATARI_NTSC_RGB_OUT_8888(3, line_out[3])

      ATARI_NTSC_COLOR_IN(1, line_in[1])
      ATARI_NTSC_RGB_OUT_8888(4, line_out[4])
      ATARI_NTSC_RGB_OUT_8888(5, line_out[5])
      ATARI_NTSC_RGB_OUT_8888(6, line_out[6])

      line_in += 2;
      line_out += 7;
    }

    // finish final pixels
    ATARI_NTSC_COLOR_IN(0, line_in[0])
    ATARI_NTSC_RGB_OUT_8888(0, line_out[0])
    ATARI_NTSC_RGB_OUT_8888(1, line_out[1])
    ATARI_NTSC_RGB_OUT_8888(2, line_out[2])
    ATARI_NTSC_RGB_OUT_8888(3, line_out[3])

    ATARI_NTSC_COLOR_IN(1, NTSC_black)
    ATARI_NTSC_RGB_OUT_8888(4, line_out[4])
    ATARI_NTSC_RGB_OUT_8888(5, line_out[5])
    ATARI_NTSC_RGB_OUT_8888(6, line_out[6])

    line_out += 7;

    ATARI_NTSC_COLOR_IN(0, NTSC_black)
    ATARI_NTSC_RGB_OUT_8888(0, line_out[0])
    ATARI_NTSC_RGB_OUT_8888(1, line_out[1])
    ATARI_NTSC_RGB_OUT_8888(2, line_out[2])
    ATARI_NTSC_RGB_OUT_8888(3, line_out[3])

    ATARI_NTSC_COLOR_IN(1, NTSC_black)
    ATARI_NTSC_RGB_OUT_8888(4, line_out[4])
#if 0
    ATARI_NTSC_RGB_OUT_8888(5, line_out[5])
    ATARI_NTSC_RGB_OUT_8888(6, line_out[6])
#endif

    atari_in += in_width;
    rgb_out = static_cast<char*>(rgb_out) + out_pitch;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AtariNTSC::renderWithPhosphorThread(const uInt8* atari_in, const uInt32 in_width,
  const uInt32 in_height, const uInt32 numThreads, const uInt32 threadNum,
  uInt32* rgb_in, void* rgb_out, const uInt32 out_pitch)
{
  // Adapt parameters to thread number
  const uInt32 yStart = in_height * threadNum / numThreads;
  const uInt32 yEnd = in_height * (threadNum + 1) / numThreads;
  uInt32 bufofs = AtariNTSC::outWidth(in_width) * yStart;
  const uInt32* out = static_cast<uInt32*>(rgb_out);
  atari_in += static_cast<size_t>(in_width) * yStart;
  rgb_out = static_cast<char*>(rgb_out) + static_cast<size_t>(out_pitch) * yStart;

  uInt32 const chunk_count = (in_width - 1) / PIXEL_in_chunk;

  for(uInt32 y = yStart; y < yEnd; ++y)
  {
    const uInt8* line_in = atari_in;
    ATARI_NTSC_BEGIN_ROW(NTSC_black, line_in[0]);
    auto* restrict line_out = static_cast<uInt32*>(rgb_out);
    ++line_in;

    // shift right by 2 pixel
    line_out[0] = line_out[1] = 0;
    line_out += 2;

    for(uInt32 n = chunk_count; n; --n)
    {
      // order of input and output pixels must not be altered
      ATARI_NTSC_COLOR_IN(0, line_in[0])
      ATARI_NTSC_RGB_OUT_8888(0, line_out[0])
      ATARI_NTSC_RGB_OUT_8888(1, line_out[1])
      ATARI_NTSC_RGB_OUT_8888(2, line_out[2])
      ATARI_NTSC_RGB_OUT_8888(3, line_out[3])

      ATARI_NTSC_COLOR_IN(1, line_in[1])
      ATARI_NTSC_RGB_OUT_8888(4, line_out[4])
      ATARI_NTSC_RGB_OUT_8888(5, line_out[5])
      ATARI_NTSC_RGB_OUT_8888(6, line_out[6])

      line_in += 2;
      line_out += 7;
    }

    // finish final pixels
    ATARI_NTSC_COLOR_IN(0, line_in[0])
    ATARI_NTSC_RGB_OUT_8888(0, line_out[0])
    ATARI_NTSC_RGB_OUT_8888(1, line_out[1])
    ATARI_NTSC_RGB_OUT_8888(2, line_out[2])
    ATARI_NTSC_RGB_OUT_8888(3, line_out[3])

    ATARI_NTSC_COLOR_IN(1, NTSC_black)
    ATARI_NTSC_RGB_OUT_8888(4, line_out[4])
    ATARI_NTSC_RGB_OUT_8888(5, line_out[5])
    ATARI_NTSC_RGB_OUT_8888(6, line_out[6])

    line_out += 7;

    ATARI_NTSC_COLOR_IN(0, NTSC_black)
    ATARI_NTSC_RGB_OUT_8888(0, line_out[0])
    ATARI_NTSC_RGB_OUT_8888(1, line_out[1])
    ATARI_NTSC_RGB_OUT_8888(2, line_out[2])
    ATARI_NTSC_RGB_OUT_8888(3, line_out[3])

    ATARI_NTSC_COLOR_IN(1, NTSC_black)
    ATARI_NTSC_RGB_OUT_8888(4, line_out[4])
#if 0
    ATARI_NTSC_RGB_OUT_8888(5, line_out[5])
    ATARI_NTSC_RGB_OUT_8888(6, line_out[6])
#endif

    // Do phosphor mode (blend the resulting frames)
    // Note: The unrolled code assumed that AtariNTSC::outWidth(kTIAW) == outPitch == 565
    // Now this got changed to 568 so the final 5 calculations got removed.
    for (uInt32 x = AtariNTSC::outWidth(in_width) / 8; x; --x)
    {
      // Store back into displayed frame buffer (for next frame)
      rgb_in[bufofs] = PhosphorHandler::getPixel(out[bufofs], rgb_in[bufofs]);
      ++bufofs;
      rgb_in[bufofs] = PhosphorHandler::getPixel(out[bufofs], rgb_in[bufofs]);
      ++bufofs;
      rgb_in[bufofs] = PhosphorHandler::getPixel(out[bufofs], rgb_in[bufofs]);
      ++bufofs;
      rgb_in[bufofs] = PhosphorHandler::getPixel(out[bufofs], rgb_in[bufofs]);
      ++bufofs;
      rgb_in[bufofs] = PhosphorHandler::getPixel(out[bufofs], rgb_in[bufofs]);
      ++bufofs;
      rgb_in[bufofs] = PhosphorHandler::getPixel(out[bufofs], rgb_in[bufofs]);
      ++bufofs;
      rgb_in[bufofs] = PhosphorHandler::getPixel(out[bufofs], rgb_in[bufofs]);
      ++bufofs;
      rgb_in[bufofs] = PhosphorHandler::getPixel(out[bufofs], rgb_in[bufofs]);
      ++bufofs;
    }
    // finish final 565 % 8 = 5 pixels
    /*rgb_in[bufofs] = PhosphorHandler::getPixel(out[bufofs], rgb_in[bufofs]);
    ++bufofs;
    rgb_in[bufofs] = PhosphorHandler::getPixel(out[bufofs], rgb_in[bufofs]);
    ++bufofs;
    rgb_in[bufofs] = PhosphorHandler::getPixel(out[bufofs], rgb_in[bufofs]);
    ++bufofs;
    rgb_in[bufofs] = PhosphorHandler::getPixel(out[bufofs], rgb_in[bufofs]);
    ++bufofs;
    rgb_in[bufofs] = PhosphorHandler::getPixel(out[bufofs], rgb_in[bufofs]);
    ++bufofs;*/
#if 0
    rgb_in[bufofs] = PhosphorHandler::getPixel(out[bufofs], rgb_in[bufofs]);
    ++bufofs;
    rgb_in[bufofs] = PhosphorHandler::getPixel(out[bufofs], rgb_in[bufofs]);
    ++bufofs;
#endif

    atari_in += in_width;
    rgb_out = static_cast<char*>(rgb_out) + out_pitch;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AtariNTSC::init(init_t& impl, const Setup& setup)
{
  impl.artifacts = setup.artifacts;
  if ( impl.artifacts > 0 )
    impl.artifacts *= artifacts_max - artifacts_mid;
  impl.artifacts = impl.artifacts * artifacts_mid + artifacts_mid;

  impl.fringing = setup.fringing;
  if ( impl.fringing > 0 )
    impl.fringing *= fringing_max - fringing_mid;
  impl.fringing = impl.fringing * fringing_mid + fringing_mid;

  initFilters(impl, setup);

  /* setup decoder matricies */
  {
    float* out = impl.to_rgb.data();

    int n = burst_count;
    do
    {
      float const* in = default_decoder.data();
      int n2 = 3;
      do
      {
        *out++ = *in++;
        *out++ = *in++;
      }
      while (--n2);
    #if 0  // burst_count is always 0
      if ( burst_count > 1 )
        ROTATE_IQ( s, c, 0.866025F, -0.5F ); /* +120 degrees */
    #endif
    }
    while (--n);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AtariNTSC::initFilters(init_t& impl, const Setup& setup)
{
  std::array<float, static_cast<size_t>(kernel_size) * 2> kernels{0};

  /* generate luma (y) filter using sinc kernel */
  {
    /* sinc with rolloff (dsf) */
    float const rolloff = 1 + setup.sharpness * 0.032F;
    constexpr float maxh = 32;
    float const pow_a_n = powf( rolloff, maxh );

    /* quadratic mapping to reduce negative (blurring) range */
    float to_angle = setup.resolution + 1;
    to_angle = BSPF::PI_f / maxh * luma_cutoff * (to_angle * to_angle + 1.F);

    kernels [kernel_size * 3 / 2] = maxh; /* default center value */
    for ( int i = 0; i < kernel_half * 2 + 1; i++ )
    {
      const int x = i - kernel_half;
      const float angle = x * to_angle;
      /* instability occurs at center point with rolloff very close to 1.0 */
      if ( x || pow_a_n > 1.056F || pow_a_n < 0.981F )
      {
        const float rolloff_cos_a = rolloff * cosf( angle );
        const float num = 1 - rolloff_cos_a -
            pow_a_n * cosf( maxh * angle ) +
            pow_a_n * rolloff * cosf( (maxh - 1) * angle );
        const float den = 1 - rolloff_cos_a - rolloff_cos_a + rolloff * rolloff;
        const float dsf = num / den;
        kernels [kernel_size * 3 / 2 - kernel_half + i] = dsf - 0.5F;
      }
    }

    /* apply blackman window and find sum */
    float sum = 0;
    for ( int i = 0; i < kernel_half * 2 + 1; i++ )
    {
      const float x = BSPF::PI_f * 2 / (kernel_half * 2) * i;
      const float blackman = 0.42F - 0.5F * cosf( x ) + 0.08F * cosf( x * 2 );
      sum += (kernels [kernel_size * 3 / 2 - kernel_half + i] *= blackman);
    }

    /* normalize kernel */
    sum = 1.0F / sum;
    for ( int i = 0; i < kernel_half * 2 + 1; i++ )
    {
      const int x = kernel_size * 3 / 2 - kernel_half + i;
      kernels [x] *= sum;
    }
  }

  /* generate chroma (iq) filter using gaussian kernel */
  {
    constexpr float cutoff_factor = -0.03125F;
    float cutoff = setup.bleed;

    if ( cutoff < 0 )
    {
      /* keep extreme value accessible only near upper end of scale (1.0) */
      cutoff *= cutoff;
      cutoff *= cutoff;
      cutoff *= cutoff;
      cutoff *= -30.0F / 0.65F;
    }
    cutoff = cutoff_factor - 0.65F * cutoff_factor * cutoff;

    for ( int i = -kernel_half; i <= kernel_half; i++ )
      kernels [kernel_size / 2 + i] = expf( i * i * cutoff );

    /* normalize even and odd phases separately */
    for ( int i = 0; i < 2; i++ )
    {
      float sum = 0;
      for ( int x = i; x < kernel_size; x += 2 )
        sum += kernels [x];

      sum = 1.0F / sum;
      for ( int x = i; x < kernel_size; x += 2 )
      {
        kernels [x] *= sum;
      }
    }
  }

  /* generate linear rescale kernels */
  float weight = 1.0F;
  float* out = impl.kernel.data();
  int n = rescale_out;
  do
  {
    float remain = 0;
    weight -= 1.0F / rescale_in;
    for ( int i = 0; i < kernel_size * 2; i++ )
    {
      const float cur = kernels [i];
      const float m = cur * weight;
      *out++ = m + remain;
      remain = cur - m;
    }
  }
  while (--n);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Generate pixel at all burst phases and column alignments
void AtariNTSC::genKernel(init_t& impl, float y, float i, float q, uInt32* out)
{
  /* generate for each scanline burst phase */
  float const* to_rgb = impl.to_rgb.data();
  int burst_remain = burst_count;
  y -= rgb_offset;
  do
  {
    /* Encode yiq into *two* composite signals (to allow control over artifacting).
    Convolve these with kernels which: filter respective components, apply
    sharpening, and rescale horizontally. Convert resulting yiq to rgb and pack
    into integer. Based on algorithm by NewRisingSun. */
    pixel_info_t const* pixel = atari_ntsc_pixels.data();
    int alignment_remain = alignment_count;
    do
    {
      /* negate is -1 when composite starts at odd multiple of 2 */
      float const yy = y * impl.fringing * pixel->negate;
      float const ic0 = (i + yy) * pixel->kernel [0];
      float const qc1 = (q + yy) * pixel->kernel [1];
      float const ic2 = (i - yy) * pixel->kernel [2];
      float const qc3 = (q - yy) * pixel->kernel [3];

      float const factor = impl.artifacts * pixel->negate;
      float const ii = i * factor;
      float const yc0 = (y + ii) * pixel->kernel [0];
      float const yc2 = (y - ii) * pixel->kernel [2];

      float const qq = q * factor;
      float const yc1 = (y + qq) * pixel->kernel [1];
      float const yc3 = (y - qq) * pixel->kernel [3];

      float const* k = &impl.kernel [pixel->offset];
      ++pixel;
      for ( int n = rgb_kernel_size; n; --n )
      {
        const float fi = k[0]*ic0 + k[2]*ic2;
        const float fq = k[1]*qc1 + k[3]*qc3;
        const float fy = k[kernel_size+0]*yc0 + k[kernel_size+1]*yc1 +
                  k[kernel_size+2]*yc2 + k[kernel_size+3]*yc3 + rgb_offset;
        if ( k < &impl.kernel [static_cast<size_t>(kernel_size) * 2 *
                               (rescale_out - 1)] )
          k += kernel_size * 2 - 1;
        else
          k -= kernel_size * 2 * (rescale_out - 1) + 2;
        {
          int r, g, b;  YIQ_TO_RGB( fy, fi, fq, to_rgb, r, g, b );  // NOLINT
          *out++ = PACK_RGB( r, g, b ) - rgb_bias;
        }
      }
    }
    while ( /*alignment_count > 1 && */ --alignment_remain );
  }
  while ( --burst_remain );
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const std::array<AtariNTSC::pixel_info_t, AtariNTSC::alignment_count>
AtariNTSC::atari_ntsc_pixels = { {
  { PIXEL_OFFSET1(-4, -9), PIXEL_OFFSET2(-4), { 1, 1, 1, 1            } },
  { PIXEL_OFFSET1( 0, -5), PIXEL_OFFSET2( 0), {            1, 1, 1, 1 } }
} };
