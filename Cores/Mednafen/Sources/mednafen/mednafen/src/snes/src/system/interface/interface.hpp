class Interface {
public:
  void video_scanline(uint16_t *data, unsigned line, unsigned width, unsigned height, bool interlace, bool field);
  void audio_sample(uint16_t l_sample, uint16_t r_sample);
  void input_poll();
  int16_t input_poll(bool port, unsigned device, unsigned index, unsigned id);
};
