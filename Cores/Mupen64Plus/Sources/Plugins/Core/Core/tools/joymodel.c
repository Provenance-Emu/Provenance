
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#include "SDL.h"

#define SCREEN_WIDTH	640
#define SCREEN_HEIGHT	480

// compile with: gcc -o joymodel -std=c99 -I/usr/include/SDL -lSDL -lpthread -lm joymodel.c

static void DrawLine(SDL_Surface *screen, int x1, int y1, int x2, int y2, int color)
{
    // Bresenham's line algorithm
    int itmp;
    const int steep = (abs(y2 - y1) > abs(x2 - x1)) ? 1 : 0;
    if(steep)
    {
        itmp = x1; x1 = y1; y1 = itmp;
        itmp = x2; x2 = y2; y2 = itmp;
    }

    if(x1 > x2)
    {
        itmp = x1; x1 = x2; x2 = itmp;
        itmp = y1; y1 = y2; y2 = itmp;
    }

    const int dx = x2 - x1;
    const int dy = abs(y2 - y1);

    float error = dx / 2.0f;
    const int ystep = (y1 < y2) ? 1 : -1;
    int y = y1;

	SDL_Rect pix_area;

    for (int x = x1; x <= x2; x++)
    {
        if(steep)
        {
            pix_area.x = y;
            pix_area.y = x;
        }
        else
        {
            pix_area.x = x;
            pix_area.y = y;
        }
        pix_area.w = 1;
        pix_area.h = 1;
		SDL_FillRect(screen, &pix_area, color);

        error -= dy;
        if (error < 0)
        {
            y += ystep;
            error += dx;
        }
    }
}

static int compareDoubles(const void *p1, const void *p2)
{
    double d1 = *((double *) p1);
    double d2 = *((double *) p2);
    if (d1 < d2)
        return -1;
    else if (d1 > d2)
        return 1;
    else
        return 0;
}

void WatchJoystick(SDL_Joystick *joystick)
{
	SDL_Surface *screen;
	const char *name;
	int i, done;
	SDL_Event event;
	int x, y, draw;
	SDL_Rect axis_area[2];

	/* Set a video mode to display joystick axis position */
	screen = SDL_SetVideoMode(SCREEN_WIDTH, SCREEN_HEIGHT, 16, 0);
	if ( screen == NULL ) {
		fprintf(stderr, "Couldn't set video mode: %s\n",SDL_GetError());
		return;
	}

	/* Print info about the joystick we are watching */
	name = SDL_JoystickName(SDL_JoystickIndex(joystick));
	printf("Watching joystick %d: (%s)\n", SDL_JoystickIndex(joystick),
	       name ? name : "Unknown Joystick");
	printf("Joystick has %d axes, %d hats, %d balls, and %d buttons\n",
	       SDL_JoystickNumAxes(joystick), SDL_JoystickNumHats(joystick),
	       SDL_JoystickNumBalls(joystick),SDL_JoystickNumButtons(joystick));

	/* Initialize drawing rectangles */
	memset(axis_area, 0, (sizeof axis_area));
	draw = 0;

    double dMaxR = 0;
    double dRmaxByAngle[1024];
    int iNonZeroValues = 0;
    for (i = 0; i < 1024; i++)
        dRmaxByAngle[i] = 0.0;
    
	/* Loop, getting joystick events! */
	done = 0;
	while ( ! done )
	{
		while ( SDL_PollEvent(&event) )
		{
			switch (event.type)
			{
			    case SDL_JOYAXISMOTION:
			        if (event.jaxis.axis >= 0 && event.jaxis.axis <= 1)
			        {
		                double dX = (float) SDL_JoystickGetAxis(joystick, 0) / 32767.0;
		                double dY = (float) SDL_JoystickGetAxis(joystick, 1) / 32767.0;
		                double dR = sqrt(dX * dX + dY * dY);
		                if (dR > dMaxR) dMaxR = dR;
		                if (dR > 0.5)
		                {
		                    // calculate 10-bit angle
		                    double dAngle = 0.0;
		                    if (dX == 0.0)
		                    {
		                        if (dY < 0.0)
		                            dAngle = 256;
		                        else
		                            dAngle = 768;
		                    }
		                    else if (dX > 0.0)
		                    {
		                        dAngle = atan(-dY/dX) * 512.0 / 3.1415926535797;
		                        if (dAngle < 0.0)
		                            dAngle += 1024.0;
		                    }
		                    else
		                    {
		                        dAngle = atan(-dY/dX) * 512.0 / 3.1415926535797 + 512.0;
		                    }
		                    //printf("Radius: %.2lf  Angle: %.2lf (%lf, %lf)\n", dR, dAngle, dX, dY);
		                    int iAngle = (int) dAngle;
		                    if (dRmaxByAngle[iAngle] == 0.0f)
		                    {
		                        iNonZeroValues++;
		                        printf("non-zero values: %i\n", iNonZeroValues);
		                        if (iNonZeroValues == 800) // fixme 850
		                            done = 1;
		                    }
		                    if (dR > dRmaxByAngle[iAngle])
		                        dRmaxByAngle[iAngle] = dR;
		                }
			        }
				    break;
			    case SDL_KEYDOWN:
				    if ( event.key.keysym.sym != SDLK_ESCAPE )
				    {
					    break;
				    }
				/* Fall through to signal quit */
			    case SDL_QUIT:
				    done = 1;
				    break;
		        default:
			        break;
			}
		}

		/* Erase previous axes */
		SDL_FillRect(screen, &axis_area[draw], 0x0000);

		/* Draw the X/Y axis */
		draw = !draw;
		x = (((int)SDL_JoystickGetAxis(joystick, 0))+32768);
		x *= SCREEN_WIDTH;
		x /= 65535;
		if ( x < 0 ) {
			x = 0;
		} else
		if ( x > (SCREEN_WIDTH-16) ) {
			x = SCREEN_WIDTH-16;
		}
		y = (((int)SDL_JoystickGetAxis(joystick, 1))+32768);
		y *= SCREEN_HEIGHT;
		y /= 65535;
		if ( y < 0 ) {
			y = 0;
		} else
		if ( y > (SCREEN_HEIGHT-16) ) {
			y = SCREEN_HEIGHT-16;
		}
		axis_area[draw].x = (Sint16)x;
		axis_area[draw].y = (Sint16)y;
		axis_area[draw].w = 16;
		axis_area[draw].h = 16;
		SDL_FillRect(screen, &axis_area[draw], 0xFFFF);

		SDL_UpdateRects(screen, 2, axis_area);
	}
	
	if (iNonZeroValues >= 800)
	{
		/* Erase previous axes */
		SDL_FillRect(screen, &axis_area[draw], 0x0000);
        // normalize the radii values
		printf("Maximum radius = %.3lf (16-bit: %i)\n", dMaxR, (int) (dMaxR * 32768));
		for (int x = 0; x < 1024; x++)
		{
		    dRmaxByAngle[x] /= dMaxR;
		}
        // divide circle into octants
        double dCoefA[8], dCoefB[8], dCoefC[8];
	    for (int oct = 0; oct < 8; oct++)
	    {
            const int startX = oct * 128;
            const int stopX = startX + 128;
            // pre-process the Rmax data by throwing out all of the non-0 points which are below the mean in any of the encompassing 16-point windows
            double dRmaxWindow[16], dRmaxSum = 0.0;
            int iXWindow[16];
            int windHead = 0, windTail=0;
            for (x = startX; x < stopX; x++)
            {
                // new point?
                const double dNewPoint = dRmaxByAngle[x];
                if (dNewPoint == 0.0)
                    continue;
                // remove old point falling out of window
                if (windHead-windTail == 16)
                {
                    dRmaxSum -= dRmaxWindow[windTail & 15];
                    windTail++;
                }
                // add new point
                dRmaxWindow[windHead & 15] = dNewPoint;
                iXWindow[windHead & 15] = x;
                dRmaxSum += dNewPoint;
                windHead++;
                // cull the herd
                if (windHead - windTail == 16)
                {
                    double dAverage = dRmaxSum / 16.0;
                    for (int i = 2; i < 14; i++)
                    {
                        if (dRmaxWindow[i] < dAverage)
                        {
                            dRmaxByAngle[iXWindow[i]] = 0.0;
                        }
                    }
                }
            }
	        // pre-process the Rmax data by throwing out all of the points that are less than the median
	        /*
	        double dOctantSorted[128];
	        for (x = startX; x < stopX; x++)
	        {
	            dOctantSorted[x-startX] = dRmaxByAngle[x];
	        }
	        qsort(dOctantSorted, 128, sizeof(double), compareDoubles);
	        for (x = 0; x < 128; x++)
	            if (dOctantSorted[x] > 0.0)
	                break;
	        double dRmaxMedian = dOctantSorted[(x+128)/2];
	        for (x = startX; x < stopX; x++)
	        {
	            if (dRmaxByAngle[x] < dRmaxMedian)
	                dRmaxByAngle[x] = 0.0;
	        }
	        */
            // calculate least-squares quadratic regression fit
            double dS[5][2];
            for (int i = 0; i < 2; i++)
                for (int j = 0; j < 5; j++)
                    dS[j][i] = 0.0;
            double dYSum = 0.0;
            int N = 0;
            for (x = startX; x < stopX; x++)
            {
                if (dRmaxByAngle[x] > 0.0)
                {
                    dYSum += dRmaxByAngle[x];
                    N++;
                }
            }
            const double dYMean = dYSum / N;
            for (x = startX; x < stopX; x++)
            {
                double dX = (x - startX) / 128.0;
                double dY = dRmaxByAngle[x];
                if (dY > 0.0)
                {
                    dY -=  dYMean;
                    dS[0][0] += 1.0;
                    dS[1][0] += dX;
                    dS[2][0] += dX * dX;
                    dS[3][0] += dX * dX * dX;
                    dS[4][0] += dX * dX * dX * dX;
                    dS[0][1] += dY;
                    dS[1][1] += dX * dY;
                    dS[2][1] += dX * dX * dY;
                }
            }
            /* Here's one way to do it
            double dDenom2 = (dS[0][0] * dS[2][0] * dS[4][0] - pow(dS[1][0],2) * dS[4][0] - dS[0][0] * pow(dS[3][0],2) + 2 * dS[1][0] * dS[2][0] * dS[3][0] - pow(dS[2][0],3));
            double dA2 = (dS[0][1] * dS[1][0] * dS[3][0] - dS[1][1] * dS[0][0] * dS[3][0] - dS[0][1] * pow(dS[2][0],2)
                       + dS[1][1] * dS[1][0] * dS[2][0] + dS[2][1] * dS[0][0] * dS[2][0] - dS[2][1] * pow(dS[1][0],2)) / dDenom2;
            double dB2 = (dS[1][1] * dS[0][0] * dS[4][0] - dS[0][1] * dS[1][0] * dS[4][0] + dS[0][1] * dS[2][0] * dS[3][0]
                       - dS[2][1] * dS[0][0] * dS[3][0] - dS[1][1] * pow(dS[2][0],2) + dS[2][1] * dS[1][0] * dS[2][0]) / dDenom2;
            double dC2 = (dS[0][1] * dS[2][0] * dS[4][0] - dS[1][1] * dS[1][0] * dS[4][0] - dS[0][1] * pow(dS[3][0],2)
                       + dS[1][1] * dS[2][0] * dS[3][0] + dS[2][1] * dS[1][0] * dS[3][0] - dS[2][1] * pow(dS[2][0],2)) / dDenom2 + dYMean;
            printf("Least-squares fit for %03i - %03i degrees: A=%.3lf B=%.3lf C=%.3lf\n", oct*45, oct*45+45, dA2, dB2, dC2);
            */
            /* Here's another */
            double dSxx   = dS[2][0] - dS[1][0] * dS[1][0] / dS[0][0];
            double dSxy   = dS[1][1] - dS[1][0] * dS[0][1] / dS[0][0];
            double dSxx2  = dS[3][0] - dS[1][0] * dS[2][0] / dS[0][0];
            double dSx2y  = dS[2][1] - dS[2][0] * dS[0][1] / dS[0][0];
            double dSx2x2 = dS[4][0] - dS[2][0] * dS[2][0] / dS[0][0];
            double dDenom = dSxx * dSx2x2 - dSxx2 * dSxx2;
            double dA = (dSx2y * dSxx - dSxy * dSxx2) / dDenom;
            double dB = (dSxy * dSx2x2 - dSx2y * dSxx2) / dDenom;
            double dC = dS[0][1] / dS[0][0] - dB * dS[1][0] / dS[0][0] - dA * dS[2][0] / dS[0][0] + dYMean;
            printf("Least-squares fit for %03i - %03i degrees: A=%.3lf B=%.3lf C=%.3lf\n", oct*45, oct*45+45, dA, dB, dC);
            dCoefA[oct] = dA;
            dCoefB[oct] = dB;
            dCoefC[oct] = dC;
            // draw the points
            for (x = startX; x < stopX; x++)
            {
                if (dRmaxByAngle[x] == 0.0)
                    continue;
                int pixX = (int) ((0.5 * dRmaxByAngle[x] *  cos(x * 3.14159265 / 512) + 0.5) * SCREEN_HEIGHT);
                int pixY = (int) ((0.5 * dRmaxByAngle[x] * -sin(x * 3.14159265 / 512) + 0.5) * SCREEN_HEIGHT);
                if (pixY < 1) pixY = 1;
                if (pixY > SCREEN_HEIGHT-2) pixY = SCREEN_HEIGHT-2;
                axis_area[0].x = pixX - 1;
                axis_area[0].y = pixY - 1;
                axis_area[0].w = 3;
                axis_area[0].h = 3;
        		SDL_FillRect(screen, &axis_area[0], 0xF800);
            }
            // draw the curve
            for (x = startX; x < stopX; x += 4)
            {
                double dX0 = (x - startX) / 128.0;
                double dX1 = dX0 + (4.0 / 128.0);
                double dR0 = (dA*dX0*dX0 + dB*dX0 + dC);
                double dR1 = (dA*dX1*dX1 + dB*dX1 + dC);
                int lineX0 = (int) ((0.5 * dR0 *  cos(x * 3.14159265 / 512) + 0.5) * SCREEN_HEIGHT);
                int lineY0 = (int) ((0.5 * dR0 * -sin(x * 3.14159265 / 512) + 0.5) * SCREEN_HEIGHT);
                int lineX1 = (int) ((0.5 * dR1 *  cos((x+4) * 3.14159265 / 512) + 0.5) * SCREEN_HEIGHT);
                int lineY1 = (int) ((0.5 * dR1 * -sin((x+4) * 3.14159265 / 512) + 0.5) * SCREEN_HEIGHT);
                DrawLine(screen, lineX0, lineY0, lineX1, lineY1, 0xffff);
            }
            // refresh the screen
            SDL_UpdateRect(screen, 0, 0, 0, 0);
	    }
	    // find the octant with the maximum area under the curve
	    int iBigOct[2] = { -1, -1 };
	    double dBigArea[2] = { 0.0, 0.0 };
	    for (int oct = 0; oct < 8; oct++)
	    {
	        double dArea = (dCoefA[oct] / 3.0) + (dCoefB[oct] / 2.0) + dCoefC[oct];
	        if (iBigOct[oct&1] == -1 || dArea > dBigArea[oct&1])
	        {
	            iBigOct[oct&1] = oct;
	            dBigArea[oct&1] = dArea;
	        }
	    }
	    printf("Octants %i and %i have the most area\n", iBigOct[0], iBigOct[1]);
	    // draw this curve in blue on each octant
	    double dHardA[2] = {  0.250,  0.228 };
	    double dHardB[2] = { -0.115, -0.361 };
	    double dHardC[2] = {  0.867,  1.000 };
	    for (int oct = 0; oct < 8; oct++)
	    {
            const int startX = oct * 128;
            const int stopX = startX + 128;
            // draw the curve
            //const double dA = dCoefA[iBigOct[oct&1]];
            //const double dB = dCoefB[iBigOct[oct&1]];
            //const double dC = dCoefC[iBigOct[oct&1]];
            const double dA = dHardA[oct&1];
            const double dB = dHardB[oct&1];
            const double dC = dHardC[oct&1];
            for (x = startX; x < stopX; x += 4)
            {
                double dX0 = (x - startX) / 128.0;
                double dX1 = dX0 + (4.0 / 128.0);
                double dR0 = (dA*dX0*dX0 + dB*dX0 + dC);
                double dR1 = (dA*dX1*dX1 + dB*dX1 + dC);
                int lineX0 = (int) ((0.5 * dR0 *  cos(x * 3.14159265 / 512) + 0.5) * SCREEN_HEIGHT);
                int lineY0 = (int) ((0.5 * dR0 * -sin(x * 3.14159265 / 512) + 0.5) * SCREEN_HEIGHT);
                int lineX1 = (int) ((0.5 * dR1 *  cos((x+4) * 3.14159265 / 512) + 0.5) * SCREEN_HEIGHT);
                int lineY1 = (int) ((0.5 * dR1 * -sin((x+4) * 3.14159265 / 512) + 0.5) * SCREEN_HEIGHT);
                DrawLine(screen, lineX0, lineY0, lineX1, lineY1, 0x001f);
            }

	    }
        // refresh the screen
        SDL_UpdateRect(screen, 0, 0, 0, 0);
	    // wait for keypress
       	while (1)
       	{
    		if (SDL_PollEvent(&event))
		    {
			    if (event.type == SDL_KEYDOWN)
			        break;
			}
			SDL_Delay(10);
    	}
	}
	
}

int main(int argc, char *argv[])
{
	const char *name;
	int i;
	SDL_Joystick *joystick;

	/* Initialize SDL (Note: video is required to start event loop) */
	if ( SDL_Init(SDL_INIT_VIDEO|SDL_INIT_JOYSTICK) < 0 ) {
		fprintf(stderr, "Couldn't initialize SDL: %s\n",SDL_GetError());
		exit(1);
	}

	/* Print information about the joysticks */
	printf("There are %d joysticks attached\n", SDL_NumJoysticks());
	for ( i=0; i<SDL_NumJoysticks(); ++i ) {
		name = SDL_JoystickName(i);
		printf("Joystick %d: %s\n",i,name ? name : "Unknown Joystick");
		joystick = SDL_JoystickOpen(i);
		if (joystick == NULL) {
			fprintf(stderr, "SDL_JoystickOpen(%d) failed: %s\n", i, SDL_GetError());
		} else {
			printf("       axes: %d\n", SDL_JoystickNumAxes(joystick));
			printf("      balls: %d\n", SDL_JoystickNumBalls(joystick));
			printf("       hats: %d\n", SDL_JoystickNumHats(joystick));
			printf("    buttons: %d\n", SDL_JoystickNumButtons(joystick));
			SDL_JoystickClose(joystick);
		}
	}

	if ( argv[1] ) {
		joystick = SDL_JoystickOpen(atoi(argv[1]));
		if ( joystick == NULL ) {
			printf("Couldn't open joystick %d: %s\n", atoi(argv[1]),
			       SDL_GetError());
		} else {
			WatchJoystick(joystick);
			SDL_JoystickClose(joystick);
		}
	}
	SDL_QuitSubSystem(SDL_INIT_VIDEO|SDL_INIT_JOYSTICK);

	return(0);
}
