
struct in_default_bind;

void in_gp2x_init(const struct in_default_bind *defbinds);

enum  { GP2X_BTN_UP = 0,      GP2X_BTN_LEFT = 2,      GP2X_BTN_DOWN = 4,  GP2X_BTN_RIGHT = 6,
        GP2X_BTN_START = 8,   GP2X_BTN_SELECT = 9,    GP2X_BTN_L = 10,    GP2X_BTN_R = 11,
        GP2X_BTN_A = 12,      GP2X_BTN_B = 13,        GP2X_BTN_X = 14,    GP2X_BTN_Y = 15,
        GP2X_BTN_VOL_UP = 23, GP2X_BTN_VOL_DOWN = 22, GP2X_BTN_PUSH = 27 };

/* FIXME */
#ifndef GP2X_DEV_GP2X
extern int gp2x_dev_id;
#define GP2X_DEV_GP2X 1
#define GP2X_DEV_WIZ 2
#define GP2X_DEV_CAANOO 3
#endif
