/*
 Ordered dithering methods provided for:
   8x8 (Quantize8x8)
   4x4 (Quantize4x4)
   3x3 (Quantize3x3)
   4x2 (Quantize4x2)
   3x2 (Quantize3x2)
   2x2 (Quantize2x2)
 The functions are:
 
   template<int m, int in_max>
   int QuantizeFunc(size_t quant_pos, double value)
   
      - Quantizes value, assumed to be in range 0..in_max, to range 0..m
      - quant_pos tells the coordinate into the dithering matrix

   template<int m, int in_max>
   int QuantizeFunc(size_t quant_pos, unsigned value)

      - Quantizes value, assumed to be in range 0..in_max, to range 0..m
      - quant_pos tells the coordinate into the dithering matrix

 Copyright (C) 1992,2008 Joel Yliluoma (http://iki.fi/bisqwit/)
*/

#define OrderedDitherDecl(n) \
    static const double flts[n]; \
    static const int ints[n]; \
    enum { mul = n+1, \
           maxin = in_max, \
           even = !(maxin % mul), \
           intmul = even ? 1 : mul };

/* macroes for initializing dither tables */
#define d(n) (n)/double(mul) - 0.5
#define i(n) even ? (n*in_max/mul - (int)in_max/2) \
                  : (n*in_max - (int)mul*in_max/2)

template<int m, int in_max = 255>
struct QuantizeNoDither
{
    int res;
    template<typename IntType>
    QuantizeNoDither(IntType v) : res(v * m / in_max) { }
    operator int() const { return res; }
};

template<int m, typename Base>
struct QuantizeFuncBase: private Base
{
    int res;
    
    QuantizeFuncBase(size_t quant_pos, double v) : res(0)
    {
        if(v > 0.0)
        {
            const double dither_threshold = Base::flts[quant_pos];
            res = (int)(v * (m / double(Base::maxin)) + dither_threshold);
            if(res > m) res = m;
        }
    }
    
    QuantizeFuncBase(size_t quant_pos, unsigned char v) : res(v)
    {
        if(m == Base::maxin) return;
        if(m < Base::maxin)
        {
            // With dithering
            const int dither_threshold = Base::ints[quant_pos];
            const int intmul = Base::intmul;
            res = (res * (m * intmul) + dither_threshold) / (Base::maxin * intmul);
        }
        else
        {
            // Without dithering
            res = QuantizeNoDither<m, Base::maxin> (res);
        }
    }
};

#define QuantizeFuncDecl(name, base) \
  template<int m, int in_max=255> \
  struct name: private QuantizeFuncBase<m, base<in_max> > \
  { \
      typedef QuantizeFuncBase<m, base<in_max> > Base; \
      template<typename A, typename B> name(A a, B b) : Base(a, b) { } \
      operator int() const { return Base::res; } \
  }

/******* Quantizing with 8x8 ordered dithering ********/
template<int in_max> struct OrderedDither_8x8 { OrderedDitherDecl(8*8) };
    template<int in_max>
    const double OrderedDither_8x8<in_max>::flts[] /* A table for 8x8 ordered dithering */
    = { d(1 ), d(49), d(13), d(61), d( 4), d(52), d(16), d(64),
        d(33), d(17), d(45), d(29), d(36), d(20), d(48), d(32),
        d(9 ), d(57), d( 5), d(53), d(12), d(60), d( 8), d(56),
        d(41), d(25), d(37), d(21), d(44), d(28), d(40), d(24),
        d(3 ), d(51), d(15), d(63), d( 2), d(50), d(14), d(62),
        d(35), d(19), d(47), d(31), d(34), d(18), d(46), d(30),
        d(11), d(59), d( 7), d(55), d(10), d(58), d( 6), d(54),
        d(43), d(27), d(39), d(23), d(42), d(26), d(38), d(22) };
    template<int in_max>
    const int OrderedDither_8x8<in_max>::ints[]
    = { i(1 ), i(49), i(13), i(61), i( 4), i(52), i(16), i(64),
        i(33), i(17), i(45), i(29), i(36), i(20), i(48), i(32),
        i(9 ), i(57), i( 5), i(53), i(12), i(60), i( 8), i(56),
        i(41), i(25), i(37), i(21), i(44), i(28), i(40), i(24),
        i(3 ), i(51), i(15), i(63), i( 2), i(50), i(14), i(62),
        i(35), i(19), i(47), i(31), i(34), i(18), i(46), i(30),
        i(11), i(59), i( 7), i(55), i(10), i(58), i( 6), i(54),
        i(43), i(27), i(39), i(23), i(42), i(26), i(38), i(22) };
QuantizeFuncDecl(Quantize8x8, OrderedDither_8x8);


/******* Quantizing with 4x4 ordered dithering ********/
template<int in_max> struct OrderedDither_4x4 { OrderedDitherDecl(4*4) };
    template<int in_max>
    const double OrderedDither_4x4<in_max>::flts[] /* A table for 4x4 ordered dithering */
    = { d( 1), d( 9), d( 3), d(11),
        d(13), d( 5), d(15), d( 7),
        d( 4), d(12), d( 2), d(10),  
        d(16), d( 8), d(14), d( 6) };
    template<int in_max>
    const int OrderedDither_4x4<in_max>::ints[]
    = { i( 1), i( 9), i( 3), i(11),
        i(13), i( 5), i(15), i( 7),
        i( 4), i(12), i( 2), i(10),
        i(16), i( 8), i(14), i( 6) };
QuantizeFuncDecl(Quantize4x4, OrderedDither_4x4);

/******* Quantizing with 3x3 ordered dithering ********/
template<int in_max> struct OrderedDither_3x3 { OrderedDitherDecl(3*3) };
    template<int in_max>
    const double OrderedDither_3x3<in_max>::flts[] /* A table for 3x3 ordered dithering */
    = { d(1), d(7), d(3),
        d(6), d(4), d(9),
        d(8), d(2), d(5) };
    template<int in_max>
    const int OrderedDither_3x3<in_max>::ints[]
    = { i(1), i(7), i(3),
        i(6), i(4), i(9),  
        i(8), i(2), i(5) };
QuantizeFuncDecl(Quantize3x3, OrderedDither_3x3);

/******* Quantizing with 4x2 ordered dithering ********/
template<int in_max> struct OrderedDither_4x2 { OrderedDitherDecl(4*2) };
    template<int in_max>
    const double OrderedDither_4x2<in_max>::flts[] /* A table for 4x2 ordered dithering */
    = { d(1), d(5), d(2), d(6),
        d(7), d(3), d(8), d(4) };
    template<int in_max>
    const int OrderedDither_4x2<in_max>::ints[]
    = { i(1), i(5), i(2), i(6),
        i(7), i(3), i(8), i(4) };
QuantizeFuncDecl(Quantize4x2, OrderedDither_4x2);

/******* Quantizing with 3x2 ordered dithering ********/
template<int in_max> struct OrderedDither_3x2 { OrderedDitherDecl(3*2) };
    template<int in_max>
    const double OrderedDither_3x2<in_max>::flts[] /* A table for 3x2 ordered dithering */
    = { d(1), d(5), d(3),
        d(4), d(2), d(6) };
    template<int in_max>
    const int OrderedDither_3x2<in_max>::ints[]
    = { i(1), i(5), i(3),
        i(4), i(2), i(6) };
QuantizeFuncDecl(Quantize3x2, OrderedDither_3x2);

/******* Quantizing with 2x2 ordered dithering ********/
template<int in_max> struct OrderedDither_2x2 { OrderedDitherDecl(2*2) };
    template<int in_max>
    const double OrderedDither_2x2<in_max>::flts[] /* A table for 2x2 ordered dithering */
    = { d(1), d(4),
        d(3), d(2) };
    template<int in_max>
    const int OrderedDither_2x2<in_max>::ints[]
    = { i(1), i(4),
        i(3), i(2) };
QuantizeFuncDecl(Quantize2x2, OrderedDither_2x2);


#undef OrderedDitherDecl
#undef QuantizeFuncDecl
#undef i
#undef d
