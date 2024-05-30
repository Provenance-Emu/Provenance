#ifndef LIBPICOFE_GL_H
#define LIBPICOFE_GL_H

#ifdef HAVE_GLES

int gl_init(void *display, void *window, int *quirks);
int gl_flip(const void *fb, int w, int h);
void gl_finish(void);

/* for external flips */
extern void *gl_es_display;
extern void *gl_es_surface;

#else

static __inline int gl_init(void *display, void *window, int *quirks)
{
  return -1;
}
static __inline int gl_flip(const void *fb, int w, int h)
{
  return -1;
}
static __inline void gl_finish(void)
{
}

#define gl_es_display (void *)0
#define gl_es_surface (void *)0

#endif

#define GL_QUIRK_ACTIVATE_RECREATE 1

#endif // LIBPICOFE_GL_H
