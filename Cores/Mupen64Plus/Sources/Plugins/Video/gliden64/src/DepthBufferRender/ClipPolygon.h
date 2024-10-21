#ifndef CLIP_POLYGON_H
#define CLIP_POLYGON_H

#define VISIBLE     0
#define LEFT        1
#define RIGHT       2
#define TOP         4
#define BOT         8

struct vertexclip
{
	float x,y,z;
	int visible;
};

/*
 *      vbp is a pointer to a vertex array. The first 3 vertices in that
 *      array is our source vertices. The rest of the array will be used
 *      to hold new vertices created during clipping.
 *
 *      you can then access the new vertices using the *final variable
 *
 *      function returns the number of vertices in the resulting polygon
 */
int ClipPolygon(vertexclip *** final, vertexclip * vbp, int numVertices);

#endif // CLIP_POLYGON_H
