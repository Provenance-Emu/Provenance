static uint64 randstate = 0;

static uint64 round_up_pow2(uint64 v)
{
 v--;
 v |= v >> 1;
 v |= v >> 2;
 v |= v >> 4;
 v |= v >> 8;
 v |= v >> 16;
 v |= v >> 32;
 v++;

 v += (v == 0);

 return(v);
}

static inline uint32 NormalRand(void)
{
 randstate = (19073486328125ULL * randstate) + 1;
 return(randstate >> 16);
}

static void SeedRand(uint64 val)
{
 randstate = val;
}

static uint32 rand_range(uint32 min, uint32 max)
{
 uint64 range = (max - min) + 1;
 uint64 mask = (round_up_pow2(range) - 1);
 uint32 rv;

 do
 {
  rv = (NormalRand() & mask);
 } while(rv >= range);

 rv += min;
 return(rv);
}

