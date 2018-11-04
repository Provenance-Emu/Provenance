#include "gles.h"
#include "rend/rend.h"

#include <algorithm>
/*

Drawing and related state management
Takes vertex, textures and renders to the currently set up target




*/

//Uncomment this to disable the stencil work around
//Seems like there's a bug either on the wrapper, or nvogl making
//stencil not work properly (requiring some double calls to get proper results)
//#define NO_STENCIL_WORKAROUND


const static u32 CullMode[]= 
{

	GL_NONE, //0    No culling          No culling
	GL_NONE, //1    Cull if Small       Cull if ( |det| < fpu_cull_val )

	GL_FRONT, //2   Cull if Negative    Cull if ( |det| < 0 ) or ( |det| < fpu_cull_val )
	GL_BACK,  //3   Cull if Positive    Cull if ( |det| > 0 ) or ( |det| < fpu_cull_val )
};
const static u32 Zfunction[]=
{
	GL_NEVER,      //GL_NEVER,              //0 Never
	GL_LESS,        //GL_LESS/*EQUAL*/,     //1 Less
	GL_EQUAL,       //GL_EQUAL,             //2 Equal
	GL_LEQUAL,      //GL_LEQUAL,            //3 Less Or Equal
	GL_GREATER,     //GL_GREATER/*EQUAL*/,  //4 Greater
	GL_NOTEQUAL,    //GL_NOTEQUAL,          //5 Not Equal
	GL_GEQUAL,      //GL_GEQUAL,            //6 Greater Or Equal
	GL_ALWAYS,      //GL_ALWAYS,            //7 Always
};

/*
0   Zero                  (0, 0, 0, 0)
1   One                   (1, 1, 1, 1)
2   Dither Color          (OR, OG, OB, OA) 
3   Inverse Dither Color  (1-OR, 1-OG, 1-OB, 1-OA)
4   SRC Alpha             (SA, SA, SA, SA)
5   Inverse SRC Alpha     (1-SA, 1-SA, 1-SA, 1-SA)
6   DST Alpha             (DA, DA, DA, DA)
7   Inverse DST Alpha     (1-DA, 1-DA, 1-DA, 1-DA)
*/

const static u32 DstBlendGL[] =
{
	GL_ZERO,
	GL_ONE,
	GL_SRC_COLOR,
	GL_ONE_MINUS_SRC_COLOR,
	GL_SRC_ALPHA,
	GL_ONE_MINUS_SRC_ALPHA,
	GL_DST_ALPHA,
	GL_ONE_MINUS_DST_ALPHA
};

const static u32 SrcBlendGL[] =
{
	GL_ZERO,
	GL_ONE,
	GL_DST_COLOR,
	GL_ONE_MINUS_DST_COLOR,
	GL_SRC_ALPHA,
	GL_ONE_MINUS_SRC_ALPHA,
	GL_DST_ALPHA,
	GL_ONE_MINUS_DST_ALPHA
};

extern int screen_width;
extern int screen_height;

PipelineShader* CurrentShader;
u32 gcflip;

static struct
{
	TSP tsp;
	//TCW tcw;
	PCW pcw;
	ISP_TSP isp;
	u32 clipmode;
	//u32 texture_enabled;
	u32 stencil_modvol_on;
	u32 program;
	GLuint texture;

	void Reset(const PolyParam* gp)
	{
		program=~0;
		texture=~0;
		tsp.full = ~gp->tsp.full;
		//tcw.full = ~gp->tcw.full;
		pcw.full = ~gp->pcw.full;
		isp.full = ~gp->isp.full;
		clipmode=0xFFFFFFFF;
//		texture_enabled=~gp->pcw.Texture;
		stencil_modvol_on=false;
	}
} cache;

s32 SetTileClip(u32 val, bool set)
{
	if (!settings.rend.Clipping)
		return 0;

	/*
	if (set)
	{
		if (cache.clipmode==val)
			return clip_mode;
		cache.clipmode=val;
	}*/

	u32 clipmode=val>>28;
	s32 clip_mode;
	if (clipmode<2)
	{
		clip_mode=0;    //always passes
	}
	else if (clipmode&1)
		clip_mode=-1;   //render stuff outside the region
	else
		clip_mode=1;    //render stuff inside the region

	float csx=0,csy=0,cex=0,cey=0;


	csx=(float)(val&63);
	cex=(float)((val>>6)&63);
	csy=(float)((val>>12)&31);
	cey=(float)((val>>17)&31);
	csx=csx*32;
	cex=cex*32 +32;
	csy=csy*32;
	cey=cey*32 +32;

	if (csx <= 0 && csy <= 0 && cex >= 640 && cey >= 480)
		return 0;
	
	if (set && clip_mode) {
		csy = 480 - csy;
		cey = 480 - cey;
		float dc2s_scale_h = screen_height / 480.0f;
		float ds2s_offs_x = (screen_width - dc2s_scale_h * 640) / 2;
		csx = csx * dc2s_scale_h + ds2s_offs_x;
		cex = cex * dc2s_scale_h + ds2s_offs_x;
		csy = csy * dc2s_scale_h;
		cey = cey * dc2s_scale_h;
		glUniform4f(CurrentShader->pp_ClipTest, csx, cey, cex, csy);
	}

	return clip_mode;
}

void SetCull(u32 CulliMode)
{
	if (CullMode[CulliMode]==GL_NONE)
	{ 
		glDisable(GL_CULL_FACE);
	}
	else
	{
		glEnable(GL_CULL_FACE);
		glCullFace(CullMode[CulliMode]); //GL_FRONT/GL_BACK, ...
	}
}

template <u32 Type, bool SortingEnabled>
__forceinline
	void SetGPState(const PolyParam* gp,u32 cflip=0)
{
	//has to preserve cache_tsp/cache_isp
	//can freely use cache_tcw
	CurrentShader=&gl.pogram_table[GetProgramID(Type==ListType_Punch_Through?1:0,SetTileClip(gp->tileclip,false)+1,gp->pcw.Texture,gp->tsp.UseAlpha,gp->tsp.IgnoreTexA,gp->tsp.ShadInstr,gp->pcw.Offset,gp->tsp.FogCtrl)];
	
	if (CurrentShader->program == -1)
		CompilePipelineShader(CurrentShader);
	if (CurrentShader->program != cache.program)
	{
		cache.program=CurrentShader->program;
		glUseProgram(CurrentShader->program);
	}
	SetTileClip(gp->tileclip,true);

	//This for some reason doesn't work properly
	//So, shadow bit emulation is disabled.
	//This bit normally control which pixels are affected
	//by modvols
#ifdef NO_STENCIL_WORKAROUND
	const u32 stencil=(gp->pcw.Shadow!=0)?0x80:0x0;
#else
	//force everything to be shadowed
	const u32 stencil=0x80;
#endif

	if (cache.stencil_modvol_on!=stencil)
	{
		cache.stencil_modvol_on=stencil;

		glStencilFunc(GL_ALWAYS,stencil,stencil);
	}

	if (gp->texid != cache.texture)
	{
		cache.texture=gp->texid;
		if (gp->texid != -1) {
			//verify(glIsTexture(gp->texid));
			glBindTexture(GL_TEXTURE_2D, gp->texid);
		}
	}

	if (gp->tsp.full!=cache.tsp.full)
	{
		cache.tsp=gp->tsp;

		if (Type==ListType_Translucent)
		{
			glBlendFunc(SrcBlendGL[gp->tsp.SrcInstr],DstBlendGL[gp->tsp.DstInstr]);

#ifdef WEIRD_SLOWNESS
			//SGX seems to be super slow with discard enabled blended pixels
			//can't cache this -- due to opengl shader api
			bool clip_alpha_on_zero=gp->tsp.SrcInstr==4 && (gp->tsp.DstInstr==1 || gp->tsp.DstInstr==5);
			glUniform1f(CurrentShader->cp_AlphaTestValue,clip_alpha_on_zero?(1/255.f):(-2.f));
#endif
		}
	}

	//set cull mode !
	//cflip is required when exploding triangles for triangle sorting
	//gcflip is global clip flip, needed for when rendering to texture due to mirrored Y direction
	SetCull(gp->isp.CullMode^cflip^gcflip);


	if (gp->isp.full!= cache.isp.full)
	{
		cache.isp.full=gp->isp.full;

		//set Z mode, only if required
		if (!(Type==ListType_Punch_Through || (Type==ListType_Translucent && SortingEnabled)))
			glDepthFunc(Zfunction[gp->isp.DepthMode]);
		
#if TRIG_SORT
		if (SortingEnabled)
			glDepthMask(GL_FALSE);
		else
#endif
			glDepthMask(!gp->isp.ZWriteDis);
	}
}

template <u32 Type, bool SortingEnabled>
void DrawList(const List<PolyParam>& gply)
{
	PolyParam* params=gply.head();
	int count=gply.used();


	if (count==0)
		return;
	//we want at least 1 PParam


	//reset the cache state
	cache.Reset(params);

	//set some 'global' modes for all primitives

	//Z funct. can be fixed on these combinations, avoid setting it all the time
	if (Type==ListType_Punch_Through || (Type==ListType_Translucent && SortingEnabled))
		glDepthFunc(Zfunction[6]);

	glEnable(GL_STENCIL_TEST);
	glStencilFunc(GL_ALWAYS,0,0);
	glStencilOp(GL_KEEP,GL_KEEP,GL_REPLACE);

#ifndef NO_STENCIL_WORKAROUND
	//This looks like a driver bug
	glStencilOp(GL_KEEP,GL_KEEP,GL_REPLACE);
#endif

	while(count-->0)
	{
		if (params->count>2) //this actually happens for some games. No idea why ..
		{
			SetGPState<Type,SortingEnabled>(params);
			glDrawElements(GL_TRIANGLE_STRIP, params->count, GL_UNSIGNED_SHORT, (GLvoid*)(2*params->first)); glCheck();
		}

		params++;
	}
}

bool operator<(const PolyParam &left, const PolyParam &right)
{
/* put any condition you want to sort on here */
	return left.zvZ<right.zvZ;
	//return left.zMin<right.zMax;
}

//Sort based on min-z of each strip
void SortPParams()
{
	if (pvrrc.verts.used()==0 || pvrrc.global_param_tr.used()<=1)
		return;

	Vertex* vtx_base=pvrrc.verts.head();
	u16* idx_base=pvrrc.idx.head();

	PolyParam* pp=pvrrc.global_param_tr.head();
	PolyParam* pp_end= pp + pvrrc.global_param_tr.used();

	while(pp!=pp_end)
	{
		if (pp->count<2)
		{
			pp->zvZ=0;
		}
		else
		{
			u16* idx=idx_base+pp->first;

			Vertex* vtx=vtx_base+idx[0];
			Vertex* vtx_end=vtx_base + idx[pp->count-1]+1;

			u32 zv=0xFFFFFFFF;
			while(vtx!=vtx_end)
			{
				zv=min(zv,(u32&)vtx->z);
				vtx++;
			}

			pp->zvZ=(f32&)zv;
		}
		pp++;
	}

	std::stable_sort(pvrrc.global_param_tr.head(),pvrrc.global_param_tr.head()+pvrrc.global_param_tr.used());
}

Vertex* vtx_sort_base;


struct IndexTrig
{
	u16 id[3];
	u16 pid;
	f32 z;
};


struct SortTrigDrawParam
{
	PolyParam* ppid;
	u16 first;
	u16 count;
};

float min3(float v0,float v1,float v2)
{
	return min(min(v0,v1),v2);
}

float max3(float v0,float v1,float v2)
{
	return max(max(v0,v1),v2);
}


float minZ(Vertex* v,u16* mod)
{
	return min(min(v[mod[0]].z,v[mod[1]].z),v[mod[2]].z);
}

bool operator<(const IndexTrig &left, const IndexTrig &right)
{
	return left.z<right.z;
}


#if 0
/*

	Per triangle sorting experiments

*/

//approximate the triangle area
float area_x2(Vertex* v)
{
	return 2/3*fabs( (v[0].x-v[2].x)*(v[1].y-v[0].y) - (v[0].x-v[1].x)*(v[2].y-v[0].y)) ;
}

//approximate the distance ^2
float distance_apprx(Vertex* a, Vertex* b)
{
	float xd=a->x-b->x;
	float yd=a->y-b->y;

	return xd*xd+yd*yd;
}

//was good idea, but not really working ..
bool Intersect(Vertex* a, Vertex* b)
{
	float a1=area_x2(a);
	float a2=area_x2(b);

	float d = distance_apprx(a,b);

	return (a1+a1)>d;
}

//root for quick-union
u16 rid(vector<u16>& v, u16 id)
{
	while(id!=v[id]) id=v[id];
	return id;
}

struct TrigBounds
{
	float xs,xe;
	float ys,ye;
	float zs,ze;
};

//find 3d bounding box for triangle
TrigBounds bound(Vertex* v)
{
	TrigBounds rv = {	min(min(v[0].x,v[1].x),v[2].x), max(max(v[0].x,v[1].x),v[2].x),
						min(min(v[0].y,v[1].y),v[2].y), max(max(v[0].y,v[1].y),v[2].y),
						min(min(v[0].z,v[1].z),v[2].z), max(max(v[0].z,v[1].z),v[2].z),
					};

	return rv;
}

//bounding box 2d intersection
bool Intersect(TrigBounds& a, TrigBounds& b)
{
	return  ( !(a.xe<b.xs || a.xs>b.xe) && !(a.ye<b.ys || a.ys>b.ye) /*&& !(a.ze<b.zs || a.zs>b.ze)*/ );
}


bool operator<(const IndexTrig &left, const IndexTrig &right)
{
	/*
	TrigBounds l=bound(vtx_sort_base+left.id);
	TrigBounds r=bound(vtx_sort_base+right.id);

	if (!Intersect(l,r))
	{
		return true;
	}
	else
	{
		return (l.zs + l.ze) < (r.zs + r.ze);
	}*/

	return minZ(&vtx_sort_base[left.id])<minZ(&vtx_sort_base[right.id]);
}

//Not really working cuz of broken intersect
bool Intersect(const IndexTrig &left, const IndexTrig &right)
{
	TrigBounds l=bound(vtx_sort_base+left.id);
	TrigBounds r=bound(vtx_sort_base+right.id);

	return Intersect(l,r);
}

#endif

//are two poly params the same?
bool PP_EQ(PolyParam* pp0, PolyParam* pp1)
{
	return (pp0->pcw.full&PCW_DRAW_MASK)==(pp1->pcw.full&PCW_DRAW_MASK) && pp0->isp.full==pp1->isp.full && pp0->tcw.full==pp1->tcw.full && pp0->tsp.full==pp1->tsp.full && pp0->tileclip==pp1->tileclip;
}

static vector<SortTrigDrawParam>	pidx_sort;

void fill_id(u16* d, Vertex* v0, Vertex* v1, Vertex* v2,  Vertex* vb)
{
	d[0]=v0-vb;
	d[1]=v1-vb;
	d[2]=v2-vb;
}

void GenSorted()
{
	u32 tess_gen=0;

	pidx_sort.clear();

	if (pvrrc.verts.used()==0 || pvrrc.global_param_tr.used()<=1)
		return;

	Vertex* vtx_base=pvrrc.verts.head();
	u16* idx_base=pvrrc.idx.head();

	PolyParam* pp_base=pvrrc.global_param_tr.head();
	PolyParam* pp=pp_base;
	PolyParam* pp_end= pp + pvrrc.global_param_tr.used();
	
	Vertex* vtx_arr=vtx_base+idx_base[pp->first];
	vtx_sort_base=vtx_base;

	static u32 vtx_cnt;

	int vtx_count=idx_base[pp_end[-1].first+pp_end[-1].count-1]-idx_base[pp->first];
	if (vtx_count>vtx_cnt)
		vtx_cnt=vtx_count;

#if PRINT_SORT_STATS
	printf("TVTX: %d || %d\n",vtx_cnt,vtx_count);
#endif
	
	if (vtx_count<=0)
		return;

	//make lists of all triangles, with their pid and vid
	static vector<IndexTrig> lst;
	
	lst.resize(vtx_count*4);
	

	int pfsti=0;

	while(pp!=pp_end)
	{
		u32 ppid=(pp-pp_base);

		if (pp->count>2)
		{
			u16* idx=idx_base+pp->first;

			Vertex* vtx=vtx_base+idx[0];
			Vertex* vtx_end=vtx_base + idx[pp->count-1]-1;
			u32 flip=0;
			while(vtx!=vtx_end)
			{
				Vertex* v0, * v1, * v2, * v3, * v4, * v5;

				if (flip)
				{
					v0=&vtx[2];
					v1=&vtx[1];
					v2=&vtx[0];
				}
				else
				{
					v0=&vtx[0];
					v1=&vtx[1];
					v2=&vtx[2];
				}

				if (settings.pvr.subdivide_transp)
				{
					u32 tess_x=(max3(v0->x,v1->x,v2->x)-min3(v0->x,v1->x,v2->x))/32;
					u32 tess_y=(max3(v0->y,v1->y,v2->y)-min3(v0->y,v1->y,v2->y))/32;

					if (tess_x==1) tess_x=0;
					if (tess_y==1) tess_y=0;

					//bool tess=(maxZ(v0,v1,v2)/minZ(v0,v1,v2))>=1.2;

					if (tess_x + tess_y)
					{
						v3=pvrrc.verts.Append(3);
						v4=v3+1;
						v5=v4+1;

						//xyz
						for (int i=0;i<3;i++)
						{
							((float*)&v3->x)[i]=((float*)&v0->x)[i]*0.5f+((float*)&v2->x)[i]*0.5f;
							((float*)&v4->x)[i]=((float*)&v0->x)[i]*0.5f+((float*)&v1->x)[i]*0.5f;
							((float*)&v5->x)[i]=((float*)&v1->x)[i]*0.5f+((float*)&v2->x)[i]*0.5f;
						}

						//*TODO* Make it perspective correct

						//uv
						for (int i=0;i<2;i++)
						{
							((float*)&v3->u)[i]=((float*)&v0->u)[i]*0.5f+((float*)&v2->u)[i]*0.5f;
							((float*)&v4->u)[i]=((float*)&v0->u)[i]*0.5f+((float*)&v1->u)[i]*0.5f;
							((float*)&v5->u)[i]=((float*)&v1->u)[i]*0.5f+((float*)&v2->u)[i]*0.5f;
						}

						//color
						for (int i=0;i<4;i++)
						{
							v3->col[i]=v0->col[i]/2+v2->col[i]/2;
							v4->col[i]=v0->col[i]/2+v1->col[i]/2;
							v5->col[i]=v1->col[i]/2+v2->col[i]/2;
						}

						fill_id(lst[pfsti].id,v0,v3,v4,vtx_base);
						lst[pfsti].pid= ppid ;
						lst[pfsti].z = minZ(vtx_base,lst[pfsti].id);
						pfsti++;

						fill_id(lst[pfsti].id,v2,v3,v5,vtx_base);
						lst[pfsti].pid= ppid ;
						lst[pfsti].z = minZ(vtx_base,lst[pfsti].id);
						pfsti++;

						fill_id(lst[pfsti].id,v3,v4,v5,vtx_base);
						lst[pfsti].pid= ppid ;
						lst[pfsti].z = minZ(vtx_base,lst[pfsti].id);
						pfsti++;

						fill_id(lst[pfsti].id,v5,v4,v1,vtx_base);
						lst[pfsti].pid= ppid ;
						lst[pfsti].z = minZ(vtx_base,lst[pfsti].id);
						pfsti++;

						tess_gen+=3;
					}
					else
					{
						fill_id(lst[pfsti].id,v0,v1,v2,vtx_base);
						lst[pfsti].pid= ppid ;
						lst[pfsti].z = minZ(vtx_base,lst[pfsti].id);
						pfsti++;
					}
				}
				else
				{
					fill_id(lst[pfsti].id,v0,v1,v2,vtx_base);
					lst[pfsti].pid= ppid ;
					lst[pfsti].z = minZ(vtx_base,lst[pfsti].id);
					pfsti++;
				}

				flip ^= 1;
				
				vtx++;
			}
		}
		pp++;
	}

	u32 aused=pfsti;

	lst.resize(aused);

	//sort them
#if 1
	std::stable_sort(lst.begin(),lst.end());

	//Merge pids/draw cmds if two different pids are actually equal
	if (true)
	{
		for (u32 k=1;k<aused;k++)
		{
			if (lst[k].pid!=lst[k-1].pid)
			{
				if (PP_EQ(&pp_base[lst[k].pid],&pp_base[lst[k-1].pid]))
				{
					lst[k].pid=lst[k-1].pid;
				}
			}
		}
	}
#endif

	
#if 0
	//tries to optimise draw calls by reordering non-intersecting polygons
	//uber slow and not very effective
	{
		int opid=lst[0].pid;

		for (int k=1;k<aused;k++)
		{
			if (lst[k].pid!=opid)
			{
				if (opid>lst[k].pid)
				{
					//MOVE UP
					for (int j=k;j>0 && lst[j].pid!=lst[j-1].pid && !Intersect(lst[j],lst[j-1]);j--)
					{
						swap(lst[j],lst[j-1]);
					}
				}
				else
				{
					//move down
					for (int j=k+1;j<aused && lst[j].pid!=lst[j-1].pid && !Intersect(lst[j],lst[j-1]);j++)
					{
						swap(lst[j],lst[j-1]);
					}
				}
			}

			opid=lst[k].pid;
		}
	}
#endif

	//re-assemble them into drawing commands
	static vector<u16> vidx_sort;

	vidx_sort.resize(aused*3);

	int idx=-1;

	for (u32 i=0; i<aused; i++)
	{
		int pid=lst[i].pid;
		u16* midx=lst[i].id;

		vidx_sort[i*3 + 0]=midx[0];
		vidx_sort[i*3 + 1]=midx[1];
		vidx_sort[i*3 + 2]=midx[2];

		if (idx!=pid /* && !PP_EQ(&pp_base[pid],&pp_base[idx]) */ )
		{
			SortTrigDrawParam stdp={pp_base + pid, (u16)(i*3), 0};
			
			if (idx!=-1)
			{
				SortTrigDrawParam* last=&pidx_sort[pidx_sort.size()-1];
				last->count=stdp.first-last->first;
			}

			pidx_sort.push_back(stdp);
			idx=pid;
		}
	}

	SortTrigDrawParam* stdp=&pidx_sort[pidx_sort.size()-1];
	stdp->count=aused*3-stdp->first;

#if PRINT_SORT_STATS
	printf("Reassembled into %d from %d\n",pidx_sort.size(),pp_end-pp_base);
#endif

	//Upload to GPU if needed
	if (pidx_sort.size())
	{
		//Bind and upload sorted index buffer
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, gl.vbo.idxs2); glCheck();
		glBufferData(GL_ELEMENT_ARRAY_BUFFER,vidx_sort.size()*2,&vidx_sort[0],GL_STREAM_DRAW);

		if (tess_gen) printf("Generated %.2fK Triangles !\n",tess_gen/1000.0);
	}
}

void DrawSorted()
{
	//if any drawing commands, draw them
	if (pidx_sort.size())
	{
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, gl.vbo.idxs2); glCheck();

		u32 count=pidx_sort.size();
		
		{
			cache.Reset(pidx_sort[0].ppid);

			//set some 'global' modes for all primitives

			//Z sorting is fixed for .. sorted stuff
			glDepthFunc(Zfunction[6]);

			glEnable(GL_STENCIL_TEST);
			glStencilFunc(GL_ALWAYS,0,0);
			glStencilOp(GL_KEEP,GL_KEEP,GL_REPLACE);

		#ifndef NO_STENCIL_WORKAROUND
			//This looks like a driver bug
			glStencilOp(GL_KEEP,GL_KEEP,GL_REPLACE);
		#endif

			for (u32 p=0; p<count; p++)
			{
				PolyParam* params = pidx_sort[p].ppid;
				if (pidx_sort[p].count>2) //this actually happens for some games. No idea why ..
				{
					SetGPState<ListType_Translucent,true>(params);
					glDrawElements(GL_TRIANGLES, pidx_sort[p].count, GL_UNSIGNED_SHORT, (GLvoid*)(2*pidx_sort[p].first)); glCheck();
				
#if 0
					//Verify restriping -- only valid if no sort
					int fs=pidx_sort[p].first;

					for (u32 j=0; j<(params->count-2); j++)
					{
						for (u32 k=0; k<3; k++)
						{
							verify(idx_base[params->first+j+k]==vidx_sort[fs++]);
						}
					}

					verify(fs==(pidx_sort[p].first+pidx_sort[p].count));
#endif
				}
				params++;
			}
		}
	}
}

//All pixels are in area 0 by default.
//If inside an 'in' volume, they are in area 1
//if inside an 'out' volume, they are in area 0
/*
	Stencil bits:
		bit 7: mv affected (must be preserved)
		bit 1: current volume state
		but 0: summary result (starts off as 0)

	Lower 2 bits:

	IN volume (logical OR):
	00 -> 00
	01 -> 01
	10 -> 01
	11 -> 01

	Out volume (logical AND):
	00 -> 00
	01 -> 00
	10 -> 00
	11 -> 01
*/
void SetMVS_Mode(u32 mv_mode,ISP_Modvol ispc)
{
	if (mv_mode==0)	//normal trigs
	{
		//set states
		glEnable(GL_DEPTH_TEST);
		//write only bit 1
		glStencilMask(2);
		//no stencil testing
		glStencilFunc(GL_ALWAYS,0,2);
		//count the number of pixels in front of the Z buffer (and only keep the lower bit of the count)
		glStencilOp(GL_KEEP,GL_KEEP,GL_INVERT);
#ifndef NO_STENCIL_WORKAROUND
		//this needs to be done .. twice ? looks like
		//a bug somewhere, on gles/nvgl ?
		glStencilOp(GL_KEEP,GL_KEEP,GL_INVERT);
#endif
		//Cull mode needs to be set
		SetCull(ispc.CullMode);
	}
	else
	{
		//1 (last in) or 2 (last out)
		//each triangle forms the last of a volume

		//common states

		//no depth test
		glDisable(GL_DEPTH_TEST);
		//write bits 1:0
		glStencilMask(3);

		if (mv_mode==1)
		{
			// Inclusion volume
			//res : old : final 
			//0   : 0      : 00
			//0   : 1      : 01
			//1   : 0      : 01
			//1   : 1      : 01
			

			//if (1<=st) st=1; else st=0;
			glStencilFunc(GL_LEQUAL,1,3);
			glStencilOp(GL_ZERO,GL_ZERO,GL_REPLACE);
#ifndef NO_STENCIL_WORKAROUND
			//Look @ comment above -- this looks like a driver bug
			glStencilOp(GL_ZERO,GL_ZERO,GL_REPLACE);
#endif

			/*
			//if !=0 -> set to 10
			verifyc(dev->SetRenderState(D3DRS_STENCILFUNC,D3DCMP_LESSEQUAL));
			verifyc(dev->SetRenderState(D3DRS_STENCILREF,1));					
			verifyc(dev->SetRenderState(D3DRS_STENCILPASS,D3DSTENCILOP_REPLACE));
			verifyc(dev->SetRenderState(D3DRS_STENCILFAIL,D3DSTENCILOP_ZERO));
			*/
		}
		else
		{
			// Exclusion volume
			/*
				I've only seen a single game use it, so i guess it doesn't matter ? (Zombie revenge)
				(actually, i think there was also another, racing game)
			*/

			// The initial value for exclusion volumes is 1 so we need to invert the result before and'ing.
			//res : old : final 
			//0   : 0   : 00
			//0   : 1   : 01
			//1   : 0   : 00
			//1   : 1   : 00

			//if (1 == st) st = 1; else st = 0;
			glStencilFunc(GL_EQUAL, 1, 3);
			glStencilOp(GL_ZERO,GL_KEEP,GL_KEEP);
#ifndef NO_STENCIL_WORKAROUND
			//Look @ comment above -- this looks like a driver bug
			glStencilOp(GL_ZERO,GL_KEEP,GL_REPLACE);
#endif
		}
	}
}


void SetupMainVBO()
{
#ifndef GLES
	glBindVertexArray(gl.vbo.vao);
#endif

	glBindBuffer(GL_ARRAY_BUFFER, gl.vbo.geometry); glCheck();
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, gl.vbo.idxs); glCheck();

	//setup vertex buffers attrib pointers
	glEnableVertexAttribArray(VERTEX_POS_ARRAY); glCheck();
	glVertexAttribPointer(VERTEX_POS_ARRAY, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), (void*)offsetof(Vertex,x)); glCheck();

	glEnableVertexAttribArray(VERTEX_COL_BASE_ARRAY); glCheck();
	glVertexAttribPointer(VERTEX_COL_BASE_ARRAY, 4, GL_UNSIGNED_BYTE, GL_TRUE, sizeof(Vertex), (void*)offsetof(Vertex,col)); glCheck();

	glEnableVertexAttribArray(VERTEX_COL_OFFS_ARRAY); glCheck();
	glVertexAttribPointer(VERTEX_COL_OFFS_ARRAY, 4, GL_UNSIGNED_BYTE, GL_TRUE, sizeof(Vertex), (void*)offsetof(Vertex,spc)); glCheck();

	glEnableVertexAttribArray(VERTEX_UV_ARRAY); glCheck();
	glVertexAttribPointer(VERTEX_UV_ARRAY, 2, GL_FLOAT, GL_FALSE, sizeof(Vertex), (void*)offsetof(Vertex,u)); glCheck();
}

void SetupModvolVBO()
{
#ifndef GLES
	glBindVertexArray(gl.vbo.vao);
#endif

	glBindBuffer(GL_ARRAY_BUFFER, gl.vbo.modvols); glCheck();

	//setup vertex buffers attrib pointers
	glEnableVertexAttribArray(VERTEX_POS_ARRAY); glCheck();
	glVertexAttribPointer(VERTEX_POS_ARRAY, 3, GL_FLOAT, GL_FALSE, sizeof(float)*3, (void*)0); glCheck();

	glDisableVertexAttribArray(VERTEX_UV_ARRAY);
	glDisableVertexAttribArray(VERTEX_COL_OFFS_ARRAY);
	glDisableVertexAttribArray(VERTEX_COL_BASE_ARRAY);
}
void DrawModVols()
{
	if (pvrrc.modtrig.used()==0 /*|| GetAsyncKeyState(VK_F4)*/)
		return;

	SetupModvolVBO();

	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

	glUseProgram(gl.modvol_shader.program);
	glUniform1f(gl.modvol_shader.sp_ShaderColor,0.5f);

	glDepthMask(GL_FALSE);
	glDepthFunc(GL_GREATER);

	if(0 /*|| GetAsyncKeyState(VK_F5)*/ )
	{
		//simply draw the volumes -- for debugging
		SetCull(0);
		glDrawArrays(GL_TRIANGLES,0,pvrrc.modtrig.used()*3);
		SetupMainVBO();
	}
	else
	{
		/*
		mode :
		normal trig : flip
		last *in*   : flip, merge*in* &clear from last merge
		last *out*  : flip, merge*out* &clear from last merge
		*/

		/*

			Do not write to color
			Do not write to depth

			read from stencil bits 1:0
			write to stencil bits 1:0
		*/

		glColorMask(GL_FALSE,GL_FALSE,GL_FALSE,GL_FALSE);

		if ( 0 /* || GetAsyncKeyState(VK_F6)*/ )
		{
			//simple single level stencil
			glEnable(GL_STENCIL_TEST);
			glStencilFunc(GL_ALWAYS,0x1,0x1);
			glStencilOp(GL_KEEP,GL_KEEP,GL_INVERT);
#ifndef NO_STENCIL_WORKAROUND
			//looks like a driver bug
			glStencilOp(GL_KEEP,GL_KEEP,GL_INVERT);
#endif
			glStencilMask(0x1);
			SetCull(0);
			glDrawArrays(GL_TRIANGLES,0,pvrrc.modtrig.used()*3);
		}
		else if (true)
		{
			//Full emulation
			//the *out* mode is buggy

			u32 mod_base=0; //cur start triangle
			u32 mod_last=0; //last merge

			u32 cmv_count=(pvrrc.global_param_mvo.used()-1);
			ISP_Modvol* params=pvrrc.global_param_mvo.head();

			//ISP_Modvol
			for (u32 cmv=0;cmv<cmv_count;cmv++)
			{

				ISP_Modvol ispc=params[cmv];
				mod_base=ispc.id;
				u32 sz=params[cmv+1].id-mod_base;

				u32 mv_mode = ispc.DepthMode;


				if (mv_mode==0)	//normal trigs
				{
					SetMVS_Mode(0,ispc);
					//Render em (counts intersections)
					//verifyc(dev->DrawPrimitiveUP(D3DPT_TRIANGLELIST,sz,pvrrc.modtrig.data+mod_base,3*4));
					glDrawArrays(GL_TRIANGLES,mod_base*3,sz*3);
				}
				else if (mv_mode<3)
				{
					while(sz)
					{
						//merge and clear all the prev. stencil bits

						//Count Intersections (last poly)
						SetMVS_Mode(0,ispc);
						glDrawArrays(GL_TRIANGLES,mod_base*3,3);

						//Sum the area
						SetMVS_Mode(mv_mode,ispc);
						glDrawArrays(GL_TRIANGLES,mod_last*3,(mod_base-mod_last+1)*3);

						//update pointers
						mod_last=mod_base+1;
						sz--;
						mod_base++;
					}
				}
			}
		}
		//disable culling
		SetCull(0);
		//enable color writes
		glColorMask(GL_TRUE,GL_TRUE,GL_TRUE,GL_TRUE);

		//black out any stencil with '1'
		glEnable(GL_BLEND);
		glBlendFunc(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA);
		
		glEnable(GL_STENCIL_TEST);
		glStencilFunc(GL_EQUAL,0x81,0x81); //only pixels that are Modvol enabled, and in area 1
		
		//clear the stencil result bit
		glStencilMask(0x3);    //write to lsb 
		glStencilOp(GL_ZERO,GL_ZERO,GL_ZERO);
#ifndef NO_STENCIL_WORKAROUND
		//looks like a driver bug ?
		glStencilOp(GL_ZERO,GL_ZERO,GL_ZERO);
#endif

		//don't do depth testing
		glDisable(GL_DEPTH_TEST);

		SetupMainVBO();
		glDrawArrays(GL_TRIANGLE_STRIP,0,4);

		//Draw and blend
		//glDrawArrays(GL_TRIANGLES,pvrrc.modtrig.used(),2);

	}

	//restore states
	glDepthMask(GL_TRUE);
	glDisable(GL_BLEND);
	glEnable(GL_DEPTH_TEST);
	glDisable(GL_STENCIL_TEST);
}

void DrawStrips()
{
	SetupMainVBO();
	//Draw the strips !

	//initial state
	glDisable(GL_BLEND); glCheck();
	glEnable(GL_DEPTH_TEST);

	//We use sampler 0
	glActiveTexture(GL_TEXTURE0);

	//Opaque
	//Nothing extra needs to be setup here
	/*if (!GetAsyncKeyState(VK_F1))*/
	DrawList<ListType_Opaque,false>(pvrrc.global_param_op);

	if (settings.rend.ModifierVolumes)
		DrawModVols();

	//Alpha tested
	//setup alpha test state
	/*if (!GetAsyncKeyState(VK_F2))*/
	DrawList<ListType_Punch_Through,false>(pvrrc.global_param_pt);


	//Alpha blended
	//Setup blending
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	/*if (!GetAsyncKeyState(VK_F3))*/
	{
		/*
		if (UsingAutoSort())
			SortRendPolyParamList(pvrrc.global_param_tr);
		else
			*/
#if TRIG_SORT
		if (pvrrc.isAutoSort)
			DrawSorted();
		else
			DrawList<ListType_Translucent,false>(pvrrc.global_param_tr);
#else
		if (pvrrc.isAutoSort)
			SortPParams();
		DrawList<ListType_Translucent,true>(pvrrc.global_param_tr);
#endif
	}
}
