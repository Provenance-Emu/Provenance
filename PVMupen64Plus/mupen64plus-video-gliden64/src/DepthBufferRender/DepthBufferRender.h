//****************************************************************
//
// Software rendering to N64 depth buffer
// Created by Gonetz, Dec 2004
//
//****************************************************************

#ifndef DEPTH_BUFFER_RENDER_H
#define DEPTH_BUFFER_RENDER_H

struct vertexi
{
	int x, y;      // Screen position in 16:16 bit fixed point
	int z;         // z value in 16:16 bit fixed point
};

void Rasterize(vertexi * vtx, int vertices, int dzdx);

#endif //DEPTH_BUFFER_RENDER_H
