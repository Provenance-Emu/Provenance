#ifndef INCLUDE_uXt8Z4R7EMpuEEtvSibXjNhKH3741VNc
#define INCLUDE_uXt8Z4R7EMpuEEtvSibXjNhKH3741VNc 1

#define IN_MAX_DEVS 10
#define IN_ABS_RANGE 1024	/* abs must be centered at 0, move upto +- this */

/* unified menu keys */
#define PBTN_UP    (1 <<  0)
#define PBTN_DOWN  (1 <<  1)
#define PBTN_LEFT  (1 <<  2)
#define PBTN_RIGHT (1 <<  3)

#define PBTN_MOK   (1 <<  4)
#define PBTN_MBACK (1 <<  5)
#define PBTN_MA2   (1 <<  6)	/* menu action 2 */
#define PBTN_MA3   (1 <<  7)

#define PBTN_L     (1 <<  8)
#define PBTN_R     (1 <<  9)

#define PBTN_MENU  (1 << 10)

#define PBTN_CHAR  (1 << 11)	/* character (text input) */

// TODO: move to pico
#if 0

/* ui events */
#define PEVB_VOL_DOWN   30
#define PEVB_VOL_UP     29
#define PEVB_STATE_LOAD 28
#define PEVB_STATE_SAVE 27
#define PEVB_SWITCH_RND 26
#define PEVB_SSLOT_PREV 25
#define PEVB_SSLOT_NEXT 24
#define PEVB_MENU       23
#define PEVB_FF         22
#define PEVB_PICO_PNEXT 21
#define PEVB_PICO_PPREV 20
#define PEVB_PICO_SWINP 19

#define PEV_VOL_DOWN    (1 << PEVB_VOL_DOWN)
#define PEV_VOL_UP      (1 << PEVB_VOL_UP)
#define PEV_STATE_LOAD  (1 << PEVB_STATE_LOAD)
#define PEV_STATE_SAVE  (1 << PEVB_STATE_SAVE)
#define PEV_SWITCH_RND  (1 << PEVB_SWITCH_RND)
#define PEV_SSLOT_PREV  (1 << PEVB_SSLOT_PREV)
#define PEV_SSLOT_NEXT  (1 << PEVB_SSLOT_NEXT)
#define PEV_MENU        (1 << PEVB_MENU)
#define PEV_FF          (1 << PEVB_FF)
#define PEV_PICO_PNEXT  (1 << PEVB_PICO_PNEXT)
#define PEV_PICO_PPREV  (1 << PEVB_PICO_PPREV)
#define PEV_PICO_SWINP  (1 << PEVB_PICO_SWINP)

#define PEV_MASK 0x7ff80000

#endif

enum {
	IN_CFG_BIND_COUNT = 0,
	IN_CFG_DOES_COMBOS,
	IN_CFG_BLOCKING,
	IN_CFG_KEY_NAMES,
	IN_CFG_ABS_DEAD_ZONE,	/* dead zone for analog-digital mapping */
	IN_CFG_ABS_AXIS_COUNT,	/* number of abs axes (ro) */
	IN_CFG_DEFAULT_DEV,
};

enum {
	IN_BINDTYPE_NONE = -1,
	IN_BINDTYPE_EMU = 0,
	IN_BINDTYPE_PLAYER12,
	IN_BINDTYPE_COUNT
};

#define IN_BIND_OFFS(key, btype) \
	((key) * IN_BINDTYPE_COUNT + (btype))

typedef struct InputDriver in_drv_t;

struct InputDriver {
	const char *prefix;
	void (*probe)(const in_drv_t *drv);
	void (*free)(void *drv_data);
	const char * const *
	     (*get_key_names)(const in_drv_t *drv, int *count);
	int  (*clean_binds)(void *drv_data, int *binds, int *def_finds);
	int  (*get_config)(void *drv_data, int what, int *val);
	int  (*set_config)(void *drv_data, int what, int val);
	int  (*update)(void *drv_data, const int *binds, int *result);
	int  (*update_analog)(void *drv_data, int axis_id, int *result);
	/* return -1 on no event, -2 on error */
	int  (*update_keycode)(void *drv_data, int *is_down);
	int  (*menu_translate)(void *drv_data, int keycode, char *charcode);
	int  (*get_key_code)(const char *key_name);
	const char * (*get_key_name)(int keycode);

	const struct in_default_bind *defbinds;
	const void *pdata;
};

struct in_default_bind {
	unsigned short code;
	unsigned char btype;    /* IN_BINDTYPE_* */
	unsigned char bit;
};

struct menu_keymap {
	short key;
	short pbtn;
};

struct in_pdata {
	const struct in_default_bind *defbinds;
	const struct menu_keymap *key_map;
	size_t kmap_size;
	const struct menu_keymap *joy_map;
	size_t jmap_size;
	const char * const *key_names;
};

/* to be called by drivers */
int  in_register_driver(const in_drv_t *drv,
			const struct in_default_bind *defbinds, const void *pdata);
void in_register(const char *nname, int drv_fd_hnd, void *drv_data,
		int key_count, const char * const *key_names, int combos);
void in_combos_find(const int *binds, int last_key, int *combo_keys, int *combo_acts);
int  in_combos_do(int keys, const int *binds, int last_key, int combo_keys, int combo_acts);

void in_init(void);
void in_probe(void);
int  in_update(int *result);
int  in_update_analog(int dev_id, int axis_id, int *value);
int  in_update_keycode(int *dev_id, int *is_down, char *charcode, int timeout_ms);
int  in_menu_wait_any(char *charcode, int timeout_ms);
int  in_menu_wait(int interesting, char *charcode, int autorep_delay_ms);
int  in_config_parse_dev(const char *dev_name);
int  in_config_bind_key(int dev_id, const char *key, int binds, int bind_type);
int  in_get_config(int dev_id, int what, void *val);
int  in_set_config(int dev_id, int what, const void *val, int size);
int  in_get_key_code(int dev_id, const char *key_name);
int  in_name_to_id(const char *dev_name);
int  in_bind_key(int dev_id, int keycode, int mask, int bind_type, int force_unbind);
void in_unbind_all(int dev_id, int act_mask, int bind_type);
void in_clean_binds(void);
void in_debug_dump(void);

const int  *in_get_dev_binds(int dev_id);
const int  *in_get_dev_def_binds(int dev_id);
const char *in_get_dev_name(int dev_id, int must_be_active, int skip_pfix);
const char *in_get_key_name(int dev_id, int keycode);

#define in_set_config_int(dev_id, what, v) { \
	int val_ = v; \
	in_set_config(dev_id, what, &val_, sizeof(val_)); \
}

#endif /* INCLUDE_uXt8Z4R7EMpuEEtvSibXjNhKH3741VNc */
