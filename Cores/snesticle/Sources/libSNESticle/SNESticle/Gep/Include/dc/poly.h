
#ifndef _POLY_H
#define _POLY_H

struct TextureT;

void PolyInit();
void PolyShutdown();

void PolyColor4f(Float32 r, Float32 g, Float32 b, Float32 a);
void PolyST(Float32 s0, Float32 t0, Float32 s1, Float32 t1);
void PolyUV(Int32 u0, Int32 v0, Int32 w, Int32 h);
void PolyTexture(TextureT *pTexture);
void PolyRect(Float32 fLeft, Float32 fTop, Float32 fRight, Float32 fBottom);
void PolySprite(Float32 x0, Float32 y0, Float32 w, Float32 h);
void PolyMode(Uint32 uMode);

#endif
