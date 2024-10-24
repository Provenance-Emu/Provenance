class sBus : public Bus {
public:
  bool load_cart();
  void unload_cart();

  void power();
  void reset();

  inline uint8 read(unsigned addr)
  {
   uint8 r;

   r = Bus::read(addr);

   #if defined(CHEAT_SYSTEM)
   if(cheat.active() && cheat.exists(addr)) {
     cheat.read(addr, r);
   }
   #endif

   return r;
  }

  void serialize(serializer&);
  sBus();
  ~sBus();

private:
  void map_reset();
  void map_system();
  void map_generic();
  void map_generic_sram();
};

extern sBus bus;
