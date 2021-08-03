void SetOpenGLPalette(uint8 *data);
void BlitOpenGL(uint8 *buf);
void KillOpenGL(void);
int InitOpenGL(int l, int r, int t, int b, double xscale,double yscale, int efx, int ipolate,
                int stretchx, int stretchy, SDL_Surface *screen);

