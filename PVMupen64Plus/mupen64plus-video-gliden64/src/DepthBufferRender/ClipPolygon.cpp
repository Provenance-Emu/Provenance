
/*
 *      2D clipping of a triangle into a polygon using the clipping
 *      boundarys LeftClip, RightClip, TopClip and BotClip.
 *
 *      The code is based on Sutherland-Hodgman algorithm where we
 *      clip the polygon against each clipping boundary in turn.
 *
 *      Note! This code is far from optimal but it does what it is
 *            supposed to do.
 *
 *      This source is part of the fatmap2.txt document by
 *      Mats Byggmastar, mri@penti.sit.fi
 *      17.4.1997 Jakobstad, Finland
 *
 *      Companies with self respect are encouraged to contact me if
 *      any of this code is to be used as part of a commercial product.
 */

//****************************************************************
//
// Adopted for GLideN64 by Gonetz, Dec 2016
//
//****************************************************************


#include <gSP.h>
#include "ClipPolygon.h"

float LeftClip  =   0.0f;
float RightClip = 320.0f;
float TopClip   = 240.0f;
float BotClip   =   0.0f;

inline int cliptestx(vertexclip * v)
{
	int bits = 0;
	if(v->y < LeftClip)
		bits |= LEFT;
	if(v->y > RightClip)
		bits |= RIGHT;
	return bits;
}

inline int cliptesty(vertexclip * v)
{
	int bits = 0;
	if(v->y < BotClip)
		bits |= BOT;
	if(v->y > TopClip)
		bits |= TOP;
	return bits;
}

/*
 *      vbp is a pointer to a vertex array. The first 3 vertices in that
 *      array is our source vertices. The rest of the array will be used
 *      to hold new vertices created during clipping.
 *
 *      you can then access the new vertices using the *final variable
 *
 *      function returns the number of vertices in the resulting polygon
 */

int ClipPolygon(vertexclip *** final, vertexclip * vbp, int numVertices)
{
	LeftClip = gSP.viewport.x;
	RightClip = LeftClip + gSP.viewport.width;
	BotClip = gSP.viewport.y;
	TopClip = BotClip + gSP.viewport.height;
	int max, n, dsti;
	static vertexclip * vp1[12], * vp2[12];     // vertex ptr buffers
	vertexclip ** src = vp1;
	vertexclip ** dst = vp2;
	vertexclip ** tmp;

	for (n = 0; n < numVertices; n++)
		vp1[n] = vbp + n;
	vp1[n] = vbp + 0;

	vbp += numVertices;       // Next free vertex

	dsti = 0;
	max = numVertices;

	// right clip

	for (n = 0; n < max; n++) {
		vertexclip * src1 = src[n];             // current vertex
		vertexclip * src2 = src[n + 1];           // next vertex
		if ((src1->visible & RIGHT) == VISIBLE) {
			dst[dsti++] = src1;                 // add visible vertex to list
			if ((src2->visible & RIGHT) == VISIBLE)
				continue;
		} else if ((src2->visible & RIGHT) != VISIBLE)
			continue;
		float a = (RightClip - src1->x) / (src2->x - src1->x);
		float ima = 1.0f - a;
		dst[dsti] = vbp++;                      // create new vertex
		dst[dsti]->y = src1->y*ima + src2->y*a;
		dst[dsti]->x = RightClip;
		dst[dsti]->z = src1->z*ima + src2->z*a;
		dst[dsti]->visible = cliptesty(dst[dsti]);
		dsti++;
	}
	dst[dsti] = dst[0];
	tmp = src; src = dst; dst = tmp;            // swap src - dst buffers
	max = dsti;
	dsti = 0;

	// left clip

	for(n = 0; n < max; n++) {
		vertexclip * src1 = src[n];             // current vertex
		vertexclip * src2 = src[n+1];           // next vertex
		if((src1->visible & LEFT) == VISIBLE) {
			dst[dsti++] = src1;                 // add visible vertex to list
			if((src2->visible & LEFT) == VISIBLE)
				continue;
		} else if((src2->visible & LEFT) != VISIBLE)
			continue;
		float a = (LeftClip - src1->x) / (src2->x - src1->x);
		float ima = 1.0f - a;
		dst[dsti] = vbp++;                      // create new vertex
		dst[dsti]->y = src1->y*ima + src2->y*a;
		dst[dsti]->x = LeftClip;
		dst[dsti]->z = src1->z*ima + src2->z*a;
		dst[dsti]->visible = cliptesty(dst[dsti]);
		dsti++;
	}
	dst[dsti] = dst[0];
	tmp = src; src = dst; dst = tmp;            // Swap src - dst buffers
	max = dsti;
	dsti = 0;

	// top clip

	for(n = 0; n < max; n++) {
		vertexclip * src1 = src[n];             // current vertex
		vertexclip * src2 = src[n+1];           // next vertex
		if((src1->visible & TOP) == VISIBLE) {
			dst[dsti++] = src1;                 // add visible vertex to list
			if((src2->visible & TOP) == VISIBLE)
				continue;
		} else if((src2->visible & TOP) != VISIBLE)
			continue;
		float a = (TopClip - src1->y) / (src2->y - src1->y);
		float ima = 1.0f - a;
		dst[dsti] = vbp++;                      // create new vertex
		dst[dsti]->x = src1->x*ima + src2->x*a;
		dst[dsti]->y = TopClip;
		dst[dsti]->z = src1->z*ima + src2->z*a;
		dst[dsti]->visible = cliptestx(dst[dsti]);
		dsti++;
	}
	dst[dsti] = dst[0];
	tmp = src; src = dst; dst = tmp;            // swap src - dst buffers
	max = dsti;
	dsti = 0;

	// bot clip

	for(n = 0; n < max; n++) {
		vertexclip * src1 = src[n];             // current vertex
		vertexclip * src2 = src[n+1];           // next vertex
		if((src1->visible & BOT) == VISIBLE) {
			dst[dsti++] = src1;                 // add visible vertex to list
			if((src2->visible & BOT) == VISIBLE)
				continue;
		} else if((src2->visible & BOT) != VISIBLE)
			continue;
		float a = (BotClip - src1->y) / (src2->y - src1->y);
		float ima = 1.0f - a;
		dst[dsti] = vbp++;                      // create new vertex
		dst[dsti]->x = src1->x*ima + src2->x*a;
		dst[dsti]->y = BotClip;
		dst[dsti]->z = src1->z*ima + src2->z*a;
		dsti++;
	}

	*final = dst;

	return dsti;
}
