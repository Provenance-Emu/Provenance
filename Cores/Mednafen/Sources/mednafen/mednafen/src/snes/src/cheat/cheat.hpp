struct CheatCode {
  unsigned addr;
  uint8 data;
  signed compare;
};

class Cheat : public vector<CheatCode> {
public:
  bool enabled() const;
  void enable(bool);
  void synchronize();
  void read(unsigned, uint8&) const;

  inline bool active() const;
  inline bool exists(unsigned addr) const;

  Cheat();

  void remove_read_patches(void);
  void install_read_patch(const CheatCode& c);

private:
  uint8 bitmask[0x200000];
  bool system_enabled;
};

extern Cheat cheat;
