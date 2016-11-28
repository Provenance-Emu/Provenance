#ifndef LIBPICOFE_XENV_H
#define LIBPICOFE_XENV_H

#define XENV_CAP_KEYS	(1<<0)
#define XENV_CAP_MOUSE	(1<<1)

/* xenv_flags specify if we need keys and mouse,
 * on return, flag is removed if input is not available */
int  xenv_init(int *xenv_flags, const char *window_title);

/* read events from X, calling key_cb for key, mouseb_cb for mouse button
 * and mousem_cb for mouse motion events */
int  xenv_update(int (*key_cb)(void *cb_arg, int kc, int is_pressed),
		 int (*mouseb_cb)(void *cb_arg, int x, int y, int button, int is_pressed),
		 int (*mousem_cb)(void *cb_arg, int x, int y),
		 void *cb_arg);

int  xenv_minimize(void);
void xenv_finish(void);

#endif // LIBPICOFE_XENV_H
