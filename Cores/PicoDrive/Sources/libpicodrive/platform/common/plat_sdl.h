
extern const struct in_default_bind *in_sdl_defbinds;
extern const struct menu_keymap *in_sdl_key_map;
extern const int in_sdl_key_map_sz;
extern const struct menu_keymap *in_sdl_joy_map;
extern const int in_sdl_joy_map_sz;
extern const char * const *in_sdl_key_names;
extern const char *plat_device;
extern const struct in_default_bind in_sdl_kbd_map[];

void linux_menu_init(void);
